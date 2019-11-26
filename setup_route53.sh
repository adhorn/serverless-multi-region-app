#!/usr/bin/env bash
set -e

REGIONS=${REGIONS:-"us-west-2 us-east-1"}
AWS_PROFILE=${AWS_PROFILE:-"default"}
AWS_ROUTE53_PROFILE=${AWS_ROUTE53_PROFILE:-$AWS_PROFILE}
APP_ENV=${APP_ENV:-"dev"}
STACKNAME=globalAppwithVPC-${APP_ENV:-"dev"}
DOMAIN=${DOMAIN:-"adhorn.me"}
SUBDOMAIN=globalvpc.${DOMAIN}

TRAFFIC_POLICY_ENDPOINTS=()
TRAFFIC_POLICY_RULES=()

i=0
for REGION in ${REGIONS[@]}; do
    ((i++))

    DOMAIN_NAME=$(aws cloudformation describe-stacks --stack-name ${STACKNAME} --region ${REGION} --output text \
                                       --query 'Stacks[0].Outputs[?OutputKey==`ServiceEndpoint`].OutputValue' \
                                       --profile ${AWS_PROFILE} \
                                       | sed 's/https:\/\///g' | sed "s/\/${APP_ENV}//g")
    REGIONAL_DOMAIN=$(aws apigateway get-domain-name --domain-name ${SUBDOMAIN} --region ${REGION} \
                                                     --query 'regionalDomainName' --profile ${AWS_PROFILE})

    # Create HealthChecks and tag them
    HEALTHCHECK=$(aws route53 create-health-check --caller-reference $(date "+%Y%m%d%H%M%S") \
                                          --health-check-config Type=HTTPS,ResourcePath="/${APP_ENV}/health",FullyQualifiedDomainName=${DOMAIN_NAME},RequestInterval=10,FailureThreshold=1 \
                                          --profile ${AWS_ROUTE53_PROFILE} --output text --query 'HealthCheck.Id')
    aws route53 change-tags-for-resource --resource-type healthcheck --resource-id ${HEALTHCHECK} \
                                               --add-tags Key=Name,Value=${STACKNAME}-${REGION} \
                                               --profile ${AWS_ROUTE53_PROFILE}

    # Build up policy endpoint & rules for later
    TRAFFIC_POLICY_ENDPOINTS+=("\"srv$i\": {\"Type\": \"value\", \"Value\": ${REGIONAL_DOMAIN}}")

    # Setting Weight to 0 for all of the records in the group, traffic is routed to all resources with equal probability.
    # See: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-values-weighted.html#rrsets-values-weighted-weight
    TRAFFIC_POLICY_RULES+=("{\"EndpointReference\": \"srv$i\", \"Weight\": \"0\", \"EvaluateTargetHealth\": \"true\", \"HealthCheck\": \"${HEALTHCHECK}\"}")
done

TRAFFIC_POLICY_DOCUMENT=$(cat <<HEREDOC
{
    "AWSPolicyFormatVersion": "2015-10-01",
    "RecordType": "CNAME",
    "StartRule": "round_robin",
    "Endpoints": {$(IFS=, ; echo "${TRAFFIC_POLICY_ENDPOINTS[*]}")},
    "Rules":{
        "round_robin": {
            "RuleType": "weighted",
            "Items": [
                $(echo $(IFS=, ; echo "${TRAFFIC_POLICY_RULES[*]}"))
            ]
        }
    }
}
HEREDOC
)

# Create Routing policy
TRAFFIC_POLICY=$(aws route53 create-traffic-policy \
    --name ${STACKNAME} \
    --document "${TRAFFIC_POLICY_DOCUMENT}" \
    --profile ${AWS_ROUTE53_PROFILE} \
    --output text \
    --query 'TrafficPolicy.Id'
)

#  Get the Zone id to create a policy record on the domain
HOSTEDZONE=$(aws route53 list-hosted-zones --query 'HostedZones[?Name==`'${DOMAIN}'.`].Id' \
                                           --output text --profile ${AWS_ROUTE53_PROFILE})

# create a policy record on the domain with the routing policy
POLICY_RECORD=$(aws route53 create-traffic-policy-instance --traffic-policy-id ${TRAFFIC_POLICY} \
                                                           --hosted-zone-id ${HOSTEDZONE} --ttl 60 \
                                                           --name "${SUBDOMAIN}" --traffic-policy-version 1 \
                                                           --profile ${AWS_ROUTE53_PROFILE})

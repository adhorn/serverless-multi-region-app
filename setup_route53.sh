DOMAIN=adhorn.me
SUBDOMAIN=globalvpc.${DOMAIN}
REGION1=us-west-2
REGION2=us-east-1
STACKNAME=globalAppwithVPC-dev
PROFILE=adrian-private

USWEST2DOMAIN=$(aws cloudformation describe-stacks --stack-name ${STACKNAME} --region ${REGION1} --output text --query 'Stacks[0].Outputs[?OutputKey==`ServiceEndpoint`].OutputValue' | sed 's/https:\/\///g' | sed 's/\/dev//g')
USEAST1DOMAIN=$(aws cloudformation describe-stacks --stack-name ${STACKNAME} --region ${REGION2} --output text --query 'Stacks[0].Outputs[?OutputKey==`ServiceEndpoint`].OutputValue' | sed 's/https:\/\///g' | sed 's/\/dev//g')

USWEST2REG=$(aws apigateway get-domain-name --domain-name ${SUBDOMAIN} --region ${REGION1} --query 'regionalDomainName') 
USEAST1REG=$(aws apigateway get-domain-name --domain-name ${SUBDOMAIN} --region ${REGION2} --query 'regionalDomainName')


# Create HealthChecks and tag them
HEALTHCHECK1=$(aws route53 create-health-check  --caller-reference $(date "+%Y%m%d%H%M%S") --health-check-config Type=HTTPS,ResourcePath="/dev/health",FullyQualifiedDomainName=${USWEST2DOMAIN},RequestInterval=10,FailureThreshold=1 --profile ${PROFILE} --output text --query 'HealthCheck.Id')
HEALTHCHECK1_TAG=$(aws route53 change-tags-for-resource --resource-type healthcheck --resource-id ${HEALTHCHECK1} --add-tags Key=Name,Value=${STACKNAME}-${REGION1} --profile ${PROFILE})

HEALTHCHECK2=$(aws route53 create-health-check  --caller-reference $(date "+%Y%m%d%H%M%S") --health-check-config Type=HTTPS,ResourcePath="/dev/health",FullyQualifiedDomainName=${USEAST1DOMAIN},RequestInterval=10,FailureThreshold=1 --profile ${PROFILE} --output text --query 'HealthCheck.Id')
HEALTHCHECK2_TAG=$(aws route53 change-tags-for-resource --resource-type healthcheck --resource-id ${HEALTHCHECK2} --add-tags Key=Name,Value=${STACKNAME}-${REGION2} --profile ${PROFILE})


#  Create Routing policy
TRAFFIC_POLICY=$(aws route53 create-traffic-policy \
   --name ${STACKNAME} \
   --document '{
        "AWSPolicyFormatVersion": "2015-10-01",
        "RecordType": "CNAME",
        "StartRule": "round_robin",
        "Endpoints": {
            "srv1": {
                "Type": "value",
                "Value": '${USWEST2REG}'
            },
            "srv2": {
                "Type": "value",
                "Value": '${USEAST1REG}'
            }
        },
        "Rules":{
            "round_robin":{
                "RuleType":"weighted",
                "Items": [
                    {
                        "EndpointReference": "srv1",
                        "Weight": "50",
                        "EvaluateTargetHealth": "true",
                        "HealthCheck": "'${HEALTHCHECK1}'"
                    },
                    {
                        "EndpointReference": "srv2",
                        "Weight": "50",
                        "EvaluateTargetHealth": "true",
                        "HealthCheck": "'${HEALTHCHECK2}'"
                    }
                ]
            }
        }
    }' \
    --profile ${PROFILE} \
    --output text \
    --query 'TrafficPolicy.Id')

#  Get the Zone id to create a policy record on the domain
HOSTEDZONE=$(aws route53 list-hosted-zones --query 'HostedZones[?Name==`'${DOMAIN}'.`].Id' --output text --profile ${PROFILE})

# create a policy record on the domain with the routing policy
POLICY_RECORD=$(aws route53 create-traffic-policy-instance --traffic-policy-id ${TRAFFIC_POLICY} --hosted-zone-id ${HOSTEDZONE} --ttl 60 --name "globalvpc.adhorn.me"  --traffic-policy-version 1 --profile ${PROFILE})
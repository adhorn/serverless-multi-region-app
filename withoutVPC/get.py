from __future__ import unicode_literals
import sys
import logging
import boto3
import os

log = logging.getLogger()
log.setLevel(logging.DEBUG)

sys.path.insert(0, './vendored')
import simplejson as json
# simplejson can handle Decimal object while the \
# standard json package can't.

region = os.environ["AWS_REGION"]
tablename = os.environ["tablename"]

dynamodb = boto3.resource('dynamodb', region_name=region)
table = dynamodb.Table(tablename)


def get_from_dynamo(event):
    log.debug("Received in get_from_dynamo: {}".format(json.dumps(event)))
    item_id = event['pathParameters']['item_id']
    log.debug("item_id: {}".format(item_id))
    item = table.get_item(
        Key={
            'item_id': item_id,
        }
    )
    return item['Item']


def get_item(event, context):
    log.debug("Received event in get_item: {}".format(json.dumps(event)))
    body = {
        "item_id": get_from_dynamo(event),
    }
    response = {
        "statusCode": 200,
        "body": json.dumps(body)
    }
    return response

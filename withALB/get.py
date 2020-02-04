from __future__ import unicode_literals
import sys
import logging
import boto3
import os


log = logging.getLogger()
log.setLevel(logging.DEBUG)

sys.path.insert(0, './vendor')
import simplejson as json
# simplejson can handle Decimal object while the \
# standard json package can't.
# OK

region = os.environ["AWS_REGION"]
tablename = os.environ["tablename"]

dynamodb = boto3.resource('dynamodb', region_name=region)
table = dynamodb.Table(tablename)


def makehealthcheckcalls():
    log.debug("status: {}".format(os.environ["STATUS"]))
    return int(os.environ["STATUS"])


def get_from_dynamo(event):
    log.debug("Received in get_from_dynamo: {}".format(json.dumps(event)))
    item_id = event
    log.debug("item_id: {}".format(item_id))
    item = table.get_item(
        Key={
            'item_id': item_id,
        }
    )
    return item['Item']


def get_item(event, context):
    log.debug("Received event in get_item: {}".format(json.dumps(event)))
    basepath = event["path"].split('/')
    print(basepath)
    if basepath[1] == "get":
        body = {
            "item_id": get_from_dynamo(basepath[2]),
            "retrieved from": region
        }
        response = {
            "statusCode": 200,
            "isBase64Encoded": False,
            "headers": {
                "Content-Type": "text/html; charset=utf-8"
            },
            "body": json.dumps(body)
        }

    elif basepath[1] == "health":
        response = {
            "statusCode": makehealthcheckcalls(),
            "isBase64Encoded": False,
            "headers": {
                "Content-Type": "text/html; charset=utf-8"
            },
            "body": "<html><body><h1> \
                    health: {0} {1} \
                    </h1></body></html>".format(
                makehealthcheckcalls(), region
            )
        }
    return response

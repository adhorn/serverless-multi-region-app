import json
import logging
import boto3
import os


log = logging.getLogger()
log.setLevel(logging.DEBUG)

region = os.environ["AWS_REGION"]
tablename = os.environ["tablename"]

dynamodb = boto3.resource('dynamodb', region_name=region)
table = dynamodb.Table(tablename)


def put_to_dynamo(event):
    log.debug("Received in put_to_dynamo: {}".format(json.dumps(event)))
    data = json.loads(event["body"])
    item_id = data.get("item_id", )
    session_comment = data.get("session_comment", )

    table.put_item(
        Item={
            'item_id': item_id,
            'session_comment': session_comment
        }
    )
    return item_id


def create_item(event, context):
    log.debug("Event in create_item: {}".format(json.dumps(event)))
    item_id = put_to_dynamo(event)
    body = {
        "item_id": " {}".format(item_id)
    }

    response = {
        "statusCode": 200,
        "body": json.dumps(body)
    }
    return response

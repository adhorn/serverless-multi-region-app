from __future__ import unicode_literals
import sys
import logging
import os

log = logging.getLogger()
log.setLevel(logging.DEBUG)

sys.path.insert(0, './vendored')
import simplejson as json


def makehealthcheckcalls():
    return os.environ["STATUS"]


def lambda_handler(event, context):
    log.debug("Received event in get_profile: {}".format(json.dumps(event)))

    response = {
        "statusCode": makehealthcheckcalls()
    }
    return response

"""
Handles interactions with AWS IoT Shadow through Boto. Boto is preinstalled
in AWS Lambda.
"""
import os
import time
import json

import boto3

thingName = os.environ.get("AWS_IOT_MY_THING_NAME")
myAWSRegion = os.environ.get("MY_AWS_REGION")
topic = "$aws/things/{}/shadow/update".format(thingName)

def update_shadow(new_value_dict):
    """
    Updates IoT shadow's "desired" state with values from new_value_dict. Logs
    current "desired" state after update.

    Updated Shadow Topics:
    ----------------------
    $aws/things/thingName/shadow/update/delta
    $aws/things/thingName/shadow/update/documents
    $aws/things/thingName/shadow/update/accepted


    Args:
        new_value_dict: Python dict of values to update in shadow
    """
    payload_dict = {
        "state": {
            "desired" : new_value_dict
        }
    }
    JSON_payload = json.dumps(payload_dict)
    shadow_client = boto3.client('iot-data', myAWSRegion)
    response = shadow_client.update_thing_shadow(thingName=thingName,
                                                 payload=JSON_payload)
    res_payload = json.loads(response['payload'].read().decode('utf-8'))
    print("Garage: {0}".format(res_payload.get("state").get("desired").get("garage")))
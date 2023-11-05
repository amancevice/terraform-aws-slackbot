"""
SSM ParameterStore helper
"""
import json

import boto3

from logger import logger

ssm = boto3.client("ssm")


def getSecret(name):
    params = {"Name": name, "WithDecryption": True}
    logger.info("ssm:GetParameter %s", json.dumps(params))
    result = ssm.get_parameter(**params)
    value = result["Parameter"]["Value"]
    return value

import json
import os

import boto3

from .logger import logger

EVENT_BUS_NAME = os.environ["EVENT_BUS_NAME"]
SECRET_ID = os.environ["SECRET_ID"]

SECRETS = boto3.client("secretsmanager")


def export(secret_id=None, client=None):
    client = client or SECRETS
    params = {"SecretId": secret_id or SECRET_ID}
    logger.info("secretsmanager:GetSecretSring %s", json.dumps(params))
    result = client.get_secret_value(**params)
    secret = json.loads(result["SecretString"])
    os.environ.update(**secret)

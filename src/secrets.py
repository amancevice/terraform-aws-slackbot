import json
import os

import boto3

from logger import logger


def export(boto3_session=None, **params):
    secret = fetch(boto3_session, **params)
    os.environ.update(**secret)


def fetch(boto3_session=None, **params):
    boto3_session = boto3_session or boto3.Session()
    secrets = boto3_session.client('secretsmanager')
    logger.info('GET SECRET %s', logger.json(params))
    secret = json.loads(secrets.get_secret_value(**params)['SecretString'])
    return secret

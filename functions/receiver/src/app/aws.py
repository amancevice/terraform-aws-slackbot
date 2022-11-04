import json
from urllib.parse import parse_qsl

import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

from .env import EVENT_BUS_NAME
from .logger import logger


class EventBus:
    def __init__(self, name=None, session=None):
        self.name = name or EVENT_BUS_NAME
        self.session = session or boto3.Session()
        self.client = self.session.client("events")

    def publish(self, *entries):
        params = {"Entries": list(entries)}
        logger.info("events:PutEvents %s", json.dumps(params))
        return self.client.put_events(**params)


class SigV4Signer:
    def __init__(self, session=None):
        self.session = session or boto3.Session()
        self.sigv4auth = SigV4Auth(
            credentials=self.session.get_credentials(),
            service_name="execute-api",
            region_name=self.session.region_name,
        )

    def get_headers(self, *args, **kwargs):
        # Prepare AWS request
        awsrequest = AWSRequest(*args, **kwargs)
        awsrequest.prepare()

        # Sign request
        self.sigv4auth.add_auth(awsrequest)
        headers = {k.lower(): v for k, v in awsrequest.headers.items()}

        # Return signing headers
        return headers

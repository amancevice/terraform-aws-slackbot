import base64
import json

import boto3

from logger import logger


class Event:
    def __init__(self, event):
        self.event = event

    def __getitem__(self, key):
        return self.event[key]


class EventBridgeEvent(Event):
    @property
    def detail(self):
        return self.event['detail']

    @property
    def detail_type(self):
        return self.event['detail-type']


class HttpEvent(Event):
    @property
    def body(self):
        if self.event.get('isBase64Encoded'):
            return base64.b64decode(self.event['body']).decode()
        return self.event.get('body')

    @property
    def headers(self):
        headers = self.event.get('headers') or {}
        return {k.lower(): v for k, v in headers.items()}

    @property
    def query(self):
        return self.event['queryStringParameters']

    @property
    def route_key(self):
        return self.event.get('routeKey')

    @property
    def trace_header(self):
        return self.headers.get('x-amzn-trace-id')


class Events:
    def __init__(self, bus=None, source=None, boto3_session=None):
        self.bus = bus or 'default'
        self.source = source or 'slack'
        self.boto3_session = boto3_session or boto3.Session()
        self.client = self.boto3_session.client('events')

    def publish(self, detail_type, detail, trace_header=None):
        entry = dict(
            Detail=json.dumps(detail),
            DetailType=detail_type,
            EventBusName=self.bus,
            Source=self.source,
            TraceHeader=trace_header,
        )
        params = dict(Entries=[{k: v for k, v in entry.items() if v}])
        logger.info('PUT EVENTS %s', json.dumps(params))
        return self.client.put_events(**params)

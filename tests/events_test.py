import base64
import json
from unittest.mock import MagicMock

import pytest

from src.events import (Event, EventBridgeEvent, HttpEvent, Events)


class TestEvent:
    def setup(self):
        self.subject = Event({'fizz': 'buzz'})

    def test_getitem(self):
        assert self.subject['fizz'] == 'buzz'

    def test_len(self):
        assert len(self.subject) == 1


class TestEventBridgeEvent:
    def setup(self):
        self.subject = EventBridgeEvent({
            'url': 'https://slack.com/api/some.method',
            'body': '{"fizz": "buzz"}',
            'headers': {'content-type': 'application/json; charset=utf-8'},
            'task-token': '<token>',
        })

    @pytest.mark.parametrize(('attr', 'exp'), [
        ('url', 'https://slack.com/api/some.method'),
        ('body', '{"fizz": "buzz"}'),
        ('headers', {'content-type': 'application/json; charset=utf-8'}),
        ('task_token', '<token>'),
    ])
    def test_attr(self, attr, exp):
        assert getattr(self.subject, attr) == exp


class TestHttpEvent:
    def setup(self):
        body = json.dumps({'jazz': 'fuzz'})
        self.subject = HttpEvent({
            'routeKey': 'POST /resource',
            'headers': {'X-Amzn-Trace-Id': 'TRACE-ID'},
            'queryStringParameters': {'fizz': 'buzz'},
            'body': base64.b64encode(body.encode()).decode(),
            'isBase64Encoded': True,
        })

    def test_body(self):
        assert self.subject.body == json.dumps({'jazz': 'fuzz'})
        self.subject.event['isBase64Encoded'] = False
        self.subject.event['body'] = json.dumps({'jazz': 'fuzz'})
        assert self.subject.body == json.dumps({'jazz': 'fuzz'})

    def test_headers(self):
        assert self.subject.headers == {'x-amzn-trace-id': 'TRACE-ID'}

    def test_query(self):
        assert self.subject.query == {'fizz': 'buzz'}

    def test_route_key(self):
        assert self.subject.route_key == 'POST /resource'

    def test_trace_header(self):
        assert self.subject.trace_header == 'TRACE-ID'


class TestEvents:
    def setup(self):
        self.boto3_session = MagicMock()
        self.default = Events(boto3_session=self.boto3_session)
        self.subject = Events('slack', boto3_session=self.boto3_session)

    def test_bus_name(self):
        assert self.default.bus == 'default'
        assert self.subject.bus == 'slack'

    def test_publish(self):
        self.subject.publish('type', {'fizz': 'buzz'}, 'TRACE-ID')
        self.subject.boto3_session\
            .client.return_value\
            .put_events.assert_called_once_with(Entries=[{
                'Detail': json.dumps({'fizz': 'buzz'}),
                'DetailType': 'type',
                'EventBusName': 'slack',
                'Source': 'slack',
                'TraceHeader': 'TRACE-ID',
            }])

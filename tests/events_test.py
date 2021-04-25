import base64
import json
from unittest.mock import MagicMock

from src.events import (Event, EventBridgeEvent, HttpEvent, Events)


class TestEvent:
    def setup(self):
        self.subject = Event({'fizz': 'buzz'})

    def test_getitem(self):
        assert self.subject['fizz'] == 'buzz'


class TestEventBridgeEvent:
    def setup(self):
        self.subject = EventBridgeEvent({
            'detail': {'fizz': 'buzz'},
            'detail-type': 'jazz-fuzz',
        })

    def test_detail(self):
        assert self.subject.detail == {'fizz': 'buzz'}

    def test_detail_type(self):
        assert self.subject.detail_type == 'jazz-fuzz'


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

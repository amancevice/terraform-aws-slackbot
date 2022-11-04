import index


class TestHandler:
    def test_handler(self):
        expected = {"statusCode": 200}
        returned = index.handler({})
        assert expected == returned

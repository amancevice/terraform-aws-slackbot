import json
from urllib.parse import parse_qsl

from logger import logger


@logger.bind
def handler(event, *_):
    body = event["body"]
    routeKey = event["routeKey"]

    # body is a url-encoded JSON string in the 'payload' key
    if routeKey in ["POST /callback", "POST /menu"]:
        data = json.loads(dict(parse_qsl(body))["payload"])

    # body is a url-encoded string
    elif routeKey in ["POST /slash"]:
        data = dict(parse_qsl(body))
        data["type"] = "slash_command"

    # body is a JSON string
    else:
        data = json.loads(body)

    return data

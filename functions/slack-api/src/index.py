from app import env

env.export()  # Export SecretsManager JSON to environment

import os
from urllib.request import Request, urlopen

from app.logger import logger

SLACK_API_TOKEN = os.environ.get("SLACK_API_TOKEN")


@logger.bind
def handler(event, _):
    # Extract request info
    data = event.get("data") or ""
    headers = event.get("headers") or {}
    method = event.get("method") or "POST"
    token = event.get("token") or SLACK_API_TOKEN
    url = event["url"]

    # Update headers
    if "authorization" not in headers:
        headers["authorization"] = f"Bearer {token}"
    if "content-type" not in headers:
        headers["content-type"] = "application/json; charset=utf-8"

    # Send request
    res = send_request(method, url, data, headers)

    # Return response
    ret = {
        "statusCode": res.code,
        "headers": dict(res.headers),
        "body": res.read().decode(),
    }
    return ret


def send_request(method, url, data, headers):
    logger.info("%s %s", method, url)
    req = Request(url, data.encode(), headers, method=method)
    res = urlopen(req)
    return res

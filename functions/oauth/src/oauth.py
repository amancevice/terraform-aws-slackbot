"""
Slack OAuth helper
"""
import json
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from logger import logger


def authorize(client_id, client_secret, code, redirect_uri, **_):
    # Set up OAuth request
    url = "https://slack.com/api/oauth.v2.access"
    headers = {"content-type": "application/x-www-form-urlencoded"}
    payload = {
        "client_id": client_id,
        "client_secret": client_secret,
        "code": code,
        "redirect_uri": redirect_uri,
    }
    data = urlencode(payload).encode()

    # Execute request to complete OAuth workflow
    logger.info("POST %s", url)
    req = Request(url, data, headers, method="POST")
    res = urlopen(req)

    # Return response
    resdata = res.read().decode()
    result = json.loads(resdata)
    return result

import json
import os
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from logger import logger
from secret import getSecret

client_id = os.environ["CLIENT_ID"]
client_secret = getSecret(os.environ["CLIENT_SECRET_PARAMETER"])


@logger.bind
def handler(event, *_):
    # Set up OAuth request
    url = "https://slack.com/api/oauth.v2.access"
    headers = {"content-type": "application/x-www-form-urlencoded"}
    payload = {"client_id": client_id, "client_secret": client_secret, **event}
    data = urlencode(payload).encode()

    # Execute request to complete OAuth workflow
    logger.info("POST %s", url)
    req = Request(url, data, headers, method="POST")
    res = urlopen(req)

    # Return response
    resdata = res.read().decode()
    result = json.loads(resdata)
    return result

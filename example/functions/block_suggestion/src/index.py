import base64
import json
import re
from urllib.request import urlopen

from logger import logger


@logger.bind
def handler(event, _):
    action_id = event.get("action_id")
    seachterm = event.get("value")

    # Get menu options
    if action_id == "slack_oauth_scopes":
        options = slack_oauth_scopes(seachterm)
    else:
        options = []

    # Send response
    response = {
        "statusCode": 200,
        "body": json.dumps({"options": options}),
    }
    return response


def slack_oauth_scopes(term):
    url = "https://api.slack.com/scopes"
    with urlopen(url) as res:
        html = res.read().decode()
    scopes = re.findall(r"&quot;name&quot;:&quot;(.*?)&quot;", html)
    options = [
        {"value": x, "text": {"type": "plain_text", "text": x}}
        for x in scopes
        if x.startswith(term)
    ]
    return options

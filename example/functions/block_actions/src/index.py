import base64
import json
from urllib.request import Request, urlopen

from logger import logger


@logger.bind
def handler(event, _):
    # Handle interaction
    for action in iter_actions(event):
        try:
            action(event)
        except Exception as err:
            print(err)

    # Respond
    response = {"statusCode": 200}
    return response


def iter_actions(event):
    actions = event.get("actions") or []
    for action in actions:
        action_id = action.get("action_id")
        if action_id == "slack_oauth_scopes":
            yield slack_oauth_scopes_action


def slack_oauth_scopes_action(event):
    state = event["state"]["values"]
    block = state["slack_oauth_scopes"]["slack_oauth_scopes"]
    scope = block["selected_option"]
    url = event["response_url"]
    headers = {"content-type": "application/json; charset=utf-8"}
    text = "Choose a Slack OAuth scope to learn more"
    blocks = [
        {
            "type": "section",
            "text": {"type": "plain_text", "text": text},
        },
        {
            "block_id": "slack_oauth_scopes",
            "type": "actions",
            "elements": [
                {
                    "type": "external_select",
                    "action_id": "slack_oauth_scopes",
                    "placeholder": {"type": "plain_text", "text": "Select scope"},
                    "initial_option": scope,
                },
                {
                    "type": "button",
                    "action_id": "open_slack_oauth_scope",
                    "text": {"type": "plain_text", "text": "Open"},
                    "url": f"https://api.slack.com/scopes/{scope['value']}",
                },
            ],
        },
    ]
    message = {"replace_original": True, "text": text, "blocks": blocks}
    data = json.dumps(message).encode()
    req = Request(url, data, headers, method="POST")
    urlopen(req)

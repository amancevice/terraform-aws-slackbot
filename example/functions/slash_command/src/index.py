import json

from logger import logger


@logger.bind
def handler(event, _):
    command = event["command"]

    if command == "/test":
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
                    }
                ],
            },
        ]
    data = {"text": text, "blocks": blocks}
    body = json.dumps(data)
    resp = {"statusCode": "200", "body": body}
    return resp

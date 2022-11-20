"""
Lambda Entrypoint
"""
from app import env

env.export()  # Export SecretsManager JSON to environment

from app.api import Api
from app.events import BlockSuggestion, Callback, EventCallback, OAuth, Slash
from app.errors import Forbidden
from app.logger import logger
from app.slackbot import Slackbot

api = Api()
bot = Slackbot()


@api.any("/health")
def any_health(request):
    """
    Sign request & pass through to API Gateway
    """
    return api.respond(200, {"ok": True})


@api.any("/install")
def any_install(_):
    """
    Redirect to Slack install URL
    """
    location = bot.oauth.install_uri
    return api.respond(302, location=location)


@api.any("/oauth")
def any_oauth(request):
    """
    Complete OAuth workflow, publish event, and redirect to OAuth success URI
    """
    event = OAuth(request)
    location = bot.install(event)
    return api.respond(302, location=location)


@api.post("/callbacks")
def post_callbacks(request):
    """
    Verify origin, publish to EventBridge, then sign & pass through to API Gateway
    """
    event = Callback(request)
    bot.verify(event)
    bot.publish(event)
    return bot.resolve(event)


@api.post("/events")
def post_events(request):
    """
    Verify origin, publish to EventBridge, then respond 200 OK
    """
    event = EventCallback(request)
    bot.verify(event)

    # First-time URL verification for events
    body = None
    detail = event.get_detail()
    if detail.get("type") == "url_verification":
        challenge = detail.get("challenge")
        body = {"challenge": challenge}
    else:
        bot.publish(event)

    return api.respond(200, body)


@api.post("/menus")
def post_menus(request):
    """
    Verify origin, publish to EventBridge, then sign & pass through to API Gateway
    """
    event = BlockSuggestion(request)
    bot.verify(event)
    bot.publish(event)
    return bot.resolve(event)


@api.post("/slash/{cmd}")
def post_slash(request):
    """
    Verify origin, publish to EventBridge, then sign & pass through to API Gateway
    """
    event = Slash(request)
    bot.verify(event)
    bot.publish(event)
    return bot.resolve(event)


@logger.bind
def handler(event, *_):
    """
    Lambda@Edge handler for CloudFront
    """
    try:
        return api.handle(event)
    except Forbidden as err:
        return api.reject(403)
    except Exception as err:
        logger.error("%s", err)
        return api.reject(500)

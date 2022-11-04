"""
API Generator
"""
import json

from .errors import Forbidden
from .logger import logger


class Api:
    def __init__(self):
        self.routes = {}

    def handle(self, event):
        # Extract route method
        route_key = event["routeKey"]
        route = self.routes.get(route_key)

        # Raise 403 FORBIDDEN if bad route
        if route is None:
            raise Forbidden

        # Execute request
        return route(event)

    def route(self, path, method):
        def inner(handler):
            def wrapper(request):
                return handler(request)

            self.routes[f"{method} {path}"] = wrapper
            return wrapper

        return inner

    def any(self, path):
        return self.route(path, "ANY")

    def post(self, path):
        return self.route(path, "POST")

    @classmethod
    def reject(cls, code):
        return cls.respond(code, {"ok": False})

    @staticmethod
    def respond(code, body=None, **headers):
        """
        Send response instead of passing through to API Gateway

        :param int code: HTTP status code
        :param str desc: HTTP status text
        :param str body: HTTP response body
        """
        body = json.dumps(body) if body else ""
        if int(code) < 400:
            logger.info("RESPONSE [%d] %s", code, body or "-")
        else:
            logger.error("RESPONSE [%d] %s", code, body or "-")
        headers.setdefault("content-type", "application/json; charset=utf-8")
        response = {"statusCode": str(code), "body": body, "headers": headers}
        return response

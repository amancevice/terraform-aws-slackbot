"""
Logger
"""
import json
import logging

LOG_FORMAT = "%(levelname)s %(awsRequestId)s %(message)s"
LOG_LEVEL = logging.INFO
LOG_NAME = "slackbot"


class SuppressFilter(logging.Filter):
    """
    Suppress Log Records from registered logger

    Taken from ``aws_lambda_powertools.logging.filters.SuppressFilter``
    """

    def __init__(self, logger):
        self.logger = logger

    def filter(self, record):
        logger = record.name
        return False if self.logger in logger else True


class LambdaLoggerAdapter(logging.LoggerAdapter):
    """
    Lambda logger adapter.
    """

    @staticmethod
    def getLogger(name, level=None, format_string=None, stream=None):
        # Get logger, handler, formatter
        logger = logging.getLogger(name)
        handler = logging.StreamHandler(stream)
        formatter = logging.Formatter(format_string or LOG_FORMAT)
        handler.setFormatter(formatter)

        # Set log level
        logger.setLevel(level or LOG_LEVEL)

        # Set handler if necessary
        if not logger.handlers:  # and not logger.parent.handlers:
            logger.addHandler(handler)

        # Suppress AWS logging for this logger
        for handler in logging.root.handlers:
            logFilter = SuppressFilter(name)
            handler.addFilter(logFilter)

        return logger

    def __init__(self, logger, extra=None):
        super().__init__(logger, extra or dict(awsRequestId="-"))

    def bind(self, handler):
        """
        Decorate Lambda handler to attach logger to AWS request.

        :Example:

        >>> logger = lambo.getLogger(__name__)
        >>>
        >>> @logger.attach
        ... def handler(event, context):
        ...     logger.info('Hello, world!')
        ...     return {'ok': True}
        ...
        >>> handler({'fizz': 'buzz'})
        >>> # => INFO RequestId: {awsRequestId} EVENT {"fizz": "buzz"}
        >>> # => INFO RequestId: {awsRequestId} Hello, world!
        >>> # => INFO RequestId: {awsRequestId} RETURN {"ok": True}
        """

        def wrapper(event=None, context=None):
            try:
                params = {"default": str}
                self.addContext(context)
                self.info("EVENT %s", json.dumps(event, **params))
                result = handler(event, context)
                self.info("RETURN %s", json.dumps(result, **params))
                return result
            finally:
                self.dropContext()

        return wrapper

    def addContext(self, context=None):
        """
        Add runtime context to logger.
        """
        try:
            awsRequestId = f"RequestId: {context.aws_request_id}"
        except AttributeError:
            awsRequestId = "-"
        self.extra.update(awsRequestId=awsRequestId)
        return self

    def dropContext(self):
        """
        Drop runtime context from logger.
        """
        self.extra.update(awsRequestId="-")
        return self


def getLogger(name, level=None, format_string=None, stream=None):
    """
    Helper to get Lambda logger.

    :Example:

    >>> getLogger('logger-name', 'DEBUG', '%(message)s')
    """
    logger = LambdaLoggerAdapter.getLogger(name, level, format_string, stream)
    return LambdaLoggerAdapter(logger)


logger = getLogger(LOG_NAME)

from logger import logger


@logger.bind
def handler(*_):
    return {"statusCode": 200}

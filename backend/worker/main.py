import logging
import time

from app.core.logging import setup_logging

setup_logging()
logger = logging.getLogger(__name__)


if __name__ == "__main__":
    logger.info("Worker placeholder started")
    while True:
        time.sleep(60)

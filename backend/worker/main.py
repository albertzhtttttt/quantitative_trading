import logging
import time

from app.core.logging import setup_logging

setup_logging()
logger = logging.getLogger(__name__)


if __name__ == "__main__":
    # 当前阶段先保留 worker 常驻占位进程，后续在此接入回测任务和模拟盘运行器。
    logger.info("Worker 占位进程已启动")
    while True:
        time.sleep(60)

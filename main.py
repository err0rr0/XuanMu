import os

import uvicorn

from app import create_app
from config import WORKSPACE, get_config, load_config
from logger import setup_logging


def main() -> None:
    cfg = get_config()
    dev_reload = os.environ.get("XUANMU_DEV_RELOAD", "").strip() == "1"

    if dev_reload:
        # 开发模式：使用 import string 让 uvicorn 自己 fork worker，支持热重载
        uvicorn.run(
            "app:create_app",
            factory=True,
            host=cfg.system.listen_addr,
            port=cfg.system.listen_port,
            reload=True,
            reload_excludes=[".venv", "web", ".xuanmu", ".git", "__pycache__"],
            log_config=None,
            access_log=False,
        )
    else:
        # 生产模式：直接传 app 实例
        application = create_app()
        uvicorn.run(
            application,
            host=cfg.system.listen_addr,
            port=cfg.system.listen_port,
            log_config=None,
            access_log=False,
        )


if __name__ == "__main__":
    load_config()
    setup_logging(level="INFO", file_path=WORKSPACE / "app.log")

    main()

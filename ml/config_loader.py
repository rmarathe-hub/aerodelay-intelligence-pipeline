from __future__ import annotations

from functools import lru_cache
from typing import Any

import yaml

from ml.paths import CONFIG_PATH


@lru_cache(maxsize=1)
def load_config() -> dict[str, Any]:
    with CONFIG_PATH.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle)

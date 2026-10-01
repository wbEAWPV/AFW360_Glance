"""Launcher for the AFW 360 Shiny dashboard. The app's code is in AFW360-shiny/.

This file sits next to data_raw/ and data_dashboard/ so that one folder holds
everything the app needs: Posit Connect deploys this folder with this file as
the entry point, and `python -m shiny run app.py` runs it locally.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "AFW360-shiny"))

from dashboard import app  # noqa: E402

__all__ = ["app"]

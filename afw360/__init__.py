"""AFW 360 At A Glance: dashboard data access.

All dashboard chunks read inputs through :mod:`afw360.loader`, so a change of
data source touches one module. Display formatting lives in :mod:`afw360.format`.
"""

from afw360.format import format_value

__all__ = ["format_value"]
__version__ = "0.1.0"

"""
admin.py - DEPRECATED barrel file.
All routes have been split into routes/ directory.
This file re-exports all routers for backward compatibility.
"""
from routes.admin_products import router as _admin_products
from routes.admin_categories import router as _admin_categories
from routes.admin_orders import router as _admin_orders
from routes.admin_users import router as _admin_users
from routes.admin_delivery import router as _admin_delivery
from routes.admin_offers import router as _admin_offers

# Re-export all routers - main.py now imports directly from routes/
__all__ = [
    "_admin_products", "_admin_categories", "_admin_orders",
    "_admin_users", "_admin_delivery", "_admin_offers",
]

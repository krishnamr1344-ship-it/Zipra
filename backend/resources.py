"""
resources.py - DEPRECATED barrel file.
All routes have been split into routes/ directory.
This file re-exports all routers for backward compatibility.
"""
from routes.categories import router as _categories
from routes.products import router as _products
from routes.addresses import router as _addresses
from routes.cart import router as _cart
from routes.orders import router as _orders
from routes.payments import router as _payments
from routes.offers import router as _offers
from routes.delivery import router as _delivery

# Re-export all routers - main.py now imports directly from routes/
__all__ = [
    "_categories", "_products", "_addresses", "_cart",
    "_orders", "_payments", "_offers", "_delivery",
]

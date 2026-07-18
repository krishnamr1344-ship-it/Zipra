from fastapi import HTTPException, Request, status
from sqlalchemy.orm import Session

from app.models import User, Address, CartItem, Product, Order


def get_user_id(request: Request) -> str:
    user_id = getattr(request.state, "user_id", None)
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    return user_id


def get_user(user_id: str, db: Session) -> User:
    user = db.query(User).filter(User.id == user_id, User.is_deleted == False).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


def get_address_or_404(addr_id: str, user_id: str, db: Session) -> Address:
    addr = db.query(Address).filter(
        Address.id == addr_id,
        Address.user_id == user_id,
        Address.is_deleted == False,
    ).first()
    if not addr:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Address not found")
    return addr


def get_cart_item_or_404(item_id: str, user_id: str, db: Session):
    item = db.query(CartItem).filter(
        CartItem.id == item_id,
        CartItem.user_id == user_id,
        CartItem.is_deleted == False,
    ).first()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cart item not found")
    return item


def get_product_or_404(prod_id: str, db: Session) -> Product:
    prod = db.query(Product).filter(
        Product.id == prod_id,
        Product.is_deleted == False,
    ).first()
    if not prod:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    return prod


def get_order_or_404(order_id: str, user_id: str, db: Session) -> Order:
    order = db.query(Order).filter(
        Order.id == order_id,
        Order.user_id == user_id,
        Order.is_deleted == False,
    ).first()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    return order


def require_admin(request: Request) -> str:
    role = getattr(request.state, "user_role", None)
    user_id = getattr(request.state, "user_id", None)
    if role != "admin" or not user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return user_id


def require_shop_owner(request: Request) -> str:
    role = getattr(request.state, "user_role", None)
    user_id = getattr(request.state, "user_id", None)
    if role != "shop_owner" or not user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Shop owner access required")
    return user_id


def get_shop_for_owner(user_id: str, db: Session):
    from app.models import Shop
    shop = db.query(Shop).filter(
        Shop.owner_id == user_id,
        Shop.is_deleted == False,
    ).first()
    if not shop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shop not found for this owner")
    return shop

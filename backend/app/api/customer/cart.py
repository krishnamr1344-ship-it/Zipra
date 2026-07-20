from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models import CartItem, Product
from app.schemas import CartAddRequest, CartUpdateRequest, CartItemResponse, MessageResponse
from app.utils.helpers import get_user_id, get_user, get_cart_item_or_404, get_product_or_404

router = APIRouter(prefix="/api")


def _cart_item_to_response(item: CartItem) -> CartItemResponse:
    return CartItemResponse(
        id=str(item.id),
        product_id=str(item.product_id),
        product_name=item.product.name,
        product_price=float(item.product.price),
        product_unit=item.product.unit,
        product_image=item.product.images[0].image_url if item.product.images else None,
        quantity=item.quantity,
        subtotal=round(float(item.product.price) * item.quantity, 2),
    )


@router.get("/cart", response_model=list[CartItemResponse])
def list_cart(request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    items = db.query(CartItem).filter(
        CartItem.user_id == user_id,
        CartItem.is_deleted == False,
    ).all()
    return [_cart_item_to_response(i) for i in items]


@router.post("/cart", response_model=CartItemResponse, status_code=status.HTTP_201_CREATED)
def add_to_cart(body: CartAddRequest, request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    get_user(user_id, db)
    product = get_product_or_404(body.product_id, db)

    if product.stock < body.quantity:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Insufficient stock")

    existing = db.query(CartItem).filter(
        CartItem.user_id == user_id,
        CartItem.product_id == body.product_id,
        CartItem.is_deleted == False,
    ).first()

    if existing:
        existing.quantity = body.quantity
        db.commit()
        db.refresh(existing)
        return _cart_item_to_response(existing)

    soft_deleted = db.query(CartItem).filter(
        CartItem.user_id == user_id,
        CartItem.product_id == body.product_id,
        CartItem.is_deleted == True,
    ).first()
    if soft_deleted:
        soft_deleted.is_deleted = False
        soft_deleted.quantity = body.quantity
        db.commit()
        db.refresh(soft_deleted)
        return _cart_item_to_response(soft_deleted)

    item = CartItem(user_id=user_id, product_id=body.product_id, quantity=body.quantity)
    db.add(item)
    db.commit()
    db.refresh(item)
    return _cart_item_to_response(item)


@router.put("/cart/{item_id}", response_model=CartItemResponse)
def update_cart_item(item_id: str, body: CartUpdateRequest, request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    item = get_cart_item_or_404(item_id, user_id, db)

    if body.quantity == 0:
        item.is_deleted = True
        db.commit()
        raise HTTPException(status_code=status.HTTP_200_OK, detail="Item removed from cart")

    product = db.query(Product).filter(Product.id == item.product_id).first()
    if product and product.stock < body.quantity:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Insufficient stock")

    item.quantity = body.quantity
    db.commit()
    db.refresh(item)
    return _cart_item_to_response(item)


@router.delete("/cart/{item_id}", response_model=MessageResponse)
def remove_cart_item(item_id: str, request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    item = get_cart_item_or_404(item_id, user_id, db)
    item.is_deleted = True
    db.commit()
    return MessageResponse(message="Item removed from cart")


@router.delete("/cart", response_model=MessageResponse)
def clear_cart(request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    items = db.query(CartItem).filter(
        CartItem.user_id == user_id,
        CartItem.is_deleted == False,
    ).all()
    for item in items:
        item.is_deleted = True
    db.commit()
    return MessageResponse(message="Cart cleared")

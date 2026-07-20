import os
import re
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile, File, status
from sqlalchemy.orm import Session
from sqlalchemy import update

from app.db.session import get_db
from app.models import Product, ProductImage, Category, Shop
from app.schemas import (
    ShopProductCreate, ShopProductResponse, ShopProductStockUpdate,
    ProductResponse, MessageResponse,
)
from app.utils.helpers import require_shop_owner, get_shop_for_owner

router = APIRouter(prefix="/api/shop/products", tags=["shop-products"])


def _product_to_response(p: Product) -> ShopProductResponse:
    return ShopProductResponse(
        id=str(p.id), category_id=str(p.category_id),
        category_name=p.category.name if p.category else None,
        name=p.name, description=p.description,
        price=float(p.price),
        original_price=float(p.original_price) if p.original_price else None,
        unit=p.unit,
        images=[img.image_url for img in p.images if not img.is_deleted],
        stock=p.stock,
        approval_status=p.approval_status or "approved",
        created_at=p.created_at,
    )


@router.get("", response_model=list[ShopProductResponse])
def list_shop_products(
    request: Request,
    status_filter: str = None,
    db: Session = Depends(get_db),
):
    user_id = require_shop_owner(request)
    shop = get_shop_for_owner(user_id, db)
    query = db.query(Product).filter(Product.shop_id == shop.id, Product.is_deleted == False)
    if status_filter:
        query = query.filter(Product.approval_status == status_filter)
    products = query.order_by(Product.created_at.desc()).all()
    return [_product_to_response(p) for p in products]


@router.get("/pending", response_model=list[ShopProductResponse])
def list_pending_products(request: Request, db: Session = Depends(get_db)):
    user_id = require_shop_owner(request)
    shop = get_shop_for_owner(user_id, db)
    products = db.query(Product).filter(
        Product.shop_id == shop.id,
        Product.approval_status == "pending",
        Product.is_deleted == False,
    ).order_by(Product.created_at.desc()).all()
    return [_product_to_response(p) for p in products]


@router.get("/approved", response_model=list[ShopProductResponse])
def list_approved_products(request: Request, db: Session = Depends(get_db)):
    user_id = require_shop_owner(request)
    shop = get_shop_for_owner(user_id, db)
    products = db.query(Product).filter(
        Product.shop_id == shop.id,
        Product.approval_status == "approved",
        Product.is_deleted == False,
    ).order_by(Product.created_at.desc()).all()
    return [_product_to_response(p) for p in products]


@router.get("/rejected", response_model=list[ShopProductResponse])
def list_rejected_products(request: Request, db: Session = Depends(get_db)):
    user_id = require_shop_owner(request)
    shop = get_shop_for_owner(user_id, db)
    products = db.query(Product).filter(
        Product.shop_id == shop.id,
        Product.approval_status == "rejected",
        Product.is_deleted == False,
    ).order_by(Product.created_at.desc()).all()
    return [_product_to_response(p) for p in products]


@router.post("", response_model=ShopProductResponse, status_code=status.HTTP_201_CREATED)
def create_shop_product(body: ShopProductCreate, request: Request, db: Session = Depends(get_db)):
    user_id = require_shop_owner(request)
    shop = get_shop_for_owner(user_id, db)
    cat = db.query(Category).filter(Category.id == body.category_id, Category.is_deleted == False).first()
    if not cat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
    product = Product(
        category_id=body.category_id,
        shop_id=shop.id,
        approval_status="pending",
        name=body.name.strip(),
        description=body.description.strip() if body.description else None,
        price=body.price,
        original_price=body.original_price,
        unit=body.unit.strip().lower(),
        stock=body.stock,
    )
    db.add(product)
    db.flush()
    for i, url in enumerate(body.images):
        db.add(ProductImage(product_id=product.id, image_url=url.strip(), sort_order=i))
    db.commit()
    db.refresh(product)
    return _product_to_response(product)


@router.put("/{product_id}", response_model=ShopProductResponse)
def update_shop_product(product_id: str, body: ShopProductCreate, request: Request, db: Session = Depends(get_db)):
    user_id = require_shop_owner(request)
    shop = get_shop_for_owner(user_id, db)
    product = db.query(Product).filter(
        Product.id == product_id,
        Product.shop_id == shop.id,
        Product.is_deleted == False,
    ).first()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    cat = db.query(Category).filter(Category.id == body.category_id, Category.is_deleted == False).first()
    if not cat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
    product.category_id = body.category_id
    product.name = body.name.strip()
    product.description = body.description.strip() if body.description else None
    product.price = body.price
    product.original_price = body.original_price
    product.unit = body.unit.strip().lower()
    product.stock = body.stock
    for old_img in product.images:
        old_img.is_deleted = True
    for i, url in enumerate(body.images):
        db.add(ProductImage(product_id=product.id, image_url=url.strip(), sort_order=i))
    product.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(product)
    return _product_to_response(product)


@router.delete("/{product_id}", response_model=MessageResponse)
def delete_shop_product(product_id: str, request: Request, db: Session = Depends(get_db)):
    user_id = require_shop_owner(request)
    shop = get_shop_for_owner(user_id, db)
    product = db.query(Product).filter(
        Product.id == product_id,
        Product.shop_id == shop.id,
        Product.is_deleted == False,
    ).first()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    product.is_deleted = True
    product.updated_at = datetime.now(timezone.utc)
    db.commit()
    return MessageResponse(message="Product deleted")


@router.put("/{product_id}/stock", response_model=ShopProductResponse)
def update_product_stock(product_id: str, body: ShopProductStockUpdate, request: Request, db: Session = Depends(get_db)):
    user_id = require_shop_owner(request)
    shop = get_shop_for_owner(user_id, db)
    product = db.query(Product).filter(
        Product.id == product_id,
        Product.shop_id == shop.id,
        Product.is_deleted == False,
    ).first()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    product.stock = body.stock
    product.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(product)
    return _product_to_response(product)


@router.post("/{product_id}/upload-image", status_code=status.HTTP_201_CREATED)
async def upload_shop_product_image(
    product_id: str, request: Request,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    user_id = require_shop_owner(request)
    MAX_FILE_SIZE = 10 * 1024 * 1024
    ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}
    if file.size and file.size > MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail="File too large (max 10MB)")
    if file.content_type and file.content_type not in ALLOWED_TYPES:
        raise HTTPException(status_code=400, detail="Only JPG, PNG, WebP allowed")
    shop = get_shop_for_owner(user_id, db)
    product = db.query(Product).filter(
        Product.id == product_id,
        Product.shop_id == shop.id,
        Product.is_deleted == False,
    ).first()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    ext = file.filename.split(".")[-1] if file.filename else "jpg"
    safe_name = re.sub(r'[^a-zA-Z0-9_.-]', '_', file.filename or 'upload')
    filename = f"{uuid.uuid4()}.{ext}"
    os.makedirs("uploads", exist_ok=True)
    content = await file.read()
    with open(f"uploads/{filename}", "wb") as f:
        f.write(content)
    max_sort = db.query(db.func.max(ProductImage.sort_order)).filter(
        ProductImage.product_id == product_id, ProductImage.is_deleted == False
    ).scalar() or 0
    img = ProductImage(product_id=product.id, image_url=f"/uploads/{filename}", sort_order=max_sort + 1)
    db.add(img)
    db.commit()
    db.refresh(img)
    return {"id": str(img.id), "image_url": img.image_url, "sort_order": img.sort_order}

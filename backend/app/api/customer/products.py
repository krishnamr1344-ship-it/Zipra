from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models import Product
from app.schemas import ProductCreate, ProductResponse

router = APIRouter(prefix="/api")


@router.get("/products", response_model=list[ProductResponse])
def list_products(category_id: Optional[str] = None, db: Session = Depends(get_db)):
    query = db.query(Product).filter(Product.is_deleted == False, Product.approval_status == "approved")
    if category_id:
        query = query.filter(Product.category_id == category_id)
    products = query.order_by(Product.name).all()
    result = []
    for p in products:
        result.append(ProductResponse(
            id=str(p.id),
            category_id=str(p.category_id),
            category_name=p.category.name if p.category else None,
            name=p.name,
            description=p.description,
            price=float(p.price),
            original_price=float(p.original_price) if p.original_price else None,
            unit=p.unit,
            images=[img.image_url for img in p.images if not img.is_deleted],
            stock=p.stock,
        ))
    return result


@router.get("/products/{product_id}", response_model=ProductResponse)
def get_product(product_id: str, db: Session = Depends(get_db)):
    p = db.query(Product).filter(Product.id == product_id, Product.is_deleted == False).first()
    if not p:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    return ProductResponse(
        id=str(p.id),
        category_id=str(p.category_id),
        category_name=p.category.name if p.category else None,
        name=p.name,
        description=p.description,
        price=float(p.price),
        original_price=float(p.original_price) if p.original_price else None,
        unit=p.unit,
        images=[img.image_url for img in p.images if not img.is_deleted],
        stock=p.stock,
    )

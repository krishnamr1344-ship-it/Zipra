from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile, File, status
from sqlalchemy import func
from sqlalchemy.orm import Session
from sqlalchemy import update

from app.db.session import get_db
from app.models import Category, Product, ProductImage, Shop
from app.schemas import ProductCreate, ProductResponse, MessageResponse
from app.utils.helpers import require_admin

router = APIRouter(prefix="/api/admin")


@router.get("/products", response_model=list[ProductResponse])
def list_products(request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    products = db.query(Product).filter(Product.is_deleted == False).order_by(Product.name).all()
    return [
        ProductResponse(
            id=str(p.id), category_id=str(p.category_id),
            category_name=p.category.name if p.category else None,
            name=p.name, description=p.description,
            price=float(p.price), original_price=float(p.original_price) if p.original_price else None, unit=p.unit,
            images=[img.image_url for img in p.images if not img.is_deleted],
            stock=p.stock,
        ) for p in products
    ]


@router.post("/products", response_model=ProductResponse, status_code=status.HTTP_201_CREATED)
def create_product(body: ProductCreate, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    cat = db.query(Category).filter(Category.id == body.category_id, Category.is_deleted == False).first()
    if not cat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
    if not body.shop_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="shop_id is required — assign product to a shop")
    shop = db.query(Shop).filter(Shop.id == body.shop_id, Shop.is_deleted == False).first()
    if not shop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shop not found")
    product = Product(
        category_id=body.category_id, shop_id=body.shop_id, name=body.name.strip(),
        description=body.description.strip() if body.description else None,
        price=body.price, original_price=body.original_price, unit=body.unit.strip().lower(),
        stock=body.stock,
    )
    db.add(product)
    db.flush()
    for i, url in enumerate(body.images):
        db.add(ProductImage(product_id=product.id, image_url=url.strip(), sort_order=i))
    db.commit()
    db.refresh(product)
    return ProductResponse(
        id=str(product.id), category_id=str(product.category_id),
        category_name=cat.name,
        name=product.name, description=product.description,
        price=float(product.price), original_price=float(product.original_price) if product.original_price else None, unit=product.unit,
        images=[img.image_url for img in product.images if not img.is_deleted],
        stock=product.stock,
    )


@router.put("/products/{product_id}", response_model=ProductResponse)
def update_product(product_id: str, body: ProductCreate, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    product = db.query(Product).filter(Product.id == product_id, Product.is_deleted == False).first()
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
    db.commit()
    db.refresh(product)
    return ProductResponse(
        id=str(product.id), category_id=str(product.category_id),
        category_name=cat.name,
        name=product.name, description=product.description,
        price=float(product.price), original_price=float(product.original_price) if product.original_price else None, unit=product.unit,
        images=[img.image_url for img in product.images if not img.is_deleted],
        stock=product.stock,
    )


@router.delete("/products/{product_id}", response_model=MessageResponse)
def delete_product(product_id: str, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    product = db.query(Product).filter(Product.id == product_id, Product.is_deleted == False).first()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    product.is_deleted = True
    db.commit()
    return MessageResponse(message="Product deleted")


@router.post("/products/{product_id}/upload-image", status_code=status.HTTP_201_CREATED)
async def upload_product_image(product_id: str, request: Request, file: UploadFile = File(...), db: Session = Depends(get_db)):
    from app.utils.storage import upload_to_gcs
    require_admin(request)
    product = db.query(Product).filter(Product.id == product_id, Product.is_deleted == False).first()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    image_url = await upload_to_gcs(file, folder="products")

    max_sort = db.query(func.max(ProductImage.sort_order)).filter(ProductImage.product_id == product_id, ProductImage.is_deleted == False).scalar() or 0
    img = ProductImage(product_id=product.id, image_url=image_url, sort_order=max_sort + 1)
    db.add(img)
    db.commit()
    db.refresh(img)
    return {"id": str(img.id), "image_url": img.image_url, "sort_order": img.sort_order}

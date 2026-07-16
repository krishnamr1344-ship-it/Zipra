from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from database import get_db
from models import Category, Product
from schemas import CategoryCreate, CategoryResponse, MessageResponse
from routes.admin_utils import require_admin

router = APIRouter(prefix="/api/admin")


@router.get("/categories", response_model=list[CategoryResponse])
def list_categories(request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    cats = db.query(Category).filter(Category.is_deleted == False).order_by(Category.name).all()
    return [CategoryResponse(id=str(c.id), name=c.name, description=c.description, image=c.image) for c in cats]


@router.post("/categories", response_model=CategoryResponse, status_code=status.HTTP_201_CREATED)
def create_category(body: CategoryCreate, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    existing = db.query(Category).filter(Category.name == body.name.strip(), Category.is_deleted == False).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Category already exists")
    cat = Category(
        name=body.name.strip(),
        description=body.description.strip() if body.description else None,
        image=body.image.strip() if body.image else None,
    )
    db.add(cat)
    db.commit()
    db.refresh(cat)
    return CategoryResponse(id=str(cat.id), name=cat.name, description=cat.description, image=cat.image)


@router.put("/categories/{category_id}", response_model=CategoryResponse)
def update_category(category_id: str, body: CategoryCreate, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    cat = db.query(Category).filter(Category.id == category_id, Category.is_deleted == False).first()
    if not cat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
    dup = db.query(Category).filter(Category.name == body.name.strip(), Category.id != category_id, Category.is_deleted == False).first()
    if dup:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Category name already taken")
    cat.name = body.name.strip()
    cat.description = body.description.strip() if body.description else None
    cat.image = body.image.strip() if body.image else None
    db.commit()
    db.refresh(cat)
    return CategoryResponse(id=str(cat.id), name=cat.name, description=cat.description, image=cat.image)


@router.delete("/categories/{category_id}", response_model=MessageResponse)
def delete_category(category_id: str, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    cat = db.query(Category).filter(Category.id == category_id, Category.is_deleted == False).first()
    if not cat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
    has_products = db.query(Product).filter(Product.category_id == category_id, Product.is_deleted == False).first()
    if has_products:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot delete category with existing products")
    cat.is_deleted = True
    db.commit()
    return MessageResponse(message="Category deleted")

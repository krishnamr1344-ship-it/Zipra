from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models import Category
from app.schemas import CategoryResponse

router = APIRouter(prefix="/api")


@router.get("/categories", response_model=list[CategoryResponse])
def list_categories(db: Session = Depends(get_db)):
    cats = db.query(Category).filter(Category.is_deleted == False).order_by(Category.name).all()
    return [
        CategoryResponse(id=str(c.id), name=c.name, description=c.description, image=c.image)
        for c in cats
    ]


@router.get("/categories/{category_id}", response_model=CategoryResponse)
def get_category(category_id: str, db: Session = Depends(get_db)):
    cat = db.query(Category).filter(Category.id == category_id, Category.is_deleted == False).first()
    if not cat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
    return CategoryResponse(id=str(cat.id), name=cat.name, description=cat.description, image=cat.image)

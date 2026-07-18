from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models import User, Address
from app.schemas import MessageResponse
from app.utils.helpers import require_admin

router = APIRouter(prefix="/api/admin")


@router.get("/users")
def list_users(request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    users = db.query(User).filter(User.is_deleted == False).order_by(User.created_at.desc()).all()
    result = []
    for u in users:
        gps_addr = db.query(Address).filter(
            Address.user_id == u.id,
            Address.label == "GPS Location",
            Address.is_deleted == False,
        ).first()
        addr_info = None
        if gps_addr:
            gmaps = f"https://www.google.com/maps?q={gps_addr.latitude},{gps_addr.longitude}" if gps_addr.latitude and gps_addr.longitude else None
            addr_info = {
                "address_line1": gps_addr.address_line1,
                "address_line2": gps_addr.address_line2,
                "city": gps_addr.city,
                "state": gps_addr.state,
                "pincode": gps_addr.pincode,
                "address_type": gps_addr.address_type,
                "house_number": gps_addr.house_number,
                "floor_number": gps_addr.floor_number,
                "landmark": gps_addr.landmark,
                "latitude": float(gps_addr.latitude) if gps_addr.latitude else None,
                "longitude": float(gps_addr.longitude) if gps_addr.longitude else None,
                "maps_link": gmaps,
            }
        result.append({
            "id": str(u.id),
            "name": u.name,
            "email": u.email,
            "phone": u.phone,
            "role": u.role,
            "created_at": u.created_at,
            "gps_address": addr_info,
        })
    return result


@router.delete("/users/{user_id}", response_model=MessageResponse)
def delete_user(user_id: str, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    user = db.query(User).filter(User.id == user_id, User.is_deleted == False).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    user.is_deleted = True
    db.commit()
    return MessageResponse(message="User deleted")

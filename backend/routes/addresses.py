import json

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
import httpx

from database import get_db
from models import Address
from schemas import (
    AddressCreate, AddressUpdate, AddressResponse, GpsAddressCreate, MessageResponse,
)
from routes.helpers import get_user_id, get_user, get_address_or_404

router = APIRouter(prefix="/api")


@router.get("/addresses", response_model=list[AddressResponse])
def list_addresses(request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    addrs = db.query(Address).filter(
        Address.user_id == user_id,
        Address.is_deleted == False,
    ).order_by(Address.is_default.desc(), Address.created_at.desc()).all()
    return [
        AddressResponse(
            id=str(a.id), label=a.label, address_line1=a.address_line1,
            address_line2=a.address_line2, city=a.city, state=a.state,
            pincode=a.pincode, landmark=a.landmark,
            address_type=a.address_type, house_number=a.house_number,
            floor_number=a.floor_number,
            latitude=float(a.latitude) if a.latitude else None,
            longitude=float(a.longitude) if a.longitude else None,
            is_default=a.is_default,
            maps_link=f"https://www.google.com/maps?q={a.latitude},{a.longitude}" if a.latitude and a.longitude else None,
        ) for a in addrs
    ]


@router.post("/addresses", response_model=AddressResponse, status_code=status.HTTP_201_CREATED)
def create_address(body: AddressCreate, request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    get_user(user_id, db)

    if body.is_default:
        db.query(Address).filter(Address.user_id == user_id, Address.is_deleted == False).update(
            {"is_default": False}
        )

    addr = Address(
        user_id=user_id, label=body.label.strip(),
        address_line1=body.address_line1.strip(),
        address_line2=body.address_line2.strip() if body.address_line2 else None,
        city=body.city.strip(), state=body.state.strip(),
        pincode=body.pincode.strip(),
        address_type=body.address_type,
        house_number=body.house_number.strip() if body.house_number else None,
        floor_number=body.floor_number.strip() if body.floor_number else None,
        landmark=body.landmark.strip() if body.landmark else None,
        latitude=body.latitude, longitude=body.longitude,
        is_default=body.is_default,
    )
    db.add(addr)
    db.commit()
    db.refresh(addr)
    maps = f"https://www.google.com/maps?q={body.latitude},{body.longitude}" if body.latitude and body.longitude else None
    return AddressResponse(
        id=str(addr.id), label=addr.label,
        address_line1=addr.address_line1, address_line2=addr.address_line2,
        city=addr.city, state=addr.state, pincode=addr.pincode,
        address_type=addr.address_type, house_number=addr.house_number,
        floor_number=addr.floor_number, landmark=addr.landmark,
        latitude=float(addr.latitude) if addr.latitude else None,
        longitude=float(addr.longitude) if addr.longitude else None,
        is_default=addr.is_default,
        maps_link=maps,
    )


@router.put("/addresses/{address_id}", response_model=AddressResponse)
def update_address(address_id: str, body: AddressUpdate, request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    addr = get_address_or_404(address_id, user_id, db)

    if body.is_default is True:
        db.query(Address).filter(Address.user_id == user_id, Address.is_deleted == False).update(
            {"is_default": False}
        )

    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if value is not None and isinstance(value, str):
            setattr(addr, field, value.strip())
        else:
            setattr(addr, field, value)

    db.commit()
    db.refresh(addr)
    maps = f"https://www.google.com/maps?q={addr.latitude},{addr.longitude}" if addr.latitude and addr.longitude else None
    return AddressResponse(
        id=str(addr.id), label=addr.label,
        address_line1=addr.address_line1, address_line2=addr.address_line2,
        city=addr.city, state=addr.state, pincode=addr.pincode,
        address_type=addr.address_type, house_number=addr.house_number,
        floor_number=addr.floor_number, landmark=addr.landmark,
        latitude=float(addr.latitude) if addr.latitude else None,
        longitude=float(addr.longitude) if addr.longitude else None,
        is_default=addr.is_default,
        maps_link=maps,
    )


@router.delete("/addresses/{address_id}", response_model=MessageResponse)
def delete_address(address_id: str, request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    addr = get_address_or_404(address_id, user_id, db)
    addr.is_deleted = True
    db.commit()
    return MessageResponse(message="Address deleted")


@router.post("/addresses/auto", response_model=AddressResponse, status_code=status.HTTP_201_CREATED)
def create_address_from_gps(body: GpsAddressCreate, request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    get_user(user_id, db)

    label = "GPS Location"
    address_line1 = f"{body.latitude:.6f}, {body.longitude:.6f}"
    city = "Unknown"
    state = "Unknown"
    pincode = "000000"

    try:
        with httpx.Client(timeout=10) as client:
            resp = client.get(
                "https://nominatim.openstreetmap.org/reverse",
                params={"lat": body.latitude, "lon": body.longitude, "format": "json"},
                headers={"User-Agent": "DeliveryApp/1.0"},
            )
        if resp.status_code == 200:
            data = resp.json()
            if "address" in data:
                addr_data = data["address"]
                area = addr_data.get("suburb") or addr_data.get("city_district") or ""
                road = addr_data.get("road") or ""
                house = addr_data.get("house_number") or ""
                parts = []
                if road:
                    parts.append(road)
                if house:
                    parts.append(house)
                city = addr_data.get("city") or addr_data.get("town") or addr_data.get("village") or addr_data.get("county") or "Unknown"
                address_line1 = ", ".join(parts) if parts else data.get("display_name", address_line1)
                address_line2 = f"{area}, {city}" if area and city else area or None
                state = addr_data.get("state") or "Unknown"
                pincode = addr_data.get("postcode") or "000000"
    except Exception:
        pass

    existing_gps = db.query(Address).filter(
        Address.user_id == user_id,
        Address.latitude != None,
        Address.longitude != None,
        Address.is_deleted == False,
    ).first()

    if existing_gps:
        existing_gps.address_line1 = address_line1
        existing_gps.address_line2 = address_line2
        existing_gps.city = city
        existing_gps.state = state
        existing_gps.pincode = pincode
        existing_gps.landmark = body.landmark
        existing_gps.address_type = body.address_type
        existing_gps.house_number = body.house_number
        existing_gps.floor_number = body.floor_number
        existing_gps.latitude = body.latitude
        existing_gps.longitude = body.longitude
        db.commit()
        db.refresh(existing_gps)
        maps = f"https://www.google.com/maps?q={body.latitude},{body.longitude}" if body.latitude and body.longitude else None
        return AddressResponse(
            id=str(existing_gps.id), label=existing_gps.label,
            address_line1=existing_gps.address_line1, address_line2=existing_gps.address_line2,
            city=existing_gps.city, state=existing_gps.state,
            pincode=existing_gps.pincode, landmark=existing_gps.landmark,
            address_type=existing_gps.address_type,
            house_number=existing_gps.house_number,
            floor_number=existing_gps.floor_number,
            latitude=float(existing_gps.latitude) if existing_gps.latitude else None,
            longitude=float(existing_gps.longitude) if existing_gps.longitude else None,
            is_default=existing_gps.is_default,
            maps_link=maps,
        )

    has_address = db.query(Address).filter(
        Address.user_id == user_id, Address.is_deleted == False
    ).first()
    is_default = has_address is None

    addr = Address(
        user_id=user_id, label=label,
        address_line1=address_line1, address_line2=address_line2,
        city=city, state=state,
        pincode=pincode, landmark=body.landmark,
        address_type=body.address_type,
        house_number=body.house_number,
        floor_number=body.floor_number,
        latitude=body.latitude, longitude=body.longitude,
        is_default=is_default,
    )
    db.add(addr)
    db.commit()
    db.refresh(addr)
    maps = f"https://www.google.com/maps?q={body.latitude},{body.longitude}" if body.latitude and body.longitude else None
    return AddressResponse(
        id=str(addr.id), label=addr.label,
        address_line1=addr.address_line1, address_line2=addr.address_line2,
        city=addr.city, state=addr.state, pincode=addr.pincode,
        address_type=addr.address_type, house_number=addr.house_number,
        floor_number=addr.floor_number, landmark=addr.landmark,
        latitude=float(addr.latitude) if addr.latitude else None,
        longitude=float(addr.longitude) if addr.longitude else None,
        is_default=addr.is_default,
        maps_link=maps,
    )


@router.get("/places/search")
def search_places(q: str, db: Session = Depends(get_db)):
    try:
        import httpx
        with httpx.Client(timeout=10) as client:
            resp = client.get(
                "https://nominatim.openstreetmap.org/search",
                params={"q": q, "format": "json", "limit": 10, "addressdetails": 1},
                headers={"User-Agent": "DeliveryApp/1.0"},
            )
        if resp.status_code != 200:
            return []
        data = resp.json()
        results = []
        for item in data:
            addr_data = item.get("address", {})
            results.append({
                "display_name": item.get("display_name", ""),
                "latitude": float(item.get("lat", 0)),
                "longitude": float(item.get("lon", 0)),
                "address_line1": ", ".join(filter(None, [addr_data.get("road", ""), addr_data.get("house_number", "")])),
                "address_line2": addr_data.get("suburb") or addr_data.get("city_district") or "",
                "city": addr_data.get("city") or addr_data.get("town") or addr_data.get("village") or addr_data.get("county") or "",
                "state": addr_data.get("state") or "",
                "pincode": addr_data.get("postcode") or "",
            })
        return results
    except Exception:
        return []

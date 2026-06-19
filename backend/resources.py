"""
resources.py
Purpose: CRUD endpoints for categories, products, addresses, cart, orders, payments.
Security:
  - All endpoints require JWT auth (enforced by middleware).
  - Ownership validation: users access ONLY their own data.
  - Input validated by Pydantic before DB access.
  - Payments store NO sensitive data (card numbers, CVV, etc.).
  - SQLAlchemy ORM only — no raw SQL.
  - Soft-delete used everywhere (is_deleted flag).
"""
import logging
import json
import secrets
import string as _string
logger = logging.getLogger(__name__)
import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
import httpx

from typing import Optional

from database import get_db
from models import (
    User, Category, Product, ProductImage, ProductFlag, Address, CartItem,
    Order, OrderItem, Payment, DeliveryZone, ComboPack, ComboPackItem, ProductSuggestion,
    WishlistItem, AppVersion, Notification,
)
from schemas import (
    CategoryCreate, CategoryResponse,
    ProductCreate, ProductResponse,
    AddressCreate, AddressUpdate, AddressResponse, GpsAddressCreate,
    CartAddRequest, CartUpdateRequest, CartItemResponse, CartValidateResponse, CartValidateItem,
    OrderCreateRequest, OrderDirectCreateRequest, OrderResponse, OrderItemResponse, DeliveryAddress,
    PaymentProcessRequest, PaymentResponse, MessageResponse,
    ZoneCheckRequest, ZoneCheckResponse,
    ComboPackItemInput, ComboPackItemResponse, ComboPackResponse, PackAddRequest,
    SuggestProductRequest,
    WishlistAddRequest, WishlistItemResponse,
    AppVersionResponse, NotificationResponse,
)

router = APIRouter(prefix="/api")

import os as _os
import uuid as _uuid
from fastapi import UploadFile, File as FastAPIFile
import httpx as _httpx
from config import SUPABASE_URL, SUPABASE_UPLOAD_KEY, SUPABASE_STORAGE_BUCKET


_MIME_MAP = {
    ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
    ".png": "image/png", ".webp": "image/webp",
    ".gif": "image/gif",
}

_MAX_UPLOAD_SIZE = 5 * 1024 * 1024  # 5 MB

# Magic bytes for image validation
_IMAGE_MAGIC = {
    b"\xff\xd8\xff": "image/jpeg",
    b"\x89PNG\r\n\x1a\n": "image/png",
    b"GIF87a": "image/gif",
    b"GIF89a": "image/gif",
    b"RIFF": "image/webp",  # WEBP starts with RIFF, need extra check
}


def _detect_image_type(data: bytes) -> str | None:
    for magic, mime in _IMAGE_MAGIC.items():
        if data.startswith(magic):
            if magic == b"RIFF" and len(data) > 12:
                if data[8:12] in (b"WEBP",):
                    return mime
                continue
            return mime
    return None


def _normalize_mime(filename: str, content_type: str | None) -> str:
    ext = _os.path.splitext(filename)[1].lower()
    mapped = _MIME_MAP.get(ext)
    if mapped:
        return mapped
    if content_type and content_type.startswith("image/"):
        return content_type
    return "image/png"


@router.post("/upload")
async def upload_image(file: UploadFile = FastAPIFile(...)):
    if file.size is not None and file.size > _MAX_UPLOAD_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File too large. Maximum size is {_MAX_UPLOAD_SIZE // (1024 * 1024)} MB",
        )

    ext = _os.path.splitext(file.filename or "image.png")[1] or ".png"
    if ext.lower() not in _MIME_MAP:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported file extension '{ext}'. Allowed: {', '.join(_MIME_MAP)}",
        )

    data = await file.read()

    if len(data) > _MAX_UPLOAD_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File too large. Maximum size is {_MAX_UPLOAD_SIZE // (1024 * 1024)} MB",
        )

    detected_mime = _detect_image_type(data)
    if detected_mime is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is not a valid image",
        )

    filename = f"{_uuid.uuid4().hex}{ext}"
    content_type = _normalize_mime(file.filename or "image.png", file.content_type)

    async with _httpx.AsyncClient() as client:
        res = await client.post(
            f"{SUPABASE_URL}/storage/v1/object/{SUPABASE_STORAGE_BUCKET}/{filename}",
            headers={
                "Authorization": f"Bearer {SUPABASE_UPLOAD_KEY}",
                "Content-Type": content_type,
            },
            content=data,
        )
        if res.status_code not in (200, 201):
            raise HTTPException(status_code=res.status_code, detail=res.text)

    url = f"{SUPABASE_URL}/storage/v1/object/public/{SUPABASE_STORAGE_BUCKET}/{filename}"
    return {"url": url}


# ─── HELPERS ──────────────────────────────────────────────────────

import re as _re

_ZONE_RE = _re.compile(r'\s*Zone\s+\d+\s*', _re.IGNORECASE)

# Map ward/division numbers to locality names for Chennai.
# Used when Nominatim only returns zone-based admin names.
# Source: Chennai Ward GeoJSON + manual research.
# Zone X (Kodambakkam) wards that are actually part of Vadapalani locality.
_WARD_TO_LOCALITY: dict[str, str] = {
    "0": "St. Thomas Mount Cantonment",
    "1": "Ennore",
    "2": "Kathivakkam",
    "3": "Ernavur",
    "4": "Ernavur",
    "5": "Ernavur",
    "6": "Kargil Nagar",
    "7": "Tiruvottiyur",
    "8": "Tiruvottiyur",
    "9": "Tiruvottiyur",
    "10": "Tiruvottiyur",
    "11": "Tiruvottiyur",
    "12": "Tiruvottiyur",
    "13": "Tiruvottiyur",
    "14": "Tiruvottiyur",
    "15": "Edayanchavadi",
    "16": "Dwaraka Nagar",
    "17": "Mathur",
    "18": "Manali",
    "19": "Mathur",
    "20": "Manali",
    "21": "Manali",
    "22": "Puzhal",
    "23": "Puzhal",
    "24": "Surapattu",
    "25": "Kathirvedu",
    "26": "Kathirvedu",
    "27": "Madhavaram Milk Colony",
    "28": "Madhavaram Milk Colony",
    "29": "Manali",
    "30": "Madhavaram",
    "31": "Madhavaram",
    "32": "Kolathur",
    "33": "Madhavaram",
    "34": "Chinna Kodungaiyur",
    "35": "Kodungaiyur",
    "36": "Vyasarpadi",
    "37": "Vyasarpadi",
    "38": "New Washermanpet",
    "39": "New Washermanpet",
    "40": "New Washermanpet",
    "41": "Korukkupet",
    "42": "Korukkupet",
    "43": "Tondiarpet",
    "44": "Perambur",
    "45": "Vyasarpadi",
    "46": "Thiru Vi Ka Nagar",
    "47": "Washermanpet",
    "48": "Washermanpet",
    "49": "Royapuram",
    "50": "Royapuram",
    "51": "Washermanpet",
    "52": "Royapuram",
    "53": "Basin Bridge",
    "54": "Vallalar Nagar",
    "55": "Vallalar Nagar",
    "56": "Vallalar Nagar",
    "57": "George Town",
    "58": "Vepery",
    "59": "Island Grounds",
    "60": "George Town",
    "61": "Egmore",
    "62": "Chintadripet",
    "63": "Triplicane",
    "64": "Periyar Nagar",
    "65": "Villivakkam",
    "66": "Periyar Nagar",
    "67": "Periyar Nagar",
    "68": "Perambur",
    "69": "Perambur",
    "70": "Perambur",
    "71": "Otteri",
    "72": "Pulianthope",
    "73": "Otteri",
    "74": "Otteri",
    "75": "Otteri",
    "76": "Choolai",
    "77": "Pulianthope",
    "78": "Choolai",
    "79": "Venkatapuram",
    "80": "Venkatapuram",
    "81": "Ambattur",
    "82": "Venkatapuram",
    "83": "Korattur",
    "84": "Korattur",
    "85": "Ambattur",
    "86": "Nolambur",
    "87": "Anna Nagar West",
    "88": "Anna Nagar West",
    "89": "Mogappair East",
    "90": "Anna Nagar West",
    "91": "Nolambur",
    "92": "Mogappair East",
    "93": "Mogappair East",
    "94": "Villivakkam",
    "95": "Villivakkam",
    "96": "ICF Colony",
    "97": "Ayanavaram",
    "98": "Ayanavaram",
    "99": "Anna Nagar West",
    "100": "Anna Nagar",
    "101": "Anna Nagar",
    "102": "Shenoy Nagar",
    "103": "Kilpauk",
    "104": "Purasawalkam",
    "105": "Arumbakkam",
    "106": "Aminjikarai",
    "107": "Chetpet",
    "108": "Aminjikarai",
    "109": "Aminjikarai",
    "110": "Nungambakkam",
    "111": "Thousand Lights",
    "112": "Kodambakkam",
    "113": "Nungambakkam",
    "114": "Chepauk",
    "115": "Royapettah",
    "116": "Triplicane",
    "117": "Teynampet",
    "118": "Teynampet",
    "119": "Gopalapuram",
    "120": "Triplicane",
    "121": "Mylapore",
    "122": "Nandanam",
    "123": "Abhiramapuram",
    "124": "Mylapore",
    "125": "Santhome",
    "126": "Mylapore",
    "127": "Saligramam",
    "128": "Virugambakkam",
    "129": "Vadapalani",
    "130": "Vadapalani",
    "131": "K.K.Nagar",
    "132": "Ashok Nagar",
    "133": "Ashok Nagar",
    "134": "Kodambakkam",
    "135": "West Mambalam",
    "136": "West Mambalam",
    "137": "K.K.Nagar",
    "138": "Jafferkhanpet",
    "139": "Ekkattuthangal",
    "140": "Thiyagaraya Nagar",
    "141": "Thiyagaraya Nagar",
    "142": "Saidapet",
    "143": "Nolambur",
    "144": "Nerkundram",
    "145": "Nerkundram",
    "146": "Alapakkam",
    "147": "Alapakkam",
    "148": "Virugambakkam",
    "149": "Valasaravakkam",
    "150": "Karampakkam",
    "151": "Porur",
    "152": "Valasaravakkam",
    "153": "Porur",
    "154": "Ramapuram",
    "155": "Nesapakkam",
    "156": "Porur",
    "157": "Manapakkam",
    "158": "Nandambakkam",
    "159": "Alandur",
    "160": "St. Thomas Mount Cantonment",
    "161": "St. Thomas Mount Cantonment",
    "162": "St. Thomas Mount Cantonment",
    "163": "St. Thomas Mount Cantonment",
    "164": "St. Thomas Mount Cantonment",
    "165": "Alandur",
    "166": "Alandur",
    "167": "Alandur",
    "168": "Perungudi",
    "169": "Perungudi",
    "170": "SIDCO Industrial Estate",
    "171": "Little Mount",
    "172": "Kotturpuram",
    "173": "MRC Nagar",
    "174": "Guindy",
    "175": "Adyar",
    "176": "Adyar",
    "177": "Adyar",
    "178": "Adyar",
    "179": "Adyar",
    "180": "Adyar",
    "181": "Adyar",
    "182": "Adyar",
    "183": "Perungudi",
    "184": "Perungudi",
    "185": "Perungudi",
    "186": "Perungudi",
    "187": "Perungudi",
    "188": "Perungudi",
    "189": "Perungudi",
    "190": "Perungudi",
    "191": "Perungudi",
    "192": "Sozhinganallur",
    "193": "Sozhinganallur",
    "194": "Sozhinganallur",
    "195": "Sozhinganallur",
    "196": "Sozhinganallur",
    "197": "Sozhinganallur",
    "198": "Sozhinganallur",
    "199": "Sozhinganallur",
    "200": "Sozhinganallur",
}

def _extract_area(addr_data: dict) -> str:
    """Extract locality name from Nominatim address.

    Strategy:
    1. If primary admin fields contain "Zone N" (zone-based name), check
       locality-specific fields (railway, station, metro, etc.).
       Only use them if the zone-stripped primary is NOT a substring of the
       specific value (avoids picking POI names like "Anna Nagar Tower Exit"
       over the correct "Anna Nagar").
    2. If no suitable specific field found, prefer the zone-stripped suburb
       name (e.g. "Zone 8 Anna Nagar" → "Anna Nagar") over ward mapping,
       since the zone name is generally more accurate.
    3. Last resort: extract ward/division number from neighbourhood field
       and look it up in _WARD_TO_LOCALITY.
    """
    primary = ""
    for key in ("suburb", "neighbourhood", "city_district", "city"):
        val = addr_data.get(key)
        if val:
            primary = val
            break

    if "zone" in primary.lower():
        stripped_primary = _ZONE_RE.sub("", primary).strip().lower()

        # Try locality-specific fields (railway, station, metro, locality, hamlet)
        for key in ("railway", "station", "metro", "locality", "hamlet"):
            val = addr_data.get(key)
            if val and "zone" not in val.lower():
                # Skip if the specific value is just a POI named after the primary area
                # e.g. railway="Anna Nagar Tower Exit" while zone-stripped="Anna Nagar"
                if not stripped_primary or stripped_primary not in val.lower():
                    return _ZONE_RE.sub("", val).strip()

        # Prefer zone-stripped suburb name over ward mapping
        # e.g. "Zone 8 Anna Nagar" → "Anna Nagar"
        if stripped_primary:
            return _ZONE_RE.sub("", primary).strip()

        # Last resort: try ward/division number mapping from neighbourhood field
        neighbourhood = addr_data.get("neighbourhood") or ""
        ward_match = _re.search(r"(?:Division|Ward)\s*(\d+)", neighbourhood, _re.IGNORECASE)
        if ward_match:
            ward_no = ward_match.group(1)
            if ward_no in _WARD_TO_LOCALITY:
                return _WARD_TO_LOCALITY[ward_no]

    return _ZONE_RE.sub("", primary).strip()

def _get_user_id(request: Request) -> str:
    user_id = getattr(request.state, "user_id", None)
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    return user_id


def _get_user(user_id: str, db: Session) -> User:
    user = db.query(User).filter(User.id == user_id, User.is_deleted == False).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


def _get_address_or_404(addr_id: str, user_id: str, db: Session) -> Address:
    _validate_uuid(addr_id)
    addr = db.query(Address).filter(
        Address.id == addr_id,
        Address.user_id == user_id,
        Address.is_deleted == False,
    ).first()
    if not addr:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Address not found")
    return addr


def _get_cart_item_or_404(item_id: str, user_id: str, db: Session) -> CartItem:
    _validate_uuid(item_id)
    item = db.query(CartItem).filter(
        CartItem.id == item_id,
        CartItem.user_id == user_id,
        CartItem.is_deleted == False,
    ).first()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cart item not found")
    return item


def _validate_uuid(uuid_str: str) -> str:
    try:
        uuid.UUID(uuid_str)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid ID format")
    return uuid_str


def _get_product_or_404(prod_id: str, db: Session, for_update: bool = False) -> Product:
    _validate_uuid(prod_id)
    query = db.query(Product).filter(
        Product.id == prod_id,
        Product.is_deleted == False,
    )
    if for_update:
        query = query.with_for_update()
    prod = query.first()
    if not prod:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    if prod.flag is not None and not prod.flag.is_enabled:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    return prod


def _get_order_or_404(order_id: str, user_id: str, db: Session) -> Order:
    _validate_uuid(order_id)
    order = db.query(Order).filter(
        Order.id == order_id,
        Order.user_id == user_id,
        Order.is_deleted == False,
    ).first()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    return order


def _cart_item_to_response(item: CartItem) -> CartItemResponse:
    product = item.product
    selling_price = round(float(product.price) * (100 - product.discount_percent) / 100, 2) if product else 0
    return CartItemResponse(
        id=str(item.id),
        product_id=str(item.product_id),
        product_name=product.name if product else '',
        product_price=selling_price,
        product_unit=product.unit if product else '',
        product_image=next((img.image_url for img in product.images if not img.is_deleted), None) if product else None,
        quantity=item.quantity,
        subtotal=round(selling_price * item.quantity, 2),
    )


def _order_to_response(order: Order, include_otp: bool = False) -> OrderResponse:
    items = []
    for oi in order.items:
        if not oi.is_deleted:
            items.append(OrderItemResponse(
                id=str(oi.id),
                product_id=str(oi.product_id),
                product_name=oi.product_name,
                product_price=round(float(oi.product_price), 2),
                quantity=oi.quantity,
                subtotal=round(float(oi.subtotal), 2),
            ))
    delivery_address = None
    if order.address_id and order.address:
        addr = order.address
        maps = f"https://www.google.com/maps?q={addr.latitude},{addr.longitude}" if addr.latitude and addr.longitude else None
        delivery_address = DeliveryAddress(
            address_line1=addr.address_line1,
            address_line2=addr.address_line2,
            city=addr.city,
            state=addr.state,
            pincode=addr.pincode,
            address_type=addr.address_type,
            house_number=addr.house_number,
            floor_number=addr.floor_number,
            landmark=addr.landmark,
            latitude=float(addr.latitude) if addr.latitude else None,
            longitude=float(addr.longitude) if addr.longitude else None,
            maps_link=maps,
        )
    return OrderResponse(
        id=str(order.id),
        status=order.status,
        total_amount=round(float(order.total_amount), 2),
        payment_method=order.payment_method,
        items=items,
        delivery_address=delivery_address,
        delivery_otp=order.delivery_otp if include_otp else None,
        created_at=order.created_at,
    )


# ─── CATEGORIES ───────────────────────────────────────────────────

@router.get("/categories", response_model=list[CategoryResponse])
def list_categories(db: Session = Depends(get_db)):
    cats = db.query(Category).filter(Category.is_deleted == False).order_by(Category.name).all()
    return [
        CategoryResponse(id=str(c.id), name=c.name, description=c.description, image=c.image)
        for c in cats
    ]


@router.get("/categories/{category_id}", response_model=CategoryResponse)
def get_category(category_id: str, db: Session = Depends(get_db)):
    _validate_uuid(category_id)
    cat = db.query(Category).filter(Category.id == category_id, Category.is_deleted == False).first()
    if not cat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
    return CategoryResponse(id=str(cat.id), name=cat.name, description=cat.description, image=cat.image)


# ─── PRODUCTS ─────────────────────────────────────────────────────

@router.get("/products", response_model=list[ProductResponse])
def list_products(category_id: Optional[str] = None, db: Session = Depends(get_db)):
    query = db.query(Product).filter(Product.is_deleted == False)
    if category_id:
        _validate_uuid(category_id)
        query = query.filter(Product.category_id == category_id)
    products = query.order_by(Product.name).all()
    products = [p for p in products if p.flag is None or p.flag.is_enabled]
    result = []
    for p in products:
        enabled = p.flag.is_enabled if p.flag else True
        result.append(ProductResponse(
            id=str(p.id),
            category_id=str(p.category_id),
            category_name=p.category.name if p.category else None,
            name=p.name,
            description=p.description,
            price=round(float(p.price), 2),
            unit=p.unit,
            images=[img.image_url for img in p.images if not img.is_deleted],
            stock=p.stock, discount_percent=p.discount_percent,
            is_enabled=enabled,
        ))
    return result


@router.get("/products/{product_id}", response_model=ProductResponse)
def get_product(product_id: str, db: Session = Depends(get_db)):
    _validate_uuid(product_id)
    p = db.query(Product).filter(Product.id == product_id, Product.is_deleted == False).first()
    if not p or (p.flag is not None and not p.flag.is_enabled):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    return ProductResponse(
        id=str(p.id),
        category_id=str(p.category_id),
        category_name=p.category.name if p.category else None,
        name=p.name,
        description=p.description,
        price=round(float(p.price), 2),
        unit=p.unit,
        images=[img.image_url for img in p.images if not img.is_deleted],
        stock=p.stock, discount_percent=p.discount_percent,
        is_enabled=p.flag.is_enabled if p.flag else True,
    )


# ─── ADDRESSES ────────────────────────────────────────────────────
# Ownership: all queries filter by user_id from JWT.

@router.get("/addresses", response_model=list[AddressResponse])
def list_addresses(request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
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
    user_id = _get_user_id(request)
    _get_user(user_id, db)

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
    user_id = _get_user_id(request)
    _validate_uuid(address_id)
    addr = _get_address_or_404(address_id, user_id, db)

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
    user_id = _get_user_id(request)
    _validate_uuid(address_id)
    addr = _get_address_or_404(address_id, user_id, db)
    addr.is_deleted = True
    db.commit()
    return MessageResponse(message="Address deleted")


@router.post("/addresses/auto", response_model=AddressResponse, status_code=status.HTTP_201_CREATED)
def create_address_from_gps(body: GpsAddressCreate, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    _get_user(user_id, db)

    label = "GPS Location"
    address_line1 = f"{body.latitude:.6f}, {body.longitude:.6f}"
    city = "Unknown"
    state = "Unknown"
    pincode = "000000"

    try:
        with httpx.Client(timeout=httpx.Timeout(10.0, connect=5, read=8, write=5, pool=5)) as client:
            resp = client.get(
                "https://nominatim.openstreetmap.org/reverse",
                params={"lat": body.latitude, "lon": body.longitude, "format": "json"},
                headers={"User-Agent": "DeliveryApp/1.0"},
            )
        if resp.status_code == 200:
            data = resp.json()
            if "address" in data:
                addr_data = data["address"]
                area = _extract_area(addr_data)
                road = addr_data.get("road") or ""
                house = addr_data.get("house_number") or ""
                parts = []
                if road:
                    parts.append(road)
                if house:
                    parts.append(house)
                city = addr_data.get("city") or addr_data.get("town") or addr_data.get("village") or addr_data.get("county") or "Unknown"
                address_line1 = ", ".join(parts) if parts else data.get("display_name", address_line1)
                address_line2 = area or city or None
                state = addr_data.get("state") or "Unknown"
                pincode = addr_data.get("postcode") or "000000"
    except Exception as e:
        logger.warning("Nominatim reverse geocode failed: %s", e)

    # If user already has a GPS auto-created address, update it
    existing_gps = db.query(Address).filter(
        Address.user_id == user_id,
        Address.label == "GPS Location",
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

    # Set as default if no other address exists
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


# ─── PLACES SEARCH ──────────────────────────────────────────────────

@router.get("/places/reverse")
def reverse_geocode(lat: float, lng: float, db: Session = Depends(get_db)):
    try:
        import httpx
        with httpx.Client(timeout=httpx.Timeout(10.0, connect=5, read=8, write=5, pool=5)) as client:
            resp = client.get(
                "https://nominatim.openstreetmap.org/reverse",
                params={"lat": lat, "lon": lng, "format": "json", "addressdetails": 1},
                headers={"User-Agent": "DeliveryApp/1.0"},
            )
        if resp.status_code != 200:
            return {"display_name": "", "address_line1": "", "address_line2": "", "city": "", "state": "", "pincode": ""}
        data = resp.json()
        addr_data = data.get("address", {})
        road = addr_data.get("road") or ""
        house = addr_data.get("house_number") or ""
        area = _extract_area(addr_data)
        city_raw = addr_data.get("city") or addr_data.get("town") or addr_data.get("village") or addr_data.get("county") or ""
        city = _ZONE_RE.sub("", city_raw).strip()
        city = _re.sub(r'\s+(Corporation|Municipal|Municipality|Municipal\s+Corporation)\s*$', '', city).strip()
        parts = []
        if road:
            parts.append(road)
        if house:
            parts.append(house)
        return {
            "display_name": data.get("display_name", ""),
            "address_line1": ", ".join(parts) if parts else data.get("display_name", ""),
            "address_line2": area or city or "",
            "city": city,
            "state": addr_data.get("state") or "",
            "pincode": addr_data.get("postcode") or "",
        }
    except Exception:
        return {"display_name": "", "address_line1": "", "address_line2": "", "city": "", "state": "", "pincode": ""}


@router.get("/places/search")
def search_places(q: str, db: Session = Depends(get_db)):
    try:
        import httpx
        with httpx.Client(timeout=httpx.Timeout(10.0, connect=5, read=8, write=5, pool=5)) as client:
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
                "address_line2": _extract_area(addr_data),
                "city": addr_data.get("city") or addr_data.get("town") or addr_data.get("village") or addr_data.get("county") or "",
                "state": addr_data.get("state") or "",
                "pincode": addr_data.get("postcode") or "",
            })
        return results
    except Exception:
        return []


# ─── WISHLIST ─────────────────────────────────────────────────────

@router.get("/wishlist", response_model=list[WishlistItemResponse])
def list_wishlist(request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    items = db.query(WishlistItem).filter(
        WishlistItem.user_id == user_id,
        WishlistItem.is_deleted == False,
    ).order_by(WishlistItem.created_at.desc()).all()
    result = []
    for item in items:
        prod = item.product
        result.append(WishlistItemResponse(
            id=str(item.id),
            product_id=str(item.product_id),
            product_name=prod.name if prod else "",
            product_price=round(float(prod.price), 2) if prod else 0,
            product_unit=prod.unit if prod else "",
            product_image=next((img.image_url for img in prod.images if not img.is_deleted), None) if prod else None,
            product_discount_percent=prod.discount_percent if prod else 0,
            product_final_price=round(float(prod.price) * (100 - (prod.discount_percent or 0)) / 100, 2) if prod else 0,
            created_at=item.created_at,
        ))
    return result


@router.post("/wishlist", response_model=WishlistItemResponse, status_code=status.HTTP_201_CREATED)
def add_to_wishlist(body: WishlistAddRequest, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    _get_user(user_id, db)
    product = _get_product_or_404(body.product_id, db)

    existing = db.query(WishlistItem).filter(
        WishlistItem.user_id == user_id,
        WishlistItem.product_id == body.product_id,
        WishlistItem.is_deleted == False,
    ).first()
    if existing:
        return WishlistItemResponse(
            id=str(existing.id),
            product_id=str(existing.product_id),
            product_name=product.name,
            product_price=round(float(product.price), 2),
            product_unit=product.unit,
            product_image=next((img.image_url for img in product.images if not img.is_deleted), None),
            product_discount_percent=product.discount_percent,
            product_final_price=round(float(product.price) * (100 - (product.discount_percent or 0)) / 100, 2),
            created_at=existing.created_at,
        )

    soft = db.query(WishlistItem).filter(
        WishlistItem.user_id == user_id,
        WishlistItem.product_id == body.product_id,
        WishlistItem.is_deleted == True,
    ).first()
    if soft:
        soft.is_deleted = False
        db.commit()
        db.refresh(soft)
        return WishlistItemResponse(
            id=str(soft.id),
            product_id=str(soft.product_id),
            product_name=product.name,
            product_price=round(float(product.price), 2),
            product_unit=product.unit,
            product_image=next((img.image_url for img in product.images if not img.is_deleted), None),
            product_discount_percent=product.discount_percent,
            product_final_price=round(float(product.price) * (100 - (product.discount_percent or 0)) / 100, 2),
            created_at=soft.created_at,
        )

    item = WishlistItem(user_id=user_id, product_id=body.product_id)
    db.add(item)
    db.commit()
    db.refresh(item)
    return WishlistItemResponse(
        id=str(item.id),
        product_id=str(item.product_id),
        product_name=product.name,
        product_price=round(float(product.price), 2),
        product_unit=product.unit,
        product_image=next((img.image_url for img in product.images if not img.is_deleted), None),
        product_discount_percent=product.discount_percent,
        product_final_price=round(float(product.price) * (100 - (product.discount_percent or 0)) / 100, 2),
        created_at=item.created_at,
    )


@router.delete("/wishlist/{product_id}", response_model=MessageResponse)
def remove_from_wishlist(product_id: str, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    _validate_uuid(product_id)
    item = db.query(WishlistItem).filter(
        WishlistItem.user_id == user_id,
        WishlistItem.product_id == product_id,
        WishlistItem.is_deleted == False,
    ).first()
    if not item:
        return MessageResponse(message="Item not in wishlist")
    item.is_deleted = True
    db.commit()
    return MessageResponse(message="Removed from wishlist")


# ─── CART ─────────────────────────────────────────────────────────
# Ownership: all queries filter by user_id from JWT.

@router.get("/cart", response_model=list[CartItemResponse])
def list_cart(request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    items = db.query(CartItem).filter(
        CartItem.user_id == user_id,
        CartItem.is_deleted == False,
    ).all()
    return [_cart_item_to_response(i) for i in items]


@router.post("/cart", response_model=CartItemResponse, status_code=status.HTTP_201_CREATED)
def add_to_cart(body: CartAddRequest, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    _get_user(user_id, db)
    product = _get_product_or_404(body.product_id, db, for_update=True)

    if product.stock < body.quantity:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Insufficient stock")

    existing = db.query(CartItem).filter(
        CartItem.user_id == user_id,
        CartItem.product_id == body.product_id,
        CartItem.is_deleted == False,
    ).first()

    if existing:
        new_qty = existing.quantity + body.quantity
        if product.stock < new_qty:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Insufficient stock for {product.name}")
        existing.quantity = new_qty
        db.commit()
        db.refresh(existing)
        return _cart_item_to_response(existing)

    # Check if there's a soft-deleted entry and restore it.
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
    user_id = _get_user_id(request)
    _validate_uuid(item_id)
    item = _get_cart_item_or_404(item_id, user_id, db)

    if body.quantity == 0:
        item.is_deleted = True
        db.commit()
        from fastapi.responses import JSONResponse
        return JSONResponse(content={"detail": "Item removed from cart"}, status_code=status.HTTP_200_OK)

    item.quantity = body.quantity
    product = item.product
    if product and body.quantity > 0 and product.stock < body.quantity:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Insufficient stock for {product.name}")
    db.commit()
    db.refresh(item)
    return _cart_item_to_response(item)


@router.delete("/cart/{item_id}", response_model=MessageResponse)
def remove_cart_item(item_id: str, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    _validate_uuid(item_id)
    item = _get_cart_item_or_404(item_id, user_id, db)
    item.is_deleted = True
    db.commit()
    return MessageResponse(message="Item removed from cart")


@router.delete("/cart", response_model=MessageResponse)
def clear_cart(request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    items = db.query(CartItem).filter(
        CartItem.user_id == user_id,
        CartItem.is_deleted == False,
    ).all()
    for item in items:
        item.is_deleted = True
    db.commit()
    return MessageResponse(message="Cart cleared")


@router.post("/cart/validate", response_model=CartValidateResponse)
def validate_cart(request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    cart_items = db.query(CartItem).filter(
        CartItem.user_id == user_id,
        CartItem.is_deleted == False,
    ).all()
    if not cart_items:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cart is empty")
    
    all_valid = True
    items = []
    total = 0.0
    
    for ci in cart_items:
        product = _get_product_or_404(str(ci.product_id), db)
        current_price = round(float(product.price) * (100 - (product.discount_percent or 0)) / 100, 2)
        messages = []
        
        if product.stock <= 0:
            messages.append(f"{product.name} is out of stock")
            valid = False
        elif product.stock < ci.quantity:
            messages.append(f"Only {product.stock} units available for {product.name}")
            valid = False
        else:
            valid = True
        
        subtotal = round(current_price * ci.quantity, 2)
        items.append(CartValidateItem(
            product_id=str(product.id),
            current_price=current_price,
            current_stock=product.stock,
            quantity=ci.quantity,
            subtotal=subtotal,
            valid=valid,
            message="; ".join(messages) if messages else None,
        ))
        if not valid:
            all_valid = False
        total += subtotal
    
    return CartValidateResponse(valid=all_valid, items=items, total=round(total, 2))


# ─── ORDERS ───────────────────────────────────────────────────────
# Ownership: all queries filter by user_id from JWT.

@router.get("/orders", response_model=list[OrderResponse])
def list_orders(request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    orders = db.query(Order).filter(
        Order.user_id == user_id,
        Order.is_deleted == False,
    ).order_by(Order.created_at.desc()).all()
    return [_order_to_response(o) for o in orders]


@router.get("/orders/{order_id}", response_model=OrderResponse)
def get_order(order_id: str, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    _validate_uuid(order_id)
    order = _get_order_or_404(order_id, user_id, db)
    return _order_to_response(order)


@router.post("/orders", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
def create_order(body: OrderCreateRequest, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    _get_user(user_id, db)

    addr = _get_address_or_404(body.address_id, user_id, db)

    cart_items = db.query(CartItem).filter(
        CartItem.user_id == user_id,
        CartItem.is_deleted == False,
    ).all()

    if not cart_items:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cart is empty")

    total = Decimal("0.00")
    products_with_qty = []

    for ci in cart_items:
        product = _get_product_or_404(str(ci.product_id), db, for_update=True)
        if product.stock < ci.quantity:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient stock for {product.name}",
            )
        selling_price = round(float(product.price) * (100 - (product.discount_percent or 0)) / 100, 2)
        total += Decimal(str(selling_price)) * ci.quantity
        products_with_qty.append((product, ci.quantity, selling_price))

    order = Order(
        user_id=user_id,
        address_id=addr.id,
        total_amount=total,
        payment_method=body.payment_method,
    )
    db.add(order)
    db.flush()

    try:
        for product, qty, price in products_with_qty:
            oi = OrderItem(
                order_id=order.id,
                product_id=product.id,
                product_name=product.name,
                product_price=Decimal(str(price)),
                quantity=qty,
                subtotal=Decimal(str(price)) * qty,
            )
            db.add(oi)
            product.stock -= qty

        for ci in cart_items:
            ci.is_deleted = True

        otp = ''.join(secrets.choice(_string.digits) for _ in range(6))
        order.delivery_otp = otp
        db.commit()
    except Exception:
        db.rollback()
        raise

    db.refresh(order)
    return _order_to_response(order)


@router.post("/orders/direct", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
def create_order_direct(body: OrderDirectCreateRequest, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    _get_user(user_id, db)

    total = Decimal("0.00")
    products_with_qty = []

    for item in body.items:
        product = _get_product_or_404(item.product_id, db, for_update=True)
        if product.stock < item.quantity:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient stock for {product.name}",
            )
        selling_price = round(float(product.price) * (100 - (product.discount_percent or 0)) / 100, 2)
        total += Decimal(str(selling_price)) * item.quantity
        products_with_qty.append((product, item.quantity, selling_price))

    address_id = body.address_id
    if address_id:
        _validate_uuid(address_id)
        addr = db.query(Address).filter(
            Address.id == address_id,
            Address.user_id == user_id,
            Address.is_deleted == False,
        ).first()
        if not addr:
            address_id = None
        else:
            if addr.latitude is not None and addr.longitude is not None:
                zones = db.query(DeliveryZone).filter(
                    DeliveryZone.is_deleted == False,
                    DeliveryZone.is_active == True,
                ).all()
                if zones:
                    from shapely.geometry import shape as shapely_shape
                    from shapely.geometry import Point
                    point = Point(float(addr.longitude), float(addr.latitude))
                    in_zone = False
                    for z in zones:
                        try:
                            geom = json.loads(z.geojson_data)
                            polygon = shapely_shape(geom)
                            if polygon.contains(point):
                                in_zone = True
                                break
                        except Exception:
                            continue
                    if not in_zone:
                        raise HTTPException(
                            status_code=status.HTTP_403_FORBIDDEN,
                            detail="Delivery not available in your area",
                        )

    order = Order(
        user_id=user_id,
        address_id=address_id,
        total_amount=total,
        payment_method=body.payment_method,
    )
    db.add(order)
    db.flush()

    try:
        for product, qty, price in products_with_qty:
            oi = OrderItem(
                order_id=order.id,
                product_id=product.id,
                product_name=product.name,
                product_price=Decimal(str(price)),
                quantity=qty,
                subtotal=Decimal(str(price)) * qty,
            )
            db.add(oi)
            product.stock -= qty

        payment = Payment(
            order_id=order.id,
            user_id=user_id,
            method=body.payment_method,
            status="success",
            amount=total,
        )
        payment.transaction_id = str(uuid.uuid4()).replace("-", "")[:16].upper()
        db.add(payment)

        otp = ''.join(secrets.choice(_string.digits) for _ in range(6))
        order.delivery_otp = otp
        db.commit()
    except Exception:
        db.rollback()
        raise

    db.refresh(order)
    return _order_to_response(order)


# ─── PAYMENTS ─────────────────────────────────────────────────────
# Security: NEVER accept or store card numbers, CVV, bank details.
# Only COD (Cash on Delivery) is supported.

PAYMENT_TIMEOUT_SECONDS = 60


def _payment_to_response(payment: Payment) -> PaymentResponse:
    expires_at = payment.created_at + timedelta(seconds=PAYMENT_TIMEOUT_SECONDS)
    return PaymentResponse(
        id=str(payment.id),
        order_id=str(payment.order_id),
        amount=round(float(payment.amount), 2),
        method=payment.method,
        status=payment.status,
        transaction_id=payment.transaction_id,
        expires_at=expires_at,
        created_at=payment.created_at,
    )


def _check_payment_expiry(payment: Payment, db: Session):
    if payment.status != "pending":
        return
    elapsed = (datetime.now(timezone.utc) - payment.created_at).total_seconds()
    if elapsed >= PAYMENT_TIMEOUT_SECONDS:
        payment.status = "failed"
        payment.transaction_id = None
        db.commit()
        db.refresh(payment)


@router.post("/payments/process", response_model=PaymentResponse)
def process_payment(body: PaymentProcessRequest, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    _get_user(user_id, db)
    _validate_uuid(body.order_id)

    order = db.query(Order).filter(
        Order.id == body.order_id,
        Order.user_id == user_id,
        Order.is_deleted == False,
    ).first()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")

    if order.status != "Pending":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Payment already processed")

    existing_payment = db.query(Payment).filter(
        Payment.order_id == order.id,
        Payment.is_deleted == False,
    ).first()
    if existing_payment:
        return _payment_to_response(existing_payment)

    payment = Payment(
        order_id=order.id,
        user_id=user_id,
        amount=order.total_amount,
        method=body.method,
        status="success",
        transaction_id="COD" + datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S") + str(uuid.uuid4()).split("-")[0],
    )
    order.status = "Confirmed"
    db.add(payment)
    db.commit()
    db.refresh(payment)
    return _payment_to_response(payment)


@router.get("/payments/{order_id}", response_model=PaymentResponse)
def get_payment(order_id: str, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    _validate_uuid(order_id)
    payment = db.query(Payment).filter(
        Payment.order_id == order_id,
        Payment.user_id == user_id,
        Payment.is_deleted == False,
    ).first()
    if not payment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found")
    return _payment_to_response(payment)


@router.post("/check-zone", response_model=ZoneCheckResponse)
def check_delivery_zone(body: ZoneCheckRequest, db: Session = Depends(get_db)):
    try:
        zones = db.query(DeliveryZone).filter(
            DeliveryZone.is_deleted == False,
            DeliveryZone.is_active == True,
        ).all()
        if not zones:
            return ZoneCheckResponse(serviceable=True, message="No zones configured — allowing all areas")

        from shapely.geometry import shape as shapely_shape
        from shapely.geometry import Point

        point = Point(body.lng, body.lat)
        for z in zones:
            geom = json.loads(z.geojson_data)
            polygon = shapely_shape(geom)
            if polygon.contains(point):
                return ZoneCheckResponse(serviceable=True)
        return ZoneCheckResponse(serviceable=False, message="Sorry, delivery not available in your area")
    except Exception:
        return ZoneCheckResponse(serviceable=False, message="Unable to verify delivery area")


# ─── COMBO PACKS ──────────────────────────────────────────────────


def _pack_to_response(pack: ComboPack) -> dict:
    items = []
    for pi in pack.items:
        if not pi.is_deleted:
            prod = pi.product
            items.append({
                "id": str(pi.id),
                "product_id": str(pi.product_id),
                "product_name": prod.name if prod else "",
                "product_price": round(float(prod.price), 2) if prod else 0,
                "product_unit": prod.unit if prod else "",
                "product_image": next((img.image_url for img in prod.images if not img.is_deleted), None) if prod else None,
                "quantity": pi.quantity,
            })
    return {
        "id": str(pack.id),
        "name": pack.name,
        "description": pack.description,
        "image_url": pack.image_url,
        "total_price": round(float(pack.total_price), 2),
        "discount_label": pack.discount_label,
        "savings_text": pack.savings_text,
        "is_enabled": pack.is_enabled,
        "items": items,
        "created_at": pack.created_at,
    }


@router.get("/combo-packs")
def list_combo_packs(db: Session = Depends(get_db)):
    packs = db.query(ComboPack).filter(
        ComboPack.is_deleted == False,
        ComboPack.is_enabled == True,
    ).order_by(ComboPack.name).all()

    result = []
    for pack in packs:
        # Check if all items have sufficient stock
        all_in_stock = True
        for pi in pack.items:
            if not pi.is_deleted and pi.product:
                if pi.product.stock < pi.quantity:
                    all_in_stock = False
                    break
        if not all_in_stock:
            continue
        result.append(_pack_to_response(pack))
    return result


@router.post("/combo-packs/add-to-cart", status_code=status.HTTP_200_OK)
def add_pack_to_cart(body: PackAddRequest, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    _get_user(user_id, db)
    _validate_uuid(body.pack_id)

    pack = db.query(ComboPack).filter(
        ComboPack.id == body.pack_id,
        ComboPack.is_deleted == False,
        ComboPack.is_enabled == True,
    ).first()
    if not pack:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pack not found")

    added = []
    for pi in pack.items:
        if pi.is_deleted:
            continue
        prod = _get_product_or_404(str(pi.product_id), db, for_update=True)
        if prod.stock < pi.quantity:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient stock for {prod.name}",
            )
        existing = db.query(CartItem).filter(
            CartItem.user_id == user_id,
            CartItem.product_id == pi.product_id,
            CartItem.is_deleted == False,
        ).first()
        if existing:
            existing.quantity += pi.quantity
            db.flush()
        else:
            soft = db.query(CartItem).filter(
                CartItem.user_id == user_id,
                CartItem.product_id == pi.product_id,
                CartItem.is_deleted == True,
            ).first()
            if soft:
                soft.is_deleted = False
                soft.quantity = pi.quantity
                db.flush()
            else:
                item = CartItem(user_id=user_id, product_id=pi.product_id, quantity=pi.quantity)
                db.add(item)
                db.flush()
        added.append({
            "product_id": str(pi.product_id),
            "product_name": prod.name,
            "quantity": pi.quantity,
        })
    db.commit()
    return {"message": "Pack added to cart", "items": added}


# ─── PRODUCT SUGGESTIONS ──────────────────────────────────────────


@router.post("/suggest-product", status_code=status.HTTP_201_CREATED)
def suggest_product(body: SuggestProductRequest, request: Request, db: Session = Depends(get_db)):
    user_id = getattr(request.state, "user_id", None)
    suggestion = ProductSuggestion(
        user_id=user_id,
        product_name=body.product_name.strip(),
        reason=body.reason.strip() if body.reason else None,
    )
    db.add(suggestion)
    db.commit()
    return {"message": "Thanks for your suggestion!"}


# ─── APP VERSION ─────────────────────────────────────────────────


@router.get("/app-version", response_model=AppVersionResponse)
def get_latest_app_version(db: Session = Depends(get_db)):
    record = db.query(AppVersion).filter(AppVersion.is_active == True).order_by(AppVersion.created_at.desc()).first()
    if not record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No version info available")
    return AppVersionResponse(
        latest_version=record.version,
        apk_download_url=record.apk_download_url,
        release_notes=record.release_notes,
    )


# ─── NOTIFICATIONS ────────────────────────────────────────────────


@router.get("/notifications", response_model=list[NotificationResponse])
def list_notifications(request: Request, db: Session = Depends(get_db)):
    _get_user_id(request)
    cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
    notifications = db.query(Notification).filter(
        Notification.is_deleted == False,
        Notification.created_at >= cutoff,
    ).order_by(Notification.created_at.desc()).limit(50).all()
    return [
        NotificationResponse(
            id=str(n.id),
            title=n.title,
            message=n.message,
            type=n.type,
            image_url=n.image_url,
            link=n.link,
            created_at=n.created_at,
        ) for n in notifications
    ]

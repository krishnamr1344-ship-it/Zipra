import os
import uuid
import pytest
from decimal import Decimal
from datetime import datetime, timezone
from unittest.mock import patch, MagicMock

os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")
os.environ.setdefault("JWT_SECRET", "test-secret-key-that-is-at-least-32-chars!!")

_db_file = os.path.join(os.getcwd(), "test.db")
if os.path.exists(_db_file):
    os.remove(_db_file)
os.environ.setdefault("FRONTEND_URL", "http://localhost:3000")
os.environ.setdefault("ADMIN_EMAIL", "admin@test.com")
os.environ.setdefault("ADMIN_PASSWORD", "AdminPass123!")
os.environ.setdefault("RAZORPAY_ENABLED", "false")
os.environ.setdefault("RAZORPAY_KEY_ID", "rzp_test_key")
os.environ.setdefault("RAZORPAY_KEY_SECRET", "test_secret")
os.environ.setdefault("RAZORPAY_WEBHOOK_SECRET", "whsec_test")
os.environ.setdefault("RATE_LIMIT_MAX_ATTEMPTS", "1000")
os.environ.setdefault("RATE_LIMIT_WINDOW_SECONDS", "1")
os.environ.setdefault("API_KEY", "")
os.environ.setdefault("SUPABASE_URL", "")
os.environ.setdefault("SUPABASE_SERVICE_KEY", "")

from sqlalchemy import String, TypeDecorator


class _TestUUID(TypeDecorator):
    impl = String(36)
    cache_ok = True

    def __init__(self, as_uuid=True, *args, **kwargs):
        self.as_uuid = as_uuid
        super().__init__(*args, **kwargs)

    def process_bind_param(self, value, dialect):
        if value is not None:
            return str(value)
        return value

    def process_result_value(self, value, dialect):
        if value is not None and self.as_uuid:
            return uuid.UUID(value)
        return value


import sqlalchemy.dialects.postgresql as pg_types
pg_types.UUID = _TestUUID

from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient

from database import Base, get_db
import database

database.engine = create_engine(
    os.environ["DATABASE_URL"],
    connect_args={"check_same_thread": False},
)
database.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=database.engine)

Base.metadata.create_all(bind=database.engine)

from models import User, Product, Category, Address, CartItem, Order, OrderItem, Payment, ProductFlag
from auth import _create_jwt
from main import app
import resources


@pytest.fixture()
def db_session():
    connection = database.engine.connect()
    transaction = connection.begin()
    session = database.SessionLocal(bind=connection)

    real_commit = session.commit
    def _test_commit():
        session.flush()
    session.commit = _test_commit

    real_rollback = session.rollback
    def _test_rollback():
        session.expire_all()
    session.rollback = _test_rollback

    def _override_get_db():
        yield session

    app.dependency_overrides[get_db] = _override_get_db
    yield session

    transaction.rollback()
    session.close()
    connection.close()
    app.dependency_overrides.clear()


@pytest.fixture()
def test_user(db_session):
    user = User(
        email="test@example.com",
        password_hash="dummy_hash",
        name="Test User",
        phone="1234567890",
        role="user",
    )
    db_session.add(user)
    db_session.flush()
    return user


@pytest.fixture()
def admin_user(db_session):
    user = User(
        email="admin@test.com",
        password_hash="dummy_hash",
        name="Admin",
        phone="0000000000",
        role="admin",
    )
    db_session.add(user)
    db_session.flush()
    return user


@pytest.fixture()
def auth_headers(test_user):
    token, _, _ = _create_jwt(str(test_user.id), role=test_user.role)
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture()
def admin_auth_headers(admin_user):
    token, _, _ = _create_jwt(str(admin_user.id), role=admin_user.role)
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture()
def test_category(db_session):
    cat = Category(name="Test Category")
    db_session.add(cat)
    db_session.flush()
    return cat


@pytest.fixture()
def test_product(db_session, test_category):
    product = Product(
        category_id=test_category.id,
        name="Test Product",
        price=Decimal("100.00"),
        unit="kg",
        stock=50,
        description="Test description",
        discount_percent=10,
    )
    db_session.add(product)
    db_session.flush()

    flag = ProductFlag(product_id=product.id, is_enabled=True)
    db_session.add(flag)
    db_session.flush()

    return product


@pytest.fixture()
def low_stock_product(db_session, test_category):
    product = Product(
        category_id=test_category.id,
        name="Low Stock Product",
        price=Decimal("50.00"),
        unit="kg",
        stock=3,
        description="Low stock item",
        discount_percent=0,
    )
    db_session.add(product)
    db_session.flush()

    flag = ProductFlag(product_id=product.id, is_enabled=True)
    db_session.add(flag)
    db_session.flush()

    return product


@pytest.fixture()
def test_address(db_session, test_user):
    addr = Address(
        user_id=test_user.id,
        label="Home",
        address_line1="123 Test St",
        city="Test City",
        state="Test State",
        pincode="600001",
        address_type="Home",
    )
    db_session.add(addr)
    db_session.flush()
    return addr


@pytest.fixture()
def test_order(db_session, test_user, test_product, test_address):
    order = Order(
        user_id=test_user.id,
        address_id=test_address.id,
        status="Pending",
        total_amount=Decimal("90.00"),
        payment_method="Razorpay",
    )
    db_session.add(order)
    db_session.flush()

    item = OrderItem(
        order_id=order.id,
        product_id=test_product.id,
        product_name=test_product.name,
        product_price=Decimal("90.00"),
        quantity=1,
        subtotal=Decimal("90.00"),
    )
    db_session.add(item)
    db_session.flush()

    return order


@pytest.fixture()
def test_cart_item(db_session, test_user, test_product):
    item = CartItem(
        user_id=test_user.id,
        product_id=test_product.id,
        quantity=2,
    )
    db_session.add(item)
    db_session.flush()
    return item


@pytest.fixture()
def client():
    with TestClient(app) as c:
        yield c


def _valid_signature(order_id, payment_id, secret):
    import hashlib, hmac
    return hmac.new(
        secret.encode("utf-8"),
        f"{order_id}|{payment_id}".encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def _make_razorpay_order_response(amount=9000):
    return {
        "id": f"order_{uuid.uuid4().hex[:12]}",
        "entity": "order",
        "amount": amount,
        "amount_paid": 0,
        "amount_due": amount,
        "currency": "INR",
        "receipt": "receipt_test",
        "status": "created",
        "attempts": 0,
        "notes": {},
        "created_at": int(datetime.now(timezone.utc).timestamp()),
    }


@pytest.fixture()
def mock_razorpay_client():
    with patch.object(resources, "_razorpay_create_order") as mock_fn:
        mock_fn.return_value = _make_razorpay_order_response()
        yield mock_fn

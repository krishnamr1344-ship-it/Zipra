import uuid
from decimal import Decimal
from datetime import datetime, timezone, timedelta

PAYMENT_TIMEOUT_SECONDS = 60


class TestPaymentProcess:
    """POST /api/payments/process — COD payment flow."""

    def test_cod_payment_process_success(self, client, db_session, auth_headers, test_user, test_product, test_address):
        from models import CartItem, Order, Payment
        db_session.add(CartItem(user_id=test_user.id, product_id=test_product.id, quantity=2))
        db_session.flush()

        resp = client.post("/api/orders", json={
            "address_id": str(test_address.id),
            "payment_method": "COD",
        }, headers=auth_headers)
        assert resp.status_code == 201
        order_id = resp.json()["id"]

        resp2 = client.post("/api/payments/process", json={
            "order_id": order_id,
            "method": "COD",
        }, headers=auth_headers)
        data = resp2.json()
        assert resp2.status_code == 200
        assert data["status"] == "success"
        assert data["method"] == "COD"
        assert data["transaction_id"].startswith("COD")

        db_session.expire_all()
        order = db_session.query(Order).filter(Order.id == order_id).first()
        assert order.status == "Confirmed"
        assert order.delivery_otp is not None
        assert len(order.delivery_otp) == 6

        payment = db_session.query(Payment).filter(Payment.order_id == order_id).first()
        assert payment is not None
        assert payment.status == "success"

        cart_count = db_session.query(CartItem).filter(
            CartItem.user_id == test_user.id, CartItem.is_deleted == False
        ).count()
        assert cart_count == 0

    def test_cod_payment_already_processed(self, client, db_session, auth_headers, test_user, test_product, test_address):
        from models import CartItem
        db_session.add(CartItem(user_id=test_user.id, product_id=test_product.id, quantity=1))
        db_session.flush()

        resp = client.post("/api/orders", json={
            "address_id": str(test_address.id),
            "payment_method": "COD",
        }, headers=auth_headers)
        order_id = resp.json()["id"]

        client.post("/api/payments/process", json={"order_id": order_id, "method": "COD"}, headers=auth_headers)

        resp2 = client.post("/api/payments/process", json={"order_id": order_id, "method": "COD"}, headers=auth_headers)
        assert resp2.status_code == 400
        assert "already processed" in resp2.json()["detail"].lower()

    def test_cod_payment_order_not_found(self, client, auth_headers):
        resp = client.post("/api/payments/process", json={
            "order_id": str(uuid.uuid4()),
            "method": "COD",
        }, headers=auth_headers)
        assert resp.status_code == 404

    def test_cod_payment_wrong_user(self, client, db_session, auth_headers, test_address):
        from models import User, Order
        other = User(
            email="other@test.com", password_hash="x", name="Other", phone="9999999999", role="user",
        )
        db_session.add(other)
        db_session.flush()

        order = Order(user_id=other.id, address_id=test_address.id, status="Pending", total_amount=50, payment_method="COD")
        db_session.add(order)
        db_session.flush()

        resp = client.post("/api/payments/process", json={
            "order_id": str(order.id),
            "method": "COD",
        }, headers=auth_headers)
        assert resp.status_code == 404

    def test_get_payment_status(self, client, db_session, auth_headers, test_user, test_product, test_address):
        from models import CartItem, Payment
        db_session.add(CartItem(user_id=test_user.id, product_id=test_product.id, quantity=1))
        db_session.flush()

        resp = client.post("/api/orders", json={
            "address_id": str(test_address.id),
            "payment_method": "COD",
        }, headers=auth_headers)
        order_id = resp.json()["id"]

        client.post("/api/payments/process", json={"order_id": order_id, "method": "COD"}, headers=auth_headers)

        resp2 = client.get(f"/api/payments/{order_id}", headers=auth_headers)
        assert resp2.status_code == 200
        data = resp2.json()
        assert data["status"] == "success"
        assert data["order_id"] == order_id

    def test_cart_cleared_after_payment(self, client, db_session, auth_headers, test_user, test_product, test_address):
        from models import CartItem, Product
        products = []
        for i in range(3):
            p = Product(
                category_id=test_product.category_id, name=f"P{i}", price=10, unit="kg", stock=50,
            )
            db_session.add(p)
            db_session.flush()
            db_session.add(CartItem(user_id=test_user.id, product_id=p.id, quantity=1))
            products.append(p)
        db_session.flush()

        resp = client.post("/api/orders", json={
            "address_id": str(test_address.id),
            "payment_method": "COD",
        }, headers=auth_headers)
        order_id = resp.json()["id"]

        client.post("/api/payments/process", json={"order_id": order_id, "method": "COD"}, headers=auth_headers)

        items = db_session.query(CartItem).filter(
            CartItem.user_id == test_user.id, CartItem.is_deleted == False
        ).all()
        assert len(items) == 0

    def test_direct_order_cod_auto_confirms(self, client, db_session, auth_headers, test_user, test_product, test_address):
        from models import Order
        resp = client.post("/api/orders/direct", json={
            "items": [{"product_id": str(test_product.id), "quantity": 1}],
            "payment_method": "COD",
            "address_id": str(test_address.id),
        }, headers=auth_headers)
        assert resp.status_code == 201
        data = resp.json()
        assert data["status"] == "Confirmed"
        assert data["payment_method"] == "COD"

        db_session.expire_all()
        order = db_session.query(Order).filter(Order.id == data["id"]).first()
        assert order.delivery_otp is not None
        assert len(order.delivery_otp) == 6

        assert test_product.stock == 49

    def test_payment_timeout_expiration(self, client, db_session, auth_headers, test_user, test_address):
        from models import Order, Payment
        order = Order(
            user_id=test_user.id, address_id=test_address.id,
            status="Pending", total_amount=90, payment_method="Razorpay",
        )
        db_session.add(order)
        db_session.flush()

        payment = Payment(
            order_id=order.id, user_id=test_user.id, amount=90,
            method="Razorpay", status="pending",
        )
        db_session.add(payment)
        db_session.flush()

        resp = client.get(f"/api/payments/{order.id}", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        assert "expires_at" in data

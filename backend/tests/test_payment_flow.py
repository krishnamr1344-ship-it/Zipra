import uuid
from datetime import datetime, timezone, timedelta

PAYMENT_TIMEOUT_SECONDS = 60


class TestPaymentProcess:
    """POST /api/payments/process — payment flow."""

    def test_payment_status(self, client, db_session, auth_headers, test_user, test_product, test_address):
        from models import CartItem, Payment
        db_session.add(CartItem(user_id=test_user.id, product_id=test_product.id, quantity=1))
        db_session.flush()

        resp = client.post("/api/orders", json={
            "address_id": str(test_address.id),
            "payment_method": "Razorpay",
        }, headers=auth_headers)
        assert resp.status_code == 201
        order_id = resp.json()["id"]

        # Create a pending payment
        payment = Payment(
            order_id=order_id, user_id=test_user.id,
            amount=90, method="Razorpay", status="pending",
        )
        db_session.add(payment)
        db_session.flush()

        resp2 = client.get(f"/api/payments/{order_id}", headers=auth_headers)
        assert resp2.status_code == 200
        data = resp2.json()
        assert data["status"] == "pending"
        assert data["order_id"] == order_id

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

    def test_payment_order_not_found(self, client, auth_headers):
        resp = client.get(f"/api/payments/{uuid.uuid4()}", headers=auth_headers)
        assert resp.status_code == 404

    def test_payment_wrong_user(self, client, db_session, auth_headers, test_address):
        from models import User, Order, Payment
        other = User(
            email="other@test.com", password_hash="x", name="Other", phone="9999999999", role="user",
        )
        db_session.add(other)
        db_session.flush()

        order = Order(user_id=other.id, address_id=test_address.id, status="Pending", total_amount=50, payment_method="Razorpay")
        db_session.add(order)
        db_session.flush()

        payment = Payment(
            order_id=order.id, user_id=other.id, amount=50,
            method="Razorpay", status="pending",
        )
        db_session.add(payment)
        db_session.flush()

        resp = client.get(f"/api/payments/{order.id}", headers=auth_headers)
        assert resp.status_code == 404

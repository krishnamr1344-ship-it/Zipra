import uuid
import hmac
import hashlib
import json
from decimal import Decimal
from unittest.mock import patch


def _valid_signature(order_id, payment_id, secret):
    return hmac.new(
        secret.encode("utf-8"),
        f"{order_id}|{payment_id}".encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


class TestRazorpayCreateOrder:
    """POST /api/payments/create-order — Razorpay order creation."""

    def test_create_razorpay_order_success(self, client, db_session, auth_headers, test_user, test_product, test_address, mock_razorpay_client):
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret"):
            resp = client.post("/api/orders/direct", json={
                "items": [{"product_id": str(test_product.id), "quantity": 1}],
                "payment_method": "Razorpay",
                "address_id": str(test_address.id),
            }, headers=auth_headers)
            order_id = resp.json()["id"]

            resp2 = client.post("/api/payments/create-order", json={"order_id": order_id}, headers=auth_headers)
            assert resp2.status_code == 200
            data = resp2.json()
            assert "razorpay_order_id" in data
            assert data["amount"] == 13000
            assert data["currency"] == "INR"
            assert "key_id" in data

            from models import Payment
            payment = db_session.query(Payment).filter(Payment.order_id == order_id).first()
            assert payment is not None
            assert payment.status == "pending"
            assert payment.gateway_order_id == data["razorpay_order_id"]

    def test_create_order_disabled(self, client, db_session, auth_headers, test_user, test_product, test_address):
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=False):
            resp = client.post("/api/orders/direct", json={
                "items": [{"product_id": str(test_product.id), "quantity": 1}],
                "payment_method": "Razorpay",
                "address_id": str(test_address.id),
            }, headers=auth_headers)
            order_id = resp.json()["id"]

            resp2 = client.post("/api/payments/create-order", json={"order_id": order_id}, headers=auth_headers)
            assert resp2.status_code == 503

    def test_create_order_not_configured(self, client, db_session, auth_headers, test_user, test_product, test_address):
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="", RAZORPAY_KEY_SECRET=""):
            resp = client.post("/api/orders/direct", json={
                "items": [{"product_id": str(test_product.id), "quantity": 1}],
                "payment_method": "Razorpay",
                "address_id": str(test_address.id),
            }, headers=auth_headers)
            order_id = resp.json()["id"]

            resp2 = client.post("/api/payments/create-order", json={"order_id": order_id}, headers=auth_headers)
            assert resp2.status_code == 500

    def test_create_order_wrong_method(self, client, db_session, auth_headers, test_user, test_product, test_address):
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret"):
            # Payment method must be 'Razorpay' — "invalid" is rejected at validation
            resp = client.post("/api/orders/direct", json={
                "items": [{"product_id": str(test_product.id), "quantity": 1}],
                "payment_method": "invalid",
                "address_id": str(test_address.id),
            }, headers=auth_headers)
            assert resp.status_code == 422

    def test_create_order_already_paid(self, client, db_session, auth_headers, test_user, test_product, test_address, mock_razorpay_client):
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret"):
            resp = client.post("/api/orders/direct", json={
                "items": [{"product_id": str(test_product.id), "quantity": 1}],
                "payment_method": "Razorpay",
                "address_id": str(test_address.id),
            }, headers=auth_headers)
            order_id = resp.json()["id"]

            client.post("/api/payments/create-order", json={"order_id": order_id}, headers=auth_headers)

            from models import Payment
            payment = db_session.query(Payment).filter(Payment.order_id == order_id).first()
            payment.status = "success"
            db_session.flush()

            resp2 = client.post("/api/payments/create-order", json={"order_id": order_id}, headers=auth_headers)
            assert resp2.status_code == 400

    def test_create_order_existing_success_payment(self, client, db_session, auth_headers, test_user, test_product, test_address, mock_razorpay_client):
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret"):
            resp = client.post("/api/orders/direct", json={
                "items": [{"product_id": str(test_product.id), "quantity": 1}],
                "payment_method": "Razorpay",
                "address_id": str(test_address.id),
            }, headers=auth_headers)
            order_id = resp.json()["id"]

            from models import Payment
            existing_payment = Payment(
                order_id=order_id, user_id=test_user.id, amount=90,
                method="Razorpay", status="success",
            )
            db_session.add(existing_payment)
            db_session.flush()

            resp2 = client.post("/api/payments/create-order", json={"order_id": order_id}, headers=auth_headers)
            assert resp2.status_code == 400


class TestRazorpayVerify:
    """POST /api/payments/verify — Verify Razorpay payment signature."""

    def _setup_order_with_pending_payment(self, client, db_session, auth_headers, test_user, test_product, test_address):
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret"):
            resp = client.post("/api/orders/direct", json={
                "items": [{"product_id": str(test_product.id), "quantity": 1}],
                "payment_method": "Razorpay",
                "address_id": str(test_address.id),
            }, headers=auth_headers)
            order_id = resp.json()["id"]
            client.post("/api/payments/create-order", json={"order_id": order_id}, headers=auth_headers)

            from models import Payment
            payment = db_session.query(Payment).filter(Payment.order_id == order_id).first()
            return order_id, str(payment.gateway_order_id)

    def test_verify_success(self, client, db_session, auth_headers, test_user, test_product, test_address, mock_razorpay_client):
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="test_secret"):
            order_id, gateway_order_id = self._setup_order_with_pending_payment(
                client, db_session, auth_headers, test_user, test_product, test_address
            )
            payment_id = f"pay_{uuid.uuid4().hex[:16]}"
            sig = _valid_signature(gateway_order_id, payment_id, "test_secret")

            resp = client.post("/api/payments/verify", json={
                "order_id": order_id,
                "razorpay_payment_id": payment_id,
                "razorpay_signature": sig,
            }, headers=auth_headers)
            assert resp.status_code == 200
            data = resp.json()
            assert data["status"] == "success"

            from models import Order, Payment
            db_session.expire_all()
            order = db_session.query(Order).filter(Order.id == order_id).first()
            assert order.status == "Confirmed"

            payment = db_session.query(Payment).filter(Payment.order_id == order_id).first()
            assert payment.status == "success"
            assert payment.gateway_payment_id == payment_id

    def test_verify_invalid_signature(self, client, db_session, auth_headers, test_user, test_product, test_address, mock_razorpay_client):
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="test_secret"):
            order_id, _ = self._setup_order_with_pending_payment(
                client, db_session, auth_headers, test_user, test_product, test_address
            )

            resp = client.post("/api/payments/verify", json={
                "order_id": order_id,
                "razorpay_payment_id": f"pay_{uuid.uuid4().hex[:16]}",
                "razorpay_signature": "invalid_signature",
            }, headers=auth_headers)
            assert resp.status_code == 400
            assert "verification failed" in resp.json()["detail"].lower()

            from models import Order, Payment
            db_session.expire_all()
            order = db_session.query(Order).filter(Order.id == order_id).first()
            assert order.status == "Failed"
            payment = db_session.query(Payment).filter(Payment.order_id == order_id).first()
            assert payment.status == "failed"

    def test_verify_duplicate_payment_id(self, client, db_session, auth_headers, test_user, test_product, test_address, mock_razorpay_client):
        import resources
        secret = "test_secret"
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET=secret):
            order_id, gateway_order_id = self._setup_order_with_pending_payment(
                client, db_session, auth_headers, test_user, test_product, test_address
            )
            payment_id = f"pay_{uuid.uuid4().hex[:16]}"
            sig = _valid_signature(gateway_order_id, payment_id, secret)

            from models import Payment
            dup = Payment(
                order_id=uuid.uuid4(), user_id=test_user.id, amount=90,
                method="Razorpay", status="success",
                gateway_payment_id=payment_id,
            )
            db_session.add(dup)
            db_session.flush()

            resp = client.post("/api/payments/verify", json={
                "order_id": order_id,
                "razorpay_payment_id": payment_id,
                "razorpay_signature": sig,
            }, headers=auth_headers)
            assert resp.status_code == 400

    def test_verify_no_pending_payment(self, client, db_session, auth_headers, test_user, test_product, test_address):
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret"):
            resp = client.post("/api/orders/direct", json={
                "items": [{"product_id": str(test_product.id), "quantity": 1}],
                "payment_method": "Razorpay",
                "address_id": str(test_address.id),
            }, headers=auth_headers)
            order_id = resp.json()["id"]

            resp2 = client.post("/api/payments/verify", json={
                "order_id": order_id,
                "razorpay_payment_id": f"pay_{uuid.uuid4().hex[:16]}",
                "razorpay_signature": "sig",
            }, headers=auth_headers)
            assert resp2.status_code == 404

    def test_verify_order_already_paid(self, client, db_session, auth_headers, test_user, test_product, test_address, mock_razorpay_client):
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret"):
            order_id, _ = self._setup_order_with_pending_payment(
                client, db_session, auth_headers, test_user, test_product, test_address
            )

            from models import Order
            order = db_session.query(Order).filter(Order.id == order_id).first()
            order.status = "Confirmed"
            db_session.flush()

            resp = client.post("/api/payments/verify", json={
                "order_id": order_id,
                "razorpay_payment_id": f"pay_{uuid.uuid4().hex[:16]}",
                "razorpay_signature": "sig",
            }, headers=auth_headers)
            assert resp.status_code == 400


class TestRazorpayWebhook:
    """POST /api/payments/webhook — Razorpay webhook handler."""

    WEBHOOK_SECRET = "whsec_test"

    def _make_webhook_payload(self, event_type, payment_id, gateway_order_id, status="captured", error_desc=""):
        payload = {
            "event": event_type,
            "payload": {
                "payment": {
                    "entity": {
                        "id": payment_id,
                        "order_id": gateway_order_id,
                        "status": status,
                        "amount": 9000,
                        "currency": "INR",
                    }
                }
            }
        }
        if error_desc:
            payload["payload"]["payment"]["entity"]["error_description"] = error_desc
        return payload

    def _sign_webhook(self, body_bytes):
        return hmac.new(
            self.WEBHOOK_SECRET.encode("utf-8"),
            body_bytes,
            hashlib.sha256,
        ).hexdigest()

    def _setup_razorpay_order(self, client, db_session, auth_headers, test_user, test_product, test_address):
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret"):
            resp = client.post("/api/orders/direct", json={
                "items": [{"product_id": str(test_product.id), "quantity": 1}],
                "payment_method": "Razorpay",
                "address_id": str(test_address.id),
            }, headers=auth_headers)
            order_id = resp.json()["id"]
            client.post("/api/payments/create-order", json={"order_id": order_id}, headers=auth_headers)

            from models import Payment
            payment = db_session.query(Payment).filter(Payment.order_id == order_id).first()
            return order_id, str(payment.gateway_order_id)

    def test_webhook_payment_captured(self, client, db_session, auth_headers, test_user, test_product, test_address, mock_razorpay_client):
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret", RAZORPAY_WEBHOOK_SECRET=self.WEBHOOK_SECRET):
            order_id, gateway_order_id = self._setup_razorpay_order(
                client, db_session, auth_headers, test_user, test_product, test_address
            )
            payment_id = f"pay_{uuid.uuid4().hex[:16]}"
            payload = self._make_webhook_payload("payment.captured", payment_id, gateway_order_id)
            body = json.dumps(payload).encode()
            sig = self._sign_webhook(body)

            resp = client.post(
                "/api/payments/webhook",
                content=body,
                headers={"Content-Type": "application/json", "X-Razorpay-Signature": sig},
            )
            assert resp.status_code == 200

            from models import Order, Payment
            db_session.expire_all()
            order = db_session.query(Order).filter(Order.id == order_id).first()
            assert order.status == "Confirmed"

            payment = db_session.query(Payment).filter(Payment.order_id == order_id).first()
            assert payment.status == "success"
            assert payment.gateway_payment_id == payment_id

    def test_webhook_payment_failed(self, client, db_session, auth_headers, test_user, test_product, test_address, mock_razorpay_client):
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret", RAZORPAY_WEBHOOK_SECRET=self.WEBHOOK_SECRET):
            order_id, gateway_order_id = self._setup_razorpay_order(
                client, db_session, auth_headers, test_user, test_product, test_address
            )
            payment_id = f"pay_{uuid.uuid4().hex[:16]}"
            payload = self._make_webhook_payload("payment.failed", payment_id, gateway_order_id, status="failed", error_desc="Insufficient funds")
            body = json.dumps(payload).encode()
            sig = self._sign_webhook(body)

            resp = client.post(
                "/api/payments/webhook",
                content=body,
                headers={"Content-Type": "application/json", "X-Razorpay-Signature": sig},
            )
            assert resp.status_code == 200

            from models import Order, Payment
            db_session.expire_all()
            order = db_session.query(Order).filter(Order.id == order_id).first()
            assert order.status == "Failed"

            payment = db_session.query(Payment).filter(Payment.order_id == order_id).first()
            assert payment.status == "failed"
            assert payment.failure_reason == "Insufficient funds"

    def test_webhook_duplicate(self, client, db_session, auth_headers, test_user, test_product, test_address, mock_razorpay_client):
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret", RAZORPAY_WEBHOOK_SECRET=self.WEBHOOK_SECRET):
            order_id, gateway_order_id = self._setup_razorpay_order(
                client, db_session, auth_headers, test_user, test_product, test_address
            )
            payment_id = f"pay_{uuid.uuid4().hex[:16]}"

            from models import Payment
            payment = db_session.query(Payment).filter(Payment.order_id == order_id).first()
            payment.status = "success"
            payment.gateway_payment_id = payment_id
            db_session.flush()

            payload = self._make_webhook_payload("payment.captured", payment_id, gateway_order_id)
            body = json.dumps(payload).encode()
            sig = self._sign_webhook(body)

            resp = client.post(
                "/api/payments/webhook",
                content=body,
                headers={"Content-Type": "application/json", "X-Razorpay-Signature": sig},
            )
            assert resp.status_code == 200
            data = resp.json()
            assert data["status"] == "already_processed"

    def test_webhook_invalid_hmac(self, client, db_session, auth_headers, test_user, test_product, test_address, mock_razorpay_client):
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret", RAZORPAY_WEBHOOK_SECRET=self.WEBHOOK_SECRET):
            _, gateway_order_id = self._setup_razorpay_order(
                client, db_session, auth_headers, test_user, test_product, test_address
            )
            payment_id = f"pay_{uuid.uuid4().hex[:16]}"
            payload = self._make_webhook_payload("payment.captured", payment_id, gateway_order_id)
            body = json.dumps(payload).encode()

            resp = client.post(
                "/api/payments/webhook",
                content=body,
                headers={"Content-Type": "application/json", "X-Razorpay-Signature": "wrong_signature"},
            )
            assert resp.status_code == 200
            data = resp.json()
            assert data["status"] == "ignored"

    def test_webhook_missing_payload(self, client, db_session):
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret", RAZORPAY_WEBHOOK_SECRET=self.WEBHOOK_SECRET):
            resp = client.post(
                "/api/payments/webhook",
                content=json.dumps({"event": "payment.captured", "payload": {"payment": {"entity": {}}}}).encode(),
                headers={"Content-Type": "application/json", "X-Razorpay-Signature": self._sign_webhook(b"{}")},
            )
            assert resp.status_code == 200

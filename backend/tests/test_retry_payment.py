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


class TestRetryPayment:
    """Retry payment flow — previously fixed bugs: 514b32e, e6663a1, ca71520."""

    RAZORPAY_SECRET = "test_secret"

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

    def test_retry_after_failed_razorpay(self, client, db_session, auth_headers, test_user, test_product, test_address, mock_razorpay_client):
        """Old non-successful payments are deleted before creating new Razorpay order (514b32e, e6663a1)."""
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret"):
            order_id, _ = self._setup_razorpay_order(
                client, db_session, auth_headers, test_user, test_product, test_address
            )

            from models import Payment
            payments_before = db_session.query(Payment).filter(Payment.order_id == order_id).all()
            assert len(payments_before) == 1

            resp = client.post("/api/payments/create-order", json={"order_id": order_id}, headers=auth_headers)
            assert resp.status_code == 200

            payments_after = db_session.query(Payment).filter(Payment.order_id == order_id).all()
            assert len(payments_after) == 1
            assert payments_after[0].status == "pending"

    def test_retry_after_failed_verify(self, client, db_session, auth_headers, test_user, test_product, test_address, mock_razorpay_client):
        """After signature failure, order status is 'Failed', retry allowed (ca71520)."""
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET=self.RAZORPAY_SECRET):
            order_id, gateway_order_id = self._setup_razorpay_order(
                client, db_session, auth_headers, test_user, test_product, test_address
            )

            resp = client.post("/api/payments/verify", json={
                "order_id": order_id,
                "razorpay_payment_id": f"pay_{uuid.uuid4().hex[:16]}",
                "razorpay_signature": "bad_sig",
            }, headers=auth_headers)
            assert resp.status_code == 400

            from models import Order
            db_session.expire_all()
            order = db_session.query(Order).filter(Order.id == order_id).first()
            assert order.status == "Failed"

            resp2 = client.post("/api/payments/create-order", json={"order_id": order_id}, headers=auth_headers)
            assert resp2.status_code == 200

    def test_retry_not_allowed_for_confirmed(self, client, db_session, auth_headers, test_user, test_product, test_address, mock_razorpay_client):
        """Confirmed orders reject retry (ca71520 regression guard)."""
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret"):
            order_id, _ = self._setup_razorpay_order(
                client, db_session, auth_headers, test_user, test_product, test_address
            )

            from models import Order
            order = db_session.query(Order).filter(Order.id == order_id).first()
            order.status = "Confirmed"
            db_session.flush()

            resp = client.post("/api/payments/create-order", json={"order_id": order_id}, headers=auth_headers)
            assert resp.status_code == 400

    def test_retry_pending_allows_new_razorpay_order(self, client, db_session, auth_headers, test_user, test_product, test_address, mock_razorpay_client):
        """Pending orders can create Razorpay orders (baseline)."""
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret"):
            order_id, _ = self._setup_razorpay_order(
                client, db_session, auth_headers, test_user, test_product, test_address
            )

            from models import Order
            order = db_session.query(Order).filter(Order.id == order_id).first()
            assert order.status == "Pending"

            resp = client.post("/api/payments/create-order", json={"order_id": order_id}, headers=auth_headers)
            assert resp.status_code == 200

    def test_retry_deletes_only_nonsuccess_old_payments(self, client, db_session, auth_headers, test_user, test_product, test_address, mock_razorpay_client):
        """Only non-successful payments are deleted on retry (514b32e)."""
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret"):
            order_id, _ = self._setup_razorpay_order(
                client, db_session, auth_headers, test_user, test_product, test_address
            )

            from models import Payment
            old_payment = db_session.query(Payment).filter(Payment.order_id == order_id).first()

            old_payment.status = "failed"
            db_session.flush()

            extra_failed = Payment(
                order_id=order_id, user_id=test_user.id, amount=90,
                method="Razorpay", status="failed",
            )
            db_session.add(extra_failed)
            db_session.flush()

            old_count = db_session.query(Payment).filter(Payment.order_id == order_id).count()
            assert old_count == 2

            resp = client.post("/api/payments/create-order", json={"order_id": order_id}, headers=auth_headers)
            assert resp.status_code == 200

            new_count = db_session.query(Payment).filter(Payment.order_id == order_id).count()
            assert new_count == 1
            assert db_session.query(Payment).filter(Payment.order_id == order_id).first().status == "pending"

    def test_retry_does_not_restore_stock_on_failure(self, client, db_session, auth_headers, test_user, test_product, test_address, mock_razorpay_client):
        """Failed verify does NOT restore stock (stock was never deducted on failure)."""
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET=self.RAZORPAY_SECRET):
            initial_stock = test_product.stock

            order_id, gateway_order_id = self._setup_razorpay_order(
                client, db_session, auth_headers, test_user, test_product, test_address
            )

            db_session.expire_all()
            prod = db_session.query(type(test_product)).filter(type(test_product).id == test_product.id).first()
            assert prod.stock == initial_stock

            resp = client.post("/api/payments/verify", json={
                "order_id": order_id,
                "razorpay_payment_id": f"pay_{uuid.uuid4().hex[:16]}",
                "razorpay_signature": "bad_sig",
            }, headers=auth_headers)
            assert resp.status_code == 400

            db_session.expire_all()
            prod = db_session.query(type(test_product)).filter(type(test_product).id == test_product.id).first()
            assert prod.stock == initial_stock

    def test_razorpay_create_order_after_failed_webhook(self, client, db_session, auth_headers, test_user, test_product, test_address, mock_razorpay_client):
        """Webhook payment.failed → retry via create-order works."""
        import resources
        whsec = "whsec_test"
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret", RAZORPAY_WEBHOOK_SECRET=whsec):
            order_id, gateway_order_id = self._setup_razorpay_order(
                client, db_session, auth_headers, test_user, test_product, test_address
            )
            payment_id = f"pay_{uuid.uuid4().hex[:16]}"

            payload = {
                "event": "payment.failed",
                "payload": {
                    "payment": {
                        "entity": {
                            "id": payment_id,
                            "order_id": gateway_order_id,
                            "status": "failed",
                            "amount": 9000,
                            "currency": "INR",
                            "error_description": "Card declined",
                        }
                    }
                }
            }
            body = json.dumps(payload).encode()
            sig = hmac.new(whsec.encode("utf-8"), body, hashlib.sha256).hexdigest()

            resp = client.post(
                "/api/payments/webhook",
                content=body,
                headers={"Content-Type": "application/json", "X-Razorpay-Signature": sig},
            )
            assert resp.status_code == 200

            from models import Order
            db_session.expire_all()
            order = db_session.query(Order).filter(Order.id == order_id).first()
            assert order.status == "Failed"

            resp2 = client.post("/api/payments/create-order", json={"order_id": order_id}, headers=auth_headers)
            assert resp2.status_code == 200

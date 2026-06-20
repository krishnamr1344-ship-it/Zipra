import uuid
import hmac
import hashlib
from decimal import Decimal
from unittest.mock import patch


def _valid_signature(order_id, payment_id, secret):
    return hmac.new(
        secret.encode("utf-8"),
        f"{order_id}|{payment_id}".encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


class TestStockDeduction:
    """Stock deduction and restoration tests."""

    def test_stock_deducted_on_cod_payment(self, client, db_session, auth_headers, test_user, test_product, test_address):
        initial_stock = test_product.stock
        from models import CartItem
        db_session.add(CartItem(user_id=test_user.id, product_id=test_product.id, quantity=3))
        db_session.flush()

        resp = client.post("/api/orders", json={
            "address_id": str(test_address.id),
            "payment_method": "COD",
        }, headers=auth_headers)
        order_id = resp.json()["id"]

        client.post("/api/payments/process", json={"order_id": order_id, "method": "COD"}, headers=auth_headers)

        db_session.expire_all()
        prod = db_session.query(type(test_product)).filter(type(test_product).id == test_product.id).first()
        assert prod.stock == initial_stock - 3

    def test_stock_deducted_on_razorpay_verify(self, client, db_session, auth_headers, test_user, test_product, test_address, mock_razorpay_client):
        initial_stock = test_product.stock
        import resources
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret"):
            resp = client.post("/api/orders/direct", json={
                "items": [{"product_id": str(test_product.id), "quantity": 2}],
                "payment_method": "Razorpay",
                "address_id": str(test_address.id),
            }, headers=auth_headers)
            assert resp.status_code == 201
            order_id = resp.json()["id"]

            resp2 = client.post("/api/payments/create-order", json={
                "order_id": order_id,
            }, headers=auth_headers)
            assert resp2.status_code == 200

            from models import Payment
            payment = db_session.query(Payment).filter(Payment.order_id == order_id).first()
            gateway_order_id = payment.gateway_order_id
            payment_id = f"pay_{uuid.uuid4().hex[:16]}"
            sig = _valid_signature(gateway_order_id, payment_id, "secret")

            resp3 = client.post("/api/payments/verify", json={
                "order_id": order_id,
                "razorpay_payment_id": payment_id,
                "razorpay_signature": sig,
            }, headers=auth_headers)
            assert resp3.status_code == 200

            db_session.expire_all()
            prod = db_session.query(type(test_product)).filter(type(test_product).id == test_product.id).first()
            assert prod.stock == initial_stock - 2

    def test_stock_restored_on_admin_cancel(self, client, db_session, admin_auth_headers, test_user, test_product, test_address):
        from models import Order, OrderItem, Payment
        initial_stock = test_product.stock
        qty = 2

        order = Order(
            user_id=test_user.id, address_id=test_address.id,
            status="Confirmed", total_amount=Decimal(str(90 * qty)),
            payment_method="COD", delivery_otp="123456",
        )
        db_session.add(order)
        db_session.flush()

        oi = OrderItem(
            order_id=order.id, product_id=test_product.id,
            product_name=test_product.name, product_price=Decimal("90.00"),
            quantity=qty, subtotal=Decimal(str(90 * qty)),
        )
        db_session.add(oi)
        db_session.flush()

        test_product.stock -= qty
        db_session.flush()

        resp = client.put(f"/api/admin/orders/{order.id}/status", json={
            "status": "Cancelled",
        }, headers=admin_auth_headers)
        assert resp.status_code == 200

        db_session.expire_all()
        prod = db_session.query(type(test_product)).filter(type(test_product).id == test_product.id).first()
        assert prod.stock == initial_stock

    def test_stock_not_deducted_on_order_creation(self, client, db_session, auth_headers, test_user, test_product, test_address):
        initial_stock = test_product.stock

        from models import CartItem
        db_session.add(CartItem(user_id=test_user.id, product_id=test_product.id, quantity=2))
        db_session.flush()

        resp = client.post("/api/orders", json={
            "address_id": str(test_address.id),
            "payment_method": "COD",
        }, headers=auth_headers)
        assert resp.status_code == 201

        db_session.expire_all()
        prod = db_session.query(type(test_product)).filter(type(test_product).id == test_product.id).first()
        assert prod.stock == initial_stock

    def test_stock_validation_on_cart_add(self, client, db_session, auth_headers, test_user, low_stock_product):
        resp = client.post("/api/cart", json={
            "product_id": str(low_stock_product.id),
            "quantity": 10,
        }, headers=auth_headers)
        assert resp.status_code == 400
        assert "stock" in resp.json()["detail"].lower()

    def test_stock_validation_on_cart_update(self, client, db_session, auth_headers, test_user, low_stock_product):
        from models import CartItem
        item = CartItem(user_id=test_user.id, product_id=low_stock_product.id, quantity=1)
        db_session.add(item)
        db_session.flush()

        resp = client.put(f"/api/cart/{item.id}", json={
            "quantity": 10,
        }, headers=auth_headers)
        assert resp.status_code == 400
        assert "stock" in resp.json()["detail"].lower()

    def test_stock_partial_availability(self, client, db_session, auth_headers, test_user, low_stock_product, test_address):
        from models import CartItem
        db_session.add(CartItem(user_id=test_user.id, product_id=low_stock_product.id, quantity=10))
        db_session.flush()

        resp = client.post("/api/orders", json={
            "address_id": str(test_address.id),
            "payment_method": "COD",
        }, headers=auth_headers)
        assert resp.status_code == 400
        assert "stock" in resp.json()["detail"].lower()

    def test_cart_validate_endpoint(self, client, db_session, auth_headers, test_user, low_stock_product):
        from models import CartItem
        db_session.add(CartItem(user_id=test_user.id, product_id=low_stock_product.id, quantity=10))
        db_session.flush()

        resp = client.post("/api/cart/validate", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        assert data["valid"] == False
        assert len(data["items"]) == 1
        assert data["items"][0]["valid"] == False

    def test_stock_zero_is_out_of_stock(self, client, db_session, auth_headers, test_user, test_category):
        from models import Product, ProductFlag
        prod = Product(
            category_id=test_category.id, name="Zero Stock", price=10, unit="kg", stock=0,
        )
        db_session.add(prod)
        db_session.flush()
        db_session.add(ProductFlag(product_id=prod.id, is_enabled=True))
        db_session.flush()

        from models import CartItem
        db_session.add(CartItem(user_id=test_user.id, product_id=prod.id, quantity=1))
        db_session.flush()

        resp = client.post("/api/cart/validate", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        assert data["valid"] == False

    def test_concurrent_stock_deduction_safety(self, client, db_session, auth_headers, test_user, low_stock_product, test_address):
        from models import CartItem
        user_id = test_user.id
        product_id = low_stock_product.id
        address_id = test_address.id
        db_session.add(CartItem(user_id=user_id, product_id=product_id, quantity=3))
        db_session.flush()

        resp1 = client.post("/api/orders", json={
            "address_id": str(address_id),
            "payment_method": "COD",
        }, headers=auth_headers)
        if resp1.status_code == 201:
            oid1 = resp1.json()["id"]
            r1 = client.post("/api/payments/process", json={"order_id": oid1, "method": "COD"}, headers=auth_headers)

        db_session.expire_all()
        prod = db_session.query(type(low_stock_product)).filter(type(low_stock_product).id == product_id).first()
        remaining = prod.stock

        db_session.query(CartItem).filter(
            CartItem.user_id == user_id, CartItem.product_id == product_id
        ).delete()
        db_session.flush()

        new_cart = CartItem(user_id=user_id, product_id=product_id, quantity=remaining + 1)
        db_session.add(new_cart)
        db_session.flush()

        resp2 = client.post("/api/orders", json={
            "address_id": str(address_id),
            "payment_method": "COD",
        }, headers=auth_headers)
        assert resp2.status_code == 400

"""Tests: register, login, password reset, admin auth, IDOR, email change OTP, token invalidation."""
import hashlib
from datetime import datetime, timezone, timedelta
from decimal import Decimal
from unittest.mock import patch, MagicMock

import pytest

from models import User, PasswordResetCode, TokenBlacklist, Address, Order
from auth import _create_jwt, _hash_password


# ─────────────────────────────────────────────
# REGISTER (OTP-based)
# ─────────────────────────────────────────────
class TestRegister:
    def test_register_sends_otp(self, client, db_session):
        with patch("auth._send_otp_email", return_value=None):
            resp = client.post("/api/auth/register", json={
                "name": "New User",
                "email": "new@example.com",
                "phone": "9999999999",
                "password": "StrongPass1!",
            })
            assert resp.status_code == 200
            assert "sent to your email" in resp.json()["message"].lower()

    def test_register_duplicate_email(self, client, db_session, test_user):
        with patch("auth._send_otp_email", return_value=None):
            resp = client.post("/api/auth/register", json={
                "name": "Duplicate",
                "email": test_user.email,
                "phone": "8888888888",
                "password": "StrongPass1!",
            })
            assert resp.status_code == 400
            assert "already registered" in resp.json()["detail"]

    def test_register_duplicate_phone(self, client, db_session, test_user):
        with patch("auth._send_otp_email", return_value=None):
            resp = client.post("/api/auth/register", json={
                "name": "Duplicate",
                "email": "another@example.com",
                "phone": test_user.phone,
                "password": "StrongPass1!",
            })
            assert resp.status_code == 400
            assert "already registered" in resp.json()["detail"]

    def test_register_weak_password_returns_422(self, client, db_session):
        resp = client.post("/api/auth/register", json={
            "name": "Weak",
            "email": "weak@example.com",
            "phone": "7777777777",
            "password": "short",
        })
        assert resp.status_code == 422

    def test_register_missing_fields_returns_422(self, client, db_session):
        resp = client.post("/api/auth/register", json={
            "email": "missing@example.com",
        })
        assert resp.status_code == 422

    def test_verify_registration_success(self, client, db_session):
        from auth import _PENDING_REGISTRATIONS, _hash_password
        email = "verify@example.com"
        # Manually seed pending registration
        _PENDING_REGISTRATIONS[email] = {
            "name": "Verify User",
            "password_hash": _hash_password("StrongPass1!"),
            "phone": "8888888888",
            "expires_at": __import__("time").time() + 900,
        }
        with patch("auth._verify_otp", return_value=True):
            resp = client.post("/api/auth/verify-registration", json={
                "email": email,
                "otp": "123456",
            })
            assert resp.status_code == 201
            data = resp.json()
            assert data["user"]["email"] == email
            assert "token" in data
            assert email not in _PENDING_REGISTRATIONS

    def test_verify_registration_wrong_otp(self, client, db_session):
        from auth import _PENDING_REGISTRATIONS, _hash_password
        email = "wrongotp@example.com"
        _PENDING_REGISTRATIONS[email] = {
            "name": "Wrong OTP",
            "password_hash": _hash_password("StrongPass1!"),
            "phone": "7777777777",
            "expires_at": __import__("time").time() + 900,
        }
        with patch("auth._verify_otp", return_value=False):
            resp = client.post("/api/auth/verify-registration", json={
                "email": email,
                "otp": "000000",
            })
            assert resp.status_code == 400
            assert "Invalid" in resp.json()["detail"]

    def test_verify_registration_expired(self, client, db_session):
        from auth import _PENDING_REGISTRATIONS, _hash_password
        email = "expired@example.com"
        _PENDING_REGISTRATIONS[email] = {
            "name": "Expired",
            "password_hash": _hash_password("StrongPass1!"),
            "phone": "6666666666",
            "expires_at": 0,  # expired
        }
        with patch("auth._verify_otp", return_value=True):
            resp = client.post("/api/auth/verify-registration", json={
                "email": email,
                "otp": "123456",
            })
            assert resp.status_code == 400
            assert "expired" in resp.json()["detail"].lower()
            assert email not in _PENDING_REGISTRATIONS

    def test_verify_registration_no_pending(self, client, db_session):
        resp = client.post("/api/auth/verify-registration", json={
            "email": "nobody@example.com",
            "otp": "123456",
        })
        assert resp.status_code == 400
        assert "No pending registration" in resp.json()["detail"]


# ─────────────────────────────────────────────
# LOGIN
# ─────────────────────────────────────────────
class TestLogin:
    def test_login_success(self, client, db_session, test_user):
        test_user.password_hash = _hash_password("CorrectPass1!")
        db_session.flush()
        resp = client.post("/api/auth/login", json={
            "email": test_user.email,
            "password": "CorrectPass1!",
        })
        assert resp.status_code == 200
        data = resp.json()
        assert data["user"]["email"] == test_user.email
        assert "token" in data

    def test_login_wrong_password(self, client, db_session, test_user):
        test_user.password_hash = _hash_password("CorrectPass1!")
        db_session.flush()
        resp = client.post("/api/auth/login", json={
            "email": test_user.email,
            "password": "WrongPass1!",
        })
        assert resp.status_code == 401
        assert "Invalid" in resp.json()["detail"]

    def test_login_nonexistent_email(self, client, db_session):
        resp = client.post("/api/auth/login", json={
            "email": "nobody@example.com",
            "password": "SomePass1!",
        })
        assert resp.status_code == 401

    def test_login_deactivated_user(self, client, db_session, test_user):
        test_user.is_deleted = True
        test_user.password_hash = _hash_password("CorrectPass1!")
        db_session.flush()
        resp = client.post("/api/auth/login", json={
            "email": test_user.email,
            "password": "CorrectPass1!",
        })
        assert resp.status_code == 401

    def test_login_rate_limited(self, client, db_session, test_user):
        test_user.password_hash = _hash_password("CorrectPass1!")
        db_session.flush()
        for _ in range(5):
            client.post("/api/auth/login", json={
                "email": test_user.email,
                "password": "WrongPass1!",
            })
        resp = client.post("/api/auth/login", json={
            "email": test_user.email,
            "password": "CorrectPass1!",
        })
        assert resp.status_code == 429


# ─────────────────────────────────────────────
# PASSWORD RESET
# ─────────────────────────────────────────────
class TestPasswordReset:
    def _make_code_record(self, db_session, email, code="123456", minutes_from_now=15):
        record = PasswordResetCode(
            email=email,
            code_hash=hashlib.sha256(code.encode()).hexdigest(),
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=minutes_from_now),
        )
        db_session.add(record)
        db_session.flush()
        return record

    def test_reset_password_success(self, client, db_session, test_user):
        test_user.password_hash = _hash_password("OldPass1!")
        db_session.flush()
        self._make_code_record(db_session, test_user.email, code="reset123")
        resp = client.post("/api/auth/reset-password", json={
            "email": test_user.email,
            "code": "reset123",
            "new_password": "NewPass1!",
        })
        assert resp.status_code == 200
        assert "successful" in resp.json()["message"]
        db_session.refresh(test_user)
        assert test_user.password_hash != _hash_password("OldPass1!")

    def test_reset_password_invalid_code(self, client, db_session, test_user):
        self._make_code_record(db_session, test_user.email, code="correct")
        resp = client.post("/api/auth/reset-password", json={
            "email": test_user.email,
            "code": "wrong",
            "new_password": "NewPass1!",
        })
        assert resp.status_code == 400
        assert "Invalid or expired" in resp.json()["detail"]

    def test_reset_password_expired_code(self, client, db_session, test_user):
        self._make_code_record(db_session, test_user.email, code="expired", minutes_from_now=-1)
        resp = client.post("/api/auth/reset-password", json={
            "email": test_user.email,
            "code": "expired",
            "new_password": "NewPass1!",
        })
        assert resp.status_code == 400

    def test_reset_password_nonexistent_email(self, client, db_session):
        resp = client.post("/api/auth/reset-password", json={
            "email": "nobody@example.com",
            "code": "123456",
            "new_password": "NewPass1!",
        })
        assert resp.status_code == 400

    def test_reset_password_weak_new_password_returns_422(self, client, db_session, test_user):
        self._make_code_record(db_session, test_user.email, code="reset123")
        resp = client.post("/api/auth/reset-password", json={
            "email": test_user.email,
            "code": "reset123",
            "new_password": "weak",
        })
        assert resp.status_code == 422

    def test_reset_password_reuse_code_fails(self, client, db_session, test_user):
        test_user.password_hash = _hash_password("OldPass1!")
        db_session.flush()
        self._make_code_record(db_session, test_user.email, code="usedonce")
        client.post("/api/auth/reset-password", json={
            "email": test_user.email,
            "code": "usedonce",
            "new_password": "NewPass1!",
        })
        resp = client.post("/api/auth/reset-password", json={
            "email": test_user.email,
            "code": "usedonce",
            "new_password": "AnotherPass1!",
        })
        assert resp.status_code == 400


# ─────────────────────────────────────────────
# TOKEN INVALIDATION ON PASSWORD CHANGE
# ─────────────────────────────────────────────
class TestTokenInvalidation:
    def _make_code_record(self, db_session, email, code="123456"):
        record = PasswordResetCode(
            email=email,
            code_hash=hashlib.sha256(code.encode()).hexdigest(),
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=15),
        )
        db_session.add(record)
        db_session.flush()

    def test_old_token_rejected_after_password_reset(self, client, db_session, test_user):
        test_user.password_hash = _hash_password("OldPass1!")
        db_session.flush()
        old_token, _, _ = _create_jwt(str(test_user.id), role=test_user.role, token_version=test_user.token_version)

        self._make_code_record(db_session, test_user.email, code="reset456")
        resp = client.post("/api/auth/reset-password", json={
            "email": test_user.email,
            "code": "reset456",
            "new_password": "NewPass1!",
        })
        assert resp.status_code == 200

        db_session.refresh(test_user)
        assert test_user.token_version > 0

        resp = client.put("/api/auth/profile", json={"name": "Should Fail"}, headers={"Authorization": f"Bearer {old_token}"})
        assert resp.status_code == 401

    def test_new_token_works_after_password_reset(self, client, db_session, test_user):
        test_user.password_hash = _hash_password("OldPass1!")
        db_session.flush()
        self._make_code_record(db_session, test_user.email, code="reset789")
        client.post("/api/auth/reset-password", json={
            "email": test_user.email,
            "code": "reset789",
            "new_password": "NewPass1!",
        })
        db_session.refresh(test_user)
        new_token, _, _ = _create_jwt(str(test_user.id), role=test_user.role, token_version=test_user.token_version)
        resp = client.put("/api/auth/profile", json={"name": "Should Work"}, headers={"Authorization": f"Bearer {new_token}"})
        assert resp.status_code == 200


# ─────────────────────────────────────────────
# PROFILE / EMAIL CHANGE OTP
# ─────────────────────────────────────────────
class TestProfile:
    def test_update_name(self, client, db_session, auth_headers, test_user):
        resp = client.put("/api/auth/profile", json={"name": "Updated Name"}, headers=auth_headers)
        assert resp.status_code == 200
        db_session.refresh(test_user)
        assert test_user.name == "Updated Name"

    def test_update_phone_no_email(self, client, db_session, auth_headers, test_user):
        resp = client.put("/api/auth/profile", json={"phone": "1111111111", "current_password": "TestPass1!"}, headers=auth_headers)
        assert resp.status_code == 200
        db_session.refresh(test_user)
        assert test_user.phone == "1111111111"

    def test_update_phone_missing_password_fails(self, client, auth_headers, test_user):
        resp = client.put("/api/auth/profile", json={"phone": "1111111111"}, headers=auth_headers)
        assert resp.status_code == 401
        assert "password" in resp.json()["detail"].lower()

    def test_update_email_without_otp_fails(self, client, auth_headers, test_user):
        resp = client.put("/api/auth/profile", json={"email": "newemail@example.com"}, headers=auth_headers)
        assert resp.status_code == 400
        assert "Email changes must use" in resp.json()["detail"]

    def test_request_email_change_without_smtp_fails(self, client, auth_headers):
        resp = client.post("/api/auth/request-email-change", json={"new_email": "new@example.com", "current_password": "TestPass1!"}, headers=auth_headers)
        assert resp.status_code == 503

    def test_request_email_change_wrong_password_fails(self, client, auth_headers):
        resp = client.post("/api/auth/request-email-change", json={"new_email": "new@example.com", "current_password": "wrong"}, headers=auth_headers)
        assert resp.status_code == 401

    def test_email_change_full_flow(self, client, db_session, auth_headers, test_user):
        from auth import _PENDING_EMAIL_CHANGES

        with patch.multiple("auth", SMTP_HOST="smtp.test.com", SMTP_USERNAME="u", SMTP_PASSWORD="p", SMTP_FROM_EMAIL="noreply@test.com"), \
             patch("auth.smtplib.SMTP", return_value=MagicMock()):
            # Step 1: Initiate (OTP sent to current email)
            resp = client.post("/api/auth/request-email-change", json={"new_email": "new@example.com", "current_password": "TestPass1!"}, headers=auth_headers)
            assert resp.status_code == 200

            pending = _PENDING_EMAIL_CHANGES.get(str(test_user.id))
            assert pending is not None
            assert pending["new_email"] == "new@example.com"
            assert pending["current_otp_hash"] is not None
            assert pending["current_otp_expires"] is not None
            assert pending["new_otp_hash"] is None

            # We need to know the OTP; patch _send_otp_email to return a known code
        # Need to patch _send_otp_email to return known codes for the rest
        with patch.multiple("auth", SMTP_HOST="smtp.test.com", SMTP_USERNAME="u", SMTP_PASSWORD="p", SMTP_FROM_EMAIL="noreply@test.com"), \
             patch("auth.smtplib.SMTP", return_value=MagicMock()), \
             patch("auth._send_otp_email", side_effect=["111111", "222222"]):
            # Step 1: Initiate (OTP "111111" sent to current email)
            resp = client.post("/api/auth/request-email-change", json={"new_email": "new@example.com", "current_password": "TestPass1!"}, headers=auth_headers)
            assert resp.status_code == 200

            pending = _PENDING_EMAIL_CHANGES.get(str(test_user.id))
            assert pending is not None
            assert pending["new_email"] == "new@example.com"

            # Step 2: Verify current email OTP (completes first phase, sends OTP to new email)
            resp = client.post("/api/auth/complete-email-change", json={"current_email_otp": "111111"}, headers=auth_headers)
            assert resp.status_code == 200
            assert "sent to new email" in resp.json()["message"].lower()

            pending = _PENDING_EMAIL_CHANGES.get(str(test_user.id))
            assert pending is not None
            assert pending["new_otp_hash"] is not None

            # Step 3: Verify new email OTP and complete
            resp = client.post("/api/auth/complete-email-change", json={
                "current_email_otp": "111111",
                "new_email_otp": "222222",
            }, headers=auth_headers)
            assert resp.status_code == 200
            db_session.refresh(test_user)
            assert test_user.email == "new@example.com"
            assert str(test_user.id) not in _PENDING_EMAIL_CHANGES

    def test_email_change_wrong_otp(self, client, auth_headers, test_user):
        from auth import _PENDING_EMAIL_CHANGES
        with patch.multiple("auth", SMTP_HOST="smtp.test.com", SMTP_USERNAME="u", SMTP_PASSWORD="p", SMTP_FROM_EMAIL="noreply@test.com"), \
             patch("auth.smtplib.SMTP", return_value=MagicMock()), \
             patch("auth._send_otp_email", return_value="123456"):
            client.post("/api/auth/request-email-change", json={"new_email": "new@example.com", "current_password": "TestPass1!"}, headers=auth_headers)
            resp = client.post("/api/auth/complete-email-change", json={"current_email_otp": "000000"}, headers=auth_headers)
            assert resp.status_code == 400
            assert "Invalid" in resp.json()["detail"]

    def test_email_change_otp_expired(self, client, auth_headers, test_user):
        from auth import _PENDING_EMAIL_CHANGES
        with patch.multiple("auth", SMTP_HOST="smtp.test.com", SMTP_USERNAME="u", SMTP_PASSWORD="p", SMTP_FROM_EMAIL="noreply@test.com"), \
             patch("auth.smtplib.SMTP", return_value=MagicMock()), \
             patch("auth._send_otp_email", return_value="123456"):
            client.post("/api/auth/request-email-change", json={"new_email": "new@example.com", "current_password": "TestPass1!"}, headers=auth_headers)
            # Manually expire the OTP
            pending = _PENDING_EMAIL_CHANGES.get(str(test_user.id))
            pending["current_otp_expires"] = 0
            resp = client.post("/api/auth/complete-email-change", json={"current_email_otp": "123456"}, headers=auth_headers)
            assert resp.status_code == 400
            assert "expired" in resp.json()["detail"].lower()

    def test_request_email_change_duplicate_new_email(self, client, db_session, auth_headers, test_user):
        # Create another user with the target email
        other = User(email="taken@example.com", password_hash="hash", name="Other", phone="9999999999")
        db_session.add(other)
        db_session.flush()
        resp = client.post("/api/auth/request-email-change", json={"new_email": "taken@example.com", "current_password": "TestPass1!"}, headers=auth_headers)
        assert resp.status_code == 400
        assert "in use" in resp.json()["detail"]

    def test_email_change_complete_without_initiate_fails(self, client, auth_headers, test_user):
        resp = client.post("/api/auth/complete-email-change", json={"current_email_otp": "123456"}, headers=auth_headers)
        assert resp.status_code == 400
        assert "No email change in progress" in resp.json()["detail"]

    def test_email_change_same_email_fails(self, client, auth_headers, test_user):
        resp = client.post("/api/auth/request-email-change", json={"new_email": "test@example.com", "current_password": "TestPass1!"}, headers=auth_headers)
        assert resp.status_code == 400
        assert "same" in resp.json()["detail"].lower()


# ─────────────────────────────────────────────
# ADMIN AUTH
# ─────────────────────────────────────────────
class TestAdminAuth:
    def _call(self, client, method, path, headers, body=None):
        http_method = getattr(client, method.lower())
        kwargs = {"headers": headers}
        if body is not None:
            kwargs["json"] = body
        return http_method(path, **kwargs)

    ADMIN_ROUTES = [
        ("GET", "/api/admin/products", None),
        ("POST", "/api/admin/products", {"name": "Test Product", "price": 10, "unit": "kg", "category_id": "1", "stock": 1}),
        ("PUT", "/api/admin/products/1", {"name": "Test Product", "price": 10, "unit": "kg", "category_id": "1", "stock": 1}),
        ("DELETE", "/api/admin/products/1", None),
        ("GET", "/api/admin/categories", None),
        ("POST", "/api/admin/categories", {"name": "Test Category"}),
        ("PUT", "/api/admin/categories/1", {"name": "Test Category"}),
        ("DELETE", "/api/admin/categories/1", None),
        ("GET", "/api/admin/orders", None),
        ("GET", "/api/admin/users", None),
    ]

    @pytest.mark.parametrize("method,path,body", ADMIN_ROUTES)
    def test_admin_route_rejects_user(self, client, auth_headers, method, path, body):
        resp = self._call(client, method, path, auth_headers, body)
        assert resp.status_code == 403, f"{method} {path} should 403 for non-admin, got {resp.status_code}"

    def test_admin_route_allows_admin(self, client, admin_auth_headers):
        resp = client.get("/api/admin/users", headers=admin_auth_headers)
        assert resp.status_code == 200

    def test_no_auth_rejected(self, client):
        resp = client.get("/api/admin/users")
        assert resp.status_code == 401


# ─────────────────────────────────────────────
# IDOR PREVENTION
# ─────────────────────────────────────────────
class TestIDOR:
    def test_cannot_access_other_user_addresses(self, client, db_session, auth_headers, test_user, test_address):
        other_user = User(email="other@example.com", password_hash="x", name="Other", phone="2222222222")
        db_session.add(other_user)
        db_session.flush()
        other_addr = Address(user_id=other_user.id, label="Other", address_line1="Other St", city="C", state="S", pincode="600002")
        db_session.add(other_addr)
        db_session.flush()
        resp = client.get("/api/addresses", headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        ids = [a["id"] for a in data]
        assert str(other_addr.id) not in ids, "Should not see other user's address"

    def test_cannot_access_other_user_orders(self, client, db_session, auth_headers, test_user, test_product, test_address):
        other_user = User(email="other2@example.com", password_hash="x", name="Other", phone="3333333333")
        db_session.add(other_user)
        db_session.flush()
        other_order = Order(user_id=other_user.id, address_id=test_address.id, status="Pending", total_amount=Decimal("10.00"), payment_method="COD")
        db_session.add(other_order)
        db_session.flush()
        resp = client.get(f"/api/orders/{other_order.id}", headers=auth_headers)
        assert resp.status_code == 404

    def test_cannot_list_other_user_addresses(self, client, db_session, auth_headers, test_user, test_address):
        other_user = User(email="other3@example.com", password_hash="x", name="Other", phone="4444444444")
        db_session.add(other_user)
        db_session.flush()
        other_addr = Address(user_id=other_user.id, label="Other", address_line1="Other St", city="C", state="S", pincode="600003")
        db_session.add(other_addr)
        db_session.flush()
        resp = client.get("/api/addresses", headers=auth_headers)
        data = resp.json()
        ids = [a["id"] for a in data]
        assert str(other_addr.id) not in ids, "Should not see other user's address"


# ─────────────────────────────────────────────
# WEBHOOK SECRET ENFORCEMENT
# ─────────────────────────────────────────────
class TestWebhookSecretEnforcement:
    def test_webhook_rejects_when_secret_not_configured(self, client):
        import resources
        payload = b'{"event":"payment.captured","payload":{"payment":{"entity":{"id":"pay_test","order_id":"order_test","status":"captured"}}}}'
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret", RAZORPAY_WEBHOOK_SECRET=""):
            resp = client.post(
                "/api/payments/webhook",
                content=payload,
                headers={"Content-Type": "application/json", "X-Razorpay-Signature": "some_sig"},
            )
            assert resp.status_code == 500
            assert "secret" in resp.json()["detail"].lower()

    def test_webhook_rejects_invalid_hmac(self, client):
        import resources
        payload = b'{"event":"payment.captured","payload":{"payment":{"entity":{"id":"pay_test","order_id":"order_test","status":"captured"}}}}'
        with patch.multiple(resources, RAZORPAY_ENABLED=True, RAZORPAY_KEY_ID="key", RAZORPAY_KEY_SECRET="secret", RAZORPAY_WEBHOOK_SECRET="whsec_test"):
            resp = client.post(
                "/api/payments/webhook",
                content=payload,
                headers={"Content-Type": "application/json", "X-Razorpay-Signature": "invalid_sig"},
            )
            assert resp.status_code == 200
            assert resp.json()["status"] == "ignored"


# ─────────────────────────────────────────────
# UNAUTHORIZED ACCESS
# ─────────────────────────────────────────────
class TestUnauthorizedAccess:
    def test_expired_token_rejected(self, client):
        expired_token, _, _ = _create_jwt("nonexistent-user", role="user", token_version=0)
        resp = client.put("/api/auth/profile", json={"name": "Hacker"}, headers={"Authorization": f"Bearer {expired_token}"})
        assert resp.status_code == 401

    def test_invalid_signature_rejected(self, client):
        resp = client.put("/api/auth/profile", json={"name": "Hacker"}, headers={"Authorization": "Bearer invalid.token.here"})
        assert resp.status_code == 401

    def test_no_token_rejected(self, client):
        resp = client.put("/api/auth/profile", json={"name": "Hacker"})
        assert resp.status_code == 401

"""
Flask Backend — Security Rules
Architecture: React → Flask API → Supabase (service_role)
Never trust frontend data. Validate everything server-side.
"""
import os
import hashlib
import hmac
from datetime import datetime, timezone

from flask import Flask, request, jsonify
from supabase import create_client, Client
from functools import wraps
import jwt

app = Flask(__name__)

# ─── Supabase Admin Client (service_role) ──────────────────────────
SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
RAZORPAY_WEBHOOK_SECRET = os.environ["RAZORPAY_WEBHOOK_SECRET"]
SUPABASE_JWT_SECRET = os.environ["SUPABASE_JWT_SECRET"]

supabase: Client = create_client(
    SUPABASE_URL,
    SUPABASE_SERVICE_KEY,
)


# ─── JWT Middleware ─────────────────────────────────────────────────
def get_user_id_from_token() -> str:
    """
    Extract user_id from Supabase JWT in Authorization header.
    NEVER trust user_id from request body — it can be spoofed.
    """
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        raise PermissionError("Missing or invalid Authorization header")

    token = auth_header.split(" ", 1)[1]

    try:
        payload = jwt.decode(
            token,
            SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            audience="authenticated",
        )
    except jwt.ExpiredSignatureError:
        raise PermissionError("Token expired")
    except jwt.InvalidTokenError:
        raise PermissionError("Invalid token")

    return payload["sub"]  # Supabase uses 'sub' for auth.uid()


def require_auth(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        try:
            request.user_id = get_user_id_from_token()
        except PermissionError as e:
            return jsonify({"error": str(e)}), 401
        return f(*args, **kwargs)
    return wrapper


# ─── Place Order ───────────────────────────────────────────────────
# NEVER trust: total_amount, product prices, quantities from frontend
@app.route("/api/place-order", methods=["POST"])
@require_auth
def place_order():
    user_id = request.user_id
    data = request.get_json()

    cart_items = data.get("cart_items", [])  # [{"product_id": "...", "quantity": 2}, ...]
    address_id = data.get("address_id")
    payment_method = data.get("payment_method")  # UPI, COD, Card

    if not cart_items or not address_id or not payment_method:
        return jsonify({"error": "Missing required fields"}), 400

    # ── 1. Verify address belongs to user ──
    addr = supabase.table("addresses").select("*").eq("id", address_id).eq("user_id", user_id).execute()
    if not addr.data:
        return jsonify({"error": "Address not found"}), 404

    # ── 2. Fetch product prices from DB (NEVER trust frontend) ──
    product_ids = [item["product_id"] for item in cart_items]
    products = supabase.table("products").select("id, price, stock, name").in_("id", product_ids).execute()
    product_map = {p["id"]: p for p in products.data}

    if len(product_map) != len(product_ids):
        return jsonify({"error": "One or more products not found"}), 400

    # ── 3. Calculate total server-side, check stock ──
    order_items_data = []
    total_amount = 0

    for item in cart_items:
        pid = item["product_id"]
        qty = item["quantity"]
        prod = product_map[pid]

        if qty < 1:
            return jsonify({"error": f"Invalid quantity for {prod['name']}"}), 400

        if prod["stock"] < qty:
            return jsonify({"error": f"Insufficient stock for {prod['name']}"}), 400

        unit_price = float(prod["price"])
        subtotal = round(unit_price * qty, 2)
        total_amount += subtotal

        order_items_data.append({
            "product_id": pid,
            "quantity": qty,
            "unit_price": unit_price,
        })

    total_amount = round(total_amount, 2)

    # ── 4. Insert order (service_role bypasses RLS) ──
    order_resp = supabase.table("orders").insert({
        "user_id": user_id,
        "address_id": address_id,
        "total_amount": total_amount,
        "payment_method": payment_method,
        "status": "Pending",
    }).execute()

    if not order_resp.data:
        return jsonify({"error": "Failed to create order"}), 500

    order_id = order_resp.data[0]["id"]

    # ── 5. Insert order_items with unit_price from DB ──
    for oi in order_items_data:
        oi["order_id"] = order_id

    supabase.table("order_items").insert(order_items_data).execute()

    # Trigger trg_decrement_stock auto-runs on order_items insert

    return jsonify({
        "order_id": order_id,
        "total_amount": total_amount,
        "status": "Pending",
    }), 201


# ─── Razorpay Webhook ──────────────────────────────────────────────
@app.route("/api/razorpay-webhook", methods=["POST"])
def razorpay_webhook():
    """
    Only trusted source: Razorpay servers.
    Verify HMAC SHA256 signature before touching DB.
    """
    webhook_signature = request.headers.get("X-Razorpay-Signature")
    body = request.get_data().decode("utf-8")

    # ── Verify HMAC SHA256 ──
    expected_sig = hmac.new(
        RAZORPAY_WEBHOOK_SECRET.encode(),
        body.encode(),
        hashlib.sha256,
    ).hexdigest()

    if not hmac.compare_digest(expected_sig, webhook_signature):
        return jsonify({"error": "Invalid signature"}), 401

    payload = request.get_json()
    event = payload.get("event", "")

    if event == "payment.captured":
        # ── Extract payment details ──
        payment_entity = payload["payload"]["payment"]["entity"]
        order_id = payment_entity.get("order_id")
        payment_id = payment_entity.get("id")
        amount = float(payment_entity.get("amount", 0)) / 100  # Razorpay returns paise

        # ── Update payment status via service_role ──
        supabase.table("payments").update({
            "status": "completed",
            "transaction_id": payment_id,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }).eq("order_id", order_id).execute()

        # ── Update order status ──
        supabase.table("orders").update({
            "status": "Confirmed",
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }).eq("id", order_id).execute()

    elif event == "payment.failed":
        payment_entity = payload["payload"]["payment"]["entity"]
        order_id = payment_entity.get("order_id")

        supabase.table("payments").update({
            "status": "failed",
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }).eq("order_id", order_id).execute()

    return jsonify({"status": "ok"}), 200


# ─── Cancel Order (user-facing, via SECURITY DEFINER) ──────────────
@app.route("/api/cancel-order", methods=["POST"])
@require_auth
def cancel_order():
    user_id = request.user_id
    data = request.get_json()
    order_id = data.get("order_id")

    if not order_id:
        return jsonify({"error": "order_id required"}), 400

    # Call the SECURITY DEFINER function in Supabase
    # This function checks auth.uid() = user_id and status = 'Pending' internally
    try:
        supabase.rpc("cancel_own_pending_order", {"p_order_id": order_id}).execute()
    except Exception as e:
        return jsonify({"error": str(e)}), 400

    return jsonify({"status": "cancelled"}), 200


if __name__ == "__main__":
    app.run(port=5000)

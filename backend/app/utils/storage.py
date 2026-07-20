import uuid
from fastapi import UploadFile, HTTPException, status

from app.core.config import GCS_BUCKET

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif"}
MAX_FILE_SIZE = 10 * 1024 * 1024

_storage_client = None


def _get_client():
    global _storage_client
    if _storage_client is None:
        try:
            from google.cloud import storage
            _storage_client = storage.Client()
        except Exception:
            _storage_client = None
    return _storage_client


async def upload_to_gcs(file: UploadFile, folder: str = "products") -> str:
    if file.size and file.size > MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail="File too large (max 10MB)")
    ext = (".{}".format(file.filename.split(".")[-1])).lower() if file.filename else ""
    if ext and ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Only JPG, PNG, WebP, HEIC allowed")

    use_ext = ext.lstrip(".") if ext else "jpg"
    blob_name = f"{folder}/{uuid.uuid4()}.{use_ext}"
    content = await file.read()

    client = _get_client()
    if client:
        bucket = client.bucket(GCS_BUCKET)
        blob = bucket.blob(blob_name)
        blob.upload_from_string(content, content_type=file.content_type or "image/jpeg")
        return blob.public_url

    import os
    local_path = f"uploads/{blob_name}"
    os.makedirs(os.path.dirname(local_path), exist_ok=True)
    with open(local_path, "wb") as f:
        f.write(content)
    return f"/uploads/{blob_name}"

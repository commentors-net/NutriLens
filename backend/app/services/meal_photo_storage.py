"""Utility helpers for uploading NutriLens meal photos to Cloud Storage."""

from __future__ import annotations

import os
import uuid
import importlib
from datetime import datetime
from datetime import timedelta
from typing import List, Tuple
from urllib.parse import urlparse

from fastapi import UploadFile


def _guess_extension(content_type: str) -> str:
    ctype = (content_type or "").lower()
    if "png" in ctype:
        return "png"
    if "webp" in ctype:
        return "webp"
    if "heic" in ctype:
        return "heic"
    return "jpg"


def _create_storage_client():
    try:
        storage_module = importlib.import_module("google.cloud.storage")
    except Exception as exc:
        raise RuntimeError(
            "google-cloud-storage is required for meal photo operations. "
            "Install backend dependencies from requirements.txt"
        ) from exc

    return storage_module.Client(project=os.getenv("GCP_PROJECT_ID", "leave-tracker-2025"))


def upload_meal_images(meal_id: str, images: List[UploadFile]) -> List[str]:
    if not images:
        return []

    bucket_name = os.getenv("NUTRILENS_MEAL_PHOTO_BUCKET", "leave-tracker-2025-frontend")
    base_prefix = os.getenv("NUTRILENS_MEAL_PHOTO_PREFIX", "meal-photos").strip("/")
    timestamp_prefix = datetime.utcnow().strftime("%Y/%m/%d")
    prefix = f"{base_prefix}/{timestamp_prefix}/{meal_id}"

    client = _create_storage_client()
    bucket = client.bucket(bucket_name)

    urls: List[str] = []
    for idx, image in enumerate(images):
        content = image.file.read()
        if not content:
            continue

        ext = _guess_extension(image.content_type or "")
        object_name = f"{prefix}/{idx + 1}-{uuid.uuid4().hex[:10]}.{ext}"
        blob = bucket.blob(object_name)
        blob.upload_from_string(content, content_type=image.content_type or "image/jpeg")

        # Frontend bucket is publicly readable; expose direct URL for the web UI.
        urls.append(f"https://storage.googleapis.com/{bucket_name}/{object_name}")

    return urls


def _meal_photo_bucket_and_prefix() -> Tuple[str, str]:
    bucket_name = os.getenv("NUTRILENS_MEAL_PHOTO_BUCKET", "leave-tracker-2025-frontend")
    base_prefix = os.getenv("NUTRILENS_MEAL_PHOTO_PREFIX", "meal-photos").strip("/")
    return bucket_name, base_prefix


def _extract_object_name_from_url(url: str) -> str:
    parsed = urlparse(str(url or "").strip())
    if parsed.scheme not in {"http", "https"}:
        raise ValueError("Unsupported image URL")

    bucket_name, base_prefix = _meal_photo_bucket_and_prefix()
    allowed_prefix = f"/{bucket_name}/{base_prefix}/"
    if parsed.netloc != "storage.googleapis.com" or not parsed.path.startswith(allowed_prefix):
        raise ValueError("Image URL is outside configured meal-photo bucket/prefix")

    object_name = parsed.path[len(f"/{bucket_name}/") :]
    if not object_name:
        raise ValueError("Invalid image object path")
    return object_name


def resolve_meal_image_url(url: str) -> str:
    """Resolve a browser-safe access URL for a stored meal photo.

    Modes:
    - public (default): returns original URL.
    - signed: returns a short-lived signed URL.
    """
    mode = os.getenv("NUTRILENS_MEAL_PHOTO_ACCESS_MODE", "public").strip().lower()
    if mode != "signed":
        return url

    object_name = _extract_object_name_from_url(url)
    bucket_name, _ = _meal_photo_bucket_and_prefix()
    ttl_seconds = int(os.getenv("NUTRILENS_MEAL_PHOTO_SIGNED_URL_TTL_SECONDS", "900"))
    ttl_seconds = max(60, min(ttl_seconds, 3600))

    client = _create_storage_client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(object_name)
    return blob.generate_signed_url(version="v4", expiration=timedelta(seconds=ttl_seconds), method="GET")


def delete_meal_image(url: str) -> bool:
    object_name = _extract_object_name_from_url(url)
    bucket_name, _ = _meal_photo_bucket_and_prefix()
    client = _create_storage_client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(object_name)
    if not blob.exists(client=client):
        return False
    blob.delete(client=client)
    return True

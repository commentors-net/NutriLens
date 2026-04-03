"""Storage helpers for mobile app diagnostic log uploads."""

from __future__ import annotations

import importlib
import json
import os
import uuid
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional


def _create_storage_client():
    storage_module = importlib.import_module("google.cloud.storage")
    return storage_module.Client(project=os.getenv("GCP_PROJECT_ID", "leave-tracker-2025"))


def _gcs_config() -> tuple[str, str]:
    bucket = os.getenv("NUTRILENS_APP_LOG_BUCKET", "leave-tracker-2025-frontend")
    prefix = os.getenv("NUTRILENS_APP_LOG_PREFIX", "app-logs").strip("/")
    return bucket, prefix


def _mode() -> str:
    return os.getenv("NUTRILENS_APP_LOG_STORAGE", "gcs").strip().lower()


def save_app_log(payload: Dict, user_identity: Optional[str] = None) -> Dict:
    log_id = str(uuid.uuid4())
    received_at = datetime.utcnow().isoformat()
    date_prefix = datetime.utcnow().strftime("%Y/%m/%d")

    enriched_payload = {
        "log_id": log_id,
        "received_at": received_at,
        "user_identity": user_identity,
        **payload,
    }

    if _mode() == "local":
        logs_dir = Path("backend") / "logs" / "mobile"
        logs_dir.mkdir(parents=True, exist_ok=True)
        file_path = logs_dir / f"{log_id}.json"
        file_path.write_text(json.dumps(enriched_payload, ensure_ascii=True, indent=2), encoding="utf-8")
        return {
            "log_id": log_id,
            "storage": "local",
            "location": str(file_path).replace("\\", "/"),
        }

    try:
        bucket_name, prefix = _gcs_config()
        object_name = f"{prefix}/{date_prefix}/{log_id}.json"

        client = _create_storage_client()
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(object_name)
        blob.upload_from_string(
            json.dumps(enriched_payload, ensure_ascii=True, indent=2),
            content_type="application/json",
        )

        return {
            "log_id": log_id,
            "storage": "gcs",
            "bucket": bucket_name,
            "object": object_name,
        }
    except Exception:
        # Fallback to local file persistence when cloud storage is unavailable.
        logs_dir = Path("backend") / "logs" / "mobile"
        logs_dir.mkdir(parents=True, exist_ok=True)
        file_path = logs_dir / f"{log_id}.json"
        file_path.write_text(json.dumps(enriched_payload, ensure_ascii=True, indent=2), encoding="utf-8")
        return {
            "log_id": log_id,
            "storage": "local-fallback",
            "location": str(file_path).replace("\\", "/"),
        }

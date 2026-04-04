"""Storage helpers for mobile app diagnostic log uploads."""

from __future__ import annotations

import importlib
import json
import os
import uuid
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional


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


def _extract_meta(data: Dict) -> Dict:
    """Return lightweight metadata fields from a full log payload."""
    return {
        "log_id": data.get("log_id"),
        "received_at": data.get("received_at"),
        "user_identity": data.get("user_identity"),
        "app_version": data.get("app_version"),
        "platform": data.get("platform"),
        "environment": data.get("environment"),
        "session_id": data.get("session_id"),
        "log_scope": data.get("log_scope"),
    }


def list_app_logs(date_str: Optional[str] = None, limit: int = 50) -> List[Dict]:
    """List stored app log metadata, newest first.

    ``date_str`` is an optional ISO date (YYYY-MM-DD) to filter by day.
    When omitted, today's logs are returned for GCS; for local mode all logs
    are returned up to *limit*.
    """
    if _mode() == "local":
        logs_dir = Path("backend") / "logs" / "mobile"
        if not logs_dir.exists():
            return []
        files = sorted(logs_dir.glob("*.json"), key=lambda f: f.stat().st_mtime, reverse=True)
        results: List[Dict] = []
        for f in files[:limit]:
            try:
                data = json.loads(f.read_text(encoding="utf-8"))
                results.append(_extract_meta(data))
            except Exception:
                continue
        return results

    # GCS mode
    try:
        bucket_name, prefix = _gcs_config()
        client = _create_storage_client()

        effective_date = date_str or datetime.utcnow().strftime("%Y-%m-%d")
        date_path = effective_date.replace("-", "/")
        blob_prefix = f"{prefix}/{date_path}/"

        blobs = list(client.list_blobs(bucket_name, prefix=blob_prefix, max_results=limit))
        blobs.sort(key=lambda b: b.time_created, reverse=True)

        results = []
        for blob in blobs[:limit]:
            try:
                data = json.loads(blob.download_as_text())
                meta = _extract_meta(data)
                meta["_gcs_object"] = blob.name
                results.append(meta)
            except Exception:
                continue
        return results
    except Exception:
        return []


def get_app_log(log_id: str, date_str: Optional[str] = None) -> Optional[Dict]:
    """Retrieve the full content of a stored log by its log_id.

    ``date_str`` (YYYY-MM-DD) narrows the GCS search to a single day prefix
    and avoids scanning the entire bucket.  Falls back to searching the last
    30 days when omitted.
    """
    if _mode() == "local":
        logs_dir = Path("backend") / "logs" / "mobile"
        file_path = logs_dir / f"{log_id}.json"
        if not file_path.exists():
            return None
        try:
            return json.loads(file_path.read_text(encoding="utf-8"))
        except Exception:
            return None

    # GCS mode
    try:
        bucket_name, prefix = _gcs_config()
        client = _create_storage_client()

        if date_str:
            candidate_dates = [date_str]
        else:
            today = datetime.utcnow().date()
            candidate_dates = [(today - timedelta(days=i)).isoformat() for i in range(30)]

        for day in candidate_dates:
            date_path = day.replace("-", "/")
            blob_name = f"{prefix}/{date_path}/{log_id}.json"
            blob = client.bucket(bucket_name).blob(blob_name)
            if blob.exists():
                return json.loads(blob.download_as_text())
        return None
    except Exception:
        return None

"""Integration tests for POST /meals/analyze endpoint."""

import io
from fastapi.testclient import TestClient

from app.main import app

# Minimal valid JPEG bytes (smallest possible JPEG that won't crash image libs)
_TINY_JPEG = (
    b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00"
    b"\xff\xdb\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t"
    b"\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a"
    b"\x1f\x1e\x1d\x1a\x1c\x1c $.' \",#\x1c\x1c(7),01444\x1f'9=82<.342\x1e"
    b"\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00"
    b"\xff\xc4\x00\x1f\x00\x00\x01\x05\x01\x01\x01\x01\x01\x01\x00\x00\x00"
    b"\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b"
    b"\xff\xc4\x00\xb5\x10\x00\x02\x01\x03\x03\x02\x04\x03\x05\x05\x04\x04"
    b"\x00\x00\x01}\x01\x02\x03\x00\x04\x11\x05\x12!1A\x06\x13Qa"
    b"\xff\xda\x00\x08\x01\x01\x00\x00?\x00\xfb\xdf\xff\xd9"
)


def _image_file(name: str = "food.jpg") -> tuple:
    """Return a (field_name, (filename, fileobj, content_type)) tuple for multipart upload."""
    return ("images", (name, io.BytesIO(_TINY_JPEG), "image/jpeg"))


client = TestClient(app)


# ---------------------------------------------------------------------------
# Required-field shape tests
# ---------------------------------------------------------------------------


def test_analyze_returns_required_fields_with_three_images():
    """Three images → 200 with all required AnalyzeMealResponse fields."""
    response = client.post(
        "/meals/analyze",
        files=[_image_file("a.jpg"), _image_file("b.jpg"), _image_file("c.jpg")],
    )
    assert response.status_code == 200

    payload = response.json()

    # Top-level required fields
    assert "overall_confidence" in payload
    assert "needs_more_photos" in payload
    assert "suggested_next_shots" in payload
    assert "items" in payload

    assert isinstance(payload["overall_confidence"], float)
    assert 0.0 <= payload["overall_confidence"] <= 1.0
    assert isinstance(payload["needs_more_photos"], bool)
    assert isinstance(payload["suggested_next_shots"], list)
    assert isinstance(payload["items"], list)

    # Per-item required fields
    assert len(payload["items"]) >= 1
    item = payload["items"][0]
    assert "item_id" in item
    assert "label" in item
    assert "grams_estimate" in item
    assert "grams_range" in item
    assert "min" in item["grams_range"]
    assert "max" in item["grams_range"]
    assert "macros" in item
    assert "kcal" in item["macros"]
    assert "protein_g" in item["macros"]
    assert "carbs_g" in item["macros"]
    assert "fat_g" in item["macros"]


def test_analyze_macros_are_positive():
    """Returned macro values should be non-negative numbers."""
    response = client.post(
        "/meals/analyze",
        files=[_image_file("a.jpg"), _image_file("b.jpg"), _image_file("c.jpg")],
    )
    assert response.status_code == 200

    for item in response.json()["items"]:
        assert item["macros"]["kcal"] >= 0
        assert item["macros"]["protein_g"] >= 0
        assert item["macros"]["carbs_g"] >= 0
        assert item["macros"]["fat_g"] >= 0


def test_analyze_grams_range_is_consistent():
    """grams_estimate should be within [min, max] of grams_range."""
    response = client.post(
        "/meals/analyze",
        files=[_image_file("a.jpg"), _image_file("b.jpg"), _image_file("c.jpg")],
    )
    assert response.status_code == 200

    for item in response.json()["items"]:
        lo = item["grams_range"]["min"]
        hi = item["grams_range"]["max"]
        est = item["grams_estimate"]
        assert lo <= est <= hi, f"grams_estimate {est} not in [{lo}, {hi}]"


# ---------------------------------------------------------------------------
# Needs-more-photos logic
# ---------------------------------------------------------------------------


def test_analyze_with_three_images_may_need_more_photos():
    """With exactly 3 images the deterministic path sets needs_more_photos=True."""
    response = client.post(
        "/meals/analyze",
        files=[_image_file("a.jpg"), _image_file("b.jpg"), _image_file("c.jpg")],
    )
    assert response.status_code == 200

    payload = response.json()
    # Deterministic fallback: < 5 images → needs_more_photos True
    assert payload["needs_more_photos"] is True
    assert len(payload["suggested_next_shots"]) > 0


def test_analyze_with_five_images_does_not_need_more_photos():
    """With 5 images the deterministic path sets needs_more_photos=False."""
    response = client.post(
        "/meals/analyze",
        files=[
            _image_file("a.jpg"),
            _image_file("b.jpg"),
            _image_file("c.jpg"),
            _image_file("d.jpg"),
            _image_file("e.jpg"),
        ],
    )
    assert response.status_code == 200

    payload = response.json()
    assert payload["needs_more_photos"] is False
    assert len(payload["suggested_next_shots"]) == 0


# ---------------------------------------------------------------------------
# Validation / error paths
# ---------------------------------------------------------------------------


def test_analyze_rejects_fewer_than_three_images():
    """Uploading only 2 images must return HTTP 400."""
    response = client.post(
        "/meals/analyze",
        files=[_image_file("a.jpg"), _image_file("b.jpg")],
    )
    assert response.status_code == 400
    assert "3" in response.json()["detail"]


def test_analyze_rejects_zero_images():
    """Sending no images at all must return HTTP 422 (validation error)."""
    response = client.post("/meals/analyze")
    assert response.status_code == 422


def test_analyze_accepts_optional_metadata():
    """Valid JSON metadata string should be accepted without error."""
    import json

    meta = json.dumps(
        {
            "client": {"platform": "android", "app_version": "0.1.0"},
            "capture": {"photo_count": 3},
            "locale": "en_MY",
        }
    )
    response = client.post(
        "/meals/analyze",
        files=[_image_file("a.jpg"), _image_file("b.jpg"), _image_file("c.jpg")],
        data={"metadata": meta},
    )
    assert response.status_code == 200


def test_analyze_ignores_invalid_metadata_json():
    """Malformed metadata JSON should not cause a 500; endpoint proceeds with empty metadata."""
    response = client.post(
        "/meals/analyze",
        files=[_image_file("a.jpg"), _image_file("b.jpg"), _image_file("c.jpg")],
        data={"metadata": "{not valid json"},
    )
    assert response.status_code == 200


# ---------------------------------------------------------------------------
# Deterministic consistency
# ---------------------------------------------------------------------------


def test_analyze_is_deterministic_for_same_payload():
    """Identical image bytes → identical label from the deterministic fallback."""
    files = [_image_file("a.jpg"), _image_file("b.jpg"), _image_file("c.jpg")]

    r1 = client.post("/meals/analyze", files=files)
    r2 = client.post("/meals/analyze", files=files)

    assert r1.status_code == 200
    assert r2.status_code == 200
    assert r1.json()["items"][0]["label"] == r2.json()["items"][0]["label"]

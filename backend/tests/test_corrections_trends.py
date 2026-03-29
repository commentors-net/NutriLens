from fastapi.testclient import TestClient

from app.main import app
from app.api import routes_meals


class _StubCorrectionsDB:
    def __init__(self, rows):
        self._rows = rows

    def get_corrections(self, start_date=None, end_date=None, limit=100):
        def in_range(row):
            row_date = row.get("date_str")
            if start_date and row_date < start_date:
                return False
            if end_date and row_date > end_date:
                return False
            return True

        filtered = [row for row in self._rows if in_range(row)]
        filtered.sort(key=lambda row: row.get("timestamp", ""), reverse=True)
        return filtered[:limit]


def test_corrections_trends_endpoint_returns_7d_and_30d_windows(monkeypatch):
    rows = [
        {
            "date_str": "2026-03-28",
            "timestamp": "2026-03-28T08:00:00",
            "original_label": "fried rice",
            "corrected_label": "white rice",
            "grams_delta": -20,
        },
        {
            "date_str": "2026-03-25",
            "timestamp": "2026-03-25T08:00:00",
            "original_label": "fried rice",
            "corrected_label": "white rice",
            "grams_delta": -15,
        },
        {
            "date_str": "2026-03-10",
            "timestamp": "2026-03-10T08:00:00",
            "original_label": "beef soup",
            "corrected_label": "chicken soup",
            "grams_delta": 10,
        },
    ]

    monkeypatch.setattr(routes_meals, "db", _StubCorrectionsDB(rows))
    client = TestClient(app)

    response = client.get("/meals/corrections/trends", params={"end": "2026-03-28", "top_k": 10, "limit": 5000})
    assert response.status_code == 200

    payload = response.json()

    assert payload["window_7d"]["total_corrections"] == 2
    assert payload["window_7d"]["days_with_corrections"] == 2
    assert payload["window_7d"]["correction_rate_per_day"] == 0.29

    assert payload["window_30d"]["total_corrections"] == 3
    assert payload["window_30d"]["days_with_corrections"] == 3
    assert payload["window_30d"]["correction_rate_per_day"] == 0.1

    top_originals = payload["top_corrected_original_labels"]
    assert top_originals[0]["original_label"] == "fried rice"
    assert top_originals[0]["count"] == 2

    top_pairs = payload["top_original_to_corrected"]
    assert top_pairs[0]["original_label"] == "fried rice"
    assert top_pairs[0]["corrected_label"] == "white rice"
    assert top_pairs[0]["count"] == 2


def test_corrections_analytics_includes_top_corrected_original_labels(monkeypatch):
    rows = [
        {
            "date_str": "2026-03-28",
            "timestamp": "2026-03-28T08:00:00",
            "original_label": "milktea",
            "corrected_label": "milk tea",
            "grams_delta": 0,
        },
        {
            "date_str": "2026-03-27",
            "timestamp": "2026-03-27T08:00:00",
            "original_label": "milktea",
            "corrected_label": "milk tea",
            "grams_delta": 5,
        },
    ]

    monkeypatch.setattr(routes_meals, "db", _StubCorrectionsDB(rows))
    client = TestClient(app)

    response = client.get("/meals/corrections/analytics", params={"start": "2026-03-01", "end": "2026-03-28"})
    assert response.status_code == 200

    payload = response.json()
    assert "top_corrected_original_labels" in payload
    assert payload["top_corrected_original_labels"][0]["original_label"] == "milktea"
    assert payload["top_corrected_original_labels"][0]["count"] == 2

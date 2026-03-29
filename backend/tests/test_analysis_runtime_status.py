from fastapi.testclient import TestClient

from app.main import app


def test_analyze_runtime_status_endpoint_shape():
    client = TestClient(app)

    response = client.get("/meals/analyze/runtime-status")
    assert response.status_code == 200

    payload = response.json()

    assert "analysis_provider" in payload
    assert payload["analysis_provider"] in {"gemini", "deterministic_fallback"}

    assert "gemini" in payload
    assert isinstance(payload["gemini"].get("enabled"), bool)
    assert isinstance(payload["gemini"].get("sdk_available"), bool)
    assert isinstance(payload["gemini"].get("api_key_configured"), bool)
    assert isinstance(payload["gemini"].get("client_ready"), bool)

    assert "feedback_rules" in payload
    assert isinstance(payload["feedback_rules"].get("enabled"), bool)
    assert isinstance(payload["feedback_rules"].get("configured_default_enabled"), bool)

from app.services import analysis


class _StubSettingsDB:
    def __init__(self):
        self._settings = {}
        self._audit = []

    def get_nutrilens_setting(self, key: str):
        return self._settings.get(key)

    def set_nutrilens_setting(self, key: str, value: str, updated_by: str):
        payload = {
            "key": key,
            "value": value,
            "updated_by": updated_by,
            "updated_at": "2026-03-28T00:00:00",
        }
        self._settings[key] = payload
        self._audit.insert(0, payload)
        return payload

    def get_nutrilens_setting_audit(self, key: str, limit: int = 20):
        rows = [entry for entry in self._audit if entry.get("key") == key]
        return rows[:limit]


def test_feedback_rules_toggle_state_persists_and_audits(monkeypatch):
    stub_db = _StubSettingsDB()

    monkeypatch.setattr(analysis, "db", stub_db)
    monkeypatch.setattr(analysis, "_feedback_rules_state_loaded", False)
    monkeypatch.setattr(analysis, "_feedback_rules_last_change", None)
    monkeypatch.setattr(analysis, "_feedback_rules_enabled", True)

    update_payload = analysis.set_feedback_rules_enabled(False, updated_by="admin_user")

    assert update_payload["enabled"] is False
    assert update_payload["last_change"]["updated_by"] == "admin_user"
    assert update_payload["recent_audit"]
    assert update_payload["recent_audit"][0]["value"] == "false"

    monkeypatch.setattr(analysis, "_feedback_rules_state_loaded", False)
    monkeypatch.setattr(analysis, "_feedback_rules_enabled", True)

    reloaded = analysis.get_feedback_rule_observability()

    assert reloaded["enabled"] is False
    assert reloaded["last_change"]["updated_by"] == "admin_user"
    assert reloaded["recent_audit"][0]["value"] == "false"

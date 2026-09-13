from app.leave_tracker.sqlite_db import SQLiteDB
import tempfile
import os

def test_user_deep_local_ai_toggle():
    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        db_path = f.name

    try:
        db = SQLiteDB(db_path)
        user = db.create_user("alice", "encrypted_pass", "secret")
        user_id = user["id"]

        # Default: deep local ai is False
        assert db.get_user_deep_local_ai_access(user_id) is False

        # Enable nutrilens and deep_local_ai
        res = db.set_user_system_access(user_id, ["leave-tracker", "nutrilens"], deep_local_ai=True)
        assert res["deep_local_ai"] is True
        assert db.get_user_deep_local_ai_access(user_id) is True

        # Disabling nutrilens also revokes deep_local_ai
        res2 = db.set_user_system_access(user_id, ["leave-tracker"], deep_local_ai=True)
        assert res2["deep_local_ai"] is False
        assert db.get_user_deep_local_ai_access(user_id) is False

        # System settings
        settings = db.get_system_settings()
        assert "local_ai_url" in settings
        assert "default_locale" in settings

        updated = db.update_system_settings({
            "local_ai_url": "http://192.168.1.50:11434",
            "default_locale": "en_MY",
        })
        assert updated["local_ai_url"] == "http://192.168.1.50:11434"
        assert updated["default_locale"] == "en_MY"
    finally:
        if os.path.exists(db_path):
            os.remove(db_path)

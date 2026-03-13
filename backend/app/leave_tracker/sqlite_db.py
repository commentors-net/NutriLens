# SQLite Database Wrapper (matches Firestore interface)
import os
import sqlite3
from typing import Optional, List, Dict, Any
from datetime import datetime, date
import json

class SQLiteDB:
    """SQLite database helper class with Firestore-compatible interface"""
    
    def __init__(self, db_path: str = None):
        # Use absolute path to avoid working directory issues.
        # In unified monorepo dev mode, default to one shared SQLite file.
        if db_path is None:
            database_url = os.getenv("DATABASE_URL", "").strip()
            if database_url.startswith("sqlite:///"):
                db_path = database_url.replace("sqlite:///", "")
            elif database_url:
                db_path = database_url
            else:
                # Get the directory where this file is located
                current_dir = os.path.dirname(os.path.abspath(__file__))
                # Go up one level to backend/app directory
                app_dir = os.path.dirname(current_dir)
                # Shared dev DB for both NutriLens + Leave Tracker
                db_path = os.path.join(app_dir, "unified_dev.db")
        
        self.db_path = db_path
        self._create_tables()
    
    def _get_connection(self):
        """Get database connection"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row  # Return rows as dictionaries
        return conn
    
    def _create_tables(self):
        """Create tables if they don't exist"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        # Users table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                username TEXT UNIQUE NOT NULL,
                password TEXT NOT NULL,
                otp_secret TEXT NOT NULL,
                is_admin INTEGER NOT NULL DEFAULT 0
            )
        ''')

        # Per-user system access table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS user_apps (
                user_id TEXT PRIMARY KEY,
                leave_tracker_access INTEGER NOT NULL DEFAULT 1,
                nutrilens_access INTEGER NOT NULL DEFAULT 1,
                FOREIGN KEY (user_id) REFERENCES users (id)
            )
        ''')

        cursor.execute('''
            CREATE TABLE IF NOT EXISTS nutrilens_profiles (
                user_id TEXT PRIMARY KEY,
                daily_calorie_goal INTEGER NOT NULL DEFAULT 2000,
                protein_goal_g REAL NOT NULL DEFAULT 100.0,
                carbs_goal_g REAL NOT NULL DEFAULT 250.0,
                fat_goal_g REAL NOT NULL DEFAULT 65.0,
                dietary_restrictions TEXT NOT NULL DEFAULT '[]',
                notifications_enabled INTEGER NOT NULL DEFAULT 0,
                breakfast_reminder_time TEXT NOT NULL DEFAULT '08:00',
                lunch_reminder_time TEXT NOT NULL DEFAULT '13:00',
                dinner_reminder_time TEXT NOT NULL DEFAULT '19:00',
                updated_at TEXT,
                FOREIGN KEY (user_id) REFERENCES users (id)
            )
        ''')
        
        # AI Instructions table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS ai_instructions (
                id TEXT PRIMARY KEY,
                instructions TEXT NOT NULL,
                created_at TEXT,
                updated_at TEXT
            )
        ''')
        
        # People table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS people (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL
            )
        ''')
        
        # Types table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS types (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL
            )
        ''')
        
        # Absences table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS absences (
                id TEXT PRIMARY KEY,
                person_id TEXT NOT NULL,
                type_id TEXT NOT NULL,
                date TEXT NOT NULL,
                duration TEXT NOT NULL,
                reason TEXT,
                applied INTEGER DEFAULT 0,
                FOREIGN KEY (person_id) REFERENCES people (id),
                FOREIGN KEY (type_id) REFERENCES types (id)
            )
        ''')
        
        conn.commit()
        conn.close()
    
    # ==================== USERS ====================
    
    def create_user(self, username: str, password: str, otp_secret: str) -> Dict[str, Any]:
        """Create a new user"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        # Generate ID
        import uuid
        user_id = str(uuid.uuid4())
        
        cursor.execute(
            "INSERT INTO users (id, username, password, otp_secret) VALUES (?, ?, ?, ?)",
            (user_id, username, password, otp_secret)
        )
        conn.commit()
        conn.close()
        
        return {
            "id": user_id,
            "username": username,
            "password": password,
            "otp_secret": otp_secret
        }
    
    def get_user_by_username(self, username: str) -> Optional[Dict[str, Any]]:
        """Get user by username"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT * FROM users WHERE username = ?", (username,))
        row = cursor.fetchone()
        conn.close()
        
        if row:
            return dict(row)
        return None
    
    def get_user_by_id(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Get user by ID"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))
        row = cursor.fetchone()
        conn.close()
        
        if row:
            return dict(row)
        return None

    def get_all_users(self) -> List[Dict[str, Any]]:
        """Get all users ordered by username."""
        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users ORDER BY username")
        rows = cursor.fetchall()
        conn.close()
        return [dict(row) for row in rows]
    
    def update_user_password(self, user_id: str, new_password: str):
        """Update user password"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute(
            "UPDATE users SET password = ? WHERE id = ?",
            (new_password, user_id)
        )
        conn.commit()
        conn.close()

    def update_user_admin_status(self, user_id: str, is_admin: bool) -> Dict[str, Any]:
        """Update user admin status"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute(
            "UPDATE users SET is_admin = ? WHERE id = ?",
            (1 if is_admin else 0, user_id)
        )
        conn.commit()
        conn.close()
        
        # Return updated user
        return self.get_user_by_id(user_id)

    def set_user_system_access(self, user_id: str, systems: List[str]) -> Dict[str, Any]:
        """Upsert allowed systems for a user."""
        allow_leave_tracker = 1 if "leave-tracker" in systems else 0
        allow_nutrilens = 1 if "nutrilens" in systems else 0

        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute(
            '''
            INSERT INTO user_apps (user_id, leave_tracker_access, nutrilens_access)
            VALUES (?, ?, ?)
            ON CONFLICT(user_id) DO UPDATE SET
                leave_tracker_access = excluded.leave_tracker_access,
                nutrilens_access = excluded.nutrilens_access
            ''',
            (user_id, allow_leave_tracker, allow_nutrilens),
        )
        conn.commit()
        conn.close()

        return {
            "systems": self.get_user_system_access(user_id),
        }

    def get_user_system_access(self, user_id: str) -> List[str]:
        """Get allowed systems for a user. Defaults to both systems if not configured."""
        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT leave_tracker_access, nutrilens_access FROM user_apps WHERE user_id = ?",
            (user_id,),
        )
        row = cursor.fetchone()
        conn.close()

        if row:
            systems: List[str] = []
            if row["leave_tracker_access"]:
                systems.append("leave-tracker")
            if row["nutrilens_access"]:
                systems.append("nutrilens")
            return systems

        # Backward-compatible default for existing users.
        default_systems = ["leave-tracker", "nutrilens"]
        self.set_user_system_access(user_id, default_systems)
        return default_systems

    # ==================== NUTRILENS PROFILE ====================

    def get_nutrilens_profile(self, user_id: str) -> Dict[str, Any]:
        """Get NutriLens profile for a user. Returns defaults if not yet configured."""
        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM nutrilens_profiles WHERE user_id = ?", (user_id,))
        row = cursor.fetchone()
        conn.close()

        if row:
            profile = dict(row)
            return {
                "daily_calorie_goal": profile["daily_calorie_goal"],
                "protein_goal_g": profile["protein_goal_g"],
                "carbs_goal_g": profile["carbs_goal_g"],
                "fat_goal_g": profile["fat_goal_g"],
                "dietary_restrictions": json.loads(profile.get("dietary_restrictions") or "[]"),
                "notifications_enabled": bool(profile.get("notifications_enabled", 0)),
                "breakfast_reminder_time": profile.get("breakfast_reminder_time", "08:00"),
                "lunch_reminder_time": profile.get("lunch_reminder_time", "13:00"),
                "dinner_reminder_time": profile.get("dinner_reminder_time", "19:00"),
            }

        return {
            "daily_calorie_goal": 2000,
            "protein_goal_g": 100.0,
            "carbs_goal_g": 250.0,
            "fat_goal_g": 65.0,
            "dietary_restrictions": [],
            "notifications_enabled": False,
            "breakfast_reminder_time": "08:00",
            "lunch_reminder_time": "13:00",
            "dinner_reminder_time": "19:00",
        }

    def update_nutrilens_profile(self, user_id: str, profile: Dict[str, Any]) -> Dict[str, Any]:
        """Create or update a user's NutriLens profile."""
        profile_data = {
            "daily_calorie_goal": profile.get("daily_calorie_goal", 2000),
            "protein_goal_g": profile.get("protein_goal_g", 100.0),
            "carbs_goal_g": profile.get("carbs_goal_g", 250.0),
            "fat_goal_g": profile.get("fat_goal_g", 65.0),
            "dietary_restrictions": profile.get("dietary_restrictions", []),
            "notifications_enabled": profile.get("notifications_enabled", False),
            "breakfast_reminder_time": profile.get("breakfast_reminder_time", "08:00"),
            "lunch_reminder_time": profile.get("lunch_reminder_time", "13:00"),
            "dinner_reminder_time": profile.get("dinner_reminder_time", "19:00"),
            "updated_at": datetime.now().isoformat(),
        }

        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute(
            '''
            INSERT INTO nutrilens_profiles (
                user_id, daily_calorie_goal, protein_goal_g, carbs_goal_g, fat_goal_g,
                dietary_restrictions, notifications_enabled, breakfast_reminder_time,
                lunch_reminder_time, dinner_reminder_time, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(user_id) DO UPDATE SET
                daily_calorie_goal = excluded.daily_calorie_goal,
                protein_goal_g = excluded.protein_goal_g,
                carbs_goal_g = excluded.carbs_goal_g,
                fat_goal_g = excluded.fat_goal_g,
                dietary_restrictions = excluded.dietary_restrictions,
                notifications_enabled = excluded.notifications_enabled,
                breakfast_reminder_time = excluded.breakfast_reminder_time,
                lunch_reminder_time = excluded.lunch_reminder_time,
                dinner_reminder_time = excluded.dinner_reminder_time,
                updated_at = excluded.updated_at
            ''',
            (
                user_id,
                profile_data["daily_calorie_goal"],
                profile_data["protein_goal_g"],
                profile_data["carbs_goal_g"],
                profile_data["fat_goal_g"],
                json.dumps(profile_data["dietary_restrictions"]),
                1 if profile_data["notifications_enabled"] else 0,
                profile_data["breakfast_reminder_time"],
                profile_data["lunch_reminder_time"],
                profile_data["dinner_reminder_time"],
                profile_data["updated_at"],
            ),
        )
        conn.commit()
        conn.close()
        return profile_data
    
    # ==================== AI INSTRUCTIONS ====================
    
    def get_ai_instructions(self) -> Optional[Dict[str, Any]]:
        """Get AI instructions (returns first record)"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT * FROM ai_instructions LIMIT 1")
        row = cursor.fetchone()
        conn.close()
        
        if row:
            return dict(row)
        return None
    
    def create_ai_instructions(self, instructions: str) -> Dict[str, Any]:
        """Create AI instructions"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        import uuid
        doc_id = str(uuid.uuid4())
        now = datetime.now().isoformat()
        
        cursor.execute(
            "INSERT INTO ai_instructions (id, instructions, created_at, updated_at) VALUES (?, ?, ?, ?)",
            (doc_id, instructions, now, now)
        )
        conn.commit()
        conn.close()
        
        return {
            "id": doc_id,
            "instructions": instructions,
            "created_at": now,
            "updated_at": now
        }
    
    def update_ai_instructions(self, instruction_id: str, instructions: str) -> Dict[str, Any]:
        """Update AI instructions by ID"""
        conn = self._get_connection()
        cursor = conn.cursor()
        now = datetime.now().isoformat()
        
        cursor.execute(
            "UPDATE ai_instructions SET instructions = ?, updated_at = ? WHERE id = ?",
            (instructions, now, instruction_id)
        )
        conn.commit()
        
        # Fetch the updated record to get created_at
        cursor.execute("SELECT * FROM ai_instructions WHERE id = ?", (instruction_id,))
        row = cursor.fetchone()
        conn.close()
        
        if row:
            return dict(row)
        
        # Fallback if not found (shouldn't happen)
        return {
            "id": instruction_id,
            "instructions": instructions,
            "updated_at": now,
            "created_at": now
        }
    
    # ==================== PEOPLE ====================
    
    def get_all_people(self) -> List[Dict[str, Any]]:
        """Get all people"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT * FROM people ORDER BY name")
        rows = cursor.fetchall()
        conn.close()
        
        return [dict(row) for row in rows]
    
    def get_person_by_id(self, person_id: str) -> Optional[Dict[str, Any]]:
        """Get person by ID"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT * FROM people WHERE id = ?", (person_id,))
        row = cursor.fetchone()
        conn.close()
        
        if row:
            return dict(row)
        return None
    
    def create_person(self, name: str) -> Dict[str, Any]:
        """Create a new person"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        import uuid
        person_id = str(uuid.uuid4())
        
        cursor.execute(
            "INSERT INTO people (id, name) VALUES (?, ?)",
            (person_id, name)
        )
        conn.commit()
        conn.close()
        
        return {"id": person_id, "name": name}
    
    def update_person(self, person_id: str, name: str) -> Dict[str, Any]:
        """Update a person"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute(
            "UPDATE people SET name = ? WHERE id = ?",
            (name, person_id)
        )
        conn.commit()
        conn.close()
        
        return {"id": person_id, "name": name}
    
    def delete_person(self, person_id: str):
        """Delete a person"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute("DELETE FROM people WHERE id = ?", (person_id,))
        conn.commit()
        conn.close()
    
    # ==================== TYPES ====================
    
    def get_all_types(self) -> List[Dict[str, Any]]:
        """Get all leave types"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT * FROM types ORDER BY name")
        rows = cursor.fetchall()
        conn.close()
        
        return [dict(row) for row in rows]
    
    def get_type_by_id(self, type_id: str) -> Optional[Dict[str, Any]]:
        """Get leave type by ID"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT * FROM types WHERE id = ?", (type_id,))
        row = cursor.fetchone()
        conn.close()
        
        if row:
            return dict(row)
        return None
    
    def create_type(self, name: str) -> Dict[str, Any]:
        """Create a new leave type"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        import uuid
        type_id = str(uuid.uuid4())
        
        cursor.execute(
            "INSERT INTO types (id, name) VALUES (?, ?)",
            (type_id, name)
        )
        conn.commit()
        conn.close()
        
        return {"id": type_id, "name": name}
    
    def update_type(self, type_id: str, name: str) -> Dict[str, Any]:
        """Update a leave type"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute(
            "UPDATE types SET name = ? WHERE id = ?",
            (name, type_id)
        )
        conn.commit()
        conn.close()
        
        return {"id": type_id, "name": name}
    
    def delete_type(self, type_id: str):
        """Delete a leave type"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute("DELETE FROM types WHERE id = ?", (type_id,))
        conn.commit()
        conn.close()
    
    # ==================== ABSENCES ====================
    
    def get_all_absences(self, person_id: Optional[str] = None, 
                        type_id: Optional[str] = None,
                        date_from: Optional[date] = None,
                        date_to: Optional[date] = None) -> List[Dict[str, Any]]:
        """Get all absences with optional filters"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        query = "SELECT * FROM absences WHERE 1=1"
        params = []
        
        if person_id:
            query += " AND person_id = ?"
            params.append(person_id)
        
        if type_id:
            query += " AND type_id = ?"
            params.append(type_id)
        
        if date_from:
            query += " AND date >= ?"
            params.append(date_from.isoformat())
        
        if date_to:
            query += " AND date <= ?"
            params.append(date_to.isoformat())
        
        query += " ORDER BY date DESC"
        
        cursor.execute(query, params)
        rows = cursor.fetchall()
        conn.close()
        
        return [dict(row) for row in rows]
    
    def get_absence_by_id(self, absence_id: str) -> Optional[Dict[str, Any]]:
        """Get absence by ID"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT * FROM absences WHERE id = ?", (absence_id,))
        row = cursor.fetchone()
        conn.close()
        
        if row:
            return dict(row)
        return None
    
    def create_absence(self, person_id: str, type_id: str, date_str: str, 
                      duration: str, reason: str = "", applied: int = 0) -> Dict[str, Any]:
        """Create a new absence"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        import uuid
        absence_id = str(uuid.uuid4())
        
        cursor.execute(
            "INSERT INTO absences (id, person_id, type_id, date, duration, reason, applied) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (absence_id, person_id, type_id, date_str, duration, reason, applied)
        )
        conn.commit()
        conn.close()
        
        return {
            "id": absence_id,
            "person_id": person_id,
            "type_id": type_id,
            "date": date_str,
            "duration": duration,
            "reason": reason,
            "applied": applied
        }
    
    def update_absence(self, absence_id: str, person_id: str, type_id: str, 
                      date_str: str, duration: str, reason: str = "", applied: int = 0) -> Dict[str, Any]:
        """Update an absence"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute(
            "UPDATE absences SET person_id = ?, type_id = ?, date = ?, duration = ?, reason = ?, applied = ? WHERE id = ?",
            (person_id, type_id, date_str, duration, reason, applied, absence_id)
        )
        conn.commit()
        conn.close()
        
        return {
            "id": absence_id,
            "person_id": person_id,
            "type_id": type_id,
            "date": date_str,
            "duration": duration,
            "reason": reason,
            "applied": applied
        }
    
    def delete_absence(self, absence_id: str):
        """Delete an absence"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute("DELETE FROM absences WHERE id = ?", (absence_id,))
        conn.commit()
        conn.close()
    
    def bulk_delete_absences(self, absence_ids: List[str]):
        """Delete multiple absences"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        placeholders = ",".join(["?" for _ in absence_ids])
        cursor.execute(f"DELETE FROM absences WHERE id IN ({placeholders})", absence_ids)
        conn.commit()
        conn.close()
    
    def bulk_update_applied(self, absence_ids: List[str], applied: int):
        """Update applied status for multiple absences"""
        conn = self._get_connection()
        cursor = conn.cursor()
        
        placeholders = ",".join(["?" for _ in absence_ids])
        cursor.execute(f"UPDATE absences SET applied = ? WHERE id IN ({placeholders})", [applied] + absence_ids)
        conn.commit()
        conn.close()

# Create singleton instance
sqlite_db = SQLiteDB()

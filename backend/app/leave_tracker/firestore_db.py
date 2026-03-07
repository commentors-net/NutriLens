# Firestore Database Connection and Helper Functions
import os
from google.cloud import firestore
from typing import Optional, List, Dict, Any
from datetime import datetime, date

class FirestoreDB:
    """Firestore database helper class"""
    
    def __init__(self):
        # Initialize Firestore client
        # Will use GOOGLE_APPLICATION_CREDENTIALS env var for auth
        self.db = firestore.Client()
        
        # Collection names
        self.USERS = "users"
        self.AI_INSTRUCTIONS = "ai_instructions"
        self.ABSENCES = "absences"
        self.PEOPLE = "people"
        self.TYPES = "types"
    
    # ==================== USERS ====================
    
    def create_user(self, username: str, password: str, otp_secret: str) -> Dict[str, Any]:
        """Create a new user"""
        user_ref = self.db.collection(self.USERS).document()
        user_data = {
            "username": username,
            "password": password,
            "otp_secret": otp_secret,
            "created_at": datetime.now().isoformat()
        }
        user_ref.set(user_data)
        return {"id": user_ref.id, **user_data}
    
    def get_user_by_username(self, username: str) -> Optional[Dict[str, Any]]:
        """Get user by username"""
        users = self.db.collection(self.USERS).where("username", "==", username).limit(1).stream()
        for user in users:
            return {"id": user.id, **user.to_dict()}
        return None
    
    def get_user_by_id(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Get user by ID"""
        user_ref = self.db.collection(self.USERS).document(user_id)
        user = user_ref.get()
        if user.exists:
            return {"id": user.id, **user.to_dict()}
        return None
    
    def update_user_password(self, user_id: str, new_password: str):
        """Update user password"""
        user_ref = self.db.collection(self.USERS).document(user_id)
        user_ref.update({"password": new_password})
    
    # ==================== AI INSTRUCTIONS ====================
    
    def get_ai_instructions(self) -> Optional[Dict[str, Any]]:
        """Get the latest AI instructions"""
        instructions = self.db.collection(self.AI_INSTRUCTIONS)\
            .order_by("updated_at", direction=firestore.Query.DESCENDING)\
            .limit(1)\
            .stream()
        for instruction in instructions:
            return {"id": instruction.id, **instruction.to_dict()}
        return None
    
    def create_ai_instructions(self, instructions: str) -> Dict[str, Any]:
        """Create new AI instructions"""
        now = datetime.now().isoformat()
        instruction_ref = self.db.collection(self.AI_INSTRUCTIONS).document()
        instruction_data = {
            "instructions": instructions,
            "created_at": now,
            "updated_at": now
        }
        instruction_ref.set(instruction_data)
        return {"id": instruction_ref.id, **instruction_data}
    
    def update_ai_instructions(self, instruction_id: str, instructions: str) -> Dict[str, Any]:
        """Update existing AI instructions"""
        instruction_ref = self.db.collection(self.AI_INSTRUCTIONS).document(instruction_id)
        instruction_data = {
            "instructions": instructions,
            "updated_at": datetime.now().isoformat()
        }
        instruction_ref.update(instruction_data)
        instruction = instruction_ref.get()
        return {"id": instruction.id, **instruction.to_dict()}
    
    # ==================== PEOPLE ====================
    
    def create_person(self, name: str) -> Dict[str, Any]:
        """Create a new person"""
        person_ref = self.db.collection(self.PEOPLE).document()
        person_data = {"name": name}
        person_ref.set(person_data)
        return {"id": person_ref.id, **person_data}
    
    def get_all_people(self) -> List[Dict[str, Any]]:
        """Get all people"""
        people = self.db.collection(self.PEOPLE).order_by("name").stream()
        return [{"id": person.id, **person.to_dict()} for person in people]
    
    def get_person_by_id(self, person_id: str) -> Optional[Dict[str, Any]]:
        """Get person by ID"""
        person_ref = self.db.collection(self.PEOPLE).document(person_id)
        person = person_ref.get()
        if person.exists:
            return {"id": person.id, **person.to_dict()}
        return None
    
    def get_person_by_name(self, name: str) -> Optional[Dict[str, Any]]:
        """Get person by name"""
        people = self.db.collection(self.PEOPLE).where("name", "==", name).limit(1).stream()
        for person in people:
            return {"id": person.id, **person.to_dict()}
        return None
    
    def update_person(self, person_id: str, name: str) -> Dict[str, Any]:
        """Update person"""
        person_ref = self.db.collection(self.PEOPLE).document(person_id)
        person_ref.update({"name": name})
        person = person_ref.get()
        return {"id": person.id, **person.to_dict()}
    
    def delete_person(self, person_id: str) -> bool:
        """Delete person"""
        self.db.collection(self.PEOPLE).document(person_id).delete()
        return True
    
    # ==================== TYPES ====================
    
    def create_type(self, name: str) -> Dict[str, Any]:
        """Create a new leave type"""
        type_ref = self.db.collection(self.TYPES).document()
        type_data = {"name": name}
        type_ref.set(type_data)
        return {"id": type_ref.id, **type_data}
    
    def get_all_types(self) -> List[Dict[str, Any]]:
        """Get all leave types"""
        types = self.db.collection(self.TYPES).order_by("name").stream()
        return [{"id": t.id, **t.to_dict()} for t in types]
    
    def get_type_by_id(self, type_id: str) -> Optional[Dict[str, Any]]:
        """Get type by ID"""
        type_ref = self.db.collection(self.TYPES).document(type_id)
        type_doc = type_ref.get()
        if type_doc.exists:
            return {"id": type_doc.id, **type_doc.to_dict()}
        return None
    
    def get_type_by_name(self, name: str) -> Optional[Dict[str, Any]]:
        """Get type by name"""
        types = self.db.collection(self.TYPES).where("name", "==", name).limit(1).stream()
        for type_doc in types:
            return {"id": type_doc.id, **type_doc.to_dict()}
        return None
    
    def update_type(self, type_id: str, name: str) -> Dict[str, Any]:
        """Update leave type"""
        type_ref = self.db.collection(self.TYPES).document(type_id)
        type_ref.update({"name": name})
        type_doc = type_ref.get()
        return {"id": type_doc.id, **type_doc.to_dict()}
    
    def delete_type(self, type_id: str) -> bool:
        """Delete leave type"""
        self.db.collection(self.TYPES).document(type_id).delete()
        return True
    
    # ==================== ABSENCES ====================
    
    def create_absence(self, date_val: date, duration: str, reason: str, 
                      type_id: str, person_id: str, applied: int = 0) -> Dict[str, Any]:
        """Create a new absence"""
        absence_ref = self.db.collection(self.ABSENCES).document()
        absence_data = {
            "date": date_val.isoformat(),  # Store as ISO string
            "duration": duration,
            "reason": reason,
            "type_id": type_id,
            "person_id": person_id,
            "applied": applied,
            "created_at": datetime.now().isoformat()
        }
        absence_ref.set(absence_data)
        return {"id": absence_ref.id, **absence_data}
    
    def get_all_absences(self, person_id: Optional[str] = None, 
                         type_id: Optional[str] = None,
                         date_from: Optional[date] = None,
                         date_to: Optional[date] = None) -> List[Dict[str, Any]]:
        """Get all absences with optional filters"""
        query = self.db.collection(self.ABSENCES)
        
        # Apply filters
        if person_id:
            query = query.where("person_id", "==", person_id)
        if type_id:
            query = query.where("type_id", "==", type_id)
        if date_from:
            query = query.where("date", ">=", date_from.isoformat())
        if date_to:
            query = query.where("date", "<=", date_to.isoformat())
        
        # Order by date descending
        query = query.order_by("date", direction=firestore.Query.DESCENDING)
        
        absences = query.stream()
        result = []
        for absence in absences:
            data = absence.to_dict()
            # Convert date string back to date object
            if "date" in data:
                data["date"] = datetime.fromisoformat(data["date"]).date()
            result.append({"id": absence.id, **data})
        return result
    
    def get_absence_by_id(self, absence_id: str) -> Optional[Dict[str, Any]]:
        """Get absence by ID"""
        absence_ref = self.db.collection(self.ABSENCES).document(absence_id)
        absence = absence_ref.get()
        if absence.exists:
            data = absence.to_dict()
            # Convert date string back to date object
            if "date" in data:
                data["date"] = datetime.fromisoformat(data["date"]).date()
            return {"id": absence.id, **data}
        return None
    
    def update_absence(self, absence_id: str, **kwargs) -> Dict[str, Any]:
        """Update absence fields"""
        absence_ref = self.db.collection(self.ABSENCES).document(absence_id)
        
        # Convert date to ISO string if present
        if "date" in kwargs and isinstance(kwargs["date"], date):
            kwargs["date"] = kwargs["date"].isoformat()
        
        absence_ref.update(kwargs)
        absence = absence_ref.get()
        data = absence.to_dict()
        
        # Convert date string back to date object
        if "date" in data:
            data["date"] = datetime.fromisoformat(data["date"]).date()
        
        return {"id": absence.id, **data}
    
    def delete_absence(self, absence_id: str) -> bool:
        """Delete absence"""
        self.db.collection(self.ABSENCES).document(absence_id).delete()
        return True
    
    def bulk_delete_absences(self, absence_ids: List[str]) -> int:
        """Delete multiple absences"""
        batch = self.db.batch()
        for absence_id in absence_ids:
            absence_ref = self.db.collection(self.ABSENCES).document(absence_id)
            batch.delete(absence_ref)
        batch.commit()
        return len(absence_ids)
    
    def bulk_update_applied(self, absence_ids: List[str], applied: int) -> int:
        """Update applied status for multiple absences"""
        batch = self.db.batch()
        for absence_id in absence_ids:
            absence_ref = self.db.collection(self.ABSENCES).document(absence_id)
            batch.update(absence_ref, {"applied": applied})
        batch.commit()
        return len(absence_ids)


# Global instance
firestore_db = FirestoreDB()

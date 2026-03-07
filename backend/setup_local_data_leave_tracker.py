"""
Setup Local Development Data
This script copies production Firestore data to local JSON files for development.
"""
import json
from google.cloud import firestore
from datetime import datetime, date

def export_firestore_data():
    """Export all data from production Firestore to local JSON"""
    
    print("🔄 Connecting to Firestore...")
    db = firestore.Client(project='leave-tracker-2025')
    
    data = {
        "users": [],
        "ai_instructions": [],
        "people": [],
        "types": [],
        "absences": []
    }
    
    # Export users
    print("📥 Exporting users...")
    users_ref = db.collection('users').stream()
    for doc in users_ref:
        user_data = doc.to_dict()
        user_data['id'] = doc.id
        data['users'].append(user_data)
    print(f"   ✅ Exported {len(data['users'])} users")
    
    # Export AI instructions
    print("📥 Exporting AI instructions...")
    ai_ref = db.collection('ai_instructions').stream()
    for doc in ai_ref:
        ai_data = doc.to_dict()
        ai_data['id'] = doc.id
        # Convert timestamps to strings
        if 'created_at' in ai_data and isinstance(ai_data['created_at'], datetime):
            ai_data['created_at'] = ai_data['created_at'].isoformat()
        if 'updated_at' in ai_data and isinstance(ai_data['updated_at'], datetime):
            ai_data['updated_at'] = ai_data['updated_at'].isoformat()
        data['ai_instructions'].append(ai_data)
    print(f"   ✅ Exported {len(data['ai_instructions'])} AI instructions")
    
    # Export people
    print("📥 Exporting people...")
    people_ref = db.collection('people').stream()
    for doc in people_ref:
        person_data = doc.to_dict()
        person_data['id'] = doc.id
        data['people'].append(person_data)
    print(f"   ✅ Exported {len(data['people'])} people")
    
    # Export types
    print("📥 Exporting types...")
    types_ref = db.collection('types').stream()
    for doc in types_ref:
        type_data = doc.to_dict()
        type_data['id'] = doc.id
        data['types'].append(type_data)
    print(f"   ✅ Exported {len(data['types'])} types")
    
    # Export absences
    print("📥 Exporting absences...")
    absences_ref = db.collection('absences').stream()
    for doc in absences_ref:
        absence_data = doc.to_dict()
        absence_data['id'] = doc.id
        # Convert date to string
        if 'date' in absence_data:
            if isinstance(absence_data['date'], date):
                absence_data['date'] = absence_data['date'].isoformat()
            elif isinstance(absence_data['date'], datetime):
                absence_data['date'] = absence_data['date'].date().isoformat()
        data['absences'].append(absence_data)
    print(f"   ✅ Exported {len(data['absences'])} absences")
    
    # Save to JSON file
    filename = 'local_dev_data.json'
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print(f"\n✅ Data exported to {filename}")
    print(f"\n📊 Summary:")
    print(f"   - Users: {len(data['users'])}")
    print(f"   - AI Instructions: {len(data['ai_instructions'])}")
    print(f"   - People: {len(data['people'])}")
    print(f"   - Types: {len(data['types'])}")
    print(f"   - Absences: {len(data['absences'])}")
    
    return filename

def clear_local_collections():
    """Clear all local Firestore collections (USE WITH CAUTION!)"""
    
    print("\n⚠️  WARNING: This will DELETE all data in your Firestore!")
    confirm = input("Type 'DELETE ALL' to confirm: ")
    
    if confirm != "DELETE ALL":
        print("❌ Operation cancelled")
        return
    
    print("🗑️  Deleting all collections...")
    db = firestore.Client(project='leave-tracker-2025')
    
    collections = ['users', 'ai_instructions', 'people', 'types', 'absences']
    
    for collection_name in collections:
        docs = db.collection(collection_name).stream()
        deleted = 0
        for doc in docs:
            doc.reference.delete()
            deleted += 1
        print(f"   ✅ Deleted {deleted} documents from {collection_name}")
    
    print("\n✅ All collections cleared")

def import_local_data(filename='local_dev_data.json'):
    """Import data from JSON file to Firestore"""
    
    print(f"📥 Loading data from {filename}...")
    
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"❌ File {filename} not found!")
        print("   Run export first to create the data file.")
        return
    
    print("🔄 Connecting to Firestore...")
    db = firestore.Client(project='leave-tracker-2025')
    
    # Import users
    print(f"📤 Importing {len(data['users'])} users...")
    for user in data['users']:
        doc_id = user.pop('id')
        db.collection('users').document(doc_id).set(user)
    
    # Import AI instructions
    print(f"📤 Importing {len(data['ai_instructions'])} AI instructions...")
    for ai in data['ai_instructions']:
        doc_id = ai.pop('id')
        # Convert timestamp strings back to datetime
        if 'created_at' in ai and isinstance(ai['created_at'], str):
            ai['created_at'] = datetime.fromisoformat(ai['created_at'])
        if 'updated_at' in ai and isinstance(ai['updated_at'], str):
            ai['updated_at'] = datetime.fromisoformat(ai['updated_at'])
        db.collection('ai_instructions').document(doc_id).set(ai)
    
    # Import people
    print(f"📤 Importing {len(data['people'])} people...")
    for person in data['people']:
        doc_id = person.pop('id')
        db.collection('people').document(doc_id).set(person)
    
    # Import types
    print(f"📤 Importing {len(data['types'])} types...")
    for type_data in data['types']:
        doc_id = type_data.pop('id')
        db.collection('types').document(doc_id).set(type_data)
    
    # Import absences
    print(f"📤 Importing {len(data['absences'])} absences...")
    for absence in data['absences']:
        doc_id = absence.pop('id')
        # Keep date as string, Firestore will handle it
        db.collection('absences').document(doc_id).set(absence)
    
    print("\n✅ Data import complete!")

if __name__ == "__main__":
    print("=" * 60)
    print("Local Development Data Setup")
    print("=" * 60)
    print("\nOptions:")
    print("1. Export production data to JSON file")
    print("2. Import JSON file to Firestore")
    print("3. Export → Clear → Import (fresh copy)")
    print("4. Exit")
    
    choice = input("\nEnter your choice (1-4): ")
    
    if choice == "1":
        export_firestore_data()
    elif choice == "2":
        import_local_data()
    elif choice == "3":
        filename = export_firestore_data()
        print("\n" + "=" * 60)
        clear_local_collections()
        print("\n" + "=" * 60)
        import_local_data(filename)
    elif choice == "4":
        print("👋 Goodbye!")
    else:
        print("❌ Invalid choice")

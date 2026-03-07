"""
Import data from local_dev_data.json into SQLite database
"""
import json
import sqlite3
from app.sqlite_db import sqlite_db  # This will create the tables

def import_to_sqlite():
    """Import all data from local_dev_data.json into SQLite"""
    
    # Initialize the database (creates tables if they don't exist)
    # This is done by importing sqlite_db above
    
    # Read the exported data
    with open('local_dev_data.json', 'r') as f:
        data = json.load(f)
    
    print("Starting SQLite import...")
    
    # Connect to database
    conn = sqlite3.connect('database.db')
    cursor = conn.cursor()
    
    # Import users
    if 'users' in data:
        print(f"\nImporting {len(data['users'])} users...")
        for user_data in data['users']:
            try:
                # Check if user already exists
                cursor.execute("SELECT id FROM users WHERE username = ?", (user_data['username'],))
                if cursor.fetchone():
                    print(f"  - User {user_data['username']} already exists, skipping")
                    continue
                
                cursor.execute(
                    "INSERT INTO users (id, username, password, otp_secret) VALUES (?, ?, ?, ?)",
                    (user_data['id'], user_data['username'], user_data['password'], user_data['otp_secret'])
                )
                print(f"  - Imported user: {user_data['username']}")
            except Exception as e:
                print(f"  - Error importing user {user_data.get('username', 'unknown')}: {e}")
    
    # Import AI instructions
    if 'ai_instructions' in data:
        print(f"\nImporting {len(data['ai_instructions'])} AI instruction sets...")
        for instruction_data in data['ai_instructions']:
            try:
                cursor.execute(
                    "INSERT INTO ai_instructions (id, instructions, created_at, updated_at) VALUES (?, ?, ?, ?)",
                    (instruction_data['id'], instruction_data['instructions'], 
                     instruction_data.get('created_at'), instruction_data.get('updated_at'))
                )
                print(f"  - Imported AI instruction set (ID: {instruction_data['id'][:8]}...)")
            except Exception as e:
                print(f"  - Error importing AI instruction: {e}")
    
    # Import people
    if 'people' in data:
        print(f"\nImporting {len(data['people'])} people...")
        for person_data in data['people']:
            try:
                cursor.execute(
                    "INSERT INTO people (id, name) VALUES (?, ?)",
                    (person_data['id'], person_data['name'])
                )
                print(f"  - Imported person: {person_data['name']}")
            except Exception as e:
                print(f"  - Error importing person {person_data.get('name', 'unknown')}: {e}")
    
    # Import types
    if 'types' in data:
        print(f"\nImporting {len(data['types'])} leave types...")
        for type_data in data['types']:
            try:
                cursor.execute(
                    "INSERT INTO types (id, name) VALUES (?, ?)",
                    (type_data['id'], type_data['name'])
                )
                print(f"  - Imported type: {type_data['name']}")
            except Exception as e:
                print(f"  - Error importing type {type_data.get('name', 'unknown')}: {e}")
    
    # Import absences
    if 'absences' in data:
        print(f"\nImporting {len(data['absences'])} absences...")
        for absence_data in data['absences']:
            try:
                cursor.execute(
                    "INSERT INTO absences (id, person_id, type_id, date, duration, reason, applied) VALUES (?, ?, ?, ?, ?, ?, ?)",
                    (absence_data['id'], absence_data['person_id'], absence_data['type_id'],
                     absence_data['date'], absence_data['duration'], 
                     absence_data.get('reason'), absence_data.get('applied', 0))
                )
                print(f"  - Imported absence for person {absence_data['person_id'][:8]}...")
            except Exception as e:
                print(f"  - Error importing absence: {e}")
    
    conn.commit()
    
    print("\n✅ SQLite import completed!")
    
    # Print summary
    cursor.execute("SELECT COUNT(*) FROM users")
    user_count = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(*) FROM ai_instructions")
    ai_count = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(*) FROM people")
    people_count = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(*) FROM types")
    types_count = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(*) FROM absences")
    absences_count = cursor.fetchone()[0]
    
    print("\n📊 Summary:")
    print(f"  - Users: {user_count}")
    print(f"  - AI Instructions: {ai_count}")
    print(f"  - People: {people_count}")
    print(f"  - Types: {types_count}")
    print(f"  - Absences: {absences_count}")
    
    conn.close()

if __name__ == "__main__":
    import_to_sqlite()

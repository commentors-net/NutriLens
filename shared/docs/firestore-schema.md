# Firestore Schema Reference

**Project**: `leave-tracker-2025`  
**Last updated**: auto-generated from source code

---

## Overview

Two logical database layers share a single Firestore instance. Collections are
prefixed (`nutrilens_*`) to avoid naming collisions.

| Layer | DB class | Collections |
|-------|---------|-------------|
| Leave Tracker | `LeaveTrackerFirestoreDB` | `users`, `user_apps`, `ai_instructions`, `people`, `types`, `absences` |
| NutriLens | `NutriLensFirestoreDB` | `nutrilens_foods`, `nutrilens_meals`, `nutrilens_meal_corrections`, `nutrilens_settings`, `nutrilens_settings_audit` |
| NutriLens profiles (in Leave Tracker DB) | `LeaveTrackerFirestoreDB` | `nutrilens_profiles` |

---

## Leave Tracker Collections

### `users/{userId}`

Stores registered users. Passwords are stored as AES-encrypted blobs
(the username is encrypted with the password as key; the plaintext
password is never persisted).

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | UUID, document ID |
| `username` | string | Unique; email for Google-SSO users |
| `password` | string | AES-encrypted (Base64) |
| `otp_secret` | string | TOTP secret (Base32) |
| `is_admin` | boolean | Default `false` |

---

### `user_apps/{userId}`

Maps a user to their allowed applications.

| Field | Type | Notes |
|-------|------|-------|
| `user_id` | string | FK → `users.id` |
| `leave_tracker_access` | boolean | Access to Leave Tracker |
| `nutrilens_access` | boolean | Access to NutriLens |

---

### `ai_instructions/{id}`

Stores the AI prompt/instructions used for leave analysis.

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | UUID |
| `instructions` | string | Freeform prompt text |
| `created_at` | string (ISO 8601) | |
| `updated_at` | string (ISO 8601) | |

---

### `people/{id}`

People tracked by Leave Tracker (employees/team members).

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | UUID |
| `name` | string | Display name |

---

### `types/{id}`

Absence types (e.g., Annual Leave, Sick Leave).

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | UUID |
| `name` | string | Display name |

---

### `absences/{id}`

Individual absence records.

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | UUID |
| `person_id` | string | FK → `people.id` |
| `type_id` | string | FK → `types.id` |
| `date` | string (YYYY-MM-DD) | Absence date |
| `duration` | string | e.g., `"full"`, `"half"` |
| `reason` | string | Optional free text |
| `applied` | integer | `0` = pending, `1` = applied |

---

### `nutrilens_profiles/{userId}`

Per-user NutriLens dietary goals and preferences. Document ID matches `users.id`.

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `daily_calorie_goal` | integer | `2000` | kcal/day |
| `protein_goal_g` | float | `100.0` | grams/day |
| `carbs_goal_g` | float | `250.0` | grams/day |
| `fat_goal_g` | float | `65.0` | grams/day |
| `dietary_restrictions` | array[string] | `[]` | e.g., `["vegetarian", "gluten-free"]` |
| `notifications_enabled` | boolean | `false` | Push notification toggle |
| `breakfast_reminder_time` | string (HH:MM) | `"08:00"` | |
| `lunch_reminder_time` | string (HH:MM) | `"13:00"` | |
| `dinner_reminder_time` | string (HH:MM) | `"19:00"` | |
| `feedback_rules_policy` | string | `"inherit"` | `"inherit"` \| `"enabled"` \| `"disabled"` |
| `updated_at` | string (ISO 8601) | — | Set on every write |

`feedback_rules_policy` values:
- `"inherit"` — follow the global admin toggle
- `"enabled"` — always apply feedback rules for this user (even if global is off)
- `"disabled"` — never apply feedback rules for this user (even if global is on)

---

## NutriLens Collections

### `nutrilens_foods/{food_id}`

Reference nutrition database. Used for macro calculation.

| Field | Type | Notes |
|-------|------|-------|
| `food_id` | string | UUID |
| `name` | string | Lowercase food label |
| `kcal_per_100g` | float | Energy |
| `protein_g_per_100g` | float | |
| `carbs_g_per_100g` | float | |
| `fat_g_per_100g` | float | |

---

### `nutrilens_meals/{meal_id}`

Persisted confirmed meals. Items are embedded (denormalised).

| Field | Type | Notes |
|-------|------|-------|
| `meal_id` | string | UUID, document ID |
| `timestamp` | string (ISO 8601) | UTC |
| `date_str` | string (YYYY-MM-DD) | Local date |
| `notes` | string | Optional user note |
| `items` | array[MealItem] | Embedded food items (see below) |

**MealItem** (array element):

| Field | Type | Notes |
|-------|------|-------|
| `food_id` | string | FK → `nutrilens_foods.food_id` |
| `label` | string | May differ from `foods.name` after correction |
| `grams` | float | Portion weight |
| `kcal` | float | Computed from food record |
| `protein_g` | float | |
| `carbs_g` | float | |
| `fat_g` | float | |

---

### `nutrilens_meal_corrections/{correction_id}`

Stores user corrections to AI meal labels. Feeds the feedback-learning pipeline.

| Field | Type | Notes |
|-------|------|-------|
| `correction_id` | string | UUID |
| `original_label` | string | Label as returned by AI |
| `corrected_label` | string | Label as corrected by user |
| `grams_delta` | integer | Signed gram adjustment (corrected − original) |
| `date_str` | string (YYYY-MM-DD) | |
| `timestamp` | string (ISO 8601) | |

---

### `nutrilens_settings/{key}`

Global admin settings. Key-value store.

| Field | Type | Notes |
|-------|------|-------|
| `key` | string | Setting key (= document ID) |
| `value` | string | Serialised value |
| `updated_by` | string | Username |
| `updated_at` | string (ISO 8601) | |

**Known keys**:

| Key | Values | Description |
|-----|--------|-------------|
| `feedback_rules_enabled` | `"true"` / `"false"` | Global feedback-rule toggle |

---

### `nutrilens_settings_audit/{key}-{timestamp}-{username}`

Immutable audit trail for every settings change.

| Field | Type | Notes |
|-------|------|-------|
| `key` | string | Setting key |
| `value` | string | Value at time of change |
| `updated_by` | string | Username |
| `updated_at` | string (ISO 8601) | |

---

## Security Rules (Recommended)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Authenticated users only
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

> Production rules should be tightened per-collection so users can only
> read/write their own documents (e.g., `nutrilens_profiles/{userId}` where
> `userId == request.auth.uid`).

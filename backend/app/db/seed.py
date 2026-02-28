"""
Database seeding script — Milestone 3.
Seeds ~55 common foods (per 100g) including Malaysian/Asian staples.

Run via:  python -m app.db.seed
Or called automatically from main.py on startup if DB is empty.
"""

from sqlalchemy.orm import Session
from app.db.models import Food

# ─────────────────────────────────────────────────────────────
# Food data: (food_id, name, kcal, protein_g, carbs_g, fat_g)
# All values are per 100g.
# Sources: USDA FoodData Central + Malaysian Food Composition data
# ─────────────────────────────────────────────────────────────
FOOD_SEED_DATA = [
    # ── Grains & Rice ────────────────────────────────────────
    ("white_rice",      "white rice",        130, 2.7,  28.7,  0.3),
    ("brown_rice",      "brown rice",        123, 2.6,  25.6,  1.0),
    ("jasmine_rice",    "jasmine rice",      130, 2.5,  28.8,  0.3),
    ("basmati_rice",    "basmati rice",      121, 3.5,  25.2,  0.4),
    ("nasi_lemak_rice", "nasi lemak rice",   168, 3.2,  28.5,  5.0),  # coconut-cooked
    ("fried_rice",      "fried rice",        163, 3.0,  24.0,  6.5),
    ("white_bread",     "white bread",       265, 9.0,  49.0,  3.2),
    ("wholemeal_bread", "wholemeal bread",   247, 9.7,  41.3,  3.4),
    ("roti_canai",      "roti canai",        301, 7.2,  42.5, 12.0),  # with ghee
    ("capati",          "capati",            237, 7.0,  38.0,  7.0),
    ("noodles_cooked",  "noodles (cooked)",  138, 4.5,  25.2,  2.0),
    ("rice_vermicelli", "rice vermicelli",   109, 2.0,  24.0,  0.3),
    ("oats",            "oats (rolled)",     389, 16.9, 66.3,  6.9),

    # ── Proteins — Meat & Poultry ────────────────────────────
    ("chicken_breast",  "chicken breast",    165, 31.0,  0.0,  3.6),
    ("chicken_thigh",   "chicken thigh",     209, 26.0,  0.0, 11.0),
    ("chicken_drumstick","chicken drumstick",172, 28.0,  0.0,  5.7),
    ("beef_lean",       "lean beef",         250, 26.0,  0.0, 15.0),
    ("pork_lean",       "lean pork",         242, 27.0,  0.0, 14.0),
    ("lamb_lean",       "lean lamb",         258, 25.0,  0.0, 17.0),

    # ── Proteins — Seafood ───────────────────────────────────
    ("salmon",          "salmon",            208, 20.0,  0.0, 13.0),
    ("tuna_canned",     "tuna (canned)",     116, 25.5,  0.0,  0.8),
    ("prawns",          "prawns / shrimp",    99, 24.0,  0.0,  0.3),
    ("fish_white",      "white fish",        105, 22.0,  0.0,  2.0),
    ("fish_fried",      "fried fish",        196, 20.0,  5.0, 11.0),
    ("squid",           "squid / sotong",     92, 15.6,  3.1,  1.4),
    ("anchovies_fried", "fried anchovies",   216, 19.0,  0.3, 15.0),  # ikan bilis

    # ── Proteins — Plant-based ───────────────────────────────
    ("tofu_firm",       "firm tofu",          76, 8.0,   1.9,  4.2),
    ("tofu_silken",     "silken tofu",        55, 5.3,   2.0,  2.7),
    ("tempeh",          "tempeh",            193, 19.0,  9.4, 11.0),
    ("eggs_whole",      "whole egg",         155, 13.0,  1.1, 11.0),
    ("eggs_boiled",     "boiled egg",        155, 13.0,  1.1, 11.0),
    ("dhal",            "dhal / lentils",    116,  9.0, 20.0,  0.4),

    # ── Vegetables ───────────────────────────────────────────
    ("broccoli",        "broccoli",           34,  2.8,  6.6,  0.4),
    ("spinach",         "spinach",            23,  2.9,  3.6,  0.4),
    ("kangkung",        "kangkung / water spinach", 19, 2.6, 3.1, 0.2),
    ("cabbage",         "cabbage",            25,  1.3,  5.8,  0.1),
    ("cauliflower",     "cauliflower",        25,  1.9,  5.0,  0.3),
    ("carrot",          "carrot",             41,  0.9,  9.6,  0.2),
    ("cucumber",        "cucumber",           16,  0.7,  3.6,  0.1),
    ("tomato",          "tomato",             18,  0.9,  3.9,  0.2),
    ("corn_sweet",      "sweet corn",         86,  3.2, 19.0,  1.2),
    ("long_bean",       "long bean / kacang panjang", 47, 2.8, 8.4, 0.4),
    ("eggplant",        "eggplant / brinjal",  25, 1.0,  5.9,  0.2),

    # ── Fruits ───────────────────────────────────────────────
    ("banana",          "banana",             89,  1.1, 22.8,  0.3),
    ("apple",           "apple",              52,  0.3, 13.8,  0.2),
    ("mango",           "mango",              60,  0.8, 15.0,  0.4),
    ("papaya",          "papaya",             43,  0.5, 10.8,  0.3),
    ("watermelon",      "watermelon",         30,  0.6,  7.6,  0.2),

    # ── Fats & Oils ──────────────────────────────────────────
    ("olive_oil",       "olive oil",         884,  0.0,  0.0,100.0),
    ("coconut_oil",     "coconut oil",       862,  0.0,  0.0,100.0),
    ("coconut_milk",    "coconut milk",      197,  2.3,  2.8, 21.0),
    ("butter",          "butter",            717,  0.9,  0.1, 81.0),

    # ── Sauces & Condiments ──────────────────────────────────
    ("sambal",          "sambal",            120,  2.0,  8.0,  9.0),
    ("soy_sauce",       "soy sauce",          53,  5.1,  4.9,  0.6),
    ("peanut_sauce",    "peanut sauce",      220,  8.0, 14.0, 17.0),  # satay sauce
]


def seed_foods(db: Session) -> int:
    """
    Insert seed foods into the database.
    Skips foods that already exist (upsert by food_id).

    Returns:
        Number of new rows inserted.
    """
    inserted = 0
    for food_id, name, kcal, protein, carbs, fat in FOOD_SEED_DATA:
        existing = db.get(Food, food_id)
        if existing is None:
            db.add(Food(
                food_id=food_id,
                name=name,
                kcal_per_100g=kcal,
                protein_g_per_100g=protein,
                carbs_g_per_100g=carbs,
                fat_g_per_100g=fat,
            ))
            inserted += 1
    db.commit()
    return inserted


if __name__ == "__main__":
    from app.db.session import SessionLocal, init_db

    init_db()
    db = SessionLocal()
    try:
        n = seed_foods(db)
        print(f"Seeded {n} new food(s). Total in DB: {db.query(Food).count()}")
    finally:
        db.close()

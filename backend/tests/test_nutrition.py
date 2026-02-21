"""
Unit tests for nutrition calculation service.
"""

import pytest
from app.services.nutrition import compute_macros, compute_total_macros


def test_compute_macros_white_rice():
    """Test macro calculation for white rice"""
    result = compute_macros("white rice", 100)
    assert result["kcal"] == 130
    assert result["protein_g"] == 2.7
    assert result["carbs_g"] == 28.7
    assert result["fat_g"] == 0.3


def test_compute_macros_chicken_breast():
    """Test macro calculation for chicken breast"""
    result = compute_macros("chicken breast", 150)
    assert result["kcal"] == 248  # 165 * 150 / 100 = 247.5 → rounds to 248
    assert result["protein_g"] == 54.0  # 36.0 * 150 / 100
    assert result["carbs_g"] == 0.0
    assert result["fat_g"] == 1.4  # 0.9 * 150 / 100 = 1.35 → rounds to 1.4


def test_compute_macros_unknown_food():
    """Test that unknown food raises ValueError"""
    with pytest.raises(ValueError, match="not found in nutrition DB"):
        compute_macros("unknown food", 100)


def test_compute_total_macros():
    """Test summing macros across items"""
    items = [
        {"label": "white rice", "grams": 180},
        {"label": "chicken breast", "grams": 150},
    ]
    result = compute_total_macros(items)
    
    # White rice: 130*180/100=234, protein=4.86, carbs=51.66, fat=0.54
    # Chicken: 165*150/100=247.5≈248, protein=54.0, carbs=0, fat=1.35
    # Total: kcal=234+248=482, protein=58.9, carbs=51.7, fat=1.9
    assert result["kcal"] == 482
    assert result["protein_g"] == 58.9
    assert result["carbs_g"] == 51.7
    assert result["fat_g"] == 1.9

"""Unit tests for analysis service."""

import pytest
from app.services.analysis import analyze_images_deterministic, build_analysis_response_from_ai_payload


@pytest.mark.asyncio
async def test_analyze_with_three_images():
    """Test deterministic analysis with minimum photos"""
    # Create some dummy image data
    image_bytes = [b"image1", b"image2", b"image3"]
    
    result = await analyze_images_deterministic(image_bytes, {})
    
    assert result.overall_confidence > 0
    assert len(result.items) == 1
    assert result.items[0].grams_range.min <= result.items[0].grams_estimate <= result.items[0].grams_range.max
    assert result.items[0].macros.kcal > 0


@pytest.mark.asyncio
async def test_analyze_with_five_images():
    """Test deterministic analysis with preferred photo count"""
    image_bytes = [b"img1", b"img2", b"img3", b"img4", b"img5"]
    
    result = await analyze_images_deterministic(image_bytes, {})
    
    # With 5 photos, should not need more
    assert result.needs_more_photos is False
    assert len(result.suggested_next_shots) == 0
    assert result.overall_confidence > 0.70


@pytest.mark.asyncio
async def test_analyze_deterministic_consistency():
    """Test that same image bytes produce consistent results"""
    image_bytes = [b"same_image", b"dummy2", b"dummy3"]
    
    result1 = await analyze_images_deterministic(image_bytes, {})
    result2 = await analyze_images_deterministic(image_bytes, {})
    
    # Same inputs → same label
    assert result1.items[0].label == result2.items[0].label
    assert result1.items[0].grams_estimate == result2.items[0].grams_estimate


@pytest.mark.asyncio
async def test_analyze_no_images_error():
    """Test that empty image list raises error"""
    with pytest.raises(ValueError):
        await analyze_images_deterministic([], {})


def test_build_analysis_response_from_ai_payload_normalizes_values():
    payload = {
        "overall_confidence": 1.5,
        "needs_more_photos": False,
        "suggested_next_shots": ["top_down", "invalid_shot", "closeup", "closeup"],
        "items": [
            {
                "label": "mystery bowl",
                "label_confidence": -0.3,
                "grams_estimate": 120,
                "grams_range": {"min": 200, "max": 50},
                "grams_confidence": 5,
            }
        ],
        "warnings": [" uncertain ", "", "uncertain"],
    }

    result = build_analysis_response_from_ai_payload(payload, image_count=3)

    assert result.overall_confidence == 1.0
    assert result.needs_more_photos is False
    assert result.suggested_next_shots == ["top_down", "closeup"]
    assert result.items[0].label_confidence == 0.0
    assert result.items[0].grams_confidence == 1.0
    assert result.items[0].grams_range.min == 200
    assert result.items[0].grams_range.max == 200
    assert any(warning.startswith("nutrition_db_unmatched") for warning in result.warnings)


def test_build_analysis_response_from_ai_payload_requires_items():
    with pytest.raises(ValueError):
        build_analysis_response_from_ai_payload({"items": []}, image_count=5)

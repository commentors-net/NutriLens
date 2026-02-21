"""
Unit tests for analysis service.
"""

import pytest
from app.services.analysis import analyze_images_deterministic


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

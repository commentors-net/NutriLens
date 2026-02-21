#!/bin/bash
# Version Sync Verification for macOS/Linux
# Runs the Python verification script

echo ""
echo "========================================"
echo "FoodVision Configuration Sync Check"
echo "========================================"
echo ""

python3 verify_sync.py

if [ $? -ne 0 ]; then
    echo ""
    echo "[ERROR] Configuration sync issues found!"
    echo "Please review the errors above."
    exit 1
fi

echo ""

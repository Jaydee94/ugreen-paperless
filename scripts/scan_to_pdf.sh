#!/bin/bash

# Configuration
SCANNER_ID="fujitsu:ScanSnap iX500:1234992"
RESOLUTION="300"
DATEI=Scan_Color_$(date +%Y%m%d_%H%M%S)

echo "--- Starting Color Scan (${RESOLUTION} dpi, Duplex) ---"

# 1. Scan and save as TIFF (Batch mode for Duplex)
# --batch-format is not supported, but --format=tiff works with --batch.
scanimage \
  --device "$SCANNER_ID" \
  --resolution $RESOLUTION \
  --mode Color \
  --source "ADF Duplex" \
  --format=tiff \
  --batch="${DATEI}_%03d.tif"

SCAN_STATUS=$?

if [ $SCAN_STATUS -ne 0 ]; then
    echo "❌ ERROR during scanning (Exit Code $SCAN_STATUS). Incomplete scan file."
    exit 1
fi

# Check if files were created
shopt -s nullglob
IMG_FILES=(${DATEI}_*.tif)

if [ ${#IMG_FILES[@]} -eq 0 ]; then
    echo "❌ ERROR: No scan files created. Check USB connection/power."
    exit 1
fi

echo " Scans created successfully. Page count: ${#IMG_FILES[@]}"

# 2. Convert images to PDF
echo "--- Converting to PDF ---"

# "Face Up" loading results in reverse order. We reverse the list to fix it.
REV_FILES=()
for ((i=${#IMG_FILES[@]}-1; i>=0; i--)); do
    REV_FILES+=("${IMG_FILES[i]}")
done

# Convert using the reversed list
convert "${REV_FILES[@]}" -rotate 180 "${DATEI}.pdf"

CONVERT_STATUS=$?

if [ $CONVERT_STATUS -ne 0 ]; then
    echo "❌ ERROR during PDF conversion (Exit Code $CONVERT_STATUS)."
    exit 1
fi

# 3. Cleanup
rm "${DATEI}"_*.tif

echo "✅ Scan completed successfully. PDF: ${DATEI}.pdf"

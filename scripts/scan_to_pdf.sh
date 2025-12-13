#!/bin/bash

# Configuration
SCANNER_ID="fujitsu:ScanSnap iX500:1234992"
RESOLUTION="200"
DATEI=Scan_Color_$(date +%Y%m%d_%H%M%S)

# Gotify Configuration
GOTIFY_URL="http://jays-ugreen:8085"
GOTIFY_TOKEN="{{ gotify_token }}"

send_notification() {
    local title="$1"
    local message="$2"
    local priority="$3"
    
    # Only send if token is configured
    if [ "$GOTIFY_TOKEN" != "CHANGE_ME" ]; then
        curl -s -S --connect-timeout 5 \
        -X POST "$GOTIFY_URL/message" \
        -H "X-Gotify-Key: $GOTIFY_TOKEN" \
        -F "title=$title" \
        -F "message=$message" \
        -F "priority=$priority" > /dev/null
    else
        echo "⚠️  Gotify token not configured, skipping notification."
    fi
}

echo "--- Starting Color Scan (${RESOLUTION} dpi, Duplex) ---"

# 1. Scan and save as TIFF (Batch mode for Duplex)

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
    send_notification "❌ Scan Failed" "Error during scanning (Exit Code $SCAN_STATUS). 🛑" 8
    exit 1
fi

# Check if files were created
shopt -s nullglob
IMG_FILES=(${DATEI}_*.tif)

if [ {{ '${#' }}IMG_FILES[@]} -eq 0 ]; then
    echo "❌ ERROR: No scan files created. Check USB connection/power."
    send_notification "❌ Scan Failed" "No scan files created. Check USB. 🔌" 8
    exit 1
fi

echo " Scans created successfully. Page count: {{ '${#' }}IMG_FILES[@]}"

# 2. Convert images to PDF
echo "--- Converting to PDF ---"

# "Face Up" loading results in reverse order. We reverse the list to fix it.
REV_FILES=()
for ((i={{ '${#' }}IMG_FILES[@]}-1; i>=0; i--)); do
    REV_FILES+=("${IMG_FILES[i]}")
done

# Convert using the reversed list
convert "${REV_FILES[@]}" -rotate 180 "${DATEI}.pdf"

CONVERT_STATUS=$?

if [ $CONVERT_STATUS -ne 0 ]; then
    echo "❌ ERROR during PDF conversion (Exit Code $CONVERT_STATUS)."
    send_notification "❌ Scan Failed" "Error during PDF conversion. 📉" 8
    exit 1
fi

# 3. Cleanup
rm "${DATEI}"_*.tif

echo "✅ Scan completed successfully. PDF: ${DATEI}.pdf"

# 4. Move to Paperless Consume Directory
echo "--- Moving to Paperless Consume Directory ---"
mv "${DATEI}.pdf" "{{ paperless_mount_point }}/"

MOVE_STATUS=$?
if [ $MOVE_STATUS -ne 0 ]; then
    echo "❌ ERROR moving file to {{ paperless_mount_point }} (Exit Code $MOVE_STATUS)."
    send_notification "❌ Scan Failed" "Error moving file to consume folder. 📂" 8
    exit 1
fi

echo "✅ File moved to {{ paperless_mount_point }}/${DATEI}.pdf"
send_notification "✅ Scan Success" "📄 PDF sent to Paperless: ${DATEI}.pdf" 5

#!/bin/bash

## Convert a mix of files in subfolders into individual .txt files

# Configuration
SOURCE_DIR="${1:-./}"  # Use first argument or current directory
OUTPUT_DIR="${2:-./all_txt}"  # Use second argument or default output directory
TEMP_DIR="/tmp/pandoc_conversion_$$"

# File types to convert (add/remove as needed)
FILE_TYPES=("*.docx" "*.doc" "*.pdf" "*.html" "*.htm" "*.md" "*.rtf" "*.odt")

# Create temporary and output directories
mkdir -p "$TEMP_DIR"
mkdir -p "$OUTPUT_DIR"

echo "Converting files from: $SOURCE_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "----------------------------------------"

# Function to convert PDF using multiple methods
convert_pdf() {
    local file="$1"
    local temp_txt="$2"
    local temp_filtered="${temp_txt}.filtered"
    
    # Method 1: Try pandoc first
    if pandoc "$file" -t plain -o "$temp_txt" 2>/dev/null && [ -s "$temp_txt" ]; then
        # Check for binary garbage in the output
        if grep -q "stream\|endstream\|/Length\|/Filter" "$temp_txt"; then
            echo "  - Pandoc produced binary output, trying alternative methods..."
        else
            return 0
        fi
    fi
    
    # Method 2: Try pdftotext (from poppler-utils)
    if command -v pdftotext >/dev/null 2>&1; then
        if pdftotext -layout "$file" "$temp_txt" 2>/dev/null && [ -s "$temp_txt" ]; then
            # Check for binary garbage in the output
            if grep -q "stream\|endstream\|/Length\|/Filter" "$temp_txt"; then
                echo "  - pdftotext produced binary output, trying alternative methods..."
            else
                return 0
            fi
        fi
    fi
    
    # Method 3: Try OCRmyPDF if available (for scanned PDFs)
    if command -v ocrmypdf >/dev/null 2>&1; then
        local temp_ocr_pdf="${TEMP_DIR}/$(basename "$file").ocr.pdf"
        if ocrmypdf --force-ocr --skip-text "$file" "$temp_ocr_pdf" >/dev/null 2>&1 && 
           pdftotext -layout "$temp_ocr_pdf" "$temp_txt" 2>/dev/null && 
           [ -s "$temp_txt" ]; then
            rm -f "$temp_ocr_pdf"
            return 0
        fi
        rm -f "$temp_ocr_pdf"
    fi
    
    # Method 4: Try pdfplumber via python
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import sys
try:
    import pdfplumber
    with pdfplumber.open('$file') as pdf:
        text = ''
        for page in pdf.pages:
            page_text = page.extract_text()
            if page_text:
                text += page_text + '\n'
    with open('$temp_txt', 'w', encoding='utf-8') as f:
        f.write(text)
    sys.exit(0 if text.strip() else 1)
except ImportError:
    sys.exit(1)
except Exception as e:
    print(f'PDF extraction error: {e}', file=sys.stderr)
    sys.exit(1)
        " 2>/dev/null && [ -s "$temp_txt" ] && return 0
    fi
    
    # Method 5: Try pdf2txt.py from pdfminer.six if available
    if command -v pdf2txt.py >/dev/null 2>&1; then
        if pdf2txt.py -o "$temp_txt" "$file" 2>/dev/null && [ -s "$temp_txt" ]; then
            return 0
        fi
    fi
    
    # Clean up any partial output with binary content
    if [ -f "$temp_txt" ]; then
        # Filter out common PDF binary content markers
        grep -v "stream\|endstream\|/Length\|/Filter\|^<<.*>>$" "$temp_txt" > "$temp_filtered"
        if [ -s "$temp_filtered" ]; then
            mv "$temp_filtered" "$temp_txt"
            return 0
        fi
        rm -f "$temp_filtered"
    fi
    
    return 1
}


# Function to convert file
convert_file() {
    local file="$1"
    local file_base=$(basename "$file")
    local file_name="${file_base%.*}"
    local file_ext="${file##*.}"
    local output_txt="$OUTPUT_DIR/${file_name}.txt"
    local temp_txt="$TEMP_DIR/${file_name}.txt"
    
    echo "Converting: $file"
    
    # Convert file to plain text
    local success=false
    
    if [[ "${file_ext,,}" == "pdf" ]]; then
        # Use special PDF conversion function
        if convert_pdf "$file" "$temp_txt"; then
            success=true
        fi
    else
        # Use pandoc for other file types
        if pandoc "$file" -t plain -o "$temp_txt" 2>/dev/null; then
            success=true
        fi
    fi
    
    if [ "$success" = true ] && [ -s "$temp_txt" ]; then
        # Move the converted file to output directory
        mv "$temp_txt" "$output_txt"
        echo "✓ Successfully converted: $file -> ${output_txt}"
    else
        echo "✗ Failed to convert: $file" >&2
        echo "[ERROR: Could not convert this file - may be encrypted, corrupted, or image-only PDF]" > "$output_txt"
    fi
    
    # Clean up temp file if it still exists
    rm -f "$temp_txt"
}

# Find and convert files
file_count=0
for pattern in "${FILE_TYPES[@]}"; do
    while IFS= read -r -d '' file; do
        convert_file "$file"
        ((file_count++))
    done < <(find "$SOURCE_DIR" -name "$pattern" -type f -print0 2>/dev/null)
done

# Clean up temp directory
rm -rf "$TEMP_DIR"

echo ""
echo "Conversion complete! $file_count files converted to: $OUTPUT_DIR"
echo "$(ls -1 "$OUTPUT_DIR" | wc -l) output files created"
#!/bin/bash
# filepath: /home/swojcik/github/GetAJobCLI/src/bash/clean_txt_for_rag.sh

#!/bin/bash

## Clean and normalize text files for better RAG performance

# Configuration
INPUT_DIR="${1:-./all_txt}"  # Use first argument or default to all_txt directory
OUTPUT_DIR="${2:-./clean_txt}"  # Use second argument or default output directory

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "Cleaning text files from: $INPUT_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "----------------------------------------"

# Function to check if text appears to be binary/garbage
# More conservative approach to preserve legitimate content
is_garbage_text() {
    local file="$1"
    local line_count=$(wc -l < "$file")
    local char_count=$(wc -c < "$file")
    local word_count=$(wc -w < "$file")
    
    # Only flag as garbage if ALL of these conditions are true
    # 1. Very low ratio of words to characters
    # 2. Contains obvious binary markers
    # 3. Has extremely long lines
    
    # Check for very low ratio of words to characters (suggesting binary/non-text content)
    if [ "$char_count" -gt 1000 ] && [ "$word_count" -lt 5 ]; then
        # Has almost no words despite significant character count
        if grep -q "stream\|endstream\|/Length\|/Filter" "$file" && 
           grep -q '.\{2000,\}' "$file"; then
            # Contains binary markers AND has extremely long lines
            return 0  # Is garbage
        fi
    fi
    
    # Not garbage
    return 1
}

# Function to clean a text file
clean_text_file() {
    local input_file="$1"
    local output_file="$2"
    local basename_file=$(basename "$input_file")
    
    echo "Processing: $basename_file"
    
    # Check if the file appears to be binary garbage
    if is_garbage_text "$input_file"; then
        echo "⚠️ File appears to contain binary/garbage content: $basename_file"
        echo "[This file contained binary or unreadable content and couldn't be properly converted]" > "$output_file"
        return
    fi
    
    # Create a temporary file
    local temp_file=$(mktemp)
    
    # 1. Remove null bytes and other control characters except newlines and tabs
    cat "$input_file" | tr -d '\000-\010\013-\014\016-\037\177' > "$temp_file"
    
    # 2. Normalize whitespace (multiple spaces to single space) but more conservatively
    sed -i 's/[[:space:]]\{4,\}/ /g' "$temp_file"
    
    # 3. Remove empty lines but keep formatting and indentation
    sed -i '/^[[:space:]]*$/d' "$temp_file"
    
    # 4. Only remove lines that are just numbers or very short symbols
    sed -i '/^[0-9]\{1,3\}$/d' "$temp_file"
    
    # 5. Convert to UTF-8 if possible
    if command -v iconv >/dev/null 2>&1; then
        iconv -f utf-8 -t utf-8 -c "$temp_file" > "$temp_file.utf8" 2>/dev/null
        if [ -s "$temp_file.utf8" ]; then
            mv "$temp_file.utf8" "$temp_file"
        else
            rm -f "$temp_file.utf8"
        fi
    fi
    
    # 6. Final cleanup of remaining non-printable characters
    tr -cd '\11\12\15\40-\176\200-\377' < "$temp_file" > "$output_file"
    
    # Calculate statistics for reporting
    local original_size=$(wc -c < "$input_file")
    local cleaned_size=$(wc -c < "$output_file")
    local reduction=$(( (original_size - cleaned_size) * 100 / original_size ))
    
    # Check if the cleaned file is too small (possible over-cleaning)
    if [ "$cleaned_size" -lt 100 ] && [ "$original_size" -gt 1000 ]; then
        echo "⚠️ Warning: Cleaning may have removed too much content (${reduction}% reduction)"
        # Create a backup of the original with minimal cleaning
        cat "$input_file" | tr -cd '\11\12\15\40-\176\200-\377' > "$output_file"
    elif [ "$reduction" -gt 50 ]; then
        echo "⚠️ Large reduction (${reduction}%): Validating content integrity"
        # Sample the first few lines to check for important content loss
        head -n 20 "$input_file" > "$temp_file.head"
        if grep -q "revolutionary\|CDDB\|data science\|important" "$temp_file.head"; then
            echo "   Found important content markers - preserving with minimal cleaning"
            # Just do minimal cleaning to preserve content
            cat "$input_file" | tr -cd '\11\12\15\40-\176\200-\377' > "$output_file"
        else
            echo "   No critical content markers found - using cleaned version"
        fi
        rm -f "$temp_file.head"
    else
        echo "✓ Cleaned: ${reduction}% reduction in size"
    fi
    
    # Clean up
    rm -f "$temp_file"
}

# Process all text files in the input directory
file_count=0
while IFS= read -r -d '' file; do
    output_file="$OUTPUT_DIR/$(basename "$file")"
    clean_text_file "$file" "$output_file"
    ((file_count++))
done < <(find "$INPUT_DIR" -name "*.txt" -type f -print0 2>/dev/null)

echo ""
echo "Cleaning complete! $file_count files processed"
echo "$(ls -1 "$OUTPUT_DIR" | wc -l) output files created in: $OUTPUT_DIR"

# Optional: Add a verification step to check for specific keywords in all files
echo ""
echo "Checking for potentially important content that may have been over-cleaned..."
for f in "$OUTPUT_DIR"/*.txt; do
    orig="$INPUT_DIR/$(basename "$f")"
    if [ -f "$orig" ] && [ -s "$orig" ] && [ ! -s "$f" ]; then
        # File was completely cleaned - check for important content
        if grep -q "revolutionary\|CDDB\|data science\|important concept" "$orig"; then
            echo "⚠️ File may contain important content despite binary markers: $(basename "$f")"
            # Restore with minimal cleaning
            cat "$orig" | tr -cd '\11\12\15\40-\176\200-\377' > "$f"
        fi
    fi
done
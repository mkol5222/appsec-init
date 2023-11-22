#!/bin/bash
OUTFILE=saved_file.sh
# Base64-encoded file content
embedded_file_base64='
dW5hbWUgLWEKZGF0ZQo=
'

# Decode and save the file
echo "$embedded_file_base64" | base64 -d > "$OUTFILE"

# Optional: Display a message
echo "File saved as $OUTFILE"

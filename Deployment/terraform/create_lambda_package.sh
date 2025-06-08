#!/bin/bash

# Convert Windows paths to Unix paths and ensure absolute path
LAMBDA_DIR=$(realpath "$(echo "${1}" | sed 's/\\/\//g')")
PACKAGE_DIR="$(realpath "$(pwd)/package")"
ZIP_FILE="$LAMBDA_DIR/lambda-deployment.zip"

echo "Current directory: $(pwd)"
echo "Lambda directory: $LAMBDA_DIR"
echo "Package directory: $PACKAGE_DIR"
echo "Zip file will be: $ZIP_FILE"

# Clean up and create package directory
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

# Install dependencies
pip install -r "$LAMBDA_DIR/requirements.txt" -t "$PACKAGE_DIR"

# Copy Python files
cp "$LAMBDA_DIR"/*.py "$PACKAGE_DIR"

# Create zip file using p7zip with parallel compression
cd "$PACKAGE_DIR"
echo "Creating zip in: $(pwd)"

# First remove any existing zip
rm -f "$ZIP_FILE"

# Create new zip with contents of current directory
7z a -tzip -mx=9 -mmt=on -bd "$ZIP_FILE" * > /dev/null

# Cleanup
cd ..
rm -rf "$PACKAGE_DIR"
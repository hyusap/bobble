#!/bin/bash

set -e

echo "Building HeadGesture CLI tool..."

# Build in release mode for better performance
swift build -c release

# Copy executable to convenient location
BINARY_PATH=".build/release/headgesture"

if [ -f "$BINARY_PATH" ]; then
    echo "✓ Build successful!"
    echo ""
    echo "Executable location: $BINARY_PATH"
    echo ""
    echo "To install globally, run:"
    echo "  sudo cp $BINARY_PATH /usr/local/bin/"
    echo ""
    echo "Or use directly:"
    echo "  $BINARY_PATH --help"
else
    echo "✗ Build failed - executable not found"
    exit 1
fi

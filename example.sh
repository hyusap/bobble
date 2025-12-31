#!/bin/bash

# Example script demonstrating HeadGesture CLI usage

HEADGESTURE=".build/release/headgesture"

echo "=== HeadGesture Example Script ==="
echo ""

# Example 1: Simple yes/no question
echo "Example 1: Do you want to proceed?"
echo "           (Nod for yes, shake for no - 10s timeout)"
$HEADGESTURE --timeout 10

case $? in
  0)
    echo "✓ You nodded - proceeding..."
    ;;
  1)
    echo "✗ You shook your head - aborting..."
    exit 1
    ;;
  2)
    echo "⏱  Timeout - no response detected"
    ;;
  3)
    echo "⚠️  Error - AirPods not connected or not available"
    exit 1
    ;;
esac

echo ""
echo "=== Script complete ==="

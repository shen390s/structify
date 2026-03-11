#!/usr/bin/env bash
# Integration test script for generated Person functions

set -e

echo "=== Structify Integration Test ==="
echo ""

# Step 1: Generate code using Haskell test
echo "Step 1: Generating code from Person struct..."
cd "$(dirname "$0")/../.."
nix develop --command bash -c "cabal run test:file-io-test"
echo ""

# Step 2: Compile generated C code
echo "Step 2: Compiling generated C code..."
cd examples/simple
nix develop /home/rshen/works/projects/cgen --command bash -c "gcc -o test_person test_person.c person_generated.c -I. -Wall -Wextra"
echo "✓ Compilation successful"
echo ""

# Step 3: Run the test
echo "Step 3: Running integration test..."
nix develop /home/rshen/works/projects/cgen --command bash -c "./test_person"
echo ""

echo "=== Integration Test Complete ==="

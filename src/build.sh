#!/bin/bash

set -e 

echo "🔨 Building upload-handler..."
cd "$(dirname "$0")/upload-handler"
mkdir -p package
cp handler.py package/
cd package && zip -r ../upload-handler.zip . -x "*.pyc" "__pycache__/*" && cd ..
rm -rf package
echo "✅ upload-handler.zip ready"

echo "🔨 Building processor..."
cd ../processor

pip3 install \
  --platform manylinux2014_x86_64 \
  --target ./package \
  --implementation cp \
  --python-version 3.11 \
  --only-binary=:all: \
  pillow --quiet

cp handler.py package/
cd package && zip -r ../processor.zip . -x "*.pyc" "__pycache__/*" && cd ..
rm -rf package
echo "✅ processor.zip ready"

echo "🎉 All packages built successfully!"
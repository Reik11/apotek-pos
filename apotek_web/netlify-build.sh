#!/bin/bash

set -e

echo "=== Installing Flutter ==="
git clone https://github.com/flutter/flutter.git flutter
cd flutter
git checkout 3.41.6
cd ..
export PATH="$PATH:`pwd`/flutter/bin"

echo "=== Flutter Version ==="
flutter --version

echo "=== Enable Web ==="
flutter config --enable-web

echo "=== Get Dependencies ==="
flutter pub get

echo "=== Build Web ==="
flutter build web --release
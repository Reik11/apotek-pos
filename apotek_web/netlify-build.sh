#!/bin/bash

set -e

if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git flutter
fi
cd flutter
git fetch
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
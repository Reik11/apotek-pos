#!/bin/bash

git clone https://github.com/flutter/flutter.git --depth 1 -b 3.41.6 flutter
export PATH="$PATH:`pwd`/flutter/bin"

flutter --version
flutter pub get
flutter build web --release --no-wasm
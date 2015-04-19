#!/usr/bin/env bash

bundle install
bower install

echo "Downloading Facebook SDK"
curl http://connect.facebook.net/en_US/sdk.js -o vendor/facebook.js

echo "Building jvectormap..."
cd vendor/bower/jvectormap
./build.sh

echo "Build complete!"

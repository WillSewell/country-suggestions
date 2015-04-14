#!/usr/bin/env bash

bundle install
bower install

echo "Building jvectormap..."
cd bower_components/jvectormap
./build.sh

echo "Build complete!"

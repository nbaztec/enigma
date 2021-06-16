#!/usr/bin/env bash
mkdir -p bundle
mkdir -p bundle/cards
mkdir -p bundle/cards-bg
cp build/app/outputs/flutter-apk/app.apk bundle/enigma.apk
cp qr/cards/*.png ./bundle/cards
cp qr/cards-bg/*.png ./bundle/cards-bg
cp qr/sprites/sprite.png qr/sprites/sprite_bg.png ./bundle/
zip -r bundle.zip bundle/*

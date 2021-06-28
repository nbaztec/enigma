#!/usr/bin/env bash
mkdir -p bundle
mkdir -p bundle/cards
mkdir -p bundle/cards-bg
cp build/app/outputs/flutter-apk/app.apk bundle/enigma.apk
cp qr/cards/*.png ./bundle/cards
cp qr/cards-bg/*.png ./bundle/cards-bg
cp qr/sprites/sprite_nobg.pdf qr/sprites/sprite_bg.pdf ./bundle/
zip -r bundle.zip bundle/*

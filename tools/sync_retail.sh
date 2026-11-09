#!/bin/sh
# Copies the shared engine and UI of FreegorGuide into FreegorGuideRetail.
# Run from the repository root after changing anything in FreegorGuide/{Core,UI,Locales}.
set -e
for d in Core UI Locales; do
  rm -rf "FreegorGuideRetail/$d"
  cp -r "FreegorGuide/$d" "FreegorGuideRetail/$d"
done
echo "FreegorGuideRetail synced."

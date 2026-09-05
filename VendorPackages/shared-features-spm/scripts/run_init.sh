#!/bin/bash
set -e
export LANG=en_US.UTF-8

echo "👋 Hey! Let's start to setup your environment"

# Install git hooks
echo "📦 Installing git hooks..."
git config core.hooksPath .githooks
echo "✅ Git hooks installed!"

echo "🎉 All done! Enjoy your new environment!\n\nFor more commands run 'make help'"

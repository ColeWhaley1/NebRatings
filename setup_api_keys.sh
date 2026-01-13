#!/bin/bash

# Setup script for API keys
# This script helps you set up your TMDB API keys for local development

echo "NebRatings API Keys Setup"
echo "========================="
echo ""
echo "This script will help you configure your API keys."
echo ""

# Check if Config.xcconfig exists
if [ ! -f "Config.xcconfig" ]; then
    echo "Creating Config.xcconfig from template..."
    cp Config.xcconfig.template Config.xcconfig
    echo "✅ Created Config.xcconfig"
    echo ""
fi

echo "Choose setup method:"
echo "1. Set environment variables (for this terminal session)"
echo "2. Add to Xcode Build Settings (recommended)"
echo "3. Set directly in Config.xcconfig (not recommended)"
echo ""
read -p "Enter choice (1-3): " choice

case $choice in
    1)
        echo ""
        read -p "Enter TMDB_API_KEY: " api_key
        read -p "Enter TMDB_API_READ_ACCESS_TOKEN: " access_token
        echo ""
        echo "Add these to your shell profile (~/.zshrc or ~/.bash_profile):"
        echo "export TMDB_API_KEY=$api_key"
        echo "export TMDB_API_READ_ACCESS_TOKEN=$access_token"
        echo ""
        echo "Or run these commands before building:"
        echo "export TMDB_API_KEY=$api_key"
        echo "export TMDB_API_READ_ACCESS_TOKEN=$access_token"
        ;;
    2)
        echo ""
        echo "To set in Xcode Build Settings:"
        echo "1. Open NebRatings.xcodeproj in Xcode"
        echo "2. Select the 'NebRatings' project in the navigator"
        echo "3. Select the 'NebRatings' target"
        echo "4. Go to the 'Build Settings' tab"
        echo "5. Click the '+' button and select 'Add User-Defined Setting'"
        echo "6. Add:"
        echo "   - Name: TMDB_API_KEY"
        echo "   - Value: (your API key)"
        echo "   - Name: TMDB_API_READ_ACCESS_TOKEN"
        echo "   - Value: (your access token)"
        echo ""
        echo "These settings are stored per-user and won't be committed to git."
        ;;
    3)
        echo ""
        read -p "Enter TMDB_API_KEY: " api_key
        read -p "Enter TMDB_API_READ_ACCESS_TOKEN: " access_token
        echo ""
        echo "Updating Config.xcconfig with direct values..."
        cat > Config.xcconfig << EOF
//
//  Config.xcconfig
//  NebRatings
//
//  Created by Cole Whaley on 11/29/25.
//

// Configuration settings file format documentation can be found at:
// https://developer.apple.com/documentation/xcode/adding-a-build-configuration-file-to-your-project

// Direct values (for local development only - not recommended for production)
TMDB_API_KEY = $api_key
TMDB_API_READ_ACCESS_TOKEN = $access_token
EOF
        echo "✅ Updated Config.xcconfig"
        echo "⚠️  Note: Config.xcconfig is in .gitignore and won't be committed"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "Setup complete! See README_API_KEYS.md for more information."


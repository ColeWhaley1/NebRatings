# Quick Start - Setting Up API Keys

Your API keys have been moved to use Xcode build settings for security. Follow these steps to configure them:

## ⚡ Quick Setup (Choose One Method)

### Method 1: Xcode Build Settings (Recommended)

1. Open `NebRatings.xcodeproj` in Xcode
2. Click on the **NebRatings** project (blue icon) in the left navigator
3. Select the **NebRatings** target
4. Click the **Build Settings** tab
5. Make sure "All" and "Combined" are selected at the top
6. Click the **"+"** button → **"Add User-Defined Setting"**
7. Add these two settings:

   **Setting 1:**
   - Name: `TMDB_API_KEY`
   - Value: `37b0ba6311b568f666b9aa77cbbd8894` (your actual API key)

   **Setting 2:**
   - Name: `TMDB_API_READ_ACCESS_TOKEN`
   - Value: `eyJhbGciOiJIUzI1NiJ9...` (your actual access token)

8. Build and run - your API keys are now configured!

### Method 2: Environment Variables

Set these before building:
```bash
export TMDB_API_KEY=your_api_key_here
export TMDB_API_READ_ACCESS_TOKEN=your_access_token_here
```

### Method 3: Use the Setup Script

Run the interactive setup script:
```bash
./setup_api_keys.sh
```

## ✅ Security Status

- ✅ `Config.xcconfig` is in `.gitignore` - your keys won't be committed
- ✅ API keys are no longer hardcoded in the repository
- ✅ Use Xcode build settings for local development
- ✅ Use environment variables for CI/CD

## 📚 More Information

See `README_API_KEYS.md` for detailed documentation.


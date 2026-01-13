# API Keys Configuration

This project uses environment variables and Xcode build settings for API keys to keep them secure and out of version control.

## Setup Instructions

### Option 1: Xcode Build Settings (Recommended for Local Development)

1. Open your project in Xcode
2. Select the **NebRatings** project in the navigator
3. Select the **NebRatings** target
4. Go to the **Build Settings** tab
5. Click the **"+"** button at the top and select **"Add User-Defined Setting"**
6. Add the following two settings:
   - **Name:** `TMDB_API_KEY`, **Value:** `your_tmdb_api_key_here`
   - **Name:** `TMDB_API_READ_ACCESS_TOKEN`, **Value:** `your_tmdb_read_access_token_here`

These settings will be stored in your `project.pbxproj` file but are user-specific and won't be committed if you exclude `xcuserdata/` (which is already in `.gitignore`).

### Option 2: Environment Variables (Recommended for CI/CD)

Set environment variables before building:

```bash
export TMDB_API_KEY=your_tmdb_api_key_here
export TMDB_API_READ_ACCESS_TOKEN=your_tmdb_read_access_token_here
```

Then build from command line:
```bash
xcodebuild -project NebRatings.xcodeproj -scheme NebRatings
```

### Option 3: Direct Values in Config.xcconfig (For Quick Testing Only)

If you need to set values directly (not recommended for production):

1. Copy `Config.xcconfig.template` to `Config.xcconfig` (if not already exists)
2. Uncomment and set the values:
   ```
   TMDB_API_KEY = your_api_key_here
   TMDB_API_READ_ACCESS_TOKEN = your_access_token_here
   ```

**Note:** `Config.xcconfig` is in `.gitignore` and will NOT be committed to version control.

## Getting Your TMDB API Keys

1. Go to [TMDB Settings](https://www.themoviedb.org/settings/api)
2. Create an API key if you haven't already
3. Copy your API Key and Read Access Token

## Security Notes

- ✅ `Config.xcconfig` is in `.gitignore` - never commit API keys
- ✅ `GoogleService-Info.plist` is in `.gitignore` - Firebase config is protected
- ✅ Use environment variables or Xcode build settings for production
- ❌ Never hardcode API keys in source files
- ❌ Never commit API keys to version control


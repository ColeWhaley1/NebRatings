# Universal Links — status & remaining manual steps

Domain: **nebratings.com**

## ✅ Done in code (committed)

| Piece | Where |
|-------|-------|
| Deep-link parse + generate | `NebRatings/Models/DeepLink.swift` (`webDomain = "nebratings.com"`) |
| Routing (`.onOpenURL` → root sheets) | `NebRatings/ContentView.swift` |
| Custom scheme `nebratings://` | `NebRatings/Info.plist` |
| Share-link generation | `NebRatings/Components/ShareContent.swift` |
| **Associated Domains entitlement** | `NebRatings/NebRatings.entitlements` (`applinks:nebratings.com`, `applinks:www.nebratings.com`) — builds & signs cleanly on Simulator |
| **AASA file, ready to upload** | `web/.well-known/apple-app-site-association` |

Link shapes: `show/{movie|tv}/{tmdbID}` and `user/{userID}`.

## ⏳ Remaining — the parts only you can do

### 1. Host the AASA file on nebratings.com
Upload the generated file so it's served at **both** URLs, over HTTPS, with
`Content-Type: application/json`, **no `.json` extension**, **no redirects**:

- `https://nebratings.com/.well-known/apple-app-site-association`
- `https://nebratings.com/apple-app-site-association`

The exact file to upload is in this repo at
`web/.well-known/apple-app-site-association`:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["ND29VRWA3P.com.colewhaley.NebRatings"],
        "components": [
          { "/": "/show/*", "comment": "Movie/TV detail pages" },
          { "/": "/user/*", "comment": "User profile pages" }
        ]
      }
    ]
  }
}
```

Host-specific notes:
- **Firebase Hosting** — put the file at `public/.well-known/apple-app-site-association` and add to `firebase.json`:
  ```json
  "hosting": {
    "headers": [
      { "source": "/.well-known/apple-app-site-association",
        "headers": [{ "key": "Content-Type", "value": "application/json" }] }
    ]
  }
  ```
- **Cloudflare Pages / Netlify / Vercel** — drop the `web/` folder in as the
  site root; they serve `.well-known/` as-is. Confirm no framework rewrite
  catches it.
- **Apex vs www** — links generate as `https://nebratings.com/...` (apex).
  Make sure the apex serves the AASA. If `www` redirects to apex, that's fine;
  just don't let the AASA path itself redirect.

Verify once live:
```bash
curl -I https://nebratings.com/.well-known/apple-app-site-association
# → 200, Content-Type: application/json, no Location/redirect
```

### 2. Enable the capability for DEVICE builds
The entitlement is already in the project. For a **device** build it must
also be enabled on the App ID:

- Easiest: Xcode → target **NebRatings** → **Signing & Capabilities**, make
  sure **Automatically manage signing** is on and you're signed into the team
  (`ND29VRWA3P`). Xcode registers the Associated Domains capability and
  regenerates the profile on the next device build.
- If you see *"provisioning profile doesn't include the associated-domains
  entitlement"*: in **Signing & Capabilities**, click **+ Capability** →
  **Associated Domains** (it'll pick up the existing entries), then let Xcode
  refresh the profile. (Simulator builds don't need any of this — they
  already work.)

### 3. Flip the switch
Once step 1 is verified live, in `NebRatings/Models/DeepLink.swift`:
```swift
static let isUniversalLinkingEnabled = true
```
This turns on public `https://nebratings.com/...` links in share sheets. The
routing that receives them is already in place.

### 4. (Recommended) web fallback pages
When the app isn't installed, `https://nebratings.com/show/...` opens in a
browser. Add simple pages at `/show/...` and `/user/...` (title, poster, an
"Open in App Store" button) so those links aren't dead ends. Not required for
Universal Links to work in-app.

## Testing

**Custom scheme — works today (Simulator):**
```bash
xcrun simctl openurl booted "nebratings://show/movie/27205"   # Inception
xcrun simctl openurl booted "nebratings://user/<aUserID>"
```

**Universal Links — after steps 1–2, on a real device:**
1. Confirm Apple can fetch your AASA:
   `https://app-site-association.cdn-apple.com/a/v1/nebratings.com`
2. Put `https://nebratings.com/show/movie/27205` in Notes/Messages and tap it.
   iOS caches AASA hard — if it opens Safari, delete+reinstall the app or
   toggle airplane mode.

## Extending later
Add `case list(id:)` to `DeepLink`, a `list/{id}` path in the parser/generator,
a `{ "/": "/list/*" }` AASA component, and a resolve branch in
`ContentView.resolvePendingLink()`.

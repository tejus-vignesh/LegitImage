# Share Extension setup

This folder holds the code for the LegitImage Share Extension, which lets
users share a screenshot from the iOS screenshot screen straight to
LegitImage. The extension cannot be added through tooling — Xcode needs
to create the target through its UI. Steps below.

## One-time Xcode setup

1. **Add the target**
   - In Xcode, `File ▸ New ▸ Target… ▸ Share Extension`.
   - Product Name: `LegitImageShareExtension`.
   - Embed in the `LegitImage` app.

2. **Replace the generated files** with the ones in this folder:
   - Delete the auto-generated `ShareViewController.swift`, `MainInterface.storyboard`, and `Info.plist`.
   - Drag in `ShareViewController.swift`, `Info.plist`, and `ShareExtension.entitlements` from this folder.
   - In the extension target's Build Settings:
     - Remove `NSExtensionMainStoryboard` references (the controller is code-only).
     - Set `INFOPLIST_FILE = ShareExtension/Info.plist`.
     - Set `CODE_SIGN_ENTITLEMENTS = ShareExtension/ShareExtension.entitlements`.

3. **Create the App Group**
   - Select the **main app** target → Signing & Capabilities → `+ Capability` → App Groups.
   - Add `group.com.LegitImage.shared`.
   - Repeat on the **Share Extension** target with the same identifier.
   - The identifier must match `SharedInbox.appGroupID` in the main app and the constants at the top of `ShareViewController.swift`.

4. **Register the URL scheme on the main app**
   - Main app target → Info → URL Types → `+`.
   - URL Schemes: `legitimage`. Identifier: `com.LegitImage.url`.
   - This lets the extension wake the host app.

5. **Add camera + photo library usage strings**
   - Main app target → Info, add:
     - `Privacy - Camera Usage Description`: "LegitImage uses the camera so you can capture a photo to verify in the moment."
     - `Privacy - Photo Library Usage Description`: "LegitImage reads the photo you pick to run the verification checks."

## Flow at runtime

1. User taps Share on the iOS screenshot screen, picks **LegitImage**.
2. `ShareViewController` reads the shared image bytes.
3. Writes them into the App Group container (`shared-image.bin`) plus a
   tiny `shared-meta.json` that marks the source as `screenshot`.
4. Opens `legitimage://verify` to wake the host app.
5. `LegitImageApp.onOpenURL` calls `SharedInbox.consume()` and pushes
   the results screen with the image already classified as a screenshot.

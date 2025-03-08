# ClipText Debug Guide

## Current Issue
- App doesn't appear in System Settings > Privacy & Security > Screen Recording
- Getting TCC (Transparency, Consent, and Control) permission errors
- Bundle identifier mismatch warning in logs

## Required Background
1. macOS App Signing Requirements
   - Apps must be code signed to request permissions
   - Development builds need proper provisioning
   - Bundle identifier must be consistent across the project

2. Permission System (TCC)
   - Screen recording requires explicit user approval
   - App must be properly registered in TCC database
   - Bundle identifier is used to track permissions

## Debugging Steps

### 1. Check Project Settings
In Xcode:
1. Click on project in navigator
2. Select target "ClipText"
3. Under "Signing & Capabilities":
   - Ensure "Automatically manage signing" is checked
   - Check that your Apple ID is selected
   - Verify Team is selected
   - Bundle Identifier should be "com.snair.cliptext"

### 2. Check Build Settings
Still in project settings:
1. Build Settings tab
2. Search for "bundle"
3. Verify:
   - Product Bundle Identifier = "com.snair.cliptext"
   - Development Team is set
   - Code Signing Identity is set to "Apple Development"

### 3. Check Info.plist
Verify contents match:
```xml
<key>CFBundleIdentifier</key>
<string>com.snair.cliptext</string>
<key>NSScreenCaptureUsageDescription</key>
<string>ClipText needs screen recording permission to capture text from your screen.</string>
```

### 4. Check Entitlements
In ClipText.entitlements:
```xml
<key>com.apple.security.screen-recording</key>
<true/>
```

### 5. Clean State
1. Delete derived data:
   - Xcode > Preferences > Locations
   - Click arrow next to Derived Data
   - Delete ClipText folder
2. Reset TCC database:
   ```bash
   tccutil reset ScreenCapture
   ```
3. Clean build folder:
   - Xcode > Product > Clean Build Folder

### 6. Build Process
1. Stop any running instances
2. Clean build folder
3. Build and run from Xcode
4. App should appear in menu bar with icon

### 7. Common Issues
- If app doesn't appear in menu bar:
  - Check AppDelegate setup
  - Verify status item creation
- If app doesn't appear in permissions:
  - Check code signing
  - Verify bundle ID consistency
  - Try building to /Applications

### 8. Logging
Current logs show:
- Bundle ID mismatch
- TCC permission errors
- App sandbox issues

### 9. Next Steps
1. Verify project settings
2. Clean all build artifacts
3. Reset TCC database
4. Build fresh from Xcode
5. Check menu bar for app icon
6. Then attempt to request permissions

### 10. Questions to Answer
1. Is the app appearing in the menu bar?
2. What's the exact bundle identifier in build settings?
3. Is code signing enabled and working?
4. Is the app being built in debug or release?
5. Where is the app being run from?

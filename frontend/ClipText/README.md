# ClipText

A simple Swift app that uses Auth0 for authentication and connects to a Cloudflare worker to access Gemini AI.

## Setup Instructions

1. **Auth0 Configuration**

   Update the `Auth0.plist` file with your Auth0 domain and client ID:
   ```xml
   <dict>
       <key>Domain</key>
       <string>YOUR_AUTH0_DOMAIN</string>
       <key>ClientId</key>
       <string>YOUR_AUTH0_CLIENT_ID</string>
   </dict>
   ```

2. **Package Dependencies**

   This project requires the following Swift packages:
   - Auth0.swift: https://github.com/auth0/Auth0.swift.git
   - JWTDecode.swift: https://github.com/auth0/JWTDecode.swift.git

   Add these packages in Xcode:
   - Go to File → Add Packages...
   - Enter the GitHub URL for each package
   - Select "Up to Next Major Version" for version rules

3. **Configure Auth0 Callback URL**

   In your Auth0 dashboard:
   - Set the Allowed Callback URLs to `YOUR_BUNDLE_IDENTIFIER://YOUR_AUTH0_DOMAIN/ios/YOUR_BUNDLE_IDENTIFIER/callback`
   - Set the Allowed Logout URLs to `YOUR_BUNDLE_IDENTIFIER://YOUR_AUTH0_DOMAIN/ios/YOUR_BUNDLE_IDENTIFIER/callback`

## Features

- Auth0 authentication
- Send prompts to Gemini AI through a Cloudflare worker
- Display AI responses in a clean interface

## Project Structure

- **Models**: Data models including User
- **Views**: SwiftUI views for the app UI
- **ViewModels**: View models for managing app state
- **Services**: API service for communicating with the backend

## Cloudflare Worker

The app connects to a Cloudflare worker at `https://my-first-worker.saeejithn.workers.dev/` which forwards requests to the Gemini API. 
# ClipText

A native macOS app that captures screen regions and converts them to text using OCR. The app uses the Gemini 2.0flash OCR API to extract text from images and automatically copies the result to your clipboard.

## Features

- Global hotkey (⌃⇧9) to trigger screen capture
- Region selection with visual feedback
- Automatic OCR processing
- Markdown-formatted text output
- System notifications for success/failure
- Menu bar integration

## Requirements

- macOS 12.0 or later
- Xcode 14.0 or later
- A Gemini 2.0flash API key

## Setup

1. Clone the repository
2. Open `ClipText.xcodeproj` in Xcode
3. Replace `YOUR_GEMINI_API_KEY` in `AppDelegate.swift` with your actual Gemini 2.0flash API key
4. Build and run the project

## Usage

1. Press ⌃⇧9 (Control + Shift + 9) to start capture
2. Click and drag to select the region you want to capture
3. Release the mouse button to process the selection
4. The extracted text will be automatically copied to your clipboard
5. A notification will appear to confirm success or show any errors

## Development

The app is structured into several key components:

- `HotkeyManager`: Handles global hotkey registration and monitoring
- `ScreenshotManager`: Manages screen region selection and capture
- `OCRService`: Handles communication with the Gemini OCR API
- `ClipboardManager`: Manages clipboard operations
- `NotificationManager`: Handles system notifications

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details. 
# **ClipText v2 – Comprehensive Product Requirements Document**

---

## **1. Overview**

ClipText v2 is a native macOS application designed to provide a fast and reliable way for users to capture a selected region of their screen, extract text using the Gemini OCR API, and copy the resulting Markdown/LaTeX text to the clipboard. This version uses modern, supported APIs—most notably ScreenCaptureKit for screen capture—to replace deprecated methods (e.g. CGWindowListCreateImage) and enforce a strictly sequential (synchronous) flow, except for a single asynchronous network timeout.

---

## **2. Objectives**

### **Primary Objective**
- Build an application that triggers on a global hotkey (default: Ctrl+Shift+9), allowing the user to hide the UI, select a screen region, capture a single frame, process it with OCR, and copy the text result to the clipboard.

### **Secondary Objectives**
- **Sequential Flow:** Ensure the capture, processing, and clipboard update operations follow a linear pipeline with minimal asynchronous branching.
- **Modern API Usage:** Replace deprecated APIs with ScreenCaptureKit (using SCStream, SCShareableContent, and SCScreenshotManager) to capture screen content reliably on macOS 15 and later.
- **Robust Error Handling:** Provide clear error and cancellation handling with immediate resource cleanup.
- **Security & Maintainability:** Secure API keys (via secure storage or environment variables) and organize code into modular components for ease of testing and maintenance.
- **Native UX:** Ensure that the app’s UI (overlays, indicators, etc.) is never captured in the screenshot and that users receive immediate feedback via notifications or alerts.

---

## **3. User Stories**

- **Hotkey Activation:**  
  *“As a user, I want to press a custom global hotkey (Ctrl+Shift+9) so that I can quickly initiate a screen capture.”*

- **Region Selection:**  
  *“As a user, I want to see a dimmed overlay that lets me select a specific region on the screen using a familiar drag-to-select interface.”*

- **Processing Feedback:**  
  *“As a user, I want to see a spinner in the top-left corner immediately after my selection so that I know processing is in progress.”*

- **Cancellation:**  
  *“As a user, I want to cancel the capture at any point by pressing the ESC key, with all operations terminating gracefully.”*

- **Clipboard Result:**  
  *“As a user, I want the text extracted via OCR to be automatically copied to my clipboard if the capture is successful.”*

- **Error Notification:**  
  *“As a user, if an error occurs (during capture, image conversion, network communication, or OCR), I want to be promptly notified and have the process clean up without leaving residual resources.”*

---

## **4. Functional Requirements**

### **4.1 Global Hotkey Registration**
- **Requirement:**  
  Register a system-wide hotkey (default: Ctrl+Shift+9) that initiates the capture process.
- **Implementation:**  
  - Use Carbon’s `RegisterEventHotKey` (see [RegisterEventHotKey](citeturn0search0)) for reliable global hotkey registration.
  - On hotkey press, the app immediately hides its UI and transitions to capture mode.

### **4.2 Overlay & Region Selection**
- **Requirement:**  
  Display a full-screen, borderless overlay to allow users to select a screen region.
- **Implementation:**  
  - Create an `NSWindow` with `NSWindow.StyleMask.borderless` and set its level to `NSWindow.Level.screenSaver`.
  - Use `NSWindow.CollectionBehavior.canJoinAllSpaces` and `fullScreenAuxiliary` to ensure coverage across all monitors.
  - Implement a custom `NSView` (e.g., `SelectionView`) that:
    - Listens for mouse events (`mouseDown`, `mouseDragged`, `mouseUp`) to draw a dynamic selection rectangle.
    - Excludes the app’s UI from the capture.
- **Cancellation:**  
  - Install an event monitor with `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` to detect the ESC key (key code 53) and cancel the capture process immediately.

### **4.3 Screen Capture Using ScreenCaptureKit**
- **Requirement:**  
  Capture a single frame from the user-selected region using modern ScreenCaptureKit APIs.
- **Implementation:**  
  - **For macOS 15 and Later:**  
    1. **Obtain Shareable Content:**  
       - Use `SCShareableContent.excludingDesktopWindows(onScreenWindowsOnly: true)` to retrieve available capture sources.
    2. **Configure Capture:**  
       - Create an `SCStreamConfiguration` and set:
         - `sourceRect` to the selected region.
         - `width` and `height` to match the region’s dimensions.
         - Other properties (e.g., shadow settings, cursor visibility) as needed.
    3. **Capture a Frame:**  
       - Start an `SCStream` with the configuration.
       - Implement a delegate (or use a completion block via the `SCStreamOutput` protocol) to receive the first frame.
       - Immediately stop the stream after capturing one frame.
       - If synchronous behavior is required, utilize dispatch semaphores or groups to wait for the frame callback.
  - **Alternative:**  
    - Use `SCScreenshotManager.captureImage(contentFilter:configuration:completionHandler:)` for a simplified asynchronous capture if performance and latency are acceptable.
- **References:**  
  - [ScreenCaptureKit Documentation](citeturn0search1)  
  - [SCStream Documentation](citeturn0search4)

### **4.4 Image Conversion & OCR Service Integration**
- **Image Conversion:**  
  - Convert the captured frame (buffer/IOSurface) to a PNG image using `NSBitmapImageRep`.
- **OCR Service:**  
  - Send the PNG image to the Gemini OCR API using `URLSession` with a single, dedicated timeout.
  - Parse the JSON response to extract formatted text (Markdown/LaTeX).
- **Error Handling:**  
  - On failure during conversion or network communication, terminate the process and display an error notification.

### **4.5 Clipboard Management**
- **Requirement:**  
  Copy the resulting text to the system clipboard upon successful OCR processing.
- **Implementation:**  
  - Use `NSPasteboard.general` to clear the existing content and write the new text in a single, atomic operation.

### **4.6 User Notifications & Alerts**
- **Requirement:**  
  Provide immediate feedback to the user on success, error, or cancellation.
- **Implementation:**  
  - Use `UNUserNotificationCenter` for background local notifications.
  - Utilize `NSAlert` for modal error messages when needed.

---

## **5. Non-Functional Requirements**

- **Responsiveness:**  
  - The overall flow (capture → OCR → clipboard update) should be near-instantaneous, constrained mainly by the OCR API’s response time.
- **Stability:**  
  - The app must gracefully handle rapid hotkey presses, ensuring no resource leaks or crashes.
- **Security:**  
  - Sensitive information such as API keys must be loaded securely (via Keychain or environment variables) and not hardcoded.
- **Maintainability:**  
  - Code should be modular (e.g., separate managers for hotkey, capture, OCR, clipboard, notifications) and well-documented.
- **Resource Management:**  
  - All temporary resources (overlay windows, SCStream instances, event monitors) must be released immediately upon completion, cancellation, or error.

---

## **6. System Architecture**

### **6.1 Components**

1. **Hotkey Manager**  
   - **Role:**  
     Registers the global hotkey (via `RegisterEventHotKey`) and triggers the capture process.
   - **Key API:**  
     - Carbon API: `RegisterEventHotKey`

2. **Capture Manager & Overlay**  
   - **Role:**  
     Displays a borderless overlay, handles region selection, and initiates screen capture.
   - **Key APIs:**  
     - `NSWindow` (with `borderless` style, `NSWindow.Level.screenSaver`)
     - Custom `NSView` for handling mouse events
     - `NSEvent.addLocalMonitorForEvents(matching:)` for ESC key detection

3. **Screen Capture Module**  
   - **Role:**  
     Captures a single frame from the selected region using ScreenCaptureKit.
   - **Key APIs:**  
     - `SCShareableContent`
     - `SCStreamConfiguration`  
     - `SCStream` (or alternatively, `SCScreenshotManager.captureImage`)
     - Delegation / completion handlers for frame retrieval
   - **Synchronous Handling:**  
     - Use dispatch semaphores or groups to wait for the frame if needed

4. **Image Conversion & OCR Service**  
   - **Role:**  
     Converts the captured frame into PNG data and sends it to the Gemini OCR API.
   - **Key APIs:**  
     - `NSBitmapImageRep`
     - `URLSession` and `URLRequest` with a timeout

5. **Clipboard Manager**  
   - **Role:**  
     Copies the OCR text to the system clipboard.
   - **Key API:**  
     - `NSPasteboard.general`

6. **Notification & Alert Manager**  
   - **Role:**  
     Provides user feedback via notifications and alerts.
   - **Key APIs:**  
     - `UNUserNotificationCenter`
     - `NSAlert`

7. **Resource Manager**  
   - **Role:**  
     Ensures that overlays, event monitors, and SCStream instances are properly cleaned up.
   - **Key Responsibility:**  
     - Immediate teardown on cancellation, errors, or completion

### **6.2 Data Flow Diagram**

```mermaid
flowchart TD
    A[Hotkey Pressed (RegisterEventHotKey)] --> B[Hide Main UI & Display Overlay (NSWindow)]
    B --> C[User Selects Region (Custom NSView handling mouse events)]
    C --> D[User Releases Mouse]
    D --> E[Initialize SCStream with SCStreamConfiguration (ScreenCaptureKit)]
    E --> F[Wait for first frame via SCStreamOutput callback]
    F --> G[Stop SCStream & Convert Frame to PNG (NSBitmapImageRep)]
    G --> H[Send PNG to Gemini OCR API (URLSession, URLRequest with timeout)]
    H --> I{OCR Response OK?}
    I -- Yes --> J[Extract text & Copy to Clipboard (NSPasteboard)]
    J --> K[Show Success Notification (UNUserNotificationCenter/NSAlert) & Cleanup]
    I -- No/Timeout --> L[Show Error Notification & Cleanup]
    B -. ESC Pressed .-> M[Cancel Capture, Stop SCStream, Cleanup]
```

---

## **7. Implementation Plan**

### **7.1 Environment Setup**
- Use the latest Xcode and Swift with a Cocoa App template.
- Ensure all sensitive credentials (API keys) are managed securely.

### **7.2 Module Development**
1. **Hotkey Manager:**  
   - Implement using Carbon’s `RegisterEventHotKey`.
   - Test global hotkey registration and conflict resolution.

2. **Overlay & Region Selection:**  
   - Develop a borderless `NSWindow` and custom selection view.
   - Handle mouse events and draw a dynamic selection rectangle.
   - Implement ESC key monitoring for cancellation.

3. **Screen Capture Module:**  
   - Replace deprecated CG APIs with ScreenCaptureKit:
     - Configure `SCStreamConfiguration` with the selected region.
     - Start an `SCStream` and capture the first frame via delegate/callback.
     - Consider using semaphores/dispatch groups to simulate synchronous capture.
   - Alternatively, evaluate using `SCScreenshotManager.captureImage` if latency is acceptable.

4. **Image Conversion & OCR Integration:**  
   - Convert the captured image to PNG using `NSBitmapImageRep`.
   - Create a POST request with `URLSession` and enforce a timeout.
   - Parse JSON response to extract formatted text.

5. **Clipboard & Notifications:**  
   - Use `NSPasteboard` to atomically update the clipboard.
   - Trigger success or error notifications using `UNUserNotificationCenter` and/or `NSAlert`.

6. **Resource Cleanup:**  
   - Implement a cleanup routine that stops SCStream, removes event monitors, and dismisses overlays.

### **7.3 Testing Strategy**
- **Unit Tests:**  
  - Test individual modules (hotkey, overlay, capture, OCR service, clipboard update).
- **Integration Tests:**  
  - Validate the full workflow from hotkey press through to clipboard update.
- **Stress Tests:**  
  - Rapid hotkey activations to ensure no resource leaks or UI hangs.
- **Error Simulation:**  
  - Simulate network failures, OCR timeouts, or capture cancellation to verify robust error handling.

---

## **8. Future Enhancements**

- **Customizable Hotkeys:**  
  - Allow users to reassign the default hotkey.
- **Multiple OCR Providers:**  
  - Add fallback or alternative OCR APIs.
- **Preference Pane:**  
  - Provide a settings window for API key management, timeout adjustments, and logging options.
- **Usage Analytics:**  
  - Integrate logging for usage metrics and error occurrences to guide future optimizations.

---

## **9. Summary**

ClipText v2 is engineered to deliver a seamless, reliable screen-to-text capture experience on macOS. By leveraging modern ScreenCaptureKit APIs and enforcing a strict sequential capture–process–deliver workflow, the app meets both user expectations and technical best practices. With robust error handling, immediate cancellation support, secure API management, and a modular architecture, this PRD provides a comprehensive blueprint for building ClipText v2 successfully.

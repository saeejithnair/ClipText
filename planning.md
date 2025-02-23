## 1. Analysis of Current Issues

1. **Unstable and Non-Sequential Flow**  
   - **Multiple Asynchronous Paths:**  
     The previous code contained numerous asynchronous blocks (multiple `Task {}`, `DispatchQueue.main.asyncAfter`, and asynchronous ScreenCaptureKit callbacks). This led to race conditions and inconsistent state management (especially around resource release and cancellation).  
   - **Complex State Transitions:**  
     The design had multiple overlapping states (overlay display, region selection, image capture, OCR processing, timeouts) that were not clearly delineated or executed in a strict sequence.

2. **Inadequate Error Handling and Resource Cleanup**  
   - **Hanging During Screen Capture:**  
     Rapidly invoking captures sometimes left the app stuck with an active ScreenCaptureKit (`SCStream`) that was neither fully stopped nor properly deallocated.  
   - **Forced Reboot on Errors:**  
     In the event of unhandled errors (e.g., image conversion or OCR issues), the app state became corrupted, necessitating a full reboot.  
   - **Cancellation Issues:**  
     The ESC key logic was split across multiple event monitors (overlay, selection view), making it unreliable in tearing down all streams, overlays, and event taps.

3. **UI/UX Inconsistencies**  
   - **Spinner/Loading Indicator Placement:**  
     The existing spinner was centered on the screen instead of positioned in the top-left corner as specified.  
   - **Overlay and Self-Capture Risks:**  
     The method of hiding the app’s own window and stacking a borderless overlay was error-prone, occasionally capturing ClipText UI elements if the sequence of hiding and capturing overlapped.

4. **Other Concerns**  
   - **Hardcoded API Key:**  
     Having an API key directly in the code was insecure and not easily changeable.  
   - **Multiple Timeouts, No OCR-Specific Timeout:**  
     Various timeouts existed for overlay display and transitions, but none dedicated solely to the OCR call.  
   - **Inconsistent Resource Cleanup:**  
     Event monitors, `SCStream` objects, and overlays were not always disposed of correctly, causing potential memory leaks and a “stuck” capture state if partial captures were interrupted.

---

## 2. High-Level Product Vision

**ClipText v2** is a **native macOS application** that captures a user-defined screen region (triggered by a global hotkey), performs OCR via a third-party (Gemini) OCR service, and places the extracted text on the system clipboard. This version emphasizes:

1. A strictly **sequential** capture → OCR → clipboard pipeline.  
2. A **single** asynchronous timeout (for the OCR API call), avoiding multiple competing timers.  
3. Reliable **cancellation** via the ESC key at any stage, cleaning up all resources.  
4. A **minimal UI** that avoids self-capture and provides a smooth user experience.

---

## 3. Objectives & User Stories

### 3.1 Objectives

1. **Simplify the Capture Flow**  
   - One hotkey press → hide ClipText UI → user selects region → capture one frame → OCR → copy text → done.

2. **Robust Error Handling**  
   - Any capture or OCR error immediately exits the process, frees resources, and notifies the user.

3. **Single API Timeout**  
   - Only the OCR API call has a dedicated timeout (e.g., 10 seconds).

4. **Seamless Cancellation**  
   - Pressing ESC at any point cancels and tears down all overlays, streams, or event monitors.

5. **Security & Maintainability**  
   - No hardcoded API keys (use secure storage or environment variables).  
   - Code structured into manageable components for easy troubleshooting and updates.

### 3.2 User Stories

- **As a user**, I can press **Ctrl+Shift+9** to initiate a screen capture and place the extracted text on my clipboard.  
- **As a user**, I see a **spinner in the top-left corner** while OCR processing is ongoing.  
- **As a user**, I can **cancel** at any time by pressing **ESC**, which cleans up all resources immediately.  
- **As a user**, if something goes wrong (e.g., network issue), I see an **alert or notification** and the process terminates.  
- **As a user**, I expect the text to appear in my clipboard on successful completion, without capturing the ClipText UI in the image.

---

## 4. Functional Requirements

### 4.1 Global Hotkey Registration

1. **Requirement:**  
   - The application registers a global hotkey (default: **Ctrl+Shift+9**) that initiates the capture sequence.
2. **Details:**  
   - On hotkey press, any visible ClipText UI is hidden, and a full-screen overlay is displayed.  
   - **Implementation Note**: While the Carbon `RegisterEventHotKey` API is not strictly “modern,” it remains one of the most reliable approaches for system-wide hotkey capture on macOS.

### 4.2 Single-Frame Screenshot & Overlay (ScreenCaptureKit)

1. **Requirement:**  
   - Display a **borderless, full-screen overlay** allowing the user to drag-select a region, then capture exactly one frame from that region using **ScreenCaptureKit**.
2. **Cancellation:**  
   - Pressing **ESC** closes the overlay, stops any ongoing screen streams, and returns the app to idle.
3. **UI Exclusion:**  
   - Hide the main ClipText window to avoid accidental self-capture.
4. **Implementation (macOS 15+):**  
   - **Overlay & Selection:**  
     - Create an `NSWindow` with style mask `.borderless` and window level `NSWindow.Level.screenSaver`.  
     - Implement a custom `NSView` (e.g., `SelectionView`) for mouse event handling (`mouseDown`, `mouseDragged`, `mouseUp`) and drawing the selection rectangle.  
   - **Screen Capture Using ScreenCaptureKit (`SCStream`)**  
     1. Use `SCShareableContent` to discover available displays or windows.  
     2. Configure an `SCStreamConfiguration` specifying the capture region (`sourceRect`) and output dimensions.  
     3. Start the `SCStream`, and implement the `SCStreamOutput` delegate to receive frames.  
     4. Once the **first frame** is received, stop the stream immediately.  
     5. Convert the captured frame (buffer) to an `NSImage` for later OCR processing.  
   - **Alternative (`SCScreenshotManager`)**  
     - For one-off captures, consider using `SCScreenshotManager.captureImage(contentFilter:configuration:completionHandler:)`.  
     - This approach can be simpler, but some developers report extra latency for repeated use.

### 4.3 Processing Indicator

1. **Requirement:**  
   - After the user releases the mouse and a capture request is initiated, display a **spinner** in the **top-left corner** to indicate processing.
2. **Implementation:**  
   - An `NSProgressIndicator` with `.spinning` style is added to the overlay `NSView`.  
   - It remains visible until OCR succeeds or fails (or until the user presses ESC).

### 4.4 Gemini OCR API Integration

1. **Requirement:**  
   - Convert the captured image to PNG, then POST it to the Gemini OCR endpoint with a single, dedicated **timeout** (e.g., 10 seconds).
2. **Implementation:**  
   - Use `NSBitmapImageRep` to convert the `NSImage` (from the `SCStream` frame) into PNG data.  
   - Construct a `URLSession` request with a 10-second timeout.  
   - Send the image as part of the POST request body, parse the JSON on success.
3. **Error Handling:**  
   - On failure (network error, invalid response, or timeout), display an alert and terminate the capture sequence (cleanup everything).

### 4.5 Clipboard Management

1. **Requirement:**  
   - If the OCR result is valid, copy the extracted text to the system clipboard.
2. **Implementation:**  
   - Use `NSPasteboard.general`.  
   - Clear existing content and write the new text in a single operation.

### 4.6 Error Handling & Resource Cleanup

1. **Requirement:**  
   - On **any error**, the app must:  
     1. Show a brief alert (`NSAlert`) or local notification.  
     2. Stop and release the `SCStream`, remove overlay windows, remove event monitors, and reset internal state.
2. **Cancellation (ESC)**  
   - At any stage (overlay selection, frame capture, OCR), pressing ESC triggers the same cleanup logic and displays a “capture canceled” notification (optional).

---

## 5. Non-Functional Requirements

1. **Performance & Responsiveness:**  
   - The capture → OCR → clipboard flow should feel near-instant, constrained mainly by the network/OCR call.  
   - Overhead from starting/stopping an `SCStream` should remain minimal given a one-shot frame capture.
2. **Security:**  
   - API keys are not hardcoded. They should be retrieved from Keychain, environment variables, or another secure method.  
   - macOS’s built-in permissions prompt for screen recording must be handled gracefully.
3. **Maintainability:**  
   - Code is segmented into modules (Hotkey Manager, Capture Manager, OCR Service, Clipboard Manager) to ensure clarity.  
   - Detailed error reporting or logging can aid troubleshooting.
4. **Resource Management:**  
   - All ephemeral resources (overlay windows, event monitors, `SCStream` instances) must be created on capture start and fully deallocated on completion or cancellation.
5. **Stability:**  
   - Repeated captures in quick succession (multiple hotkey presses) should not crash the app or leave residual streams or monitors.

---

## 6. System Architecture

### 6.1 Components

1. **Hotkey Manager**  
   - Manages global hotkey registration with `RegisterEventHotKey`.  
   - Triggers the capture flow on the main thread.

2. **Capture Manager**  
   - Presents the full-screen overlay via an `NSWindow` + custom `NSView`.  
   - Tracks the selection rectangle and receives ESC events through `NSEvent.addLocalMonitorForEvents(matching: .keyDown)`.  
   - Uses **ScreenCaptureKit** (`SCStream`) with a configured region to capture the selected area.

3. **Processing Indicator**  
   - An `NSProgressIndicator` that appears in the top-left corner once capture starts and remains until OCR completes or fails.

4. **OCR Service**  
   - Converts `NSImage` → PNG (`NSBitmapImageRep`) and sends it to the Gemini OCR endpoint using `URLSession`.  
   - Implements a single 10-second request timeout.

5. **Clipboard Manager**  
   - Replaces clipboard contents with the OCR result via `NSPasteboard.general`.

6. **Notification/Alert Manager**  
   - Handles success or error notifications using `NSAlert` or `UNUserNotificationCenter`.

7. **Resource Manager**  
   - Ensures overlays, streams, and event monitors are cleaned up in any exit scenario (success, error, or cancellation).

### 6.2 Data Flow Diagram

```mermaid
flowchart TD
    A[Hotkey Pressed (RegisterEventHotKey)] --> B[Hide Main UI & Show Overlay (NSWindow)]
    B --> C[User Selects Region (Custom NSView)]
    C --> D[User Releases Mouse => Region Defined]
    D --> E[Configure SCStream (sourceRect, dimensions)]
    E --> F[Start SCStream, Wait for First Frame]
    F --> G[Receive Frame (SCStreamOutput Callback)]
    G --> H[Stop SCStream, Convert Frame to NSImage -> PNG]
    H --> I[Send PNG to Gemini OCR API (URLSession) w/ Timeout]
    I --> J{Response OK?}
    J -- Yes --> K[Extract & Copy Text to Clipboard (NSPasteboard)]
    K --> L[Show Success Notification & Cleanup]
    J -- No/Timeout --> M[Show Error Alert & Cleanup]
    B -. ESC Pressed .-> N[Cancel Capture, Stop SCStream, Cleanup]
```

---

## 7. Implementation & Testing Plan

1. **Environment Setup**  
   - Use the latest Xcode and Swift for a Cocoa app targeting macOS 15+.  
   - Ensure the user has granted Screen Recording permissions if required by ScreenCaptureKit.

2. **Development Flow**  
   1. **Hotkey Manager**:  
      - Create a utility class to register **Ctrl+Shift+9** and call the capture logic on the main thread.  
   2. **Overlay & Selection**:  
      - Implement a borderless `NSWindow` with a custom `SelectionView` that handles mouse events and ESC.  
   3. **ScreenCaptureKit**:  
      - Set up an `SCStreamConfiguration` for capturing the selected rectangle.  
      - Use `SCShareableContent` to select the display or region.  
      - Implement `SCStreamOutput` delegate to receive frames, capturing the first frame only.  
   4. **OCR Service**:  
      - Convert the image buffer to `NSImage`, then to PNG data (`NSBitmapImageRep`).  
      - Perform a POST request with `URLSession` (single 10-second timeout).  
   5. **Clipboard & Notifications**:  
      - On success, copy the OCR text to `NSPasteboard`.  
      - Show an `NSAlert` or user notification for success or failure.  
   6. **Cleanup**:  
      - On completion, error, or cancellation, remove the overlay window, stop `SCStream`, remove event monitors, and restore the app to idle.

3. **Testing Approach**  
   - **Unit Tests**:  
     - Validate each manager/class (Hotkey Manager, Capture Manager, OCR Service) in isolation.  
   - **Integration Tests**:  
     - Run the entire flow end-to-end: from hotkey press to successful text capture.  
     - Induce errors (invalid OCR response, network issues) to confirm robust cleanup.  
   - **Stress Tests**:  
     - Press the hotkey repeatedly or rapidly to confirm no resource leaks or hangs.  
   - **Permission Tests**:  
     - Validate correct handling of Screen Recording permission prompts.

---

## 8. Future Enhancements

1. **User-Configurable Hotkeys**  
   - Allow users to change **Ctrl+Shift+9** to another combination within a preference pane.
2. **Multi-Provider OCR**  
   - Support multiple OCR endpoints or fallback logic if Gemini OCR is offline.
3. **Preferences / Settings**  
   - Customize timeouts, toggle UI spinner position, or adjust selection border color.
4. **Analytics & Logging**  
   - Optionally log usage metrics or store logs for diagnostic purposes.
5. **Localization**  
   - Add support for multiple languages for UI text and potential OCR output settings.

---

## 9. Summary

This **updated PRD** for **ClipText v2** incorporates Apple’s **ScreenCaptureKit** to capture the user’s selected region on macOS 15+ and addresses all previously identified issues:

- A single, **sequential** flow (hotkey → overlay → capture → OCR → clipboard).  
- **Robust error handling** with immediate resource cleanup on error or ESC cancellation.  
- **Modern APIs** (ScreenCaptureKit) replacing deprecated methods.  
- **Strict resource management** to avoid partial captures or locked streams.  
- **A minimal user interface** that places a spinner in the top-left corner and avoids capturing the ClipText app itself.

By following these requirements and implementation details, **ClipText v2** will provide a stable, secure, and user-friendly screen-to-text capture experience on modern macOS versions.
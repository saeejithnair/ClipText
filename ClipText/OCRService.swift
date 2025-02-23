import Foundation
import AppKit

// Define custom error types for OCR operations
enum OCRError: Error {
    case imageConversionFailed
    case apiRequestFailed
    case invalidResponse
}

// Service class to handle OCR operations using the Gemini API
final class OCRService {
    private let apiKey: String
    private let session: URLSession

    // Initialize with API key and custom URLSession configuration
    init(apiKey: String) {
        self.apiKey = apiKey
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30 // seconds
        self.session = URLSession(configuration: config)
    }

    // Perform OCR on the provided image asynchronously
    func performOCR(on image: NSImage) async throws -> String {
        // Convert NSImage to PNG data
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw OCRError.imageConversionFailed
        }

        // Encode PNG data to base64 string
        let base64Image = pngData.base64EncodedString()

        // Define the JSON payload for the Gemini API
        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": "Extract the text from this image and format it as Markdown if it contains any formatting. If it contains math equations, format them as LaTeX."
                        ],
                        [
                            "inline_data": [
                                "mime_type": "image/png",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ]
        ]

        // Serialize the payload to JSON data
        let jsonData = try JSONSerialization.data(withJSONObject: payload)

        // Set up the URL request to the Gemini API
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        // Send the request asynchronously
        let (data, response) = try await session.data(for: request)

        // Verify the HTTP response status
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OCRError.apiRequestFailed
        }

        // Parse the JSON response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let candidates = json?["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw OCRError.invalidResponse
        }

        return text
    }
}
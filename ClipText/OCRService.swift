import Foundation
import AppKit

protocol OCRServiceProtocol {
    func performOCR(on image: NSImage) async throws -> String
}

enum OCRError: LocalizedError {
    case imageConversionFailed
    case invalidResponse
    case networkError(Error)
    case apiError(String)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image for processing"
        case .invalidResponse:
            return "Invalid response from OCR service"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .timeout:
            return "OCR request timed out"
        }
    }
}

final class OCRService: OCRServiceProtocol {
    private let apiKey: String
    private let timeoutInterval: TimeInterval
    private let session: URLSession
    
    init(apiKey: String, timeoutInterval: TimeInterval = 10) {
        self.apiKey = apiKey
        self.timeoutInterval = timeoutInterval
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        config.timeoutIntervalForResource = timeoutInterval
        self.session = URLSession(configuration: config)
    }
    
    func performOCR(on image: NSImage) async throws -> String {
        guard let imageData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: imageData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw OCRError.imageConversionFailed
        }
        
        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent")!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": "Extract text from this image and format it as markdown if it contains any formatting. If it contains math equations, format them as LaTeX."
                        ],
                        [
                            "inline_data": [
                                "mime_type": "image/png",
                                "data": pngData.base64EncodedString()
                            ]
                        ]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OCRError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw OCRError.apiError(errorMessage)
            }
            
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
            
        } catch let error as URLError where error.code == .timedOut {
            throw OCRError.timeout
        } catch let error as OCRError {
            throw error
        } catch {
            throw OCRError.networkError(error)
        }
    }
} 
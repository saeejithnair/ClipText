import Cocoa

enum OCRError: Error {
    case imageConversionFailed
    case invalidResponse
    case networkError(Error)
    case apiError(String)
}

class OCRService {
    private let apiURL: URL
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
        // Construct URL with API key
        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent")!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        self.apiURL = components.url!
    }
    
    func performOCR(on image: NSImage, completion: @escaping (Result<String, OCRError>) -> Void) {
        print("Starting OCR process...")
        guard let imageData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: imageData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Failed to convert image to PNG")
            completion(.failure(.imageConversionFailed))
            return
        }
        print("Successfully converted image to PNG, size: \(pngData.count) bytes")
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        print("Set up request with URL: \(apiURL)")
        
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
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            print("Successfully serialized payload")
        } catch {
            print("Failed to serialize payload: \(error)")
            completion(.failure(.networkError(error)))
            return
        }
        
        print("Starting network request...")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error occurred: \(error)")
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type - not an HTTP response")
                completion(.failure(.invalidResponse))
                return
            }
            
            print("Received response with status code: \(httpResponse.statusCode)")
            if let data = data, let responseStr = String(data: data, encoding: .utf8) {
                print("Response body: \(responseStr)")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown error"
                print("Error response from server: \(errorMessage)")
                completion(.failure(.apiError(errorMessage)))
                return
            }
            
            guard let data = data else {
                print("No data received in response")
                completion(.failure(.invalidResponse))
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                print("Parsed JSON response: \(String(describing: json))")
                
                guard let candidates = json?["candidates"] as? [[String: Any]],
                      let firstCandidate = candidates.first,
                      let content = firstCandidate["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]],
                      let firstPart = parts.first,
                      let text = firstPart["text"] as? String else {
                    print("Failed to parse expected JSON structure")
                    completion(.failure(.invalidResponse))
                    return
                }
                
                print("Successfully extracted text: \(text)")
                completion(.success(text))
            } catch {
                print("JSON parsing error: \(error)")
                completion(.failure(.invalidResponse))
            }
        }.resume()
        print("Network request started")
    }
} 
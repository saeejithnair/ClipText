import Foundation
import AppKit

class APIService {
    static let shared = APIService()
    private let baseURL = "https://my-first-worker.saeejithn.workers.dev/"
    
    func sendPrompt(prompt: String, token: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: baseURL) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 400, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = ["prompt": prompt]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
                print("HTTP Headers: \(httpResponse.allHeaderFields)")
            }
            
            guard let data = data else {
                print("No data received from server")
                completion(.failure(NSError(domain: "No data received", code: 500, userInfo: nil)))
                return
            }
            
            print("Received \(data.count) bytes from server")
            
            // Print raw response for debugging
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("Raw response: \(responseString)")
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let firstCandidate = candidates.first,
                   let content = firstCandidate["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let firstPart = parts.first,
                   let text = firstPart["text"] as? String {
                    print("Successfully extracted text response")
                    completion(.success(text))
                } else {
                    print("Failed to extract text from candidates")
                    let responseString = String(data: data, encoding: .utf8) ?? "Unknown response format"
                    completion(.failure(NSError(domain: "Invalid response format", code: 500, userInfo: ["responseData": responseString])))
                }
            } catch {
                print("JSON parsing error: \(error)")
                completion(.failure(NSError(domain: "JSON parsing error: \(error.localizedDescription)", code: 500, userInfo: ["responseData": responseString])))
            }
        }.resume()
    }
    
    func sendPromptWithImage(prompt: String, image: NSImage, token: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: baseURL) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 400, userInfo: nil)))
            return
        }
        
        // Convert NSImage to Data
        guard let imageData = convertImageToData(image) else {
            completion(.failure(NSError(domain: "Failed to convert image", code: 400, userInfo: nil)))
            return
        }
        
        print("Image size: \(imageData.count) bytes")
        
        // Let's try using JSON with base64 again since we have a clear error from multipart
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Convert image to base64
        let base64Image = imageData.base64EncodedString()
        print("Base64 image length: \(base64Image.count) characters")
        
        // Creating the JSON payload exactly as the Cloudflare worker expects
        let body: [String: Any] = [
            "prompt": prompt,
            "images": [
                [
                    "data": base64Image,
                    "mime_type": "image/jpeg"
                ]
            ]
        ]

        
        print("JSON payload structure: \(body.keys)")
        // Print sample of the JSON structure for debugging
        if let jsonData = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted) {
            let jsonStr = String(data: jsonData, encoding: .utf8) ?? ""
            // Just print start of the JSON to avoid flooding the console
            let startOfJson = jsonStr.prefix(500).replacingOccurrences(of: "\"data\" : \"[^\"]+(.*)", with: "\"data\" : \"BASE64_DATA...\"", options: .regularExpression)
            print("JSON structure (truncated):\n\(startOfJson)...")
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            print("JSON data created: \(request.httpBody?.count ?? 0) bytes")
        } catch {
            print("Error creating JSON: \(error)")
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
                print("HTTP Headers: \(httpResponse.allHeaderFields)")
            }
            
            guard let data = data else {
                print("No data received from server")
                completion(.failure(NSError(domain: "No data received", code: 500, userInfo: nil)))
                return
            }
            
            print("Received \(data.count) bytes from server")
            
            // Print raw response for debugging
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("Raw response: \(responseString)")
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Successfully parsed JSON: \(json.keys)")
                    
                    // Check if there's an error message from the server
                    if let errorMessage = json["error"] as? String {
                        print("Server returned error: \(errorMessage)")
                        completion(.failure(NSError(domain: errorMessage, code: 400, userInfo: nil)))
                        return
                    }
                    
                    if let candidates = json["candidates"] as? [[String: Any]] {
                        print("Found \(candidates.count) candidates")
                        if let firstCandidate = candidates.first,
                           let content = firstCandidate["content"] as? [String: Any],
                           let parts = content["parts"] as? [[String: Any]],
                           let firstPart = parts.first,
                           let text = firstPart["text"] as? String {
                            print("Successfully extracted text response")
                            completion(.success(text))
                        } else {
                            print("Failed to extract text from candidates")
                            completion(.failure(NSError(domain: "Invalid response format", code: 500, userInfo: ["responseData": responseString])))
                        }
                    } else {
                        print("No candidates found in response")
                        completion(.failure(NSError(domain: "Invalid response format", code: 500, userInfo: ["responseData": responseString])))
                    }
                } else {
                    print("Failed to parse response as JSON")
                    completion(.failure(NSError(domain: "Failed to parse JSON", code: 500, userInfo: ["responseData": responseString])))
                }
            } catch {
                print("JSON parsing error: \(error)")
                completion(.failure(NSError(domain: "JSON parsing error: \(error.localizedDescription)", code: 500, userInfo: ["responseData": responseString])))
            }
        }.resume()
    }
    
    private func convertImageToData(_ image: NSImage) -> Data? {
        print("Converting NSImage to Data")
        print("Image size: \(image.size)")
        print("Image representations: \(image.representations.count)")
        
        for (index, rep) in image.representations.enumerated() {
            print("Representation \(index): \(type(of: rep)), size: \(rep.size), bitsPerSample: \(rep.bitsPerSample)")
        }
        
        // Resize image if it's too large
        let maxDimension: CGFloat = 800 // Reduced from 1024 to make the image smaller
        let originalSize = image.size
        var newSize = originalSize
        
        if originalSize.width > maxDimension || originalSize.height > maxDimension {
            if originalSize.width > originalSize.height {
                newSize = CGSize(width: maxDimension, height: originalSize.height * (maxDimension / originalSize.width))
            } else {
                newSize = CGSize(width: originalSize.width * (maxDimension / originalSize.height), height: maxDimension)
            }
            print("Resizing image from \(originalSize) to \(newSize)")
        }
        
        // Create a new NSImage with the desired size
        let resizedImage = NSImage(size: newSize)
        
        resizedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize), from: NSRect(origin: .zero, size: originalSize), operation: .copy, fraction: 1.0)
        resizedImage.unlockFocus()
        
        // Convert to bitmap representation
        guard let tiffData = resizedImage.tiffRepresentation else {
            print("Failed to get TIFF representation")
            return nil
        }
        
        guard let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            print("Failed to create bitmap representation from TIFF data")
            return nil
        }
        
        print("NSBitmapImageRep created: size=\(bitmapRep.size), pixelsWide=\(bitmapRep.pixelsWide), pixelsHigh=\(bitmapRep.pixelsHigh)")
        
        // Try with higher compression to reduce size
        let compressionFactor: CGFloat = 0.5 // Higher compression (reduced from 0.6)
        print("Using compression factor: \(compressionFactor)")
        
        let data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionFactor])
        
        if let data = data {
            print("JPEG data created: \(data.count) bytes")
            
            // Verify JPEG header
            if data.count > 2 {
                let header = data.prefix(2)
                let isJpeg = header[0] == 0xFF && header[1] == 0xD8
                print("Data has valid JPEG header: \(isJpeg)")
            }
            
            // Check if the data is too large
            let maxSize = 5 * 1024 * 1024 // 5MB limit (reduced from 10MB)
            if data.count > maxSize {
                print("Warning: Image data is very large (\(data.count) bytes). This may cause issues with the API.")
                
                // If the image is still too large, try to compress it further
                if data.count > maxSize {
                    print("Image is still too large, trying to compress further")
                    let furtherCompressedData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.3])
                    if let furtherCompressedData = furtherCompressedData {
                        print("Further compressed JPEG data: \(furtherCompressedData.count) bytes")
                        return furtherCompressedData
                    }
                }
            }
            
            return data
        } else {
            print("Failed to create JPEG data")
            return nil
        }
    }
}

// Extension to make it easier to append data
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
} 
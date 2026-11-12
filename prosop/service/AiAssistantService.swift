//
//  AIAssistantService.swift
//  prosop
//

import Foundation
import UIKit
import AVFoundation

// MARK: - AI Response Models
struct AIActionResponse: Codable, Sendable {
    var action: String
    var category_id: String?
    var category_name: String?
    var color_hex: String?
    var items: [AIItem]?
    var spoken_response: String
}

struct AIItem: Codable, Sendable {
    var id: String?
    var name: String?
    var quantity: Int?
    var price: Double?
    var details: String?
    var is_checked: Bool?
    var barcode: String?
    var category_id: String?
}

// MARK: - AI Service
class AIAssistantService {
    static let shared = AIAssistantService()
    
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "openAISecretKey") ?? ""
    }
    
    // Player to handle the MP3 data from OpenAI
    private var audioPlayer: AVAudioPlayer?
    
    // MARK: - 1. Process Text / Photo (GPT-4o-mini)
    func processRequest(prompt: String, image: UIImage?, completion: @escaping (Result<AIActionResponse, Error>) -> Void) {
        
        let apiKey = UserDefaults.standard.string(forKey: "openAISecretKey") ?? ""
        guard !apiKey.isEmpty else {
                return
        }
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var messageContent: [[String: Any]] = [
            ["type": "text", "text": prompt]
        ]
        
        if let image = image, let base64Image = image.jpegData(compressionQuality: 0.5)?.base64EncodedString() {
            messageContent.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]
            ])
        }
        
        let systemPrompt = """
                You are an intelligent inventory management assistant. Process user requests and return a strict JSON payload. DO NOT output conversational text outside of the JSON.
                
                Expected JSON schema:
                {
                  "action": "ADD_CATEGORY" | "ADD_ITEMS" | "DELETE_CATEGORY" | "DELETE_ITEMS" | "UPDATE_CATEGORY" | "UPDATE_ITEMS" | "READ_ITEMS" | "UNKNOWN",
                  "category_id": "UUID of the category",
                  "category_name": "Name of the target category",
                  "color_hex": "A 6-character hex color code",
                  "items": [{"name": "Item name", "quantity": 1, "price": 0.0, "details": "Short description", "barcode": "12345", "is_checked": false, "category_id": "UUID to move"}],
                  "spoken_response": "A natural, conversational response."
                }
                
                Rules for Actions:
                1. ADD_CATEGORY: Provide `category_name`, optional `color_hex`, and optional `items` array to populate it immediately.
                2. ADD_ITEMS: Provide `category_id` (of an existing category) AND the `items` array.
                3. DELETE_CATEGORY: Provide `category_id`.
                4. DELETE_ITEMS: Provide the `items` array. For each item you want to delete, you MUST provide its `id`.
                5. UPDATE_CATEGORY: Provide `category_id`. Use `category_name` to rename it, or `color_hex` to change its color.
                6. UPDATE_ITEMS: Provide the `items` array. For each item you want to modify, you MUST provide its `id` along with the fields to change. Use `name` to rename, `quantity` to adjust current stock, `category_id` to move it to a different category, `details` for details, `barcode` for barcode id or `is_checked` to mark/unmark it.
                7. READ_ITEMS: Use this to answer questions about what is in the inventory (e.g., "What is in the garage?", "Do I have milk?"). You MUST answer the question directly in the `spoken_response` by listing the items and their quantities.
                8. CRITICAL TENSE RULE: For all modifying actions, phrase the `spoken_response` as an intention in the FUTURE tense (e.g., "I will rename the category.", "I am ready to add the apples."). NEVER use past tense because the user must confirm the action first!
                9. CURRENCY RULE: Whenever you mention a price in the `spoken_response`, format it using the LOCAL CURRENCY provided at the end of the user's prompt.
            """
                
        
        let parameters: [String: Any] = [
            "model": "gpt-4o-mini",
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": messageContent]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        Task { @MainActor in completion(.failure(error)) }
                        return
                    }
                    guard let data = data else { return }
                    
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let message = choices.first?["message"] as? [String: Any],
                           let content = message["content"] as? String {
                            
                            let contentData = Data(content.utf8)
                            
                            // Swift 6 Fix: Use Task { @MainActor in } instead of DispatchQueue
                            Task { @MainActor in
                                do {
                                    let decoder = JSONDecoder()
                                    let aiResponse = try decoder.decode(AIActionResponse.self, from: contentData)
                                    completion(.success(aiResponse))
                                } catch {
                                    completion(.failure(error))
                                }
                            }
                        }
                    } catch {
                        Task { @MainActor in completion(.failure(error)) }
                    }
                }.resume()
    }
    
    // MARK: - 2. Transcribe Audio (Whisper-1)
    func transcribeAudio(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        let boundaryPrefix = "--\(boundary)\r\n"
        
        body.append(Data(boundaryPrefix.utf8))
        body.append(Data("Content-Disposition: form-data; name=\"model\"\r\n\r\n".utf8))
        body.append(Data("whisper-1\r\n".utf8))
        
        if let audioData = try? Data(contentsOf: fileURL) {
            body.append(Data(boundaryPrefix.utf8))
            body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".utf8))
            body.append(Data("Content-Type: audio/m4a\r\n\r\n".utf8))
            body.append(audioData)
            body.append(Data("\r\n".utf8))
        }
        
        body.append(Data("--\(boundary)--\r\n".utf8))
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let text = json["text"] as? String {
                    DispatchQueue.main.async { completion(.success(text)) }
                } else {
                    let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Whisper response."])
                    DispatchQueue.main.async { completion(.failure(error)) }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
    
    // MARK: - 3. Speak with OpenAI TTS
    func speak(_ text: String) {
        // Ensure AVAudioSession is set to playback so it routes to the main speaker properly
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        let url = URL(string: "https://api.openai.com/v1/audio/speech")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // You can change "alloy" to "echo", "fable", "onyx", "nova", or "shimmer"
        let parameters: [String: Any] = [
            "model": "tts-1",
            "voice": "alloy",
            "input": text
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                print("OpenAI TTS Error: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            // Play the audio data on the main thread
            DispatchQueue.main.async {
                do {
                    self.audioPlayer = try AVAudioPlayer(data: data)
                    self.audioPlayer?.prepareToPlay()
                    self.audioPlayer?.play()
                } catch {
                    print("AVAudioPlayer Error: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    // MARK: - 4. Validate API Key
        func validateAPIKey(_ key: String, completion: @escaping (Bool) -> Void) {
            guard let url = URL(string: "https://api.openai.com/v1/models") else {
                completion(false)
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    completion(true)
                } else {
                    completion(false)
                }
            }.resume()
        }
}

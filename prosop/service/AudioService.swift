import Foundation
import AVFoundation
import UIKit
import SwiftUI
import Combine

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    
    @Published var isRecording = false
    @Published var recordingURL: URL?
    private var audioRecorder: AVAudioRecorder?

    func requestPermission(completion: @escaping (Bool) -> Void) {
        // Changed to AVAudioSession to support iOS versions prior to 17.0
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)

            let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentPath.appendingPathComponent("ai_command.m4a")
            recordingURL = audioFilename

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            isRecording = true
            
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
        } catch {
            print("Failed to set up recording: \(error.localizedDescription)")
            stopRecording()
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        audioRecorder = nil
        
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }
}

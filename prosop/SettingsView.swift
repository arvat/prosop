//
//  SettingsView.swift
//  Prosop
//
//  Created by Arvat Vladimir on 26.02.2026.
//
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // MARK: - AppStorage
    @AppStorage("hasAcceptedAITerms") private var hasAcceptedAITerms = false
    @AppStorage("openAISecretKey") private var openAISecretKey = ""
    @AppStorage("isVoiceAnswerEnabled") private var isVoiceAnswerEnabled = true
    @AppStorage("aiPreferredLanguage") private var aiPreferredLanguage = "English"
    @AppStorage("showAIButtons") private var showAIButtons = true

    enum TokenStatus { case idle, valid, invalid }
    @State private var tokenValidationStatus: TokenStatus = .idle
    @State private var isVerifyingToken = false
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    let languageOptions = ["English", "Romanian", "Russian", "Ukrainian", "French", "German", "Spanish", "Italian"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("AI Configuration")) {

                    Toggle("Show AI Buttons on Home", isOn: $showAIButtons)
                        .tint(.blue)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            SecureField("OpenAI API Key", text: $openAISecretKey)
                                .onChange(of: openAISecretKey) { newValue in
                                    if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        verifyKey()
                                    } else {
                                        tokenValidationStatus = .idle
                                    }
                                }

                            if isVerifyingToken {
                                ProgressView().controlSize(.small)
                            } else if tokenValidationStatus == .valid {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            } else if tokenValidationStatus == .invalid {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                            }
                        }

                        Link("Get an API key from platform.openai.com", destination: URL(string: "https://platform.openai.com/api-keys")!)
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    .onAppear {
                        if !openAISecretKey.isEmpty {
                            verifyKey()
                        }
                    }

                    Toggle("Voice Answers", isOn: $isVoiceAnswerEnabled)
                        .tint(.blue)

                    Picker("Preferred Language", selection: $aiPreferredLanguage) {
                        ForEach(languageOptions, id: \.self) { language in
                            Text(language).tag(language)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Allows the app to send audio and photos to OpenAI for processing. Your data is not used to train AI models.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // MARK: - About & Support
                Section(header: Text("About & Support")) {
                    Button(action: {
                        ReviewManager.shared.requestReviewManually()
                    }) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("Rate on App Store")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Link("Privacy Policy", destination: URL(string: "https://arvat.org/apps/prosop/privacy.html")!)
                    Link("Contact Support", destination: URL(string: "https://arvat.org/apps/prosop/support.html")!)
                }
                
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("Inventory Manager")
                                .fontWeight(.semibold)
                            Text("Version \(appVersion) (\(buildNumber))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .fontWeight(.semibold)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func verifyKey() {
        let trimmedKey = openAISecretKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }
        
        isVerifyingToken = true
        AIAssistantService.shared.validateAPIKey(trimmedKey) { isValid in
            DispatchQueue.main.async {
                self.isVerifyingToken = false
                self.tokenValidationStatus = isValid ? .valid : .invalid
            }
        }
    }
}

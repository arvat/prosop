//
//  CategoryListView.swift
//  prosop
//
//  Created by Arvat Vladimir on 13.02.2026.
//

import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import AVFoundation
import Combine

// MARK: - Main Category View
struct CategoryListView: View {
    @AppStorage("hasAcceptedAITerms") private var hasAcceptedAITerms = false
    @AppStorage("isVoiceAnswerEnabled") private var isVoiceAnswerEnabled = true
    @AppStorage("aiPreferredLanguage") private var aiPreferredLanguage = "English"
    @AppStorage("showAIButtons") private var showAIButtons = true

    @StateObject private var networkMonitor = NetworkMonitor.shared

    @State private var showingAITerms = false
    @State private var showingSettings = false
    @State private var categories: [InventoryCategory] = []
    @State private var refreshTrigger = UUID()
    @State private var showingAddSheet = false
    @State private var categoryToEdit: InventoryCategory?
    @State private var searchText = ""
    @State private var showingScanner = false
    
    // MARK: AI States
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var isProcessingAI = false
    @State private var isTranscribing = false
    @State private var showingAICamera = false
    @State private var aiPhotoData: Data? = nil
    @State private var recordingTask: Task<Void, Never>?
    @State private var pendingAIResponse: AIActionResponse? = nil
    
    // Track which action the user wanted after accepting terms
    enum AIIntent { case voice, camera, none }
    @State private var pendingIntent: AIIntent = .none
    
    // Token validation
    @State private var showInvalidTokenAlert = false
    @State private var invalidTokenMessage = ""
    
    // Network validation
    @State private var showNetworkAlert = false
    @State private var networkAlertMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                List {
                if searchText.isEmpty {
                    ForEach(categories) { category in
                        NavigationLink(destination: ItemListView(category: category)) {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(Color(hex: category.colorHex))
                                    .font(.title2)
                                Text(category.title)
                                    .font(.headline)
                                
                                Spacer()
                                
                                let items = SQLiteManager.shared.fetchItems(for: category.id)
                                let activeQty = items.filter { !$0.isChecked }.reduce(0) { $0 + $1.quantity }
                                
                                Text("\(activeQty)")
                                    .font(.subheadline)
                                    .foregroundStyle(activeQty > 0 ? .green : .secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(activeQty > 0 ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            .padding(.vertical, 8)
                        }
                        .swipeActions(edge: .leading) {
                            Button("Edit") { categoryToEdit = category }.tint(.blue)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) { deleteCategory(category) }
                        }
                    }
                    .onMove(perform: moveCategory)
                    .id(refreshTrigger)
                } else {
                    GlobalSearchResults(searchText: searchText)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 16) {
                    
                    // MARK: - AI Response Confirmation Card
                    if let aiResponse = pendingAIResponse {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.blue)
                                Text("AI Assistant")
                                    .font(.headline)
                                Spacer()
                            }
                            
                            // Show the text that will be read aloud
                            Text(aiResponse.spoken_response)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                            
                            // Action Buttons based on destructiveness
                            if requiresConfirmation(action: aiResponse.action) {
                                HStack(spacing: 16) {
                                    Button(role: .cancel, action: {
                                        withAnimation { pendingAIResponse = nil }
                                    }) {
                                        Text("Cancel")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button(action: {
                                        executeAIAction(aiResponse)
                                        withAnimation { pendingAIResponse = nil }
                                    }) {
                                        Text("Execute")
                                            .bold()
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.blue)
                                }
                                .padding(.top, 8)
                            } else {
                                Button(action: {
                                    withAnimation { pendingAIResponse = nil }
                                }) {
                                    Text("Dismiss")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .padding(.top, 8)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius))
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
                        .padding(.horizontal, UIConstants.cardPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // MARK: - Floating Action Bar (Mic & Camera)
                    if showAIButtons || isProcessingAI || isTranscribing {
                    HStack(spacing: UIConstants.actionButtonSpacing) {
                            if isProcessingAI || isTranscribing {
                                ProgressView(isTranscribing ? "Listening..." : "Thinking...")
                                    .tint(.blue)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 4)
                                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            } else {
                                // Voice Command (Hold to Talk)
                                Button(action: {}) {
                                    VStack(spacing: 4) {
                                        ZStack(alignment: .topTrailing) {
                                            Image(systemName: audioRecorder.isRecording ? "mic.fill" : "mic.circle.fill")
                                                .font(.title)

                                            if !networkMonitor.isConnected {
                                                Image(systemName: "wifi.slash")
                                                    .font(.caption2)
                                                    .foregroundStyle(.red)
                                                    .offset(UIConstants.overlayIconOffset)
                                            }
                                        }
                                        Text(audioRecorder.isRecording ? "Recording..." : "Hold to Talk")
                                            .font(.caption)
                                    }
                                    .foregroundStyle(audioRecorder.isRecording ? .red : (networkMonitor.isConnected ? .blue : .gray))
                                    .opacity(networkMonitor.isConnected || audioRecorder.isRecording ? 1.0 : UIConstants.disabledOpacity)
                                }
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { _ in
                                            // 1. CHECK TERMS
                                            guard hasAcceptedAITerms else {
                                                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                                                pendingIntent = .voice
                                                showingAITerms = true
                                                return
                                            }
                                            
                                            // 2. CHECK TOKEN
                                            let apiKey = UserDefaults.standard.string(forKey: StorageKeys.openAISecretKey) ?? ""
                                            guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                                                UINotificationFeedbackGenerator().notificationOccurred(.error)
                                                invalidTokenMessage = ErrorMessages.missingAPIKey
                                                showInvalidTokenAlert = true
                                                return
                                            }

                                            // 3. CHECK NETWORK
                                            guard networkMonitor.isConnected else {
                                                UINotificationFeedbackGenerator().notificationOccurred(.error)
                                                networkAlertMessage = networkMonitor.networkIssueDescription
                                                showNetworkAlert = true
                                                return
                                            }

                                            // 4. EXECUTE
                                            if !audioRecorder.isRecording {
                                                audioRecorder.requestPermission { granted in
                                                    if granted {
                                                        // Haptic feedback on recording start
                                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                        audioRecorder.startRecording()
                                                        // ... existing recording task code ...
                                                    }
                                                }
                                            }
                                        }
                                        .onEnded { _ in
                                            recordingTask?.cancel()
                                            if audioRecorder.isRecording {
                                                // Haptic feedback on recording end
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                audioRecorder.stopRecording()
                                                if let fileURL = audioRecorder.recordingURL {
                                                    processVoiceCommand(fileURL: fileURL)
                                                }
                                            }
                                        }
                                )
                                
                                // Photo Command
                                Button(action: {
                                    // 1. CHECK TERMS
                                    guard hasAcceptedAITerms else {
                                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                                        pendingIntent = .camera
                                        showingAITerms = true
                                        return
                                    }
                                    
                                    // 2. CHECK TOKEN
                                    let apiKey = UserDefaults.standard.string(forKey: StorageKeys.openAISecretKey) ?? ""
                                    guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                                        invalidTokenMessage = ErrorMessages.missingAPIKey
                                        showInvalidTokenAlert = true
                                        return
                                    }

                                    // 3. CHECK NETWORK
                                    guard networkMonitor.isConnected else {
                                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                                        networkAlertMessage = networkMonitor.networkIssueDescription
                                        showNetworkAlert = true
                                        return
                                    }

                                    // 4. EXECUTE
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    showingAICamera = true
                                }) {
                                    VStack(spacing: 4) {
                                        ZStack(alignment: .topTrailing) {
                                            Image(systemName: "camera.viewfinder")
                                                .font(.title)

                                            if !networkMonitor.isConnected {
                                                Image(systemName: "wifi.slash")
                                                    .font(.caption2)
                                                    .foregroundStyle(.red)
                                                    .offset(UIConstants.overlayIconOffset)
                                            }
                                        }
                                        Text("Scan Items").font(.caption)
                                    }
                                    .foregroundStyle(networkMonitor.isConnected ? .blue : .gray)
                                    .opacity(networkMonitor.isConnected ? 1.0 : UIConstants.disabledOpacity)
                                }
                            }
                        }
                    .padding(.vertical, 12)
                    .padding(.horizontal, UIConstants.buttonPadding)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
                    .padding(.bottom, UIConstants.standardSpacing)
                    }

                } // End of outer VStack
                .sheet(isPresented: $showingAITerms, onDismiss: {
                    if hasAcceptedAITerms {
                        // NEW: Check if token is empty right after accepting terms
                        let currentKey = UserDefaults.standard.string(forKey: StorageKeys.openAISecretKey) ?? ""
                        if currentKey.isEmpty {
                            // Redirect to Settings so they can enter the key
                            showingSettings = true
                        } else {
                            // Proceed with their intended action (camera or voice)
                            handlePostTermsAction()
                        }
                    } else {
                        // User cancelled the terms, clear intent
                        pendingIntent = .none
                    }
                }) {
                    AITermsView(hasAccepted: $hasAcceptedAITerms)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            
            // Network Status Banner
            if !networkMonitor.isConnected && showAIButtons {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .font(.caption)
                        Text("No Internet Connection")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                        Text("AI features unavailable")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.red.opacity(0.1))
                    .foregroundStyle(.red)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: networkMonitor.isConnected)
        .navigationTitle("Prosop")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search name, details, barcode...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 16) {
                        Button(action: { showingSettings = true }) { Image(systemName: "gearshape") }
                        Button(action: { showingScanner = true }) { Image(systemName: "qrcode.viewfinder") }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddSheet = true }) { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(isPresented: $showingScanner) { BarcodeScannerSheet(scannedCode: $searchText) }
            .sheet(isPresented: $showingAddSheet) {
                let nextSeq = (categories.first?.sequence ?? 0) - 1
                CategoryFormView(categoryToEdit: nil, nextSequence: nextSeq, onSave: loadData)
            }
            .sheet(item: $categoryToEdit) { category in CategoryFormView(categoryToEdit: category, nextSequence: 0, onSave: loadData) }
            .sheet(isPresented: $showingAICamera) { CameraPicker(selectedData: $aiPhotoData) }
            .onChange(of: aiPhotoData) { newData in
                if let data = newData, let image = UIImage(data: data) {
                    handleAIRequest(prompt: AIConfiguration.defaultAnalysisPrompt, image: image)
                }
            }
            .onAppear {
                loadData()

                // Check if we should request a review
                // Delay to avoid showing on very first launch
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    ReviewManager.shared.checkAndRequestReview()
                }
            }
            .alert("API Key Required", isPresented: $showInvalidTokenAlert) {
                Button("Go to Settings", role: .none) {
                    showingSettings = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(invalidTokenMessage)
            }
            .alert("No Internet Connection", isPresented: $showNetworkAlert) {
                Button("Retry") {
                    // User can retry - we'll just dismiss and they can try again
                    // The network monitor will automatically update if connection is restored
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text(networkAlertMessage)
            }
            .overlay {
                if categories.isEmpty && searchText.isEmpty {
                    CompatContentUnavailableView(
                        title: "No Categories",
                        systemImage: "tray",
                        description: Text("Tap + to create a category")
                    )
                }
            }
        }
    }
    
    // MARK: - Logic Methods
    private func loadData() {
        categories = SQLiteManager.shared.fetchCategories()
        refreshTrigger = UUID()
    }
    
    private func moveCategory(from source: IndexSet, to destination: Int) {
        var updatedCategories = categories
        updatedCategories.move(fromOffsets: source, toOffset: destination)
        for (index, var category) in updatedCategories.enumerated() {
            category.sequence = index
            SQLiteManager.shared.saveCategory(category)
        }
        loadData()
    }
    
    private func deleteCategory(_ category: InventoryCategory) {
        withAnimation {
            SQLiteManager.shared.deleteCategory(category.id)
            loadData()
        }
    }
    
    private func handlePostTermsAction() {
        switch pendingIntent {
        case .camera:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingAICamera = true
                pendingIntent = .none
            }
        case .voice:
            pendingIntent = .none
        case .none:
            break
        }
    }
    
    // MARK: - AI Execution Methods
    private func processVoiceCommand(fileURL: URL) {
        // Validate API key before processing
        let apiKey = UserDefaults.standard.string(forKey: StorageKeys.openAISecretKey) ?? ""
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            invalidTokenMessage = ErrorMessages.missingAPIKey
            showInvalidTokenAlert = true
            return
        }
        
        // Validate network connection
        guard networkMonitor.isConnected else {
            networkAlertMessage = networkMonitor.networkIssueDescription
            showNetworkAlert = true
            return
        }
        
        isTranscribing = true
        AIAssistantService.shared.transcribeAudio(fileURL: fileURL) { result in
            isTranscribing = false
            switch result {
            case .success(let transcript):
                handleAIRequest(prompt: transcript, image: nil)
            case .failure(let error):
                // Show error alert if API key is invalid or other errors occur
                // Check if it's a network error
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain {
                    self.networkAlertMessage = "Network error during transcription. Please check your connection and try again.\n\nError: \(error.localizedDescription)"
                    self.showNetworkAlert = true
                } else {
                    self.invalidTokenMessage = "Voice transcription failed. Please check your API key in Settings.\n\nError: \(error.localizedDescription)"
                    self.showInvalidTokenAlert = true
                }
                print("Transcription failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func requiresConfirmation(action: String) -> Bool {
        return AIConfiguration.confirmableActions.contains(action)
    }
    
    private func handleAIRequest(prompt: String, image: UIImage?) {
        // Validate API key before processing
        let apiKey = UserDefaults.standard.string(forKey: StorageKeys.openAISecretKey) ?? ""
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.invalidTokenMessage = ErrorMessages.missingAPIKey
            self.showInvalidTokenAlert = true
            return
        }
        
        // Validate network connection
        guard networkMonitor.isConnected else {
            self.networkAlertMessage = self.networkMonitor.networkIssueDescription
            self.showNetworkAlert = true
            return
        }
        
        isProcessingAI = true
            
            // 1. Fetch the entire inventory database
            let allCats = SQLiteManager.shared.fetchCategories()
            var inventoryContext: [[String: Any]] = []
            
            for cat in allCats {
                let items = SQLiteManager.shared.fetchItems(for: cat.id)
                
                // 2. Map items, strictly excluding photoData
                let itemsData = items.map { item -> [String: Any] in
                    return [
                        "id": item.id.uuidString,
                        "name": item.name,
                        "quantity": item.quantity,
                        "price": item.price,
                        "details": item.details,
                        "is_checked": item.isChecked
                    ]
                }
                
                inventoryContext.append([
                    "category_id": cat.id.uuidString,
                    "category_name": cat.title,
                    "items": itemsData
                ])
            }
            
            // 3. Convert the inventory array into a JSON String
            var inventoryJSONString = "[]"
            if let jsonData = try? JSONSerialization.data(withJSONObject: inventoryContext),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                inventoryJSONString = jsonStr
            }
            
            let currencyCode = Locale.current.currency?.identifier ?? "USD"
            
            // 4. Combine the user's spoken/typed prompt with the JSON context
            let finalPrompt = """
            User Request: \(prompt)
            
            ---
            CURRENT INVENTORY DATA (JSON):
            \(inventoryJSONString)
            ---
            LOCAL CURRENCY: \(currencyCode)
            PREFERRED RESPONSE LANGUAGE: \(aiPreferredLanguage)
            """
            
            // 5. Send the single request to the AI Assistant
            AIAssistantService.shared.processRequest(prompt: finalPrompt, image: image) { result in
                DispatchQueue.main.async {
                    withAnimation { self.isProcessingAI = false }
                    
                    switch result {
                    case .success(let response):
                        withAnimation { self.pendingAIResponse = response }
                        
                        // MOVED HERE: Speak immediately upon receiving the response
                        if self.isVoiceAnswerEnabled {
                            AIAssistantService.shared.speak(response.spoken_response)
                        }
                        
                        // Only execute automatically if it's a non-destructive action (like READ_ITEMS)
                        if !self.requiresConfirmation(action: response.action) {
                            self.executeAIAction(response)
                        }
                    case .failure(let error):
                        // Distinguish between network and API errors
                        let nsError = error as NSError
                        if nsError.domain == NSURLErrorDomain {
                            // Network-related error
                            self.networkAlertMessage = "Network error occurred. Please check your connection and try again.\n\nError: \(error.localizedDescription)"
                            self.showNetworkAlert = true
                        } else {
                            // API or other error
                            self.invalidTokenMessage = "AI request failed. Please check your API key.\n\nError: \(error.localizedDescription)"
                            self.showInvalidTokenAlert = true
                        }
                        print("AI Error: \(error.localizedDescription)")
                    }
                }
            }
        }
    
    private func executeAIAction(_ response: AIActionResponse) {
            let allCats = SQLiteManager.shared.fetchCategories()
            
            switch response.action {
                
            case "ADD_CATEGORY":
                guard let catName = response.category_name else { break }
                let targetCategoryId: UUID
                
                if let existingCategory = allCats.first(where: { $0.title.lowercased() == catName.lowercased() }) {
                    targetCategoryId = existingCategory.id
                } else {
                    let nextSeq = (categories.first?.sequence ?? 0) - 1
                    let newCategory = InventoryCategory(title: catName, colorHex: response.color_hex ?? "007AFF", sequence: nextSeq)
                    SQLiteManager.shared.saveCategory(newCategory)
                    targetCategoryId = newCategory.id
                }
                
                if let items = response.items {
                    for aiItem in items {
                        var newItem = InventoryItem(
                            categoryId: targetCategoryId, name: aiItem.name ?? "New Item", details: aiItem.details ?? "",
                            price: aiItem.price ?? 0.0, quantity: aiItem.quantity ?? 1
                        )
                        if let checked = aiItem.is_checked {
                            newItem.isChecked = checked
                        }
                        SQLiteManager.shared.saveItem(newItem)
                    }
                }
                
            case "ADD_ITEMS":
                var targetCategoryId: UUID?
                if let catIdString = response.category_id, let catId = UUID(uuidString: catIdString) {
                    targetCategoryId = catId
                } else if let catName = response.category_name {
                    if let existingCategory = allCats.first(where: { $0.title.lowercased() == catName.lowercased() }) {
                        targetCategoryId = existingCategory.id
                    } else {
                        let nextSeq = (categories.first?.sequence ?? 0) - 1
                        let newCategory = InventoryCategory(title: catName, colorHex: "8E8E93", sequence: nextSeq)
                        SQLiteManager.shared.saveCategory(newCategory)
                        targetCategoryId = newCategory.id
                    }
                }
                
                guard let finalCategoryId = targetCategoryId else { break }
                if let itemsToAdd = response.items {
                    for aiItem in itemsToAdd {
                        var newItem = InventoryItem(
                            categoryId: finalCategoryId, name: aiItem.name ?? "New Item", details: aiItem.details ?? "",
                            price: aiItem.price ?? 0.0, quantity: aiItem.quantity ?? 1
                        )
                        if let checked = aiItem.is_checked {
                            newItem.isChecked = checked
                        }
                        SQLiteManager.shared.saveItem(newItem)
                    }
                }
                
            case "DELETE_CATEGORY":
                guard let catIdString = response.category_id,
                      let catId = UUID(uuidString: catIdString) else { break }
                SQLiteManager.shared.deleteCategory(catId)
                
            case "DELETE_ITEMS":
                // Supports bulk deletion via array
                if let itemsToDelete = response.items {
                    for aiItem in itemsToDelete {
                        if let idString = aiItem.id, let targetId = UUID(uuidString: idString) {
                            SQLiteManager.shared.deleteItem(targetId)
                        }
                    }
                }
                
            case "UPDATE_CATEGORY":
                guard let catIdString = response.category_id,
                      let catId = UUID(uuidString: catIdString) else { break }
                
                if var catToUpdate = allCats.first(where: { $0.id == catId }) {
                    if let newName = response.category_name, !newName.isEmpty {
                        catToUpdate.title = newName
                    }
                                        
                    if let newColor = response.color_hex, !newColor.isEmpty {
                        catToUpdate.colorHex = newColor
                    }
                    SQLiteManager.shared.saveCategory(catToUpdate)
                }
                
            case "UPDATE_ITEMS":
                guard let itemsToUpdate = response.items else { break }
                
                // Iterate over all items provided by the AI for bulk updates
                for aiItem in itemsToUpdate {
                    guard let targetIdString = aiItem.id,
                          let targetId = UUID(uuidString: targetIdString) else { continue }
                    
                    // Locate the target item across all categories
                    var foundItem: InventoryItem?
                    for cat in allCats {
                        let items = SQLiteManager.shared.fetchItems(for: cat.id)
                        if let match = items.first(where: { $0.id == targetId }) {
                            foundItem = match
                            break
                        }
                    }
                    
                    if var itemToUpdate = foundItem {
                        // 1. Rename
                        if let newName = aiItem.name {
                            itemToUpdate.name = newName
                        }
                        // 2. Adjust Quantity
                        if let absoluteQty = aiItem.quantity {
                            itemToUpdate.quantity = max(0, absoluteQty)
                        }
                        // 3. Move Category
                        if let newCatIdString = aiItem.category_id, let newCatId = UUID(uuidString: newCatIdString) {
                            itemToUpdate.categoryId = newCatId
                        }
                        // 4. Toggle Checked Status
                        if let isChecked = aiItem.is_checked {
                            itemToUpdate.isChecked = isChecked
                        }
                        // 5. Update Details/Barcode/Price
                        if let details = aiItem.details {
                            itemToUpdate.details = details
                        }
                        if let barcode = aiItem.barcode {
                            itemToUpdate.barcode = barcode
                        }
                        if let price = aiItem.price {
                            itemToUpdate.price = price
                        }
                        
                        SQLiteManager.shared.saveItem(itemToUpdate)
                    }
                }
                
            default: break
            }
            
            loadData()
        }
}

// MARK: - Existing Helper Views Below (Unchanged)
struct ItemRowView: View {
    @Binding var item: InventoryItem
    let showCategoryName: Bool
    var onToggleCheck: ((InventoryItem) -> Void)?
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: {
                withAnimation(.snappy) {
                    item.isChecked.toggle()
                    onToggleCheck?(item)
                }
            }) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isChecked ? .green : .gray.opacity(0.5))
            }
            .buttonStyle(.plain)
            
            if let data = item.photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: UIConstants.thumbnailSize, height: UIConstants.thumbnailSize)
                    .clipShape(RoundedRectangle(cornerRadius: UIConstants.thumbnailCornerRadius))
                    .overlay(RoundedRectangle(cornerRadius: UIConstants.thumbnailCornerRadius).stroke(.gray.opacity(0.2), lineWidth: 1))
                    .opacity(item.isChecked ? UIConstants.checkedOpacity : 1.0)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: UIConstants.thumbnailCornerRadius)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: UIConstants.thumbnailSize, height: UIConstants.thumbnailSize)
                    Image(systemName: "photo").foregroundStyle(.gray.opacity(0.5))
                }
                .opacity(item.isChecked ? UIConstants.checkedOpacity : 1.0)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                    .strikethrough(item.isChecked)
                
                if !item.details.isEmpty {
                    Text(item.details).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.price, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
                Text("x\(item.quantity)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct GlobalSearchResults: View {
    let searchText: String
    @State private var matchedItems: [InventoryItem] = []
    @State private var itemToEdit: InventoryItem?
    
    var body: some View {
        Group {
            if matchedItems.isEmpty {
                CompatSearchUnavailableView(text: searchText)
            } else {
                Section("Items Found") {
                    ForEach($matchedItems) { $item in
                        Button { itemToEdit = item } label: {
                            ItemRowView(item: $item, showCategoryName: true, onToggleCheck: { updatedItem in SQLiteManager.shared.saveItem(updatedItem) })
                        }
                    }
                }
            }
        }
        .onAppear { matchedItems = SQLiteManager.shared.searchItems(text: searchText) }
        .onChange(of: searchText) { searchValue in matchedItems = SQLiteManager.shared.searchItems(text: searchValue) }
        .sheet(item: $itemToEdit) { item in
            if let category = SQLiteManager.shared.fetchCategories().first(where: { $0.id == item.categoryId }) {
                 // Assuming ItemFormView exists in your project
                 ItemFormView(initialCategory: category, itemToEdit: item) {
                     matchedItems = SQLiteManager.shared.searchItems(text: searchText)
                 }
            }
        }
    }
}

// MARK: - Items View (Detail Page)
struct ItemListView: View {
    let category: InventoryCategory
    
    @State private var items: [InventoryItem] = []
    @State private var showingAddSheet = false
    @State private var itemToEdit: InventoryItem?
    
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var csvDocument: InventoryCSV?
    @State private var importErrorMsg: String?
    @State private var showImportAlert = false

    private var uncheckedTotal: Double {
        items.filter { !$0.isChecked }.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
    }
    
    private var checkedTotal: Double {
        items.filter { $0.isChecked }.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Totals Header
            if !items.isEmpty {
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "cart")
                            .font(.subheadline.bold())
                        Text(uncheckedTotal, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            .font(.subheadline.monospacedDigit())
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
                    
                    HStack(spacing: 6) {
                        Image(systemName: "cart.fill")
                            .font(.subheadline.bold())
                        Text(checkedTotal, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            .font(.subheadline.monospacedDigit())
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
                }
                .padding(.vertical, 10)
                .padding(.horizontal)
            }
            
            List {
                ForEach($items) { $item in
                    Button {
                        itemToEdit = item
                    } label: {
                        ItemRowView(item: $item, showCategoryName: false) { updatedItem in
                             SQLiteManager.shared.saveItem(updatedItem)
                             loadItems()
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) {
                            deleteItem(item)
                        }
                    }
                }
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    // MARK: - Actions Disabled if Empty
                    Button {
                        checkAll(true)
                    } label: {
                        Label("Check All", systemImage: "checkmark.circle.fill")
                    }
                    .disabled(items.isEmpty)
                    
                    Button {
                        checkAll(false)
                    } label: {
                        Label("Uncheck All", systemImage: "circle")
                    }
                    .disabled(items.isEmpty)
                    
                    Divider()
                    
                    Button {
                        let csvString = CSVHelper.generateCSV(from: items)
                        csvDocument = InventoryCSV(text: csvString)
                        showingExporter = true
                    } label: {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(items.isEmpty) // Disable export if nothing to export
                    
                    // Import stays enabled
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import CSV", systemImage: "square.and.arrow.down")
                    }
                    
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ItemFormView(initialCategory: category, itemToEdit: nil, onSave: loadItems)
        }
        .sheet(item: $itemToEdit) { item in
            ItemFormView(initialCategory: category, itemToEdit: item, onSave: loadItems)
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: csvDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "\(category.title)_Inventory"
        ) { result in
            if case .failure(let error) = result {
                print("Export failed: \(error.localizedDescription)")
            }
        }
        .alert("Import Failed", isPresented: $showImportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importErrorMsg ?? "Unknown error")
        }
        .onAppear {
            loadItems()
        }
        .overlay {
            if items.isEmpty {
                CompatContentUnavailableView(
                            title: "No Items",
                            systemImage: "tray",
                            description: Text("Tap + to create an item")
                        )
            }
        }
    }
    
    // ... (Keep existing Logic Methods: loadItems, checkAll, deleteItem, handleImport) ...
    private func loadItems() {
        items = SQLiteManager.shared.fetchItems(for: category.id)
    }
    
    private func checkAll(_ checked: Bool) {
        withAnimation {
            for i in 0..<items.count {
                items[i].isChecked = checked
                SQLiteManager.shared.saveItem(items[i])
            }
            loadItems()
        }
    }
    
    private func deleteItem(_ item: InventoryItem) {
        withAnimation {
            SQLiteManager.shared.deleteItem(item.id)
            loadItems()
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let selectedFile: URL = try result.get().first else { return }
            if selectedFile.startAccessingSecurityScopedResource() {
                let data = try String(contentsOf: selectedFile, encoding: .utf8)
                selectedFile.stopAccessingSecurityScopedResource()
                let parsedItems = CSVHelper.parseCSV(data)
                for raw in parsedItems {
                    let newItem = InventoryItem(
                        categoryId: category.id,
                        name: raw.name,
                        details: raw.details,
                        price: raw.price,
                        quantity: raw.qty,
                        barcode: raw.barcode
                    )
                    SQLiteManager.shared.saveItem(newItem)
                }
                loadItems()
            }
        } catch {
            importErrorMsg = error.localizedDescription
            showImportAlert = true
        }
    }
}

// MARK: - Category Form
struct CategoryFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    var categoryToEdit: InventoryCategory?
    var nextSequence: Int
    var onSave: () -> Void
    
    @State private var title: String = ""
    @State private var selectedColor: Color = .blue
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Folder Details") {
                    TextField("Category Name", text: $title)
                }
                Section("Folder Color") {
                    ColorPicker("Color", selection: $selectedColor)
                }
            }
            .navigationTitle(categoryToEdit != nil ? "Edit Category" : "New Category")
            .toolbar {
                // MARK: - Cancel Button Added
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }.disabled(title.isEmpty)
                }
            }
            .onAppear {
                if let cat = categoryToEdit {
                    title = cat.title
                    selectedColor = Color(hex: cat.colorHex)
                }
            }
        }
    }
    
    private func save() {
        var cat = categoryToEdit ?? InventoryCategory(title: "", colorHex: "", sequence: nextSequence)
        cat.title = title
        cat.colorHex = selectedColor.toHex() ?? "0000FF"
        SQLiteManager.shared.saveCategory(cat)
        onSave()
    }
}

// MARK: - Item Form
struct ItemFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    // ... (Keep existing properties) ...
    @State private var allCategories: [InventoryCategory] = []
    
    var initialCategory: InventoryCategory
    var itemToEdit: InventoryItem?
    var onSave: () -> Void
    
    @State private var selectedCategory: InventoryCategory?
    @State private var name: String = ""
    @State private var details: String = ""
    @State private var price: Double? = nil
    @State private var quantity: Int = 1
    @State private var barcode: String = ""
    @State private var photoData: Data? = nil
    
    // --- Camera & Scanner States ---
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var showingCamera = false
    @State private var showingScanner = false
    
    // --- NEW: Permission Alert State ---
    @State private var showCameraAlert = false
    @State private var cameraErrorMsg = "Camera access is required."

    // ... (Keep init) ...

    var body: some View {
        NavigationStack {
            Form {
                // --- Photo Section ---
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            if let data = photoData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: UIConstants.photoPreviewSize, height: UIConstants.photoPreviewSize)
                                    .clipShape(RoundedRectangle(cornerRadius: UIConstants.standardCornerRadius))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: UIConstants.standardCornerRadius)
                                            .stroke(.gray.opacity(0.3), lineWidth: 1)
                                    )
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: UIConstants.standardCornerRadius)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: UIConstants.photoPreviewSize, height: UIConstants.photoPreviewSize)
                                    Image(systemName: "camera.fill")
                                        .font(.largeTitle)
                                        .foregroundStyle(.gray)
                                }
                            }
                            
                            HStack(spacing: 20) {
                                PhotosPicker(selection: $photoItem, matching: .images) {
                                    Label("Library", systemImage: "photo.on.rectangle")
                                }
                                .buttonStyle(.bordered)
                                
                                // --- UPDATED CAMERA BUTTON ---
                                Button {
                                    checkCameraPermission()
                                } label: {
                                    Label("Camera", systemImage: "camera")
                                }
                                .buttonStyle(.bordered)
                                
                                if photoData != nil {
                                    Button(role: .destructive) {
                                        withAnimation { photoData = nil }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                
                // ... (Keep existing Sections: Item Info, Identification, Inventory Data) ...
                Section("Item Info") {
                     Picker("Category", selection: $selectedCategory) {
                        ForEach(allCategories) { category in
                            Text(category.title).tag(category as InventoryCategory?)
                        }
                    }
                    TextField("Name", text: $name)
                    TextField("Description", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Identification") {
                    HStack {
                        Image(systemName: "barcode")
                            .foregroundStyle(.secondary)
                        TextField("Barcode / SKU", text: $barcode)
                            .keyboardType(.asciiCapable)
                        
                        Button {
                            // Reuse permission check for scanner too
                            checkCameraPermission(forScanner: true)
                        } label: {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Section("Inventory Data") {
                    TextField("Price", value: $price, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .keyboardType(.decimalPad)
                    
                    Stepper(value: $quantity, in: 0...9999) {
                        HStack {
                            Text("Quantity")
                            Spacer()
                            Text("\(quantity)")
                                .fontWeight(.bold)
                        }
                    }
                }
            }
            .navigationTitle(itemToEdit != nil ? "Edit Item" : "New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }.disabled(name.isEmpty)
                }
            }
            .onChange(of: photoItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data), let compressed = uiImage.jpegData(compressionQuality: 0.7) {
                            photoData = compressed
                        } else {
                            photoData = data
                        }
                    }
                }
            }
            // --- NEW: Camera Alert ---
            .alert("Camera Access Required", isPresented: $showCameraAlert) {
                Button("Settings", role: .none) {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(cameraErrorMsg)
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerSheet(scannedCode: $barcode)
            }
            .sheet(isPresented: $showingCamera) {
                CameraPicker(selectedData: $photoData)
            }
            .onAppear {
                // ... (Keep existing onAppear logic) ...
                allCategories = SQLiteManager.shared.fetchCategories()
                if let item = itemToEdit {
                    name = item.name
                    details = item.details
                    price = item.price
                    quantity = item.quantity
                    barcode = item.barcode
                    photoData = item.photoData
                    selectedCategory = allCategories.first(where: { $0.id == item.categoryId })
                } else {
                    selectedCategory = initialCategory
                }
            }
        }
    }
    
    // --- NEW: Permission Logic ---
    private func checkCameraPermission(forScanner: Bool = false) {
        // 1. Check if hardware is available
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            cameraErrorMsg = "Camera is not available on this device (are you on Simulator?)."
            showCameraAlert = true
            return
        }

        // 2. Check authorization status
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Permission already granted
            if forScanner { showingScanner = true } else { showingCamera = true }
            
        case .notDetermined:
            // Request permission
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        if forScanner { showingScanner = true } else { showingCamera = true }
                    } else {
                        cameraErrorMsg = "Please enable camera access in Settings to take photos."
                        showCameraAlert = true
                    }
                }
            }
            
        case .denied, .restricted:
            // Previously denied
            cameraErrorMsg = "Camera access was previously denied. Please enable it in Settings."
            showCameraAlert = true
            
        @unknown default:
            break
        }
    }
    
    // ... (Keep save() function) ...
    private func save() {
        guard let cat = selectedCategory else { return }
        var item: InventoryItem
        if let existing = itemToEdit { item = existing }
        else { item = InventoryItem(categoryId: cat.id, name: "", quantity: 1) }
        
        item.categoryId = cat.id
        item.name = name
        item.details = details
        item.price = price ?? 0.0
        item.quantity = quantity
        item.barcode = barcode
        item.photoData = photoData
        
        SQLiteManager.shared.saveItem(item)
        onSave()
    }
}

// MARK: - Replaced Scanner (AVFoundation)
struct BarcodeScannerSheet: UIViewControllerRepresentable {
    @Binding var scannedCode: String
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> ScannerViewController {
        let scannerViewController = ScannerViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }
    
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ScannerDelegate {
        let parent: BarcodeScannerSheet
        
        init(_ parent: BarcodeScannerSheet) {
            self.parent = parent
        }
        
        func didFind(code: String) {
            parent.scannedCode = code
            parent.dismiss()
        }
        
        func didFail(reason: String) {
            print("Scanner failed: \(reason)")
            parent.dismiss()
        }
    }
}

// MARK: - Native AVFoundation Scanner Controller
protocol ScannerDelegate: AnyObject {
    func didFind(code: String)
    func didFail(reason: String)
}

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    weak var delegate: ScannerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.didFail(reason: "Camera not supported on this device")
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            delegate?.didFail(reason: error.localizedDescription)
            return
        }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            delegate?.didFail(reason: "Could not add video input")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            // Support all common barcode types + QR
            metadataOutput.metadataObjectTypes = [
                .ean8, .ean13, .pdf417, .qr, .code128, .code39, .upce
            ]
        } else {
            delegate?.didFail(reason: "Could not add metadata output")
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Add a "Cancel" button overlay
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Cancel", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        closeButton.layer.cornerRadius = 8
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        
        view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 80),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Add a visual guide box
        let guideView = UIView()
        guideView.layer.borderColor = UIColor.green.cgColor
        guideView.layer.borderWidth = 2
        guideView.backgroundColor = .clear
        guideView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(guideView)
        NSLayoutConstraint.activate([
            guideView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guideView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            guideView.widthAnchor.constraint(equalToConstant: 250),
            guideView.heightAnchor.constraint(equalToConstant: 250)
        ])
        
        // Start running on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    @objc func closeTapped() {
        dismiss(animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let connection = previewLayer?.connection {
             let currentDevice: UIDevice = UIDevice.current
             let orientation: UIDeviceOrientation = currentDevice.orientation
             let previewLayerConnection : AVCaptureConnection = connection
        
             if previewLayerConnection.isVideoOrientationSupported {
                 switch (orientation) {
                 case .portrait: updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)
                 case .landscapeRight: updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeLeft)
                 case .landscapeLeft: updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeRight)
                 case .portraitUpsideDown: updatePreviewLayer(layer: previewLayerConnection, orientation: .portraitUpsideDown)
                 default: updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)
                 }
             }
         }
        previewLayer?.frame = view.bounds
    }
    
    private func updatePreviewLayer(layer: AVCaptureConnection, orientation: AVCaptureVideoOrientation) {
        layer.videoOrientation = orientation
        previewLayer.frame = self.view.bounds
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            // Haptic Feedback
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            
            delegate?.didFind(code: stringValue)
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var selectedData: Data?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = true // Allows user to crop/square the photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                // Compress image to JPEG to save space
                parent.selectedData = image.jpegData(compressionQuality: 0.7)
            }
            parent.dismiss()
        }
    }
}

// MARK: - AI Privacy Consent Sheet
struct AITermsView: View {
    @Binding var hasAccepted: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
                .padding(.top, 32)
            
            Text("AI Features & Privacy")
                .font(.title2)
                .bold()
            
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(icon: "waveform", color: .blue, title: "Voice & Audio Processing", description: "Audio recorded via the 'Hold to Talk' feature is sent to our AI provider (OpenAI) securely to transcribe and execute your commands.")
                
                FeatureRow(icon: "camera", color: .green, title: "Image Analysis", description: "Photos taken for scanning are securely transmitted to identify objects and automatically categorize them in your inventory.")
                
                FeatureRow(icon: "xmark.shield", color: .red, title: "Not Used for Training", description: "Your data is processed strictly to fulfill your requests. It is not stored by the AI provider to train future models.")
            }
            .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 16) {
                Text("By continuing, you consent to sharing this data for the purpose of managing your inventory.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    hasAccepted = true
                    dismiss()
                }) {
                    Text("Accept & Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button("Not Now") {
                    dismiss()
                }
                .foregroundStyle(.blue)
            }
            .padding(.bottom, 32)
            .padding(.horizontal)
        }
        .background(Color.white)
    }
}

// Helper View for the bullet points
struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

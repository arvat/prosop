//
//  CSVHelpers.swift
//  prosop
//
//  Created by Arvat Vladimir on 14.02.2026.
//

import SwiftUI
import UniformTypeIdentifiers
import CoreTransferable

// MARK: - CSV Document Helper (For Exporting)
struct InventoryCSV: FileDocument, Transferable {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    
    var text: String
    
    init(text: String) {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        } else {
            text = ""
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
    
    // MARK: - Transferable Conformance (The Fix)
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .commaSeparatedText) { document in
            Data(document.text.utf8)
        } importing: { data in
            InventoryCSV(text: String(decoding: data, as: UTF8.self))
        }
    }
}

// MARK: - CSV Parser Helper
struct CSVHelper {
    
    static func generateCSV(from items: [InventoryItem]) -> String {
        // Updated Header
        var csv = "Name,Details,Price,Quantity,Barcode\n"
        
        for item in items {
            let name = escape(item.name)
            let details = escape(item.details)
            let barcode = escape(item.barcode) // <--- Escape barcode
            let line = "\(name),\(details),\(item.price),\(item.quantity),\(barcode)\n"
            csv += line
        }
        return csv
    }
    
    static func parseCSV(_ data: String) -> [(name: String, details: String, price: Double, qty: Int, barcode: String)] {
        var results: [(String, String, Double, Int, String)] = []
        let rows = data.components(separatedBy: .newlines)
        
        let startIndex = rows.first?.lowercased().contains("name") == true ? 1 : 0
        
        for i in startIndex..<rows.count {
            let row = rows[i]
            if row.isEmpty { continue }
            
            let columns = parseLine(row)
            
            // Now checking for 5 columns (support legacy 4 columns safely)
            if columns.count >= 4 {
                let name = columns[0]
                let details = columns[1]
                let price = Double(columns[2]) ?? 0.0
                let qty = Int(columns[3]) ?? 0
                // Check if barcode column exists, otherwise empty
                let barcode = columns.count > 4 ? columns[4] : ""
                
                results.append((name, details, price, qty, barcode))
            }
        }
        return results
    }
    
    // ... (Keep escape and parseLine private helpers the same) ...
    private static func escape(_ text: String) -> String {
        if text.contains(",") || text.contains("\"") || text.contains("\n") {
            let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return text
    }
    
    private static func parseLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var insideQuotes = false
        for char in line {
            if char == "\"" { insideQuotes.toggle() }
            else if char == "," && !insideQuotes { result.append(current); current = "" }
            else { current.append(char) }
        }
        result.append(current)
        return result.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"\"", with: "\"") }
    }
}

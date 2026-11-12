//
//  Models.swift
//  prosop
//
//  Created by Arvat Vladimir on 13.02.2026.
//

import Foundation
import SwiftUI

// MARK: - Models

struct InventoryCategory: Identifiable, Hashable {
    var id: UUID
    var title: String
    var colorHex: String
    var sequence: Int
    var timestamp: Date
    
    // SQLite: Items are fetched separately via query, not stored directly in the struct
    // We can keep a count or temporary list if needed for UI, but usually, we fetch items on demand.
    
    init(id: UUID = UUID(), title: String, colorHex: String, sequence: Int = 0, timestamp: Date = Date()) {
        self.id = id
        self.title = title
        self.colorHex = colorHex
        self.sequence = sequence
        self.timestamp = timestamp
    }
}

struct InventoryItem: Identifiable, Hashable {
    var id: UUID
    var categoryId: UUID // Foreign Key
    var name: String
    var details: String
    var price: Double
    var quantity: Int
    var barcode: String
    var timestamp: Date
    var isChecked: Bool
    var photoData: Data?
    
    init(id: UUID = UUID(), categoryId: UUID, name: String, details: String = "", price: Double = 0.0, quantity: Int, barcode: String = "", photoData: Data? = nil, isChecked: Bool = false, timestamp: Date = Date()) {
        self.id = id
        self.categoryId = categoryId
        self.name = name
        self.details = details
        self.price = price
        self.quantity = quantity
        self.barcode = barcode
        self.photoData = photoData
        self.isChecked = isChecked
        self.timestamp = timestamp
    }
}

// MARK: - Color Helper Extension
extension Color {
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else { return nil }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
    
    init(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanHex.hasPrefix("#") { cleanHex.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

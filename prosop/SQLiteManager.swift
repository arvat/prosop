//
//  SQLiteManager.swift
//  prosop
//
//  Created by Arvat Vladimir on 15.02.2026.
//

import Foundation
import SQLite3

class SQLiteManager {
    static let shared = SQLiteManager()
    private var db: OpaquePointer?
    
    // Current schema version - increment this when adding migrations
    private let currentSchemaVersion: Int32 = 1
    
    private init() {
        openDatabase()
        performMigrations()
    }
    
    private func openDatabase() {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("InventoryDB.sqlite")
        
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Error opening database")
        }
    }
    
    // MARK: - Database Schema Version
    
    private func getDatabaseVersion() -> Int32 {
        var statement: OpaquePointer?
        var version: Int32 = 0
        
        if sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                version = sqlite3_column_int(statement, 0)
            }
        }
        sqlite3_finalize(statement)
        return version
    }
    
    private func setDatabaseVersion(_ version: Int32) {
        let sql = "PRAGMA user_version = \(version);"
        execute(sql: sql)
    }
    
    // MARK: - Migration System
    
    private func performMigrations() {
        let currentVersion = getDatabaseVersion()
        
        guard currentVersion < currentSchemaVersion else {
            print("✅ Database schema up to date (v\(currentVersion))")
            return
        }
        
        print("🔄 Migrating database from v\(currentVersion) to v\(currentSchemaVersion)")
        
        // Run migrations in sequence using a switch statement
        var version = currentVersion
        
        while version < currentSchemaVersion {
            version += 1
            
            switch version {
            case 1:
                migrateToVersion1()
            case 2:
                migrateToVersion2()
            case 3:
                migrateToVersion3()
            // Add more migration cases as needed
            // case 4:
            //     migrateToVersion4()
            default:
                print("⚠️ Unknown migration version: \(version)")
            }
            
            // Update the version after each successful migration
            setDatabaseVersion(version)
            print("✅ Migrated to version \(version)")
        }
        
        print("✅ Database migration complete")
    }
    
    // MARK: - Migration Scripts
    
    /// Initial schema - Creates base tables
    private func migrateToVersion1() {
        print("Running migration v1: Creating initial tables")
        
        let createCategoryTable = """
        CREATE TABLE IF NOT EXISTS Categories (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            colorHex TEXT NOT NULL,
            sequence INTEGER NOT NULL DEFAULT 0,
            timestamp REAL NOT NULL
        );
        """
        
        let createItemTable = """
        CREATE TABLE IF NOT EXISTS Items (
            id TEXT PRIMARY KEY,
            categoryId TEXT NOT NULL,
            name TEXT NOT NULL,
            details TEXT NOT NULL DEFAULT '',
            price REAL NOT NULL DEFAULT 0.0,
            quantity INTEGER NOT NULL DEFAULT 0,
            barcode TEXT NOT NULL DEFAULT '',
            timestamp REAL NOT NULL,
            isChecked INTEGER NOT NULL DEFAULT 0,
            photoData BLOB,
            FOREIGN KEY(categoryId) REFERENCES Categories(id) ON DELETE CASCADE
        );
        """
        
        // Create indexes for better performance
        let createCategorySequenceIndex = """
        CREATE INDEX IF NOT EXISTS idx_categories_sequence ON Categories(sequence);
        """
        
        let createItemCategoryIdIndex = """
        CREATE INDEX IF NOT EXISTS idx_items_categoryId ON Items(categoryId);
        """
        
        let createItemBarcodeIndex = """
        CREATE INDEX IF NOT EXISTS idx_items_barcode ON Items(barcode);
        """
        
        execute(sql: createCategoryTable)
        execute(sql: createItemTable)
        execute(sql: createCategorySequenceIndex)
        execute(sql: createItemCategoryIdIndex)
        execute(sql: createItemBarcodeIndex)
    }
    
    /// Example: Add a new column
    private func migrateToVersion2() {
        print("Running migration v2: Add example column")
        
        // Example: Add a new column to Items table
        // let addColumnSQL = "ALTER TABLE Items ADD COLUMN exampleColumn TEXT;"
        // execute(sql: addColumnSQL)
        
        // For now, this is a placeholder for future migrations
    }
    
    /// Example: Add another feature
    private func migrateToVersion3() {
        print("Running migration v3: Add another feature")
        
        // Example: Create a new table
        // let createNewTable = """
        // CREATE TABLE IF NOT EXISTS NewFeature (
        //     id TEXT PRIMARY KEY,
        //     data TEXT
        // );
        // """
        // execute(sql: createNewTable)
    }
    
    // MARK: - SQL Execution Helper
    
    private func execute(sql: String) {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) != SQLITE_DONE {
                print("❌ Error executing SQL: \(sql)")
                if let error = sqlite3_errmsg(db) {
                    print("   SQLite Error: \(String(cString: error))")
                }
            }
        } else {
            print("❌ Error preparing SQL: \(sql)")
            if let error = sqlite3_errmsg(db) {
                print("   SQLite Error: \(String(cString: error))")
            }
        }
        sqlite3_finalize(statement)
    }
    
    // MARK: - Categories CRUD
    
    func fetchCategories() -> [InventoryCategory] {
        var categories: [InventoryCategory] = []
        let query = "SELECT * FROM Categories ORDER BY sequence ASC, timestamp DESC;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let idString = String(cString: sqlite3_column_text(statement, 0))
                let title = String(cString: sqlite3_column_text(statement, 1))
                let colorHex = String(cString: sqlite3_column_text(statement, 2))
                let sequence = Int(sqlite3_column_int(statement, 3))
                let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))
                
                categories.append(InventoryCategory(
                    id: UUID(uuidString: idString)!,
                    title: title,
                    colorHex: colorHex,
                    sequence: sequence,
                    timestamp: timestamp
                ))
            }
        }
        sqlite3_finalize(statement)
        return categories
    }
    
    func saveCategory(_ category: InventoryCategory) {
        let insertSQL = "INSERT OR REPLACE INTO Categories (id, title, colorHex, sequence, timestamp) VALUES (?, ?, ?, ?, ?);"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (category.id.uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (category.title as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (category.colorHex as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 4, Int32(category.sequence))
            sqlite3_bind_double(statement, 5, category.timestamp.timeIntervalSince1970)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error saving category")
            }
        }
        sqlite3_finalize(statement)
    }
    
    func deleteCategory(_ categoryId: UUID) {
        let deleteSQL = "DELETE FROM Categories WHERE id = ?;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (categoryId.uuidString as NSString).utf8String, -1, nil)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
        
        // Also delete items (if CASCADE not supported by current sqlite config)
        let deleteItemsSQL = "DELETE FROM Items WHERE categoryId = ?;"
        var statement2: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteItemsSQL, -1, &statement2, nil) == SQLITE_OK {
            sqlite3_bind_text(statement2, 1, (categoryId.uuidString as NSString).utf8String, -1, nil)
            sqlite3_step(statement2)
        }
        sqlite3_finalize(statement2)
    }
    
    // MARK: - Items CRUD
    
    func fetchItems(for categoryId: UUID) -> [InventoryItem] {
        var items: [InventoryItem] = []
        let query = "SELECT * FROM Items WHERE categoryId = ? ORDER BY timestamp DESC;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (categoryId.uuidString as NSString).utf8String, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
                let catId = UUID(uuidString: String(cString: sqlite3_column_text(statement, 1)))!
                let name = String(cString: sqlite3_column_text(statement, 2))
                let details = String(cString: sqlite3_column_text(statement, 3))
                let price = sqlite3_column_double(statement, 4)
                let quantity = Int(sqlite3_column_int(statement, 5))
                let barcode = String(cString: sqlite3_column_text(statement, 6))
                let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 7))
                let isChecked = sqlite3_column_int(statement, 8) != 0
                
                var photoData: Data? = nil
                if let blob = sqlite3_column_blob(statement, 9) {
                    let length = sqlite3_column_bytes(statement, 9)
                    photoData = Data(bytes: blob, count: Int(length))
                }
                
                items.append(InventoryItem(
                    id: id,
                    categoryId: catId,
                    name: name,
                    details: details,
                    price: price,
                    quantity: quantity,
                    barcode: barcode,
                    photoData: photoData,
                    isChecked: isChecked,
                    timestamp: timestamp
                ))
            }
        }
        sqlite3_finalize(statement)
        return items
    }
    
    // Add or Update
    func saveItem(_ item: InventoryItem) {
        let insertSQL = """
        INSERT OR REPLACE INTO Items (id, categoryId, name, details, price, quantity, barcode, timestamp, isChecked, photoData)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (item.id.uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (item.categoryId.uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (item.name as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 4, (item.details as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 5, item.price)
            sqlite3_bind_int(statement, 6, Int32(item.quantity))
            sqlite3_bind_text(statement, 7, (item.barcode as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 8, item.timestamp.timeIntervalSince1970)
            sqlite3_bind_int(statement, 9, item.isChecked ? 1 : 0)
            
            if let data = item.photoData {
                _ = data.withUnsafeBytes { buffer in
                        sqlite3_bind_blob(statement, 10, buffer.baseAddress, Int32(data.count), nil)
                    }
            } else {
                sqlite3_bind_null(statement, 10)
            }
            
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    func deleteItem(_ itemId: UUID) {
        let sql = "DELETE FROM Items WHERE id = ?;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (itemId.uuidString as NSString).utf8String, -1, nil)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    // Search
    func searchItems(text: String) -> [InventoryItem] {
        var items: [InventoryItem] = []
        let query = """
        SELECT * FROM Items WHERE name LIKE ? OR details LIKE ? OR barcode LIKE ?;
        """
        let searchPattern = "%\(text)%" as NSString
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, searchPattern.utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, searchPattern.utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, searchPattern.utf8String, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                // ... (Parsing same as fetchItems - simplified for brevity)
                let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))!
                let catId = UUID(uuidString: String(cString: sqlite3_column_text(statement, 1)))!
                let name = String(cString: sqlite3_column_text(statement, 2))
                let details = String(cString: sqlite3_column_text(statement, 3))
                let price = sqlite3_column_double(statement, 4)
                let quantity = Int(sqlite3_column_int(statement, 5))
                let barcode = String(cString: sqlite3_column_text(statement, 6))
                let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 7))
                let isChecked = sqlite3_column_int(statement, 8) != 0
                
                var photoData: Data? = nil
                if let blob = sqlite3_column_blob(statement, 9) {
                    let length = sqlite3_column_bytes(statement, 9)
                    photoData = Data(bytes: blob, count: Int(length))
                }
                
                items.append(InventoryItem(
                    id: id, categoryId: catId, name: name, details: details, price: price, quantity: quantity, barcode: barcode, photoData: photoData, isChecked: isChecked, timestamp: timestamp
                ))
            }
        }
        sqlite3_finalize(statement)
        return items
    }
    
    // Helper to get Item count for a category (for the main list bubbles)
    func getItemCount(for categoryId: UUID) -> Int {
        let query = "SELECT COUNT(*) FROM Items WHERE categoryId = ?;"
        var statement: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (categoryId.uuidString as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)
        return count
    }
}

//
//  CompatViews.swift
//  prosop
//
//  Created by Arvat Vladimir on 15.02.2026.
//

import SwiftUI

struct CompatContentUnavailableView: View {
    var title: String
    var systemImage: String
    var description: Text?

    var body: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView(title, systemImage: systemImage, description: description)
        } else {
            // iOS 16 Fallback
            VStack(spacing: 20) {
                Image(systemName: systemImage)
                    .font(.system(size: 50))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 6) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let description = description {
                        description
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .multilineTextAlignment(.center)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemGroupedBackground)) // Optional: matches list background
        }
    }
}

struct CompatSearchUnavailableView: View {
    var text: String
    
    var body: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView.search(text: text)
        } else {
            // iOS 16 Search Fallback
            VStack(spacing: 20) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 50))
                    .foregroundStyle(.secondary)
                
                Text("No Results for \"\(text)\"")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

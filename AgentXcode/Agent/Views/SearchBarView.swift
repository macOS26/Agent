//
//  SearchBarView.swift
//  Agent
//
//  Extracted from ContentView.swift
//

import SwiftUI

struct SearchBarView: View {
    @Binding var searchText: String
    let totalMatches: Int
    let currentMatchIndex: Int
    let previousMatch: () -> Void
    let nextMatch: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Find in log...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .onSubmit { nextMatch() }
                if !searchText.isEmpty {
                    Text(totalMatches > 0 ? "\(currentMatchIndex + 1)/\(totalMatches)" : "0 results")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 50)
                    Button { previousMatch() } label: {
                        Image(systemName: "chevron.up")
                            .frame(height: 14)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(totalMatches == 0)
                    Button { nextMatch() } label: {
                        Image(systemName: "chevron.down")
                            .frame(height: 14)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(totalMatches == 0)
                }
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(height: 14)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            Divider()
        }
    }
}
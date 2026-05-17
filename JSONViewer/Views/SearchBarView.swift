import SwiftUI

// MARK: - Search Bar

struct SearchBarView: View {
    @EnvironmentObject var viewModel: EditorViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 12))

            TextField("Search keys and values…", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .focused($isFocused)
                .onSubmit { viewModel.nextMatch() }
                .accessibilityIdentifier("searchField")

            if !viewModel.searchQuery.isEmpty {
                // Match counter
                if !viewModel.searchMatches.isEmpty {
                    Text("\(viewModel.currentMatchIndex + 1)/\(viewModel.searchMatches.count)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize()
                        .accessibilityIdentifier("searchMatchCounter")
                } else {
                    Text("No results")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "f48771"))
                        .fixedSize()
                        .accessibilityIdentifier("searchNoResults")
                }

                Divider().frame(height: 14)

                SearchBarButton(systemImage: "chevron.up", identifier: "searchPrevious") { viewModel.previousMatch() }
                    .disabled(viewModel.searchMatches.isEmpty)

                SearchBarButton(systemImage: "chevron.down", identifier: "searchNext") { viewModel.nextMatch() }
                    .disabled(viewModel.searchMatches.isEmpty)

                Divider().frame(height: 14)

                SearchBarButton(systemImage: "xmark.circle.fill", identifier: "searchClear") { viewModel.searchQuery = "" }
            }

            Divider().frame(height: 14)

            SearchBarButton(systemImage: "arrow.up.and.line.horizontal.and.arrow.down", identifier: "expandAll") { viewModel.expandAll() }
                .help("Expand All")

            SearchBarButton(systemImage: "line.horizontal.3", identifier: "collapseAll") { viewModel.collapseAll() }
                .help("Collapse All")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(hex: "252526"))
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "3c3c3c"))
        }
    }

    func focusSearch() {
        isFocused = true
    }
}

// MARK: - Reusable icon button with a generous hit area

private struct SearchBarButton: View {
    let systemImage: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

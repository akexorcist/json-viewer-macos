import SwiftUI

// MARK: - Main Editor View

struct MainEditorView: View {
    var body: some View {
        HSplitView {
            // Left: Tree (top) + Inspector (bottom)
            VSplitView {
                VStack(spacing: 0) {
                    SearchBarView()
                    TreeView()
                }
                .frame(minHeight: 120)

                FormView()
                    .frame(minHeight: 80)
            }
            .frame(minWidth: 220, idealWidth: 320, maxWidth: .infinity)

            // Right: Raw JSON (always visible)
            RawJsonView()
                .frame(minWidth: 260, idealWidth: 420, maxWidth: .infinity)
        }
        .background(Color(hex: "1e1e1e"))
    }
}

// MARK: - Raw JSON View

struct RawJsonView: View {
    @EnvironmentObject var viewModel: EditorViewModel
    @State private var rawText = ""
    @State private var parseError: String?
    /// True while we are programmatically writing rawText from a tree-side change,
    /// so the rawText onChange handler knows to skip calling applyRaw.
    @State private var suppressRawOnChange = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Raw JSON")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    formatJson()
                } label: {
                    Image(systemName: "arrow.left.arrow.right.square")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Format / Prettify JSON")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "252526"))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(hex: "3c3c3c"))
            }

            // Error banner
            if let error = parseError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color(hex: "f48771"))
                        .font(.system(size: 11))
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "f48771"))
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "3a1a1a"))
            }

            JsonTextEditor(text: $rawText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: rawText) { newText in
                    guard !suppressRawOnChange else { return }
                    applyRaw(newText)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            syncFromTree()
        }
        // Only pull in new text when the tree/inspector made the change
        .onChange(of: viewModel.treeVersion) { _ in
            syncFromTree()
        }
    }

    /// Overwrite rawText with the current serialized JSON coming from the tree side.
    /// Uses a Task-deferred flag reset so that the rawText onChange fires while
    /// suppressRawOnChange is still true, preventing a round-trip parse back into the tree.
    private func syncFromTree() {
        suppressRawOnChange = true
        rawText = viewModel.serializedJson
        parseError = nil
        Task { @MainActor in
            suppressRawOnChange = false
        }
    }

    private func applyRaw(_ text: String) {
        let sanitized = sanitizeQuotes(text)
        if sanitized != text {
            suppressRawOnChange = true
            rawText = sanitized
            Task { @MainActor in suppressRawOnChange = false }
        }
        viewModel.updateFromRaw(sanitized)
        parseError = viewModel.parseError
    }

    /// Replace smart/curly quotes with straight ASCII quotes.
    private func sanitizeQuotes(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{201C}", with: "\"")  // "
            .replacingOccurrences(of: "\u{201D}", with: "\"")  // "
            .replacingOccurrences(of: "\u{2018}", with: "'")   // '
            .replacingOccurrences(of: "\u{2019}", with: "'")   // '
    }

    private func formatJson() {
        guard parseError == nil, let root = viewModel.root else { return }
        suppressRawOnChange = true
        rawText = TreeBuilder.serialize(root)
        Task { @MainActor in suppressRawOnChange = false }
    }
}

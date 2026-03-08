import SwiftUI
import UniformTypeIdentifiers
import AppKit
import Combine

// MARK: - App Entry Point

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

struct JSONViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()


    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 500)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    providers.first?.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                        guard let data = item as? Data,
                              let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                        DispatchQueue.main.async { appState.openFile(url: url) }
                    }
                    return true
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("New") { appState.newDocument() }
                    .keyboardShortcut("n", modifiers: .command)

                Button("Open…") { appState.openFileDialog() }
                    .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("Save") { appState.save() }
                    .keyboardShortcut("s", modifiers: .command)

                Button("Save As…") { appState.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            // Edit menu: Undo/Redo
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") { appState.editorViewModel.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!appState.editorViewModel.canUndo)

                Button("Redo") { appState.editorViewModel.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!appState.editorViewModel.canRedo)
            }
        }
    }
}

// MARK: - App State (file management)

@MainActor
final class AppState: ObservableObject {
    @Published var editorViewModel = EditorViewModel()
    @Published var currentFileURL: URL?
    @Published var windowTitle: String = "Untitled"
    @Published var isDirty: Bool = false

    private var cancellable: AnyCancellable?

    init() {
        editorViewModel.loadFromText("{\n\n}")
        // Forward editorViewModel changes so CommandGroup re-evaluates canUndo/canRedo
        cancellable = editorViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }

    // MARK: - File Operations

    func newDocument() {
        editorViewModel.loadFromText("{\n\n}")
        currentFileURL = nil
        windowTitle = "Untitled"
        isDirty = false
    }

    func openFileDialog() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Open JSON File"
        if panel.runModal() == .OK, let url = panel.url {
            openFile(url: url)
        }
    }

    func openFile(url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        editorViewModel.loadFromText(text)
        currentFileURL = url
        windowTitle = url.lastPathComponent
        isDirty = false
    }

    func save() {
        if let url = currentFileURL {
            write(to: url)
        } else {
            saveAs()
        }
    }

    func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = currentFileURL?.lastPathComponent ?? "untitled.json"
        panel.title = "Save JSON File"
        if panel.runModal() == .OK, let url = panel.url {
            write(to: url)
            currentFileURL = url
            windowTitle = url.lastPathComponent
        }
    }

    private func write(to url: URL) {
        let text = editorViewModel.serializedJson
        try? text.write(to: url, atomically: true, encoding: .utf8)
        isDirty = false
    }

    func markDirty() {
        isDirty = true
    }
}

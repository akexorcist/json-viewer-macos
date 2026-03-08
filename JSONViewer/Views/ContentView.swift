import SwiftUI
import AppKit

// MARK: - App Root View (wraps ContentView with AppState binding)

struct AppRootView: View {
    @EnvironmentObject var appState: AppState
    @State private var keyMonitor: Any?

    var body: some View {
        ContentView()
            .environmentObject(appState.editorViewModel)
            .onChange(of: appState.editorViewModel.serializedJson) { _ in
                appState.markDirty()
            }
            .onAppear {
                keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                    guard event.charactersIgnoringModifiers == "z",
                          flags == .command || flags == [.command, .shift] else { return event }
                    if flags.contains(.shift) {
                        appState.editorViewModel.redo()
                    } else {
                        appState.editorViewModel.undo()
                    }
                    return nil
                }
            }
            .onDisappear {
                if let monitor = keyMonitor {
                    NSEvent.removeMonitor(monitor)
                    keyMonitor = nil
                }
            }
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var viewModel: EditorViewModel
    @EnvironmentObject var appState: AppState
    @State private var isCopied = false

    var body: some View {
        MainEditorView()
            .overlay(alignment: .bottom) {
                if isCopied {
                    Text("Copied to clipboard")
                        .font(.callout)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isCopied)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        appState.openFileDialog()
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help("Open File")

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(appState.editorViewModel.serializedJson, forType: .string)
                        isCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isCopied = false
                        }
                    } label: {
                        Image(systemName: isCopied ? "doc.on.doc.fill" : "doc.on.doc")
                    }
                    .help("Copy to Clipboard")
                }
            }
    }
}

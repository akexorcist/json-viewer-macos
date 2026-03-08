import SwiftUI
import AppKit

// A plain NSTextView wrapper that disables all macOS smart-substitution features
// (smart quotes, smart dashes, autocorrect, spell-check) that would corrupt JSON.
struct JsonTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = NSColor(Color(hex: "cccccc"))
        textView.backgroundColor = NSColor(Color(hex: "1e1e1e"))
        textView.insertionPointColor = NSColor.white
        textView.textContainerInset = NSSize(width: 8, height: 8)

        // Disable all smart substitutions that corrupt JSON
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false

        textView.string = text
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // Only update if text actually differs to avoid resetting the cursor
        if textView.string != text {
            let selected = textView.selectedRanges
            textView.string = text
            // Restore selection if it's still within bounds
            let safe = selected.compactMap { r -> NSValue? in
                let range = r.rangeValue
                guard range.location <= text.utf16.count else { return nil }
                let end = min(range.location + range.length, text.utf16.count)
                return NSValue(range: NSRange(location: range.location, length: end - range.location))
            }
            textView.selectedRanges = safe.isEmpty ? [NSValue(range: NSRange(location: text.utf16.count, length: 0))] : safe
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: JsonTextEditor

        init(_ parent: JsonTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

import XCTest
import SnapshotTesting
import SwiftUI
import AppKit
@testable import JSONViewer

// Run once with `record: true` in assertView() to generate reference images,
// then set back to `record: false` (the default) for regression checking.
@MainActor
final class SnapshotTests: XCTestCase {

    // MARK: - Helpers

    private func makeViewModel(_ json: String) -> EditorViewModel {
        let vm = EditorViewModel()
        vm.loadFromText(json)
        return vm
    }

    private func assertView<V: View>(
        _ view: V,
        size: CGSize,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        let controller = NSHostingController(rootView: view)
        // Force dark aqua so system controls (Picker, Toggle, TextField) render
        // consistently regardless of the machine's system appearance.
        controller.view.appearance = NSAppearance(named: .darkAqua)
        assertSnapshot(
            of: controller,
            as: .image(size: size),
            file: file,
            testName: testName,
            line: line
        )
    }

    // MARK: - Group 1: TreeNodeRow

    // Baseline: unselected leaf at depth 1. Key in blue, value colored, no background.
    func testTreeRow_leaf_default() {
        let vm = makeViewModel(#"{"name":"Alice","score":42}"#)
        let node = vm.root!.children[0]             // "name":"Alice"

        let view = TreeNodeRow(node: node, depth: 1)
            .environmentObject(vm)
            .frame(width: 360, height: 22)
            .background(Color(hex: "1e1e1e"))

        assertView(view, size: CGSize(width: 360, height: 22))
    }

    // Selected state: blue #094771 background, + button becomes visible.
    // This is the state where the reported spacing issue occurs.
    func testTreeRow_leaf_selected() {
        let vm = makeViewModel(#"{"name":"Alice","score":42}"#)
        let node = vm.root!.children[0]
        vm.selectedId = node.id

        let view = TreeNodeRow(node: node, depth: 1)
            .environmentObject(vm)
            .frame(width: 360, height: 22)
            .background(Color(hex: "1e1e1e"))

        assertView(view, size: CGSize(width: 360, height: 22))
    }

    // Container collapsed: chevron.right visible, preview count shown, no children.
    func testTreeRow_container_collapsed() {
        let vm = makeViewModel(#"{"user":{"name":"Alice"}}"#)
        let node = vm.root!.children[0]             // "user": {...} — not in expandedIds

        let view = TreeNodeRow(node: node, depth: 1)
            .environmentObject(vm)
            .frame(width: 360, height: 22)
            .background(Color(hex: "1e1e1e"))

        assertView(view, size: CGSize(width: 360, height: 22))
    }

    // Container expanded: chevron.down visible.
    func testTreeRow_container_expanded() {
        let vm = makeViewModel(#"{"user":{"name":"Alice"}}"#)
        let node = vm.root!.children[0]
        vm.expandedIds.insert(node.id)

        let view = TreeNodeRow(node: node, depth: 1)
            .environmentObject(vm)
            .frame(width: 360, height: 22)
            .background(Color(hex: "1e1e1e"))

        assertView(view, size: CGSize(width: 360, height: 22))
    }

    // Search match (not current): dim color, dark #2a2520 background.
    // "second" node is match index 1 — a match but not the active result.
    func testTreeRow_searchMatch() {
        let vm = makeViewModel(#"{"first":"alice","second":"alice"}"#)
        vm.searchQuery = "alice"                    // currentMatchIndex = 0 → "first" is active
        let node = vm.root!.children[1]             // "second" — match, not current

        let view = TreeNodeRow(node: node, depth: 1)
            .environmentObject(vm)
            .frame(width: 360, height: 22)
            .background(Color(hex: "1e1e1e"))

        assertView(view, size: CGSize(width: 360, height: 22))
    }

    // Current match (not selected): yellow #ffcc00 text, #3a3520 background.
    // After search sets selectedId = "target", we move selection elsewhere so the
    // current-match colour (not the selected-blue) can be verified independently.
    func testTreeRow_currentMatch() {
        let vm = makeViewModel(#"{"target":"find_me","other":"value"}"#)
        vm.searchQuery = "find_me"                  // currentMatch = "target", selectedId = "target"
        vm.selectedId = vm.root!.children[1].id     // move selection → "target" is now currentMatch but not selected
        let node = vm.root!.children[0]             // "target" — currentMatch, unselected → yellow

        let view = TreeNodeRow(node: node, depth: 1)
            .environmentObject(vm)
            .frame(width: 360, height: 22)
            .background(Color(hex: "1e1e1e"))

        assertView(view, size: CGSize(width: 360, height: 22))
    }

    // Full tree with all 6 node types expanded: verifies colour scheme per type
    // and depth-2 indentation in context.
    func testTreeRow_allTypes_fullTree() {
        let json = """
        {
          "name": "Alice",
          "score": 42,
          "active": true,
          "empty": null,
          "tags": ["swift", "macos"],
          "address": {"city": "Bangkok"}
        }
        """
        let vm = makeViewModel(json)
        vm.expandAll()                              // 10 visible rows × 22 px = 220 px + 8 px padding

        let view = TreeView()
            .environmentObject(vm)

        assertView(view, size: CGSize(width: 360, height: 240))
    }

    // MARK: - Group 2: FormView (inspector panel)

    // No selection → EmptyFormView placeholder.
    func testForm_empty() {
        let vm = makeViewModel(#"{"name":"Alice"}"#)
        // selectedId stays nil

        let view = FormView()
            .environmentObject(vm)

        assertView(view, size: CGSize(width: 320, height: 160))
    }

    // String node: TextEditor multi-line value area.
    func testForm_primitive_string() {
        let vm = makeViewModel(#"{"name":"Alice"}"#)
        vm.selectedId = vm.root!.children[0].id

        let view = FormView()
            .environmentObject(vm)

        assertView(view, size: CGSize(width: 320, height: 240))
    }

    // Number node: single-line TextField value area.
    func testForm_primitive_number() {
        let vm = makeViewModel(#"{"score":42}"#)
        vm.selectedId = vm.root!.children[0].id

        let view = FormView()
            .environmentObject(vm)

        assertView(view, size: CGSize(width: 320, height: 240))
    }

    // Boolean node: Toggle control.
    func testForm_primitive_boolean() {
        let vm = makeViewModel(#"{"active":true}"#)
        vm.selectedId = vm.root!.children[0].id

        let view = FormView()
            .environmentObject(vm)

        assertView(view, size: CGSize(width: 320, height: 240))
    }

    // Null node: static "null" text, no interactive editor.
    func testForm_primitive_null() {
        let vm = makeViewModel(#"{"empty":null}"#)
        vm.selectedId = vm.root!.children[0].id

        let view = FormView()
            .environmentObject(vm)

        assertView(view, size: CGSize(width: 320, height: 240))
    }

    // Object node: key-value list rows, draggable column separator, type badges.
    func testForm_object() {
        let vm = makeViewModel(#"{"user":{"name":"Alice","age":30}}"#)
        vm.selectedId = vm.root!.children[0].id     // "user" object with 2 children

        let view = FormView()
            .environmentObject(vm)

        assertView(view, size: CGSize(width: 320, height: 220))
    }

    // Array node: index labels [0], [1], [2], type badges.
    func testForm_array() {
        let vm = makeViewModel(#"{"tags":["swift","macos","xcode"]}"#)
        vm.selectedId = vm.root!.children[0].id     // "tags" array with 3 items

        let view = FormView()
            .environmentObject(vm)

        assertView(view, size: CGSize(width: 320, height: 220))
    }

    // MARK: - Group 3: SearchBarView

    // Idle: magnifier icon and expand/collapse buttons only.
    func testSearchBar_idle() {
        let vm = makeViewModel(#"{"name":"Alice"}"#)

        let view = SearchBarView()
            .environmentObject(vm)

        assertView(view, size: CGSize(width: 400, height: 36))
    }

    // Active with 2 matches: counter "1/2", prev/next/clear buttons visible.
    func testSearchBar_withMatches() {
        let vm = makeViewModel(#"{"first":"alice","second":"alice"}"#)
        vm.searchQuery = "alice"

        let view = SearchBarView()
            .environmentObject(vm)

        assertView(view, size: CGSize(width: 400, height: 36))
    }

    // Active with no matches: "No results" in red, no counter.
    func testSearchBar_noResults() {
        let vm = makeViewModel(#"{"name":"Alice"}"#)
        vm.searchQuery = "zzz"

        let view = SearchBarView()
            .environmentObject(vm)

        assertView(view, size: CGSize(width: 400, height: 36))
    }
}

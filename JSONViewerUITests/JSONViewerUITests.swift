import XCTest

final class JSONViewerUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Helpers

    /// Replaces all content in the raw JSON editor with the given string.
    private func setRawJson(_ json: String) {
        let editor = app.textViews["rawJsonEditor"]
        editor.click()
        editor.typeKey("a", modifierFlags: .command)
        editor.typeText(json)
    }

    /// Clicks the context-menu Delete item in the window (not the Edit menu bar Delete).
    /// After a right-click the context menu appears as a Menu under app.windows; the
    /// Edit menu bar's Delete has identifier "delete:" and lives under app.menuBars,
    /// so targeting app.windows.firstMatch disambiguates the two.
    private func clickContextMenuDelete() {
        app.windows.firstMatch.menus.firstMatch.menuItems["Delete"].click()
    }

    /// Returns the displayed text of a staticText element, checking both .value and
    /// .label because SwiftUI Text exposes content as .value on macOS, not .label.
    private func textContent(of element: XCUIElement) -> String {
        (element.value as? String)?.nilIfEmpty ?? element.label
    }

    // MARK: - Tests

    // Typing valid JSON in the raw editor syncs keys to the tree view.
    func testRawEditorUpdatesTree() {
        setRawJson(#"{"greeting":"hello"}"#)
        XCTAssertTrue(app.staticTexts["greeting"].waitForExistence(timeout: 3))
    }

    // Malformed JSON shows the error banner in the raw panel.
    // SwiftUI HStack maps to XCUIElementType.group, so search via descendants(matching: .any).
    func testInvalidJSONShowsErrorBanner() {
        setRawJson("{invalid")
        let banner = app.descendants(matching: .any).matching(identifier: "errorBanner").firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 3))
    }

    // Chevron button expands a collapsed container and collapses it again.
    func testExpandAndCollapseNode() {
        setRawJson(#"{"user":{"name":"Alice"}}"#)
        let expandBtn = app.buttons["expandBtn_user"]
        XCTAssertTrue(expandBtn.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["name"].exists)

        expandBtn.click()
        XCTAssertTrue(app.staticTexts["name"].waitForExistence(timeout: 2))

        expandBtn.click()
        XCTAssertFalse(app.staticTexts["name"].exists)
    }

    // Searching highlights matches and the counter advances on Next.
    // SwiftUI Text exposes content as .value on macOS, not .label — use textContent().
    func testSearchFlowWithNavigation() {
        setRawJson(#"{"first":"alice","second":"alice"}"#)
        let searchField = app.textFields["searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.click()
        searchField.typeText("alice")

        let counter = app.staticTexts["searchMatchCounter"]
        XCTAssertTrue(counter.waitForExistence(timeout: 3))
        XCTAssertEqual(textContent(of: counter), "1/2")

        app.buttons["searchNext"].click()
        XCTAssertEqual(textContent(of: counter), "2/2")
    }

    // The + button on a container appends a new child key.
    // The button has opacity(0) when the node is unselected, so click the key text
    // first to select the row, then click the now-visible add button.
    func testAddChildToContainer() {
        setRawJson(#"{"obj":{}}"#)
        let expandBtn = app.buttons["expandBtn_obj"]
        XCTAssertTrue(expandBtn.waitForExistence(timeout: 3))

        // Select the node so addChildBtn becomes hittable (opacity 1)
        app.staticTexts["obj"].click()
        app.buttons["addChildBtn_obj"].click()

        XCTAssertTrue(app.staticTexts["newKey"].waitForExistence(timeout: 2))
    }

    // Context-menu Delete removes the node from the tree.
    func testDeleteNodeViaContextMenu() {
        setRawJson(#"{"keep":"yes","remove":"this"}"#)
        let removeLabel = app.staticTexts["remove"]
        XCTAssertTrue(removeLabel.waitForExistence(timeout: 3))
        removeLabel.rightClick()
        clickContextMenuDelete()

        XCTAssertFalse(app.staticTexts["remove"].exists)
        XCTAssertTrue(app.staticTexts["keep"].exists)
    }

    // ⌘Z restores a node that was deleted from the tree.
    func testUndoTreeOperation() {
        setRawJson(#"{"key":"value"}"#)
        let keyLabel = app.staticTexts["key"]
        XCTAssertTrue(keyLabel.waitForExistence(timeout: 3))
        keyLabel.rightClick()
        clickContextMenuDelete()
        XCTAssertFalse(app.staticTexts["key"].exists)

        app.menuBars.menuBarItems["Edit"].click()
        app.menuItems["Undo"].click()
        XCTAssertTrue(app.staticTexts["key"].waitForExistence(timeout: 2))
    }

    // ⌘⇧Z re-applies the undone deletion.
    func testRedoAfterUndo() {
        setRawJson(#"{"key":"value"}"#)
        let keyLabel = app.staticTexts["key"]
        XCTAssertTrue(keyLabel.waitForExistence(timeout: 3))
        keyLabel.rightClick()
        clickContextMenuDelete()

        app.menuBars.menuBarItems["Edit"].click()
        app.menuItems["Undo"].click()
        XCTAssertTrue(app.staticTexts["key"].waitForExistence(timeout: 2))

        app.menuBars.menuBarItems["Edit"].click()
        app.menuItems["Redo"].click()
        XCTAssertFalse(app.staticTexts["key"].exists)
    }

    // Format button re-serializes compact JSON with indentation.
    func testFormatJSON() {
        setRawJson(#"{"a":1,"b":2}"#)
        let formatBtn = app.buttons["formatJson"]
        XCTAssertTrue(formatBtn.waitForExistence(timeout: 3))
        formatBtn.click()

        let raw = app.textViews["rawJsonEditor"].value as? String ?? ""
        XCTAssertTrue(raw.contains("\n"), "Expected formatted JSON to contain newlines")
    }

    // Selecting an object node shows the form panel; clicking "+ Add" in the header
    // appends a new child and expands the parent in the tree.
    func testFormHeaderAddChildButton() {
        setRawJson(#"{"obj":{"a":1}}"#)

        // Select the object node to open the form panel
        let expandBtn = app.buttons["expandBtn_obj"]
        XCTAssertTrue(expandBtn.waitForExistence(timeout: 3))
        app.staticTexts["obj"].click()

        // The form header's "+ Add" button has label 'Add' but no identifier —
        // .buttonStyle(.bordered) wraps a native NSButton on macOS that doesn't
        // propagate the SwiftUI-set accessibilityIdentifier. The tree's add button
        // also has label 'Add' but carries identifier 'addChildBtn_obj', so we
        // distinguish them with a predicate on the absent identifier.
        let addBtn = app.buttons
            .matching(NSPredicate(format: "label == 'Add' AND identifier == ''"))
            .firstMatch
        XCTAssertTrue(addBtn.waitForExistence(timeout: 3))
        addBtn.click()

        // addChild auto-expands the parent in the tree, so "newKey" becomes visible there.
        XCTAssertTrue(app.staticTexts["newKey"].waitForExistence(timeout: 3))
    }

    // Double-clicking a leaf key enters inline edit mode; the value label must remain
    // visible (not pushed off-screen by an expanding TextField). Renaming and confirming
    // with Return replaces the key in the tree.
    func testDoubleClickKeyInlineEdit() {
        setRawJson(#"{"username":"johndoe"}"#)
        let keyLabel = app.staticTexts["username"]
        XCTAssertTrue(keyLabel.waitForExistence(timeout: 3))

        // Enter inline key-edit mode
        keyLabel.doubleClick()

        // Select-all and type the new key name, then confirm
        app.typeKey("a", modifierFlags: .command)
        app.typeText("newname")
        app.typeKey(.return, modifierFlags: [])

        // New key must appear and old key must be gone
        XCTAssertTrue(app.staticTexts["newname"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["username"].exists)
    }

    // File > New resets the document; previously visible keys disappear.
    func testNewDocumentResetsState() {
        setRawJson(#"{"name":"Alice"}"#)
        XCTAssertTrue(app.staticTexts["name"].waitForExistence(timeout: 3))

        app.menuBars.menuBarItems["File"].click()
        app.menuItems["New"].click()

        XCTAssertFalse(app.staticTexts["name"].exists)
    }
}

// MARK: - String helper

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

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

    // Clicking the trash button on an object property row removes it from the form panel.
    func testFormPanelDeleteObjectProperty() {
        setRawJson(#"{"obj":{"keep":"yes","remove":"this"}}"#)

        let expandBtn = app.buttons["expandBtn_obj"]
        XCTAssertTrue(expandBtn.waitForExistence(timeout: 3))
        app.staticTexts["obj"].click()

        // macOS List (NSTableView) with multiple rows doesn't expose individual row static
        // texts via accessibility — wait for the delete buttons instead, which use
        // .buttonStyle(.plain) and reliably propagate their accessibilityIdentifier.
        XCTAssertTrue(app.buttons["deleteBtn_remove"].waitForExistence(timeout: 3))

        app.buttons["deleteBtn_remove"].click()

        XCTAssertFalse(app.buttons["deleteBtn_remove"].exists)
        XCTAssertTrue(app.buttons["deleteBtn_keep"].exists)
    }

    // Clicking the trash button on an array item row removes it from the form panel.
    func testFormPanelDeleteArrayItem() {
        setRawJson(#"{"arr":["user","admin"]}"#)

        let expandBtn = app.buttons["expandBtn_arr"]
        XCTAssertTrue(expandBtn.waitForExistence(timeout: 3))
        app.staticTexts["arr"].click()

        // For arrays, child.key is the index string: "0" → deleteBtn_0, "1" → deleteBtn_1.
        // Wait for deleteBtn_1 to confirm the form panel is loaded with both rows.
        XCTAssertTrue(app.buttons["deleteBtn_1"].waitForExistence(timeout: 3))

        app.buttons["deleteBtn_1"].click()

        XCTAssertFalse(app.buttons["deleteBtn_1"].exists)
        XCTAssertTrue(app.buttons["deleteBtn_0"].exists)
    }

    // Clicking the pencil button on a value cell opens an inline TextField for editing.
    func testFormPanelEditObjectValue() {
        setRawJson(#"{"obj":{"name":"Alice","other":"x"}}"#)

        let expandBtn = app.buttons["expandBtn_obj"]
        XCTAssertTrue(expandBtn.waitForExistence(timeout: 3))
        app.staticTexts["obj"].click()

        XCTAssertTrue(app.buttons["editValueBtn_name"].waitForExistence(timeout: 5))
        app.buttons["editValueBtn_name"].click()

        let valueField = app.textFields["Value"]
        XCTAssertTrue(valueField.waitForExistence(timeout: 2))
        valueField.typeKey("a", modifierFlags: .command)
        valueField.typeText("Bob")
        app.buttons["confirmValueBtn_name"].click()

        XCTAssertTrue(app.staticTexts["\"Bob\""].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["\"Alice\""].exists)
    }

    // Clicking the pencil button on a key cell opens an inline TextField for editing.
    func testFormPanelEditObjectKey() {
        setRawJson(#"{"obj":{"name":"Alice","other":"x"}}"#)

        let expandBtn = app.buttons["expandBtn_obj"]
        XCTAssertTrue(expandBtn.waitForExistence(timeout: 3))
        app.staticTexts["obj"].click()

        XCTAssertTrue(app.buttons["editKeyBtn_name"].waitForExistence(timeout: 5))
        app.buttons["editKeyBtn_name"].click()

        let keyField = app.textFields["Key"]
        XCTAssertTrue(keyField.waitForExistence(timeout: 2))
        keyField.typeKey("a", modifierFlags: .command)
        keyField.typeText("label")
        app.buttons["confirmKeyBtn_name"].click()

        XCTAssertTrue(app.staticTexts["label"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["name"].exists)
    }

    // Selecting an object node shows the form panel; clicking "+ Add" in the header
    // appends a new child and expands the parent in the tree.
    func testFormHeaderAddChildButton() {
        setRawJson(#"{"obj":{"a":1}}"#)

        // Select the object node to open the form panel
        let expandBtn = app.buttons["expandBtn_obj"]
        XCTAssertTrue(expandBtn.waitForExistence(timeout: 3))
        app.staticTexts["obj"].click()

        // The form header's "+ Add" button has label 'Add'. The tree's add button
        // also gets label 'Add' from the SF Symbol but carries identifier 'addChildBtn_obj',
        // so exclude it by identifier. This works whether or not .buttonStyle(.bordered)
        // propagates the SwiftUI accessibilityIdentifier to the native NSButton.
        let addBtn = app.buttons
            .matching(NSPredicate(format: "label == 'Add' AND identifier != 'addChildBtn_obj'"))
            .firstMatch
        XCTAssertTrue(addBtn.waitForExistence(timeout: 3))
        addBtn.click()

        // addChild auto-expands the parent in the tree, so "newKey" becomes visible there.
        XCTAssertTrue(app.staticTexts["newKey"].waitForExistence(timeout: 3))
    }

    // MARK: - Form panel: modify

    // Rename a property key via the pencil button in ObjectFormContent.
    func testFormPanelChangeKeyName() {
        setRawJson(#"{"obj":{"username":"alice","other":"x"}}"#)
        XCTAssertTrue(app.buttons["expandBtn_obj"].waitForExistence(timeout: 3))
        app.staticTexts["obj"].click()

        XCTAssertTrue(app.buttons["editKeyBtn_username"].waitForExistence(timeout: 5))
        app.buttons["editKeyBtn_username"].click()

        let keyField = app.textFields["Key"]
        XCTAssertTrue(keyField.waitForExistence(timeout: 2))
        keyField.typeKey("a", modifierFlags: .command)
        keyField.typeText("handle")
        app.buttons["confirmKeyBtn_username"].click()

        XCTAssertTrue(app.staticTexts["handle"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["username"].exists)
    }

    // Edit a string value directly via the TextEditor in PrimitiveFormContent
    // (the form shown when a primitive leaf node is selected).
    func testFormPanelChangePrimitiveValue() {
        setRawJson(#"{"greeting":"hello"}"#)
        // Root object is auto-expanded; "greeting" is visible in the tree at depth 1.
        XCTAssertTrue(app.staticTexts["greeting"].waitForExistence(timeout: 3))
        app.staticTexts["greeting"].click()

        // SwiftUI TextEditor applies .accessibilityIdentifier to its NSScrollView wrapper,
        // not the inner NSTextView that XCUITest queries. Match any textView that is not
        // the raw JSON editor.
        let editor = app.textViews.matching(NSPredicate(format: "identifier != 'rawJsonEditor'")).firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        editor.click()
        editor.typeKey("a", modifierFlags: .command)
        editor.typeText("goodbye")

        // TextEditor binding updates immediately; verify via tree displayValue.
        XCTAssertTrue(app.staticTexts["\"goodbye\""].waitForExistence(timeout: 2))
    }

    // Edit a property value via the pencil button in ObjectFormContent.
    func testFormPanelChangeObjectPropertyValue() {
        setRawJson(#"{"obj":{"price":"99","other":"x"}}"#)
        XCTAssertTrue(app.buttons["expandBtn_obj"].waitForExistence(timeout: 3))
        app.staticTexts["obj"].click()

        XCTAssertTrue(app.buttons["editValueBtn_price"].waitForExistence(timeout: 5))
        app.buttons["editValueBtn_price"].click()

        let valueField = app.textFields["Value"]
        XCTAssertTrue(valueField.waitForExistence(timeout: 2))
        valueField.typeKey("a", modifierFlags: .command)
        valueField.typeText("199")
        app.buttons["confirmValueBtn_price"].click()

        XCTAssertTrue(app.staticTexts["\"199\""].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["\"99\""].exists)
    }

    // Edit an array item value via the pencil button in ArrayFormContent.
    // VStack renders both rows eagerly so both items are accessible regardless of panel height.
    func testFormPanelChangeArrayItemValue() {
        setRawJson(#"{"arr":["hello","world"]}"#)
        XCTAssertTrue(app.buttons["expandBtn_arr"].waitForExistence(timeout: 3))
        app.staticTexts["arr"].click()

        XCTAssertTrue(app.buttons["editValueBtn_0"].waitForExistence(timeout: 5))
        app.buttons["editValueBtn_0"].click()

        let valueField = app.textFields["Value"]
        XCTAssertTrue(valueField.waitForExistence(timeout: 2))
        valueField.typeKey("a", modifierFlags: .command)
        valueField.typeText("greet")
        app.buttons["confirmValueBtn_0"].click()

        XCTAssertTrue(app.staticTexts["\"greet\""].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["\"hello\""].exists)
    }

    // Change a primitive node's type via the segmented Picker in PrimitiveFormContent.
    // Boolean → String: Toggle disappears, TextEditor appears.
    func testFormPanelChangePrimitiveType() {
        setRawJson(#"{"active":true}"#)
        XCTAssertTrue(app.staticTexts["active"].waitForExistence(timeout: 3))
        app.staticTexts["active"].click()

        // On macOS, SwiftUI Toggle renders as NSButton checkbox (not XCUIElementType.toggle).
        XCTAssertTrue(app.checkBoxes.firstMatch.waitForExistence(timeout: 2))

        // SwiftUI Picker(.segmented) doesn't expose as XCUIElementType.segmentedControl on macOS.
        // Search all descendants by label to find the "String" segment regardless of element type.
        let stringSegment = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'String'"))
            .firstMatch
        XCTAssertTrue(stringSegment.waitForExistence(timeout: 2))
        stringSegment.click()

        // After changing to String, checkbox (Toggle) is gone and TextEditor appears.
        // TextEditor identifier doesn't propagate to the inner NSTextView — match by exclusion.
        let stringEditor = app.textViews.matching(NSPredicate(format: "identifier != 'rawJsonEditor'")).firstMatch
        XCTAssertTrue(stringEditor.waitForExistence(timeout: 2))
        XCTAssertFalse(app.checkBoxes.firstMatch.exists)
    }

    // Change a property's value type via the type drop-down Menu in an ObjectFormContent row.
    // String "42" → Number 42: displayValue loses the surrounding quotes.
    func testFormPanelChangeObjectPropertyType() {
        setRawJson(#"{"obj":{"count":"42"}}"#)
        XCTAssertTrue(app.buttons["expandBtn_obj"].waitForExistence(timeout: 3))
        app.staticTexts["obj"].click()

        // String "42" is shown with quotes in the row.
        XCTAssertTrue(app.staticTexts["\"42\""].waitForExistence(timeout: 2))

        // Menu with .menuStyle(.borderlessButton) renders as MenuButton (not Button/PopUpButton).
        // It is the only MenuButton in the form panel.
        XCTAssertTrue(app.menuButtons.firstMatch.waitForExistence(timeout: 2))
        app.menuButtons.firstMatch.click()
        app.menuItems["Number"].click()

        // Number 42 is shown without quotes; string form is gone.
        XCTAssertTrue(app.staticTexts["42"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["\"42\""].exists)
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

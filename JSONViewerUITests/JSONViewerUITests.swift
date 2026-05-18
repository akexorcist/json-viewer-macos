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

    // Double-clicking a value cell in the form panel opens an inline TextField for editing.
    func testFormPanelEditObjectValue() {
        setRawJson(#"{"obj":{"name":"Alice"}}"#)

        let expandBtn = app.buttons["expandBtn_obj"]
        XCTAssertTrue(expandBtn.waitForExistence(timeout: 3))
        app.staticTexts["obj"].click()

        XCTAssertTrue(app.staticTexts["\"Alice\""].waitForExistence(timeout: 2))
        app.staticTexts["\"Alice\""].doubleClick()

        let valueField = app.textFields["Value"]
        XCTAssertTrue(valueField.waitForExistence(timeout: 2))
        valueField.typeKey("a", modifierFlags: .command)
        valueField.typeText("Bob")
        valueField.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(app.staticTexts["\"Bob\""].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["\"Alice\""].exists)
    }

    // Double-clicking a key cell in the form panel opens an inline TextField for editing.
    func testFormPanelEditObjectKey() {
        setRawJson(#"{"obj":{"name":"Alice"}}"#)

        let expandBtn = app.buttons["expandBtn_obj"]
        XCTAssertTrue(expandBtn.waitForExistence(timeout: 3))
        app.staticTexts["obj"].click()

        XCTAssertTrue(app.staticTexts["name"].waitForExistence(timeout: 2))
        app.staticTexts["name"].doubleClick()

        let keyField = app.textFields["Key"]
        XCTAssertTrue(keyField.waitForExistence(timeout: 2))
        keyField.typeKey("a", modifierFlags: .command)
        keyField.typeText("label")
        keyField.typeKey(.return, modifierFlags: [])

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

    // Rename a property key via the inline TextField in ObjectFormContent.
    func testFormPanelChangeKeyName() {
        setRawJson(#"{"obj":{"username":"alice"}}"#)
        XCTAssertTrue(app.buttons["expandBtn_obj"].waitForExistence(timeout: 3))
        app.staticTexts["obj"].click()

        XCTAssertTrue(app.staticTexts["username"].waitForExistence(timeout: 2))
        app.staticTexts["username"].doubleClick()

        let keyField = app.textFields["Key"]
        XCTAssertTrue(keyField.waitForExistence(timeout: 2))
        keyField.typeKey("a", modifierFlags: .command)
        keyField.typeText("handle")
        keyField.typeKey(.return, modifierFlags: [])

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

        // PrimitiveFormContent shows a TextEditor for the string value.
        let editor = app.textViews["primitiveStringEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        editor.click()
        editor.typeKey("a", modifierFlags: .command)
        editor.typeText("goodbye")

        // TextEditor binding updates immediately; verify via tree displayValue.
        XCTAssertTrue(app.staticTexts["\"goodbye\""].waitForExistence(timeout: 2))
    }

    // Edit a property value inline via the double-click TextField in ObjectFormContent.
    func testFormPanelChangeObjectPropertyValue() {
        setRawJson(#"{"obj":{"price":"99"}}"#)
        XCTAssertTrue(app.buttons["expandBtn_obj"].waitForExistence(timeout: 3))
        app.staticTexts["obj"].click()

        XCTAssertTrue(app.staticTexts["\"99\""].waitForExistence(timeout: 2))
        app.staticTexts["\"99\""].doubleClick()

        let valueField = app.textFields["Value"]
        XCTAssertTrue(valueField.waitForExistence(timeout: 2))
        valueField.typeKey("a", modifierFlags: .command)
        valueField.typeText("199")
        valueField.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(app.staticTexts["\"199\""].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["\"99\""].exists)
    }

    // Edit an array item value inline via the double-click TextField in ArrayFormContent.
    // VStack renders both rows eagerly so both items are accessible regardless of panel height.
    func testFormPanelChangeArrayItemValue() {
        setRawJson(#"{"arr":["hello","world"]}"#)
        XCTAssertTrue(app.buttons["expandBtn_arr"].waitForExistence(timeout: 3))
        app.staticTexts["arr"].click()

        XCTAssertTrue(app.staticTexts["\"hello\""].waitForExistence(timeout: 2))
        app.staticTexts["\"hello\""].doubleClick()

        let valueField = app.textFields["Value"]
        XCTAssertTrue(valueField.waitForExistence(timeout: 2))
        valueField.typeKey("a", modifierFlags: .command)
        valueField.typeText("greet")
        valueField.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(app.staticTexts["\"greet\""].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["\"hello\""].exists)
    }

    // Change a primitive node's type via the segmented Picker in PrimitiveFormContent.
    // Boolean → String: Toggle disappears, TextEditor appears.
    func testFormPanelChangePrimitiveType() {
        setRawJson(#"{"active":true}"#)
        XCTAssertTrue(app.staticTexts["active"].waitForExistence(timeout: 3))
        app.staticTexts["active"].click()

        // PrimitiveFormContent shows Toggle for boolean type.
        XCTAssertTrue(app.toggles.firstMatch.waitForExistence(timeout: 2))

        // Click "String" segment in the type Picker.
        let picker = app.segmentedControls["primitiveTypePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 2))
        picker.buttons["String"].click()

        // After changing to String, TextEditor replaces the Toggle.
        XCTAssertTrue(app.textViews["primitiveStringEditor"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.toggles.firstMatch.exists)
    }

    // Change a property's value type via the type drop-down Menu in an ObjectFormContent row.
    // String "42" → Number 42: displayValue loses the surrounding quotes.
    func testFormPanelChangeObjectPropertyType() {
        setRawJson(#"{"obj":{"count":"42"}}"#)
        XCTAssertTrue(app.buttons["expandBtn_obj"].waitForExistence(timeout: 3))
        app.staticTexts["obj"].click()

        // String "42" is shown with quotes in the row.
        XCTAssertTrue(app.staticTexts["\"42\""].waitForExistence(timeout: 2))

        // The row's type drop-down is a borderless Menu button labelled with the current type.
        app.buttons["String"].click()
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

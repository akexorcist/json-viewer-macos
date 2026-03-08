import SwiftUI

// MARK: - Form View (right panel - property editor for selected node)

struct FormView: View {
    @EnvironmentObject var viewModel: EditorViewModel

    var body: some View {
        if let node = viewModel.selectedNode {
            VStack(spacing: 0) {
                // Breadcrumb / header
                FormHeader(node: node)

                Divider()
                    .overlay(Color(hex: "3c3c3c"))

                // Content based on node type
                if node.type == .object {
                    ObjectFormContent(node: node)
                } else if node.type == .array {
                    ArrayFormContent(node: node)
                } else {
                    PrimitiveFormContent(node: node)
                }
            }
            .background(Color(hex: "252526"))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
        } else {
            EmptyFormView()
        }
    }
}

// MARK: - Form Header

private struct FormHeader: View {
    let node: TreeNode
    @EnvironmentObject var viewModel: EditorViewModel

    var body: some View {
        HStack(spacing: 8) {
            // Type badge
            Text(node.type.displayName.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(node.type.color)
                .cornerRadius(3)

            if !node.key.isEmpty {
                Text(node.key)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "9cdcfe"))
                    .lineLimit(1)
            } else {
                Text("Root")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Add child button (for containers)
            if node.type.isContainer {
                Button {
                    viewModel.addChild(to: node.id)
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Object Form Content

private struct ObjectFormContent: View {
    let node: TreeNode
    @EnvironmentObject var viewModel: EditorViewModel
    @State private var keyColumnWidth: CGFloat = 120

    var body: some View {
        List {
            ForEach(node.children) { child in
                ObjectPropertyRow(child: child, parentId: node.id, keyColumnWidth: $keyColumnWidth)
            }
            .onMove { from, to in
                if let idx = from.first {
                    viewModel.reorderChildren(parentId: node.id, fromIndex: idx, toIndex: to > idx ? to - 1 : to)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(hex: "252526"))
    }
}

private struct ObjectPropertyRow: View {
    let child: TreeNode
    let parentId: UUID
    @Binding var keyColumnWidth: CGFloat
    @EnvironmentObject var viewModel: EditorViewModel

    @State private var editKey: String = ""
    @State private var editValue: String = ""
    @State private var isEditingKey = false
    @State private var isEditingValue = false
    @FocusState private var keyFocused: Bool
    @FocusState private var valueFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Key
            Group {
                if isEditingKey {
                    TextField("Key", text: $editKey)
                        .textFieldStyle(.roundedBorder)
                        .focused($keyFocused)
                        .onSubmit { commitKey() }
                        .onExitCommand { isEditingKey = false }
                } else {
                    Text(child.key)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color(hex: "9cdcfe"))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture(count: 2) {
                            editKey = child.key
                            isEditingKey = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { keyFocused = true }
                        }
                }
            }
            .frame(width: keyColumnWidth, alignment: .leading)

            // Draggable column separator
            Rectangle()
                .fill(Color(hex: "3c3c3c"))
                .frame(width: 1)
                .padding(.vertical, 2)
                .overlay(
                    Color.clear
                        .frame(width: 8)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            if hovering { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 1)
                                .onChanged { value in
                                    let newWidth = keyColumnWidth + value.translation.width
                                    keyColumnWidth = min(max(newWidth, 60), 300)
                                }
                        )
                )

            // Value
            if child.isLeaf {
                Group {
                    if isEditingValue {
                        TextField("Value", text: $editValue)
                            .textFieldStyle(.roundedBorder)
                            .focused($valueFocused)
                            .onSubmit { commitValue() }
                            .onExitCommand { isEditingValue = false }
                    } else {
                        Text(child.displayValue)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(child.type.color)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onTapGesture(count: 2) {
                                editValue = child.primitive?.editString ?? ""
                                isEditingValue = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { valueFocused = true }
                            }
                    }
                }
                .padding(.leading, 8)
            } else {
                // Nested container — click to select in tree
                Button {
                    viewModel.selectedId = child.id
                    viewModel.expandedIds.insert(child.id)
                } label: {
                    Text(child.displayValue)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(hex: "007acc"))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
            }

            // Type menu
            Menu {
                ForEach(NodeType.allCases) { type in
                    Button {
                        viewModel.changeType(id: child.id, to: type)
                    } label: {
                        Label(type.displayName, systemImage: type == child.type ? "checkmark" : "")
                    }
                }
            } label: {
                Text(child.type.displayName)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(hex: "3c3c3c"))
                    .cornerRadius(3)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Delete
            Button {
                viewModel.removeNode(id: child.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "f48771"))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            viewModel.selectedId == child.id ? Color(hex: "094771") : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture { viewModel.selectedId = child.id }
    }

    private func commitKey() {
        if !editKey.isEmpty { viewModel.setKey(id: child.id, newKey: editKey) }
        isEditingKey = false
    }

    private func commitValue() {
        viewModel.setValueFromText(id: child.id, text: editValue)
        isEditingValue = false
    }
}

// MARK: - Array Form Content

private struct ArrayFormContent: View {
    let node: TreeNode
    @EnvironmentObject var viewModel: EditorViewModel

    var body: some View {
        List {
            ForEach(node.children) { child in
                ArrayItemRow(child: child, parentId: node.id)
            }
            .onMove { from, to in
                if let idx = from.first {
                    viewModel.reorderChildren(parentId: node.id, fromIndex: idx, toIndex: to > idx ? to - 1 : to)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(hex: "252526"))
    }
}

private struct ArrayItemRow: View {
    let child: TreeNode
    let parentId: UUID
    @EnvironmentObject var viewModel: EditorViewModel

    @State private var editValue = ""
    @State private var isEditingValue = false
    @FocusState private var valueFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("[\(child.key)]")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(hex: "858585"))
                .frame(width: 50, alignment: .trailing)

            if child.isLeaf {
                if isEditingValue {
                    TextField("Value", text: $editValue)
                        .textFieldStyle(.roundedBorder)
                        .focused($valueFocused)
                        .onSubmit { commitValue() }
                        .onExitCommand { isEditingValue = false }
                } else {
                    Text(child.displayValue)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(child.type.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture(count: 2) {
                            editValue = child.primitive?.editString ?? ""
                            isEditingValue = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { valueFocused = true }
                        }
                }
            } else {
                Button {
                    viewModel.selectedId = child.id
                    viewModel.expandedIds.insert(child.id)
                } label: {
                    Text(child.displayValue)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(hex: "007acc"))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            Menu {
                ForEach(NodeType.allCases) { type in
                    Button {
                        viewModel.changeType(id: child.id, to: type)
                    } label: {
                        Label(type.displayName, systemImage: type == child.type ? "checkmark" : "")
                    }
                }
            } label: {
                Text(child.type.displayName)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(hex: "3c3c3c"))
                    .cornerRadius(3)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button { viewModel.removeNode(id: child.id) } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "f48771"))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(viewModel.selectedId == child.id ? Color(hex: "094771") : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.selectedId = child.id }
    }

    private func commitValue() {
        viewModel.setValueFromText(id: child.id, text: editValue)
        isEditingValue = false
    }
}

// MARK: - Primitive Form Content

private struct PrimitiveFormContent: View {
    let node: TreeNode
    @EnvironmentObject var viewModel: EditorViewModel

    @State private var editValue = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Type selector
            HStack {
                Text("Type")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)

                Picker("", selection: Binding(
                    get: { node.type },
                    set: { viewModel.changeType(id: node.id, to: $0) }
                )) {
                    ForEach([NodeType.string, .number, .boolean, .null]) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Value editor — frame ensures inspector height stays stable across type changes
            HStack(alignment: .top) {
                Text("Value")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)

                switch node.type {
                case .boolean:
                    Toggle("", isOn: Binding(
                        get: { node.primitive?.boolValue ?? false },
                        set: { viewModel.setValue(id: node.id, primitive: .boolean($0)) }
                    ))
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)

                case .null:
                    Text("null")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(node.type.color)
                        .frame(maxWidth: .infinity, alignment: .leading)

                case .number:
                    TextField("Number", text: $editValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                        .onAppear { editValue = node.primitive?.numberString ?? "0" }
                        .onChange(of: node.id) { _ in editValue = node.primitive?.numberString ?? "0" }
                        .onSubmit {
                            viewModel.setValue(id: node.id, primitive: .number(Double(editValue) ?? 0))
                        }

                case .string:
                    TextEditor(text: Binding(
                        get: { node.primitive?.stringValue ?? "" },
                        set: { viewModel.setValue(id: node.id, primitive: .string($0)) }
                    ))
                    .font(.system(size: 13, design: .monospaced))
                    .frame(minHeight: 80)
                    .border(Color(hex: "3c3c3c"), width: 1)

                default:
                    EmptyView()
                }
            }
            .frame(minHeight: 80, alignment: .top)

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Empty Form

private struct EmptyFormView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "curlybraces")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "858585"))
            Text("Select a node to inspect")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "858585"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "252526"))
    }
}

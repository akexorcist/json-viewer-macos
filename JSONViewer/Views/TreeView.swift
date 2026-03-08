import SwiftUI

// MARK: - Tree View

struct TreeView: View {
    @EnvironmentObject var viewModel: EditorViewModel

    var body: some View {
        GeometryReader { geo in
            ScrollView([.vertical, .horizontal]) {
                ScrollViewReader { proxy in
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.visibleNodes, id: \.node.id) { item in
                            TreeNodeRow(node: item.node, depth: item.depth)
                                .id(item.node.id)
                        }
                    }
                    .padding(.vertical, 4)
                    // Ensure content is at least as wide as the view so Spacers in rows
                    // fill correctly, but can grow wider to enable horizontal scrolling.
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height, alignment: .topLeading)
                    .onChange(of: viewModel.selectedId) { id in
                        if let id = id {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                    .onChange(of: viewModel.currentMatchId) { id in
                        if let id = id {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .background(Color(hex: "1e1e1e"))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tree Node Row

struct TreeNodeRow: View {
    let node: TreeNode
    let depth: Int

    @EnvironmentObject var viewModel: EditorViewModel

    @State private var isEditingKey = false
    @State private var isEditingValue = false
    @State private var editKeyText = ""
    @State private var editValueText = ""
    @FocusState private var keyFocused: Bool
    @FocusState private var valueFocused: Bool

    private var isSelected: Bool { viewModel.selectedId == node.id }
    private var isExpanded: Bool { viewModel.expandedIds.contains(node.id) }
    private var isSearchMatch: Bool { viewModel.searchMatchIds.contains(node.id) }
    private var isCurrentMatch: Bool { viewModel.currentMatchId == node.id }

    var body: some View {
        HStack(spacing: 0) {
            // Indentation
            Spacer()
                .frame(width: CGFloat(depth) * 16 + 4)

            // Expand/Collapse button — full row height for easy clicking
            if node.type.isContainer {
                Button {
                    viewModel.toggleExpanded(node.id)
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(hex: "858585"))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 22)
            }

            // Key
            if !node.key.isEmpty {
                if isEditingKey {
                    TextField("", text: $editKeyText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color(hex: "9cdcfe"))
                        .frame(minWidth: 40)
                        .focused($keyFocused)
                        .onSubmit { commitKeyEdit() }
                        .onExitCommand { cancelKeyEdit() }
                } else {
                    Text(node.key)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(
                            isCurrentMatch ? Color(hex: "ffcc00") :
                            isSearchMatch ? Color(hex: "9cdcfe").opacity(0.6) :
                            Color(hex: "9cdcfe")
                        )
                        .fixedSize(horizontal: true, vertical: false)
                        .simultaneousGesture(TapGesture(count: 2).onEnded {
                            if node.type.isContainer {
                                viewModel.toggleExpanded(node.id)
                            } else {
                                startKeyEdit()
                            }
                        })
                }

                Text(":")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(hex: "858585"))
                    .padding(.horizontal, 2)
            }

            // Value
            if node.isLeaf {
                if isEditingValue {
                    TextField("", text: $editValueText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(node.type.color)
                        .frame(minWidth: 60)
                        .focused($valueFocused)
                        .onSubmit { commitValueEdit() }
                        .onExitCommand { cancelValueEdit() }
                } else {
                    Text(node.displayValue)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(
                            isCurrentMatch ? Color(hex: "ffcc00") :
                            isSearchMatch ? node.type.color.opacity(0.6) :
                            node.type.color
                        )
                        .fixedSize(horizontal: true, vertical: false)
                        .simultaneousGesture(TapGesture(count: 2).onEnded { startValueEdit() })
                }
            } else {
                // Container: show preview count, click to expand/collapse
                Text(node.displayValue)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(hex: "858585"))
                    .fixedSize(horizontal: true, vertical: false)
                    .onTapGesture { viewModel.toggleExpanded(node.id) }
            }

            Spacer()

            // Add button for containers (shown on hover via overlay)
            if node.type.isContainer {
                Button {
                    viewModel.addChild(to: node.id)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "858585"))
                        .padding(4)
                }
                .buttonStyle(.plain)
                .opacity(isSelected ? 1 : 0)
            }

            Spacer().frame(width: 4)
        }
        .frame(height: 22)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedId = node.id
        }
        .contextMenu { contextMenu }
        .keyboardShortcut(.delete, modifiers: [])
    }

    // MARK: - Inline Edit

    private func startKeyEdit() {
        editKeyText = node.key
        isEditingKey = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { keyFocused = true }
    }

    private func commitKeyEdit() {
        if !editKeyText.isEmpty && editKeyText != node.key {
            viewModel.setKey(id: node.id, newKey: editKeyText)
        }
        isEditingKey = false
    }

    private func cancelKeyEdit() {
        isEditingKey = false
    }

    private func startValueEdit() {
        editValueText = node.primitive?.editString ?? ""
        isEditingValue = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { valueFocused = true }
    }

    private func commitValueEdit() {
        viewModel.setValueFromText(id: node.id, text: editValueText)
        isEditingValue = false
    }

    private func cancelValueEdit() {
        isEditingValue = false
    }

    // MARK: - Background

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            Color(hex: "094771")
        } else if isCurrentMatch {
            Color(hex: "3a3520")
        } else if isSearchMatch {
            Color(hex: "2a2520")
        } else {
            Color.clear
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenu: some View {
        Button("Add Child") { viewModel.addChild(to: node.id) }
            .disabled(!node.type.isContainer)

        Divider()

        Button("Duplicate") { viewModel.duplicateNode(id: node.id) }

        Button("Delete", role: .destructive) { viewModel.removeNode(id: node.id) }
            .disabled(node.key.isEmpty && node.id == viewModel.root?.id)

        Divider()

        Menu("Change Type to…") {
            ForEach(NodeType.allCases) { type in
                Button {
                    viewModel.changeType(id: node.id, to: type)
                } label: {
                    Label(type.displayName, systemImage: type == node.type ? "checkmark" : "")
                }
                .disabled(type == node.type)
            }
        }

        Divider()

        Button("Copy Path") { viewModel.copyNodePath(id: node.id) }
        Button("Copy Value as JSON") { viewModel.copyNodeValue(id: node.id) }
    }
}

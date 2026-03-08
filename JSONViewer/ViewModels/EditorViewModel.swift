import Foundation
import SwiftUI
import Combine

// MARK: - Editor View Model

@MainActor
final class EditorViewModel: ObservableObject {

    // MARK: - Tree State

    @Published var root: TreeNode?
    @Published var parseError: String?

    // MARK: - Selection & Expansion

    @Published var selectedId: UUID?
    @Published var expandedIds: Set<UUID> = []

    // MARK: - Search

    @Published var searchQuery: String = "" {
        didSet { runSearch() }
    }
    @Published var searchMatches: [SearchMatch] = []
    @Published var currentMatchIndex: Int = 0

    // MARK: - JSON Output (synced to document)

    @Published var serializedJson: String = ""

    /// Increments every time the tree changes from the tree/inspector side (not from raw editing).
    /// RawJsonView observes this to know when to pull in the new serialized text.
    @Published private(set) var treeVersion: Int = 0

    // MARK: - History

    private var history = History<TreeNode>()
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    var selectedNode: TreeNode? {
        guard let id = selectedId, let root = root else { return nil }
        return root.find(id: id)
    }

    var visibleNodes: [(node: TreeNode, depth: Int)] {
        guard let root = root else { return [] }
        return root.flatVisible(expandedIds: expandedIds, depth: 0)
    }

    var searchMatchIds: Set<UUID> {
        Set(searchMatches.map { $0.nodeId })
    }

    var currentMatchId: UUID? {
        guard currentMatchIndex < searchMatches.count else { return nil }
        return searchMatches[currentMatchIndex].nodeId
    }

    // MARK: - Load

    func loadFromText(_ text: String) {
        do {
            let newRoot = try TreeBuilder.parse(text)
            root = newRoot
            serializedJson = text
            parseError = nil
            history.reset()
            selectedId = nil
            searchQuery = ""
            searchMatches = []
            // Expand root so the first level of children is visible
            expandedIds = newRoot.type.isContainer ? [newRoot.id] : []
            treeVersion += 1
            syncHistoryState()
        } catch {
            parseError = error.localizedDescription
        }
    }

    // Rebuild tree from raw JSON while preserving expanded/selected state by path
    func updateFromRaw(_ text: String) {
        do {
            let newRoot = try TreeBuilder.parse(text)

            if let oldRoot = root {
                // Capture paths of currently expanded and selected nodes
                let expandedPaths = expandedIds.compactMap { id -> String? in
                    oldRoot.find(id: id).map { pathString(of: $0, in: oldRoot) }
                }
                let selectedPath = selectedId.flatMap { id -> String? in
                    oldRoot.find(id: id).map { pathString(of: $0, in: oldRoot) }
                }
                root = newRoot
                expandedIds = resolveIds(for: Set(expandedPaths), in: newRoot)
                selectedId = selectedPath.flatMap { resolveId(for: $0, in: newRoot) }
            } else {
                root = newRoot
                expandedIds = newRoot.type.isContainer ? [newRoot.id] : []
            }

            serializedJson = text
            parseError = nil
            runSearch()
        } catch {
            parseError = error.localizedDescription
        }
    }

    // Build a "/" separated path string for a node within a tree
    private func pathString(of target: TreeNode, in root: TreeNode) -> String {
        var components: [String] = []
        func walk(_ node: TreeNode) -> Bool {
            if node.id == target.id { return true }
            for child in node.children {
                if walk(child) { components.insert(child.key, at: 0); return true }
            }
            return false
        }
        _ = walk(root)
        return "/" + components.joined(separator: "/")
    }

    // Find node IDs in a tree that match the given path strings
    private func resolveIds(for paths: Set<String>, in root: TreeNode) -> Set<UUID> {
        var result = Set<UUID>()
        func walk(_ node: TreeNode, path: String) {
            if paths.contains(path) { result.insert(node.id) }
            for child in node.children {
                walk(child, path: path == "/" ? "/\(child.key)" : "\(path)/\(child.key)")
            }
        }
        walk(root, path: "/")
        return result
    }

    private func resolveId(for path: String, in root: TreeNode) -> UUID? {
        resolveIds(for: [path], in: root).first
    }

    // MARK: - Operations

    func setValueFromText(id: UUID, text: String) {
        guard let node = root?.find(id: id) else { return }
        let newRoot = TreeOperations.setValueFromText(root: root!, id: id, text: text, type: node.type)
        commit(newRoot)
    }

    func setValue(id: UUID, primitive: JsonPrimitive) {
        guard root != nil else { return }
        let newRoot = TreeOperations.setValue(root: root!, id: id, primitive: primitive)
        commit(newRoot)
    }

    func setKey(id: UUID, newKey: String) {
        guard root != nil else { return }
        let newRoot = TreeOperations.setKey(root: root!, id: id, newKey: newKey)
        commit(newRoot)
    }

    func addChild(to parentId: UUID) {
        guard root != nil else { return }
        let newRoot = TreeOperations.addChild(root: root!, parentId: parentId)
        if let parent = newRoot.find(id: parentId) {
            expandedIds.insert(parentId)
            selectedId = parent.children.last?.id
        }
        commit(newRoot)
    }

    func removeNode(id: UUID) {
        guard root != nil else { return }
        if selectedId == id { selectedId = nil }
        let newRoot = TreeOperations.removeNode(root: root!, id: id)
        commit(newRoot)
    }

    func removeSelected() {
        guard let id = selectedId else { return }
        removeNode(id: id)
    }

    func duplicateNode(id: UUID) {
        guard root != nil else { return }
        let newRoot = TreeOperations.duplicateNode(root: root!, id: id)
        commit(newRoot)
    }

    func changeType(id: UUID, to type: NodeType) {
        guard root != nil else { return }
        let newRoot = TreeOperations.changeType(root: root!, id: id, newType: type)
        commit(newRoot)
    }

    func reorderChildren(parentId: UUID, fromIndex: Int, toIndex: Int) {
        guard root != nil else { return }
        let newRoot = TreeOperations.reorderChildren(root: root!, parentId: parentId, fromIndex: fromIndex, toIndex: toIndex)
        commit(newRoot)
    }

    // MARK: - Expand / Collapse

    func toggleExpanded(_ id: UUID) {
        if expandedIds.contains(id) {
            expandedIds.remove(id)
        } else {
            expandedIds.insert(id)
        }
    }

    func expandAll() {
        guard let root = root else { return }
        var ids = Set<UUID>()
        func collect(_ node: TreeNode) {
            if node.type.isContainer { ids.insert(node.id) }
            for child in node.children { collect(child) }
        }
        collect(root)
        expandedIds = ids
    }

    func collapseAll() {
        expandedIds = []
    }

    // MARK: - Undo / Redo

    func undo() {
        guard let current = root else { return }
        if let prev = history.undo(current: current) {
            root = prev
            updateSerialized()
            syncHistoryState()
        }
    }

    func redo() {
        guard let current = root else { return }
        if let next = history.redo(current: current) {
            root = next
            updateSerialized()
            syncHistoryState()
        }
    }

    // MARK: - Search

    func nextMatch() {
        guard !searchMatches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + 1) % searchMatches.count
        scrollToCurrentMatch()
    }

    func previousMatch() {
        guard !searchMatches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex - 1 + searchMatches.count) % searchMatches.count
        scrollToCurrentMatch()
    }

    private func runSearch() {
        guard let root = root else {
            searchMatches = []
            return
        }
        if searchQuery.isEmpty {
            searchMatches = []
        } else {
            searchMatches = Search.searchNodes(root: root, query: searchQuery)
            if !searchMatches.isEmpty {
                currentMatchIndex = 0
                scrollToCurrentMatch()
            }
        }
    }

    private func scrollToCurrentMatch() {
        guard currentMatchIndex < searchMatches.count, let root = root else { return }
        let match = searchMatches[currentMatchIndex]
        let ancestors = Search.getAncestorIds(root: root, nodeId: match.nodeId)
        expandedIds.formUnion(ancestors)
        selectedId = match.nodeId
    }

    // MARK: - Clipboard

    func copyNodePath(id: UUID) {
        guard let root = root, let node = root.find(id: id) else { return }
        let path = node.path(in: root)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path.isEmpty ? "/" : path, forType: .string)
    }

    func copyNodeValue(id: UUID) {
        guard let root = root, let node = root.find(id: id) else { return }
        let json = TreeBuilder.serialize(node)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)
    }

    // MARK: - Private

    private func commit(_ newRoot: TreeNode) {
        if let current = root {
            history.push(current)
        }
        root = newRoot
        treeVersion += 1
        updateSerialized()
        runSearch()
        syncHistoryState()
    }

    private func updateSerialized() {
        guard let root = root else { return }
        serializedJson = TreeBuilder.serialize(root)
    }

    private func syncHistoryState() {
        canUndo = history.canUndo
        canRedo = history.canRedo
    }
}

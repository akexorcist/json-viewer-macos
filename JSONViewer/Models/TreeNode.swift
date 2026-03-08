import Foundation

// MARK: - Tree Node

struct TreeNode: Identifiable, Equatable {
    let id: UUID
    var key: String           // property key (object), index string (array), "" for root
    var type: NodeType
    var primitive: JsonPrimitive?   // non-nil for leaf nodes
    var children: [TreeNode]        // non-empty for object/array

    // MARK: - Convenience init

    init(id: UUID = UUID(), key: String, type: NodeType, primitive: JsonPrimitive? = nil, children: [TreeNode] = []) {
        self.id = id
        self.key = key
        self.type = type
        self.primitive = primitive
        self.children = children
    }

    // MARK: - Computed

    var isLeaf: Bool { !type.isContainer }

    var displayValue: String {
        switch type {
        case .string:
            let s = primitive?.stringValue ?? ""
            return "\"\(s)\""
        case .number:
            return primitive?.numberString ?? "0"
        case .boolean:
            return primitive?.boolValue == true ? "true" : "false"
        case .null:
            return "null"
        case .object:
            let count = children.count
            return "{\(count) \(count == 1 ? "key" : "keys")}"
        case .array:
            let count = children.count
            return "[\(count) \(count == 1 ? "item" : "items")]"
        }
    }

    // Path built dynamically; we store a helper
    func path(in tree: TreeNode) -> String {
        pathComponents(in: tree)
            .map { "/\($0)" }
            .joined()
    }

    private func pathComponents(in node: TreeNode) -> [String] {
        if node.id == self.id { return [] }
        for child in node.children {
            if child.id == self.id { return [child.key] }
            var sub = child.pathComponents(in: child)
            if !sub.isEmpty {
                sub.insert(child.key, at: 0)
                return sub
            }
        }
        return []
    }
}

// MARK: - Tree Lookup

extension TreeNode {
    /// Find a node by ID (depth-first)
    func find(id: UUID) -> TreeNode? {
        if self.id == id { return self }
        for child in children {
            if let found = child.find(id: id) { return found }
        }
        return nil
    }

    /// Collect all ancestor IDs for the given node ID
    func ancestorIds(of targetId: UUID) -> Set<UUID> {
        var result = Set<UUID>()
        func walk(_ node: TreeNode, path: [UUID]) -> Bool {
            if node.id == targetId {
                result = Set(path)
                return true
            }
            for child in node.children {
                if walk(child, path: path + [node.id]) { return true }
            }
            return false
        }
        _ = walk(self, path: [])
        return result
    }

    /// Build a flat array of visible nodes given the set of expanded IDs
    func flatVisible(expandedIds: Set<UUID>, depth: Int = 0) -> [(node: TreeNode, depth: Int)] {
        var result: [(TreeNode, Int)] = [(self, depth)]
        if expandedIds.contains(id) {
            for child in children {
                result.append(contentsOf: child.flatVisible(expandedIds: expandedIds, depth: depth + 1))
            }
        }
        return result
    }

    /// Convert the entire tree back to ParsedJson (for serialization)
    func toParsedJson() -> ParsedJson {
        switch type {
        case .string:
            return .string(primitive?.stringValue ?? "")
        case .number:
            return .number(primitive?.doubleValue ?? 0)
        case .boolean:
            return .boolean(primitive?.boolValue ?? false)
        case .null:
            return .null
        case .array:
            return .array(children.map { $0.toParsedJson() })
        case .object:
            return .object(children.map { (key: $0.key, value: $0.toParsedJson()) })
        }
    }
}

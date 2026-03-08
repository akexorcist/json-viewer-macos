import Foundation

// MARK: - Tree Operations (pure functions returning new tree root)

enum TreeOperations {

    // MARK: - Set Primitive Value

    static func setValue(root: TreeNode, id: UUID, primitive: JsonPrimitive) -> TreeNode {
        updateNode(root, id: id) { node in
            var n = node
            n.primitive = primitive
            // Keep same type unless null
            return n
        }
    }

    // MARK: - Set Value from String (parses the string into appropriate primitive)

    static func setValueFromText(root: TreeNode, id: UUID, text: String, type: NodeType) -> TreeNode {
        let prim: JsonPrimitive
        switch type {
        case .string:
            prim = .string(text)
        case .number:
            prim = .number(Double(text) ?? 0)
        case .boolean:
            prim = .boolean(text.lowercased() == "true" || text == "1")
        case .null:
            prim = .null
        default:
            return root
        }
        return updateNode(root, id: id) { node in
            var n = node
            n.primitive = prim
            return n
        }
    }

    // MARK: - Set Key

    static func setKey(root: TreeNode, id: UUID, newKey: String) -> TreeNode {
        updateNode(root, id: id) { node in
            var n = node
            n.key = newKey
            return n
        }
    }

    // MARK: - Add Child

    static func addChild(root: TreeNode, parentId: UUID) -> TreeNode {
        updateNode(root, id: parentId) { parent in
            var p = parent
            let newChild = TreeBuilder.defaultChild(for: parent)
            p.children.append(newChild)
            return p
        }
    }

    // MARK: - Remove Node

    static func removeNode(root: TreeNode, id: UUID) -> TreeNode {
        // Can't remove root
        if root.id == id { return root }
        return removeFromChildren(root, id: id)
    }

    private static func removeFromChildren(_ node: TreeNode, id: UUID) -> TreeNode {
        if node.children.contains(where: { $0.id == id }) {
            var updated = node
            updated.children = node.children.filter { $0.id != id }
            if node.type == .array {
                updated.children = reindexArray(updated.children)
            }
            return updated
        }
        var updated = node
        updated.children = node.children.map { removeFromChildren($0, id: id) }
        return updated
    }

    // MARK: - Duplicate Node

    static func duplicateNode(root: TreeNode, id: UUID) -> TreeNode {
        duplicateInChildren(root, id: id)
    }

    private static func duplicateInChildren(_ node: TreeNode, id: UUID) -> TreeNode {
        if let idx = node.children.firstIndex(where: { $0.id == id }) {
            var updated = node
            var copy = deepCopy(node.children[idx])
            if node.type == .array {
                copy.key = "\(idx + 1)"
            } else {
                copy.key = "\(copy.key)_copy"
            }
            updated.children.insert(copy, at: idx + 1)
            if node.type == .array {
                updated.children = reindexArray(updated.children)
            }
            return updated
        }
        var updated = node
        updated.children = node.children.map { duplicateInChildren($0, id: id) }
        return updated
    }

    private static func deepCopy(_ node: TreeNode) -> TreeNode {
        TreeNode(
            key: node.key,
            type: node.type,
            primitive: node.primitive,
            children: node.children.map { deepCopy($0) }
        )
    }

    // MARK: - Change Type

    static func changeType(root: TreeNode, id: UUID, newType: NodeType) -> TreeNode {
        updateNode(root, id: id) { node in
            convertNode(node, to: newType)
        }
    }

    private static func convertNode(_ node: TreeNode, to newType: NodeType) -> TreeNode {
        switch newType {
        case .string:
            let s: String
            switch node.type {
            case .string: return node
            case .number: s = node.primitive?.numberString ?? "0"
            case .boolean: s = node.primitive?.boolValue == true ? "true" : "false"
            case .null: s = "null"
            case .object, .array: s = TreeBuilder.serialize(node)
            }
            return TreeNode(id: node.id, key: node.key, type: .string, primitive: .string(s))

        case .number:
            let n: Double
            switch node.type {
            case .number: return node
            case .string: n = Double(node.primitive?.stringValue ?? "") ?? 0
            case .boolean: n = node.primitive?.boolValue == true ? 1 : 0
            default: n = 0
            }
            return TreeNode(id: node.id, key: node.key, type: .number, primitive: .number(n))

        case .boolean:
            let b: Bool
            switch node.type {
            case .boolean: return node
            case .string: b = (node.primitive?.stringValue ?? "").lowercased() == "true"
            case .number: b = (node.primitive?.doubleValue ?? 0) != 0
            default: b = false
            }
            return TreeNode(id: node.id, key: node.key, type: .boolean, primitive: .boolean(b))

        case .null:
            return TreeNode(id: node.id, key: node.key, type: .null, primitive: .null)

        case .object:
            if node.type == .object { return node }
            if node.type == .array {
                let children = node.children.enumerated().map { i, child in
                    TreeNode(key: "\(i)", type: child.type, primitive: child.primitive, children: child.children)
                }
                return TreeNode(id: node.id, key: node.key, type: .object, children: children)
            }
            return TreeNode(id: node.id, key: node.key, type: .object, children: [])

        case .array:
            if node.type == .array { return node }
            if node.type == .object {
                let children = node.children.enumerated().map { i, child in
                    TreeNode(key: "\(i)", type: child.type, primitive: child.primitive, children: child.children)
                }
                return TreeNode(id: node.id, key: node.key, type: .array, children: children)
            }
            if node.isLeaf {
                let child = TreeNode(key: "0", type: node.type, primitive: node.primitive)
                return TreeNode(id: node.id, key: node.key, type: .array, children: [child])
            }
            return TreeNode(id: node.id, key: node.key, type: .array, children: [])
        }
    }

    // MARK: - Reorder Children (drag-and-drop)

    static func reorderChildren(root: TreeNode, parentId: UUID, fromIndex: Int, toIndex: Int) -> TreeNode {
        updateNode(root, id: parentId) { parent in
            var p = parent
            guard fromIndex >= 0, fromIndex < p.children.count,
                  toIndex >= 0, toIndex < p.children.count,
                  fromIndex != toIndex else { return parent }
            let item = p.children.remove(at: fromIndex)
            p.children.insert(item, at: toIndex)
            if p.type == .array {
                p.children = reindexArray(p.children)
            }
            return p
        }
    }

    // MARK: - Helpers

    private static func updateNode(_ node: TreeNode, id: UUID, update: (TreeNode) -> TreeNode) -> TreeNode {
        if node.id == id { return update(node) }
        var updated = node
        updated.children = node.children.map { updateNode($0, id: id, update: update) }
        return updated
    }

    private static func reindexArray(_ children: [TreeNode]) -> [TreeNode] {
        children.enumerated().map { i, child in
            var c = child
            c.key = "\(i)"
            return c
        }
    }

}

import Foundation

// MARK: - Tree Builder

enum TreeBuilder {

    // MARK: - Parse JSON string → TreeNode

    static func parse(_ text: String) throws -> TreeNode {
        let parser = JSONParser(text)
        let parsed = try parser.parse()
        return buildNode(from: parsed, key: "")
    }

    private static func buildNode(from parsed: ParsedJson, key: String) -> TreeNode {
        switch parsed {
        case .string(let s):
            return TreeNode(key: key, type: .string, primitive: .string(s))
        case .number(let n):
            return TreeNode(key: key, type: .number, primitive: .number(n))
        case .boolean(let b):
            return TreeNode(key: key, type: .boolean, primitive: .boolean(b))
        case .null:
            return TreeNode(key: key, type: .null, primitive: .null)
        case .array(let items):
            let children = items.enumerated().map { i, item in
                buildNode(from: item, key: "\(i)")
            }
            return TreeNode(key: key, type: .array, children: children)
        case .object(let pairs):
            let children = pairs.map { pair in
                buildNode(from: pair.value, key: pair.key)
            }
            return TreeNode(key: key, type: .object, children: children)
        }
    }

    // MARK: - TreeNode → JSON string

    static func serialize(_ node: TreeNode, indent: Int = 0) -> String {
        serializeJson(node.toParsedJson(), indent: indent)
    }

    // MARK: - Default new child value for a container

    static func defaultChild(for parent: TreeNode) -> TreeNode {
        switch parent.type {
        case .object:
            return TreeNode(key: "newKey", type: .string, primitive: .string(""))
        case .array:
            return TreeNode(key: "\(parent.children.count)", type: .null, primitive: .null)
        default:
            return TreeNode(key: "", type: .null, primitive: .null)
        }
    }
}

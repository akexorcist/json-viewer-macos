import Foundation

// MARK: - Search

struct SearchMatch: Equatable {
    let nodeId: UUID
}

enum Search {

    static func searchNodes(root: TreeNode, query: String) -> [SearchMatch] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let lower = query.lowercased()
        var matches: [SearchMatch] = []
        walk(root, query: lower, matches: &matches)
        return matches
    }

    private static func walk(_ node: TreeNode, query: String, matches: inout [SearchMatch]) {
        if !node.key.isEmpty && node.key.lowercased().contains(query) {
            matches.append(SearchMatch(nodeId: node.id))
        }
        if let prim = node.primitive {
            let valStr: String
            switch prim {
            case .string(let s):  valStr = s
            case .number:         valStr = prim.numberString
            case .boolean(let b): valStr = b ? "true" : "false"
            case .null:           valStr = "null"
            }
            if valStr.lowercased().contains(query) {
                matches.append(SearchMatch(nodeId: node.id))
            }
        }
        for child in node.children {
            walk(child, query: query, matches: &matches)
        }
    }

    static func getAncestorIds(root: TreeNode, nodeId: UUID) -> Set<UUID> {
        root.ancestorIds(of: nodeId)
    }
}

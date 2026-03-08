import Foundation
import SwiftUI

// MARK: - Node Type

enum NodeType: String, CaseIterable, Identifiable, Equatable {
    case string, number, boolean, null, object, array

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .string:  return "String"
        case .number:  return "Number"
        case .boolean: return "Boolean"
        case .null:    return "Null"
        case .object:  return "Object"
        case .array:   return "Array"
        }
    }

    var color: Color {
        switch self {
        case .string:          return Color(hex: "ce9178")
        case .number:          return Color(hex: "b5cea8")
        case .boolean:         return Color(hex: "569cd6")
        case .null:            return Color(hex: "569cd6")
        case .object, .array:  return Color(hex: "cccccc")
        }
    }

    var isContainer: Bool { self == .object || self == .array }
}

// MARK: - Primitive Value

enum JsonPrimitive: Equatable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case null

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var doubleValue: Double? {
        if case .number(let n) = self { return n }
        return nil
    }

    var boolValue: Bool? {
        if case .boolean(let b) = self { return b }
        return nil
    }

    var numberString: String {
        guard case .number(let n) = self else { return "0" }
        if n.truncatingRemainder(dividingBy: 1) == 0,
           !n.isInfinite, !n.isNaN,
           n >= -9_007_199_254_740_992, n <= 9_007_199_254_740_992 {
            return String(format: "%.0f", n)
        }
        return String(n)
    }

    var editString: String {
        switch self {
        case .string(let s):  return s
        case .number:         return numberString
        case .boolean(let b): return b ? "true" : "false"
        case .null:           return "null"
        }
    }
}

// MARK: - Parsed JSON (intermediate for parsing with ordered objects)

indirect enum ParsedJson {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case null
    case array([ParsedJson])
    case object([(key: String, value: ParsedJson)])
}

// MARK: - JSON Parse Error

enum JSONParseError: Error, LocalizedError {
    case unexpectedEndOfInput
    case unexpectedCharacter(Character)
    case invalidNumber(String)
    case expectedCommaOrBracket
    case expectedCommaOrBrace
    case expectedString
    case expectedColon

    var errorDescription: String? {
        switch self {
        case .unexpectedEndOfInput:    return "Unexpected end of input"
        case .unexpectedCharacter(let c): return "Unexpected character: '\(c)'"
        case .invalidNumber(let s):    return "Invalid number: \(s)"
        case .expectedCommaOrBracket:  return "Expected ',' or ']'"
        case .expectedCommaOrBrace:    return "Expected ',' or '}'"
        case .expectedString:          return "Expected string key"
        case .expectedColon:           return "Expected ':'"
        }
    }
}

// MARK: - JSON Parser (preserves object key ordering)

final class JSONParser {
    private let chars: [Character]
    private var idx: Int = 0

    init(_ input: String) {
        chars = Array(input)
    }

    private var current: Character? { idx < chars.count ? chars[idx] : nil }
    private func advance() { idx += 1 }

    private func skipWhitespace() {
        while let c = current, c.isWhitespace { advance() }
    }

    func parse() throws -> ParsedJson {
        skipWhitespace()
        let result = try parseValue()
        skipWhitespace()
        return result
    }

    private func parseValue() throws -> ParsedJson {
        guard let c = current else { throw JSONParseError.unexpectedEndOfInput }
        switch c {
        case "{":          return try parseObject()
        case "[":          return try parseArray()
        case "\"":         return try parseString()
        case "t":          return try parseLiteral("true",  .boolean(true))
        case "f":          return try parseLiteral("false", .boolean(false))
        case "n":          return try parseLiteral("null",  .null)
        case "-", "0"..."9": return try parseNumber()
        default: throw JSONParseError.unexpectedCharacter(c)
        }
    }

    private func parseLiteral(_ literal: String, _ result: ParsedJson) throws -> ParsedJson {
        for ch in literal {
            guard current == ch else {
                throw JSONParseError.unexpectedCharacter(current ?? " ")
            }
            advance()
        }
        return result
    }

    private func parseString() throws -> ParsedJson {
        guard current == "\"" else {
            throw JSONParseError.unexpectedCharacter(current ?? " ")
        }
        advance()
        var result = ""
        while let c = current, c != "\"" {
            if c == "\\" {
                advance()
                guard let esc = current else { throw JSONParseError.unexpectedEndOfInput }
                switch esc {
                case "\"": result += "\""; advance()
                case "\\": result += "\\"; advance()
                case "/":  result += "/";  advance()
                case "n":  result += "\n"; advance()
                case "r":  result += "\r"; advance()
                case "t":  result += "\t"; advance()
                case "b":  result += "\u{08}"; advance()
                case "f":  result += "\u{0C}"; advance()
                case "u":
                    advance()
                    var hex = ""
                    for _ in 0..<4 {
                        guard let h = current else { throw JSONParseError.unexpectedEndOfInput }
                        hex += String(h); advance()
                    }
                    if let cp = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(cp) {
                        result += String(scalar)
                    }
                default: throw JSONParseError.unexpectedCharacter(esc)
                }
            } else {
                result += String(c); advance()
            }
        }
        guard current == "\"" else { throw JSONParseError.unexpectedEndOfInput }
        advance()
        return .string(result)
    }

    private func parseNumber() throws -> ParsedJson {
        var s = ""
        if current == "-" { s += "-"; advance() }
        while let c = current, c.isNumber { s += String(c); advance() }
        if current == "." {
            s += "."; advance()
            while let c = current, c.isNumber { s += String(c); advance() }
        }
        if current == "e" || current == "E" {
            s += String(current!); advance()
            if current == "+" || current == "-" { s += String(current!); advance() }
            while let c = current, c.isNumber { s += String(c); advance() }
        }
        guard let n = Double(s) else { throw JSONParseError.invalidNumber(s) }
        return .number(n)
    }

    private func parseArray() throws -> ParsedJson {
        advance() // [
        skipWhitespace()
        var items: [ParsedJson] = []
        if current == "]" { advance(); return .array(items) }
        while true {
            skipWhitespace()
            items.append(try parseValue())
            skipWhitespace()
            if current == "]" { advance(); break }
            guard current == "," else { throw JSONParseError.expectedCommaOrBracket }
            advance()
        }
        return .array(items)
    }

    private func parseObject() throws -> ParsedJson {
        advance() // {
        skipWhitespace()
        var pairs: [(key: String, value: ParsedJson)] = []
        if current == "}" { advance(); return .object(pairs) }
        while true {
            skipWhitespace()
            guard case .string(let key) = try parseString() else {
                throw JSONParseError.expectedString
            }
            skipWhitespace()
            guard current == ":" else { throw JSONParseError.expectedColon }
            advance()
            skipWhitespace()
            let val = try parseValue()
            pairs.append((key: key, value: val))
            skipWhitespace()
            if current == "}" { advance(); break }
            guard current == "," else { throw JSONParseError.expectedCommaOrBrace }
            advance()
        }
        return .object(pairs)
    }
}

// MARK: - JSON Serialization

func serializeJson(_ value: ParsedJson, indent: Int = 0) -> String {
    let sp = String(repeating: "  ", count: indent)
    let isp = String(repeating: "  ", count: indent + 1)
    switch value {
    case .string(let s): return "\"\(escapeJsonString(s))\""
    case .number(let n):
        if n.truncatingRemainder(dividingBy: 1) == 0,
           !n.isInfinite, !n.isNaN,
           n >= -9_007_199_254_740_992, n <= 9_007_199_254_740_992 {
            return String(format: "%.0f", n)
        }
        return String(n)
    case .boolean(let b): return b ? "true" : "false"
    case .null:            return "null"
    case .array(let items):
        if items.isEmpty { return "[]" }
        let rows = items.map { isp + serializeJson($0, indent: indent + 1) }
        return "[\n\(rows.joined(separator: ",\n"))\n\(sp)]"
    case .object(let pairs):
        if pairs.isEmpty { return "{}" }
        let rows = pairs.map { "\(isp)\"\(escapeJsonString($0.key))\": \(serializeJson($0.value, indent: indent + 1))" }
        return "{\n\(rows.joined(separator: ",\n"))\n\(sp)}"
    }
}

func escapeJsonString(_ s: String) -> String {
    s
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\r", with: "\\r")
        .replacingOccurrences(of: "\t", with: "\\t")
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

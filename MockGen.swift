//
//  MockGen.swift
//  MockGen
//
//  Created by MockGen on 2.09.2026.
//  Copyright © 2026 MockGen. All rights reserved.
//

import Foundation

// MARK: - Models

struct ProtocolMethod {
    let name: String
    let parameters: [MethodParameter]
    let returnType: String
    let isAsync: Bool
    let isThrows: Bool
    let fullSignature: String
    let originalSignature: String?
}

struct MethodParameter {
    let name: String
    let externalName: String?
    let type: String
}

struct ProtocolProperty {
    let name: String
    let type: String
    let isSettable: Bool
}

struct ProtocolDefinition {
    let name: String
    let properties: [ProtocolProperty]
    let methods: [ProtocolMethod]
}

struct MockFile {
    let name: String
    let content: String
}

// MARK: - Parser

final class MockGenParser {

    private struct CollapsedLine {
        let collapsed: String
        let original: String
    }

    func parseProtocol(_ input: String) -> ProtocolDefinition? {
        let cleaned = cleanProtocol(input)
        let collapsedLines = collapseMultilineMethods(cleaned)
        let collapsedOnly = collapsedLines.map(\.collapsed)

        guard let protocolName = extractProtocolName(from: collapsedOnly) else {
            return nil
        }

        var properties: [ProtocolProperty] = []
        var methods: [ProtocolMethod] = []

        for line in collapsedLines {
            let trimmed = line.collapsed.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.contains("var ") {
                if let property = parseProperty(trimmed) {
                    properties.append(property)
                }
            } else if trimmed.contains("func ") {
                if let method = parseMethod(trimmed, originalSignature: line.original) {
                    methods.append(method)
                }
            }
        }

        return ProtocolDefinition(
            name: protocolName,
            properties: properties,
            methods: methods
        )
    }

    // MARK: - Cleaning

    private func cleanProtocol(_ input: String) -> String {
        removeComments(from: input)
    }

    private func removeComments(from input: String) -> String {
        var result = ""
        var index = input.startIndex

        var isInsideLineComment = false
        var isInsideBlockComment = false
        var isInsideString = false
        var previousCharacter: Character?

        while index < input.endIndex {
            let character = input[index]
            let nextIndex = input.index(after: index)
            let nextCharacter = nextIndex < input.endIndex ? input[nextIndex] : nil

            if isInsideLineComment {
                if character == "\n" {
                    isInsideLineComment = false
                    result.append(character)
                }

                index = nextIndex
                previousCharacter = character
                continue
            }

            if isInsideBlockComment {
                if character == "*" && nextCharacter == "/" {
                    isInsideBlockComment = false
                    index = input.index(after: nextIndex)
                    previousCharacter = "/"
                    continue
                }

                if character == "\n" {
                    result.append("\n")
                }

                index = nextIndex
                previousCharacter = character
                continue
            }

            if character == "\"" && previousCharacter != "\\" {
                isInsideString.toggle()
                result.append(character)
                index = nextIndex
                previousCharacter = character
                continue
            }

            if !isInsideString {
                if character == "/" && nextCharacter == "/" {
                    isInsideLineComment = true
                    index = input.index(after: nextIndex)
                    previousCharacter = "/"
                    continue
                }

                if character == "/" && nextCharacter == "*" {
                    isInsideBlockComment = true
                    index = input.index(after: nextIndex)
                    previousCharacter = "*"
                    continue
                }
            }

            result.append(character)
            index = nextIndex
            previousCharacter = character
        }

        return result
    }

    // MARK: - Multiline collapsing

    private func collapseMultilineMethods(_ input: String) -> [CollapsedLine] {
        let lines = input
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        var result: [CollapsedLine] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            guard trimmed.contains("func ") else {
                result.append(
                    CollapsedLine(
                        collapsed: line,
                        original: line
                    )
                )
                index += 1
                continue
            }

            var methodLines: [String] = [line]
            var parenDepth = parenthesesDelta(in: trimmed)
            var nextIndex = index + 1

            while nextIndex < lines.count {
                let nextLine = lines[nextIndex]
                let nextTrimmed = nextLine.trimmingCharacters(in: .whitespacesAndNewlines)

                let shouldContinueBecauseParensAreOpen = parenDepth > 0
                let shouldContinueBecauseReturnIsOnNextLine =
                    parenDepth == 0 &&
                    (
                        nextTrimmed.hasPrefix("async") ||
                        nextTrimmed.hasPrefix("throws") ||
                        nextTrimmed.hasPrefix("rethrows") ||
                        nextTrimmed.hasPrefix("->") ||
                        nextTrimmed.hasPrefix("where ")
                    )

                guard shouldContinueBecauseParensAreOpen || shouldContinueBecauseReturnIsOnNextLine else {
                    break
                }

                methodLines.append(nextLine)
                parenDepth += parenthesesDelta(in: nextTrimmed)
                nextIndex += 1
            }

            let collapsed = methodLines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            let original = methodLines.joined(separator: "\n")

            result.append(
                CollapsedLine(
                    collapsed: collapsed,
                    original: original
                )
            )

            index = nextIndex
        }

        return result
    }

    private func parenthesesDelta(in string: String) -> Int {
        var delta = 0
        var isInsideString = false
        var previousCharacter: Character?

        for character in string {
            if character == "\"" && previousCharacter != "\\" {
                isInsideString.toggle()
            }

            if !isInsideString {
                if character == "(" {
                    delta += 1
                } else if character == ")" {
                    delta -= 1
                }
            }

            previousCharacter = character
        }

        return delta
    }

    // MARK: - Protocol name

    private func extractProtocolName(from lines: [String]) -> String? {
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let pattern = "\\bprotocol\\s+(\\w+)"

            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }

            let nsString = trimmed as NSString
            let fullRange = NSRange(location: 0, length: nsString.length)

            guard let match = regex.firstMatch(in: trimmed, range: fullRange),
                  let nameRange = Range(match.range(at: 1), in: trimmed) else {
                continue
            }

            return String(trimmed[nameRange])
        }

        return nil
    }

    // MARK: - Properties

    private func parseProperty(_ line: String) -> ProtocolProperty? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.contains("var "),
              trimmed.contains(":"),
              trimmed.contains("{"),
              trimmed.contains("}") else {
            return nil
        }

        let pattern = "\\bvar\\s+(\\w+)\\s*:\\s*(.*?)\\s*\\{\\s*(.*?)\\s*\\}"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsString = trimmed as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        guard let match = regex.firstMatch(in: trimmed, range: fullRange),
              let nameRange = Range(match.range(at: 1), in: trimmed),
              let typeRange = Range(match.range(at: 2), in: trimmed),
              let accessorRange = Range(match.range(at: 3), in: trimmed) else {
            return nil
        }

        let name = String(trimmed[nameRange])
        let type = String(trimmed[typeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let accessors = String(trimmed[accessorRange])

        return ProtocolProperty(
            name: name,
            type: type,
            isSettable: accessors.contains("set")
        )
    }

    // MARK: - Methods

    private func parseMethod(_ line: String, originalSignature: String?) -> ProtocolMethod? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let funcRange = trimmed.range(of: "func ") else {
            return nil
        }

        let content = String(trimmed[funcRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let parenStart = content.firstIndex(of: "("),
              let parenEnd = content.lastIndex(of: ")") else {
            return nil
        }

        let rawName = String(content[..<parenStart])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let name = rawName.components(separatedBy: "<").first ?? rawName

        let paramsString = String(content[content.index(after: parenStart)..<parenEnd])

        let afterParams = String(content[content.index(after: parenEnd)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let parameters = parseParameters(paramsString)
        let isAsync = afterParams.containsWord("async")
        let isThrows = afterParams.containsWord("throws") || afterParams.containsWord("rethrows")
        let returnType = parseReturnType(from: afterParams)

        return ProtocolMethod(
            name: name,
            parameters: parameters,
            returnType: returnType,
            isAsync: isAsync,
            isThrows: isThrows,
            fullSignature: content,
            originalSignature: originalSignature
        )
    }

    private func parseReturnType(from afterParams: String) -> String {
        guard let arrowRange = afterParams.range(of: "->") else {
            return "Void"
        }

        var returnPart = String(afterParams[arrowRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let whereRange = returnPart.range(of: " where ") {
            returnPart = String(returnPart[..<whereRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if returnPart == "Void" || returnPart == "()" || returnPart.isEmpty {
            return "Void"
        }

        return returnPart
    }

    private func parseParameters(_ paramsString: String) -> [MethodParameter] {
        let params = splitByComma(paramsString)
        var parameters: [MethodParameter] = []

        for rawParam in params {
            let param = rawParam.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !param.isEmpty,
                  let colonIndex = param.firstIndex(of: ":") else {
                continue
            }

            let beforeColon = String(param[..<colonIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let afterColon = String(param[param.index(after: colonIndex)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let nameParts = beforeColon
                .split(separator: " ")
                .map(String.init)

            let externalName: String?
            let internalName: String

            if nameParts.count == 1 {
                externalName = nil
                internalName = nameParts[0]
            } else if nameParts.first == "_" {
                externalName = "_"
                internalName = nameParts.last ?? "_"
            } else {
                externalName = nameParts.first
                internalName = nameParts.last ?? beforeColon
            }

            let typeWithoutDefault = splitTypeAndDefaultValue(afterColon).type

            parameters.append(
                MethodParameter(
                    name: internalName,
                    externalName: externalName,
                    type: typeWithoutDefault
                )
            )
        }

        return parameters
    }

    private func splitTypeAndDefaultValue(_ string: String) -> (type: String, defaultValue: String?) {
        var current = ""
        var depth = 0

        for character in string {
            if character == "<" || character == "[" || character == "(" {
                depth += 1
            } else if character == ">" || character == "]" || character == ")" {
                depth -= 1
            } else if character == "=" && depth == 0 {
                let type = current.trimmingCharacters(in: .whitespacesAndNewlines)
                let defaultValue = String(string[string.index(after: string.firstIndex(of: "=")!)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (type, defaultValue)
            }

            current.append(character)
        }

        return (
            current.trimmingCharacters(in: .whitespacesAndNewlines),
            nil
        )
    }

    private func splitByComma(_ string: String) -> [String] {
        var result: [String] = []
        var current = ""
        var depth = 0
        var isInsideString = false
        var previousCharacter: Character?

        for character in string {
            if character == "\"" && previousCharacter != "\\" {
                isInsideString.toggle()
            }

            if !isInsideString {
                if character == "<" || character == "[" || character == "(" {
                    depth += 1
                } else if character == ">" || character == "]" || character == ")" {
                    depth -= 1
                } else if character == "," && depth == 0 {
                    result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                    current = ""
                    previousCharacter = character
                    continue
                }
            }

            current.append(character)
            previousCharacter = character
        }

        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            result.append(tail)
        }

        return result
    }
}

// MARK: - Code Generator

final class MockGenCodeGenerator {

    let protocolDef: ProtocolDefinition
    let authorName: String
    let appName: String
    let moduleName: String

    init(
        protocolDef: ProtocolDefinition,
        authorName: String,
        appName: String,
        moduleName: String
    ) {
        self.protocolDef = protocolDef
        self.authorName = authorName
        self.appName = appName
        self.moduleName = moduleName
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d.MM.yyyy"
        return formatter.string(from: Date())
    }

    private var yearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }

    private var needsRxSwift: Bool {
        protocolDef.methods.contains {
            $0.returnType.contains("Single<") ||
            $0.returnType.contains("Completable")
        }
    }

    private var isInteractorProtocol: Bool {
        protocolDef.name.contains("Interactor")
    }

    func generateMock() -> MockFile {
        let mockName = makeMockName(from: protocolDef.name)

        var code = """
//
//  \(mockName).swift
//  \(moduleName)-Unit-Tests
//
//  Created by \(authorName) on \(dateString).
//  Copyright © \(yearString) \(appName). All rights reserved.
//

import Foundation
@testable import \(moduleName)
"""

        if needsRxSwift {
            code += "\nimport RxSwift"
        }

        code += """


final class \(mockName): \(protocolDef.name) {


"""

        var propertyLines: [String] = []

        propertyLines.append(contentsOf: generateProtocolProperties())

        if !propertyLines.isEmpty && !protocolDef.methods.isEmpty {
            propertyLines.append("")
        }

        propertyLines.append(contentsOf: generateTrackingProperties())

        code += propertyLines.joined(separator: "\n")

        if !propertyLines.isEmpty {
            code += "\n\n"
        }

        let methodImplementations = protocolDef.methods
            .map(generateMethodImplementation)
            .joined(separator: "\n")

        code += methodImplementations
        code += "}"

        return MockFile(
            name: mockName + ".swift",
            content: code
        )
    }

    // MARK: - Names

    private func makeMockName(from protocolName: String) -> String {
        if protocolName.hasSuffix("Protocol") {
            return String(protocolName.dropLast("Protocol".count)) + "Mock"
        }

        return protocolName + "Mock"
    }

    private func methodIdentifier(_ method: ProtocolMethod) -> String {
        let sameNameMethods = protocolDef.methods.filter { $0.name == method.name }

        guard sameNameMethods.count > 1 else {
            return sanitizeIdentifier(method.name)
        }

        let overloadIndex = methodOverloadIndex(method)

        if overloadIndex == 1 {
            return sanitizeIdentifier(method.name)
        } else {
            return sanitizeIdentifier(method.name) + "\(overloadIndex)"
        }
    }

    private func methodOverloadIndex(_ method: ProtocolMethod) -> Int {
        var index = 0

        for candidate in protocolDef.methods {
            if candidate.name == method.name {
                index += 1
            }

            if candidate.name == method.name && candidate.fullSignature == method.fullSignature {
                return index
            }
        }

        return 1
    }

    private func generatePropertyName(method: ProtocolMethod, param: MethodParameter) -> String {
        methodIdentifier(method) + capitalizeFirstLetter(sanitizeIdentifier(param.name))
    }

    private func successFlagName(for method: ProtocolMethod) -> String {
        "is" + capitalizeFirstLetter(methodIdentifier(method)) + "Success"
    }

    private func sanitizeIdentifier(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))

        let scalars = value.unicodeScalars.map { scalar -> String in
            allowed.contains(scalar) ? String(scalar) : ""
        }

        let result = scalars.joined()

        if result.isEmpty {
            return "value"
        }

        if result.first?.isNumber == true {
            return "_" + result
        }

        return result
    }

    private func capitalizeFirstLetter(_ string: String) -> String {
        guard !string.isEmpty else {
            return string
        }

        return string.prefix(1).uppercased() + string.dropFirst()
    }

    // MARK: - Properties generation

    private func generateProtocolProperties() -> [String] {
        protocolDef.properties.map { property in
            let defaultValue = defaultValueExpression(for: property.type)
            return "    var \(property.name): \(property.type) = \(defaultValue)"
        }
    }

    private func generateTrackingProperties() -> [String] {
        var lines: [String] = []

        for (index, method) in protocolDef.methods.enumerated() {
            let identifier = methodIdentifier(method)

            if isInteractorProtocol && method.returnType != "Void" {
                lines.append("    var \(successFlagName(for: method)) = true")
            }

            lines.append("    private(set) var \(identifier)CallCount = 0")

            for parameter in method.parameters {
                let propertyName = generatePropertyName(method: method, param: parameter)
                let propertyType = makeCapturedPropertyType(parameter.type)
                lines.append("    private(set) var \(propertyName): \(propertyType)")
            }

            if index < protocolDef.methods.count - 1 {
                lines.append("")
            }
        }

        return lines
    }

    private func makeCapturedPropertyType(_ paramType: String) -> String {
        let clean = cleanType(paramType)

        if isOptional(clean) {
            return clean
        }

        if isClosureType(clean) {
            return "(\(clean))?"
        }

        return "\(clean)?"
    }

    // MARK: - Method generation

    private func generateMethodImplementation(_ method: ProtocolMethod) -> String {
        let identifier = methodIdentifier(method)

        var signature: String

        if let originalSignature = method.originalSignature {
            signature = formatOriginalSignature(originalSignature)
        } else {
            signature = "    func \(method.fullSignature)"
        }

        signature += " {\n"

        var body = ""
        body += "        \(identifier)CallCount += 1\n"

        for parameter in method.parameters {
            let propertyName = generatePropertyName(method: method, param: parameter)
            body += "        \(propertyName) = \(parameter.name)\n"
        }

        if method.returnType != "Void" {
            body += "\n"

            if isInteractorProtocol {
                body += generateInteractorReturnBody(for: method)
            } else {
                body += generateDefaultReturnBody(for: method)
            }
        }

        body += "    }\n"

        return signature + body
    }

    private func generateInteractorReturnBody(for method: ProtocolMethod) -> String {
        let successFlag = successFlagName(for: method)

        if method.returnType.contains("Single<") {
            let responseType = extractGenericType(method.returnType)

            return """
        if \(successFlag) {
            let response: \(responseType)! = Data.getResponse(
                bundleClass: Self.self,
                jsonName: "\(responseType)Test",
                responseType: \(responseType).self
            )
            return .just(response)
        } else {
            return .failure(SystemError.common)
        }

"""
        }

        if method.returnType.contains("Completable") {
            return """
        if \(successFlag) {
            return .empty()
        } else {
            return .error(SystemError.common)
        }

"""
        }

        let responseType = method.returnType

        if method.isThrows {
            return """
        if \(successFlag) {
            let response: \(responseType)! = Data.getResponse(
                bundleClass: Self.self,
                jsonName: "\(responseType)Test",
                responseType: \(responseType).self
            )
            return response
        } else {
            throw SystemError.common
        }

"""
        }

        return """
        let response: \(responseType)! = Data.getResponse(
            bundleClass: Self.self,
            jsonName: "\(responseType)Test",
            responseType: \(responseType).self
        )
        return response

"""
    }

    private func generateDefaultReturnBody(for method: ProtocolMethod) -> String {
        let returnType = method.returnType

        if returnType.contains("Single<") {
            let innerType = extractGenericType(returnType)
            let defaultValue = defaultValueExpression(for: innerType)
            return "        return .just(\(defaultValue))\n"
        }

        if returnType.contains("Completable") {
            return "        return .empty()\n"
        }

        let defaultValue = defaultValueExpression(for: returnType)
        return "        return \(defaultValue)\n"
    }

    private func formatOriginalSignature(_ originalSignature: String) -> String {
        let lines = originalSignature
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).replacingOccurrences(of: "\t", with: "    ") }

        let nonEmptyLines = lines.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        let minIndent = nonEmptyLines
            .map { leadingWhitespaceCount($0) }
            .min() ?? 0

        return lines
            .map { line in
                let normalized = removeLeadingWhitespace(line, count: minIndent)

                if normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return ""
                }

                return "    " + normalized
            }
            .joined(separator: "\n")
    }

    private func leadingWhitespaceCount(_ string: String) -> Int {
        var count = 0

        for character in string {
            if character == " " {
                count += 1
            } else {
                break
            }
        }

        return count
    }

    private func removeLeadingWhitespace(_ string: String, count: Int) -> String {
        var result = string
        var removed = 0

        while removed < count, result.first == " " {
            result.removeFirst()
            removed += 1
        }

        return result
    }

    // MARK: - Type helpers

    private func cleanType(_ type: String) -> String {
        type
            .replacingOccurrences(of: "@escaping ", with: "")
            .replacingOccurrences(of: "@autoclosure ", with: "")
            .replacingOccurrences(of: "@Sendable ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isOptional(_ type: String) -> Bool {
        let clean = type.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.hasSuffix("?")
    }

    private func isClosureType(_ type: String) -> Bool {
        type.contains("->")
    }

    private func extractGenericType(_ type: String) -> String {
        guard let start = type.firstIndex(of: "<"),
              let end = type.lastIndex(of: ">"),
              start < end else {
            return type
        }

        return String(type[type.index(after: start)..<end])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func defaultValueExpression(for rawType: String) -> String {
        let type = cleanType(rawType)

        if isOptional(type) {
            return "nil"
        }

        if isClosureType(type) {
            return closureDefaultValue(for: type)
        }

        switch type {
        case "String":
            return "\"\""
        case "Bool":
            return "false"
        case "Int", "Int8", "Int16", "Int32", "Int64":
            return "0"
        case "UInt", "UInt8", "UInt16", "UInt32", "UInt64":
            return "0"
        case "Double", "Float", "CGFloat", "TimeInterval":
            return "0"
        case "Decimal":
            return "0"
        case "Date":
            return "Date()"
        case "Data":
            return "Data()"
        case "URL":
            return "URL(string: \"https://example.com\")!"
        case "UUID":
            return "UUID()"
        case "IndexPath":
            return "IndexPath()"
        case "Any":
            return "()"
        case "AnyObject":
            return "NSObject()"
        default:
            break
        }

        if type.hasPrefix("[") {
            return "[]"
        }

        if type.hasPrefix("Array<") {
            return "[]"
        }

        if type.hasPrefix("Dictionary<") {
            return "[:]"
        }

        if type.hasPrefix("Set<") {
            return "[]"
        }

        return "\(type)()"
    }

    private func closureDefaultValue(for type: String) -> String {
        let stripped = stripOuterParentheses(type)

        guard let arrowRange = stripped.range(of: "->") else {
            return "{}"
        }

        let paramsPart = String(stripped[..<arrowRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let returnPart = String(stripped[arrowRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let parameterCount = closureParameterCount(paramsPart)
        let parametersExpression: String

        if parameterCount == 0 {
            parametersExpression = ""
        } else {
            parametersExpression = Array(repeating: "_", count: parameterCount)
                .joined(separator: ", ") + " in "
        }

        if returnPart == "Void" || returnPart == "()" {
            return "{ \(parametersExpression)}"
        }

        let returnDefault = defaultValueExpression(for: returnPart)
        return "{ \(parametersExpression)\(returnDefault) }"
    }

    private func stripOuterParentheses(_ type: String) -> String {
        var result = type.trimmingCharacters(in: .whitespacesAndNewlines)

        while result.hasPrefix("(") && result.hasSuffix(")") {
            result.removeFirst()
            result.removeLast()
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result
    }

    private func closureParameterCount(_ paramsPart: String) -> Int {
        let clean = stripOuterParentheses(paramsPart)

        if clean.isEmpty || clean == "Void" || clean == "()" {
            return 0
        }

        return splitTopLevelComma(clean).count
    }

    private func splitTopLevelComma(_ string: String) -> [String] {
        var result: [String] = []
        var current = ""
        var depth = 0
        var isInsideString = false
        var previousCharacter: Character?

        for character in string {
            if character == "\"" && previousCharacter != "\\" {
                isInsideString.toggle()
            }

            if !isInsideString {
                if character == "<" || character == "[" || character == "(" {
                    depth += 1
                } else if character == ">" || character == "]" || character == ")" {
                    depth -= 1
                } else if character == "," && depth == 0 {
                    result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                    current = ""
                    previousCharacter = character
                    continue
                }
            }

            current.append(character)
            previousCharacter = character
        }

        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)

        if !tail.isEmpty {
            result.append(tail)
        }

        return result
    }
}

// MARK: - String helpers

private extension String {

    func containsWord(_ word: String) -> Bool {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }

        let nsString = self as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        return regex.firstMatch(in: self, range: fullRange) != nil
    }
}

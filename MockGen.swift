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

class MockGenParser {

    func parseProtocol(_ input: String) -> ProtocolDefinition? {
        // Clean comments and documentation
        let cleaned = cleanProtocol(input)
        let originalLines = cleaned.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        
        // Collapse multiline methods into single lines
        let collapsed = collapseMultilineMethods(cleaned)
        let lines = collapsed.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)

        // Find protocol name
        guard let protocolName = extractProtocolName(from: lines) else {
            return nil
        }

        // Find properties and methods
        var properties: [ProtocolProperty] = []
        var methods: [ProtocolMethod] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Parse properties
            if trimmed.contains("var ") && trimmed.contains("{ get }") {
                if let prop = parseProperty(trimmed) {
                    properties.append(prop)
                }
            }
            // Parse methods
            else if trimmed.contains("func ") {
                if var method = parseMethod(trimmed) {
                    // Найти оригинальную сигнатуру с переносами
                    method = ProtocolMethod(
                        name: method.name,
                        parameters: method.parameters,
                        returnType: method.returnType,
                        isAsync: method.isAsync,
                        isThrows: method.isThrows,
                        fullSignature: method.fullSignature,
                        originalSignature: findOriginalSignature(methodName: method.name, in: originalLines)
                    )
                    methods.append(method)
                }
            }
        }

        return ProtocolDefinition(name: protocolName, properties: properties, methods: methods)
    }
    
    private func findOriginalSignature(methodName: String, in lines: [String]) -> String? {
        // Не сохраняем оригинальное форматирование - используем fullSignature
        return nil
    }
    
    private func collapseMultilineMethods(_ input: String) -> String {
        var result = ""
        let lines = input.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // If line contains func, check if it's multiline
            if trimmed.contains("func ") {
                var methodLines = [line]
                var j = i + 1
                var openParens = 0
                
                // Count parentheses in first line
                for char in trimmed {
                    if char == "(" { openParens += 1 }
                    else if char == ")" { openParens -= 1 }
                }
                
                // Collect remaining lines until parentheses are balanced
                while j < lines.count && openParens > 0 {
                    methodLines.append(lines[j])
                    let nextTrimmed = lines[j].trimmingCharacters(in: .whitespaces)
                    for char in nextTrimmed {
                        if char == "(" { openParens += 1 }
                        else if char == ")" { openParens -= 1 }
                    }
                    j += 1
                }
                
                // Join method lines with single space
                let fullMethod = methodLines.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
                result += fullMethod + "\n"
                i = j
            } else {
                result += line + "\n"
                i += 1
            }
        }
        
        return result
    }

    private func cleanProtocol(_ input: String) -> String {
        var result = ""
        let lines = input.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip comments and documentation
            if trimmed.hasPrefix("//") || trimmed.hasPrefix("///") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
                continue
            }

            result += line + "\n"
        }

        return result
    }

    private func extractProtocolName(from lines: [String]) -> String? {
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("protocol ") {
                let pattern = "protocol\\s+(\\w+)"
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let nsString = trimmed as NSString
                    if let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: nsString.length)) {
                        if let range = Range(match.range(at: 1), in: trimmed) {
                            return String(trimmed[range])
                        }
                    }
                }
            }
        }
        return nil
    }

    private func parseProperty(_ line: String) -> ProtocolProperty? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        guard trimmed.contains("var ") && trimmed.contains(":") else { return nil }

        var content = trimmed.replacingOccurrences(of: "var ", with: "")
        content = content.replacingOccurrences(of: "{ get }", with: "").trimmingCharacters(in: .whitespaces)

        let parts = content.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }

        guard parts.count == 2 else { return nil }

        let propName = parts[0]
        let propType = parts[1]

        return ProtocolProperty(name: propName, type: propType)
    }

    private func parseMethod(_ line: String) -> ProtocolMethod? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        guard trimmed.contains("func ") else { return nil }
        var content = trimmed.replacingOccurrences(of: "func ", with: "")

        guard let parenStart = content.firstIndex(of: "("),
              let parenEnd = content.lastIndex(of: ")") else {
            return nil
        }

        let name = String(content[..<parenStart]).trimmingCharacters(in: .whitespaces)
        let paramsString = String(content[content.index(after: parenStart)..<parenEnd])
        let afterParams = content[content.index(after: parenEnd)...].trimmingCharacters(in: .whitespaces)
        
        // Сохраняем полную сигнатуру для последующей вставки
        let fullSignature = String(content)

        let parameters = parseParameters(paramsString)

        var isAsync = false
        var isThrows = false
        var returnType = "Void"

        if afterParams.contains("async") { isAsync = true }
        if afterParams.contains("throws") { isThrows = true }

        if afterParams.contains("->") {
            if let arrow = afterParams.range(of: "->") {
                let returnPart = String(afterParams[arrow.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "Void", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !returnPart.isEmpty {
                    returnType = returnPart
                }
            }
        }

        return ProtocolMethod(
            name: name,
            parameters: parameters,
            returnType: returnType,
            isAsync: isAsync,
            isThrows: isThrows,
            fullSignature: fullSignature,
            originalSignature: nil
        )
    }

    private func parseParameters(_ paramsString: String) -> [MethodParameter] {
        var parameters: [MethodParameter] = []

        // Split by comma, but respect nested angle brackets
        let params = splitByComma(paramsString)

        for param in params {
            if param.isEmpty { continue }

            var paramNamePart = param

            // Check if has underscore (no external name)
            var externalName: String? = nil
            if paramNamePart.hasPrefix("_") {
                externalName = "_"
                paramNamePart = paramNamePart.dropFirst().trimmingCharacters(in: .whitespaces)
            }

            // Split by colon
            let colonIndex = paramNamePart.firstIndex(of: ":")
            if let colonIdx = colonIndex {
                let beforeColon = String(paramNamePart[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                let afterColon = String(paramNamePart[paramNamePart.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

                // Extract real parameter name (last word in beforeColon)
                let nameWords = beforeColon.split(separator: " ").map { String($0) }
                let paramName = nameWords.last ?? beforeColon

                // Remove default value if present
                let paramType = afterColon.split(separator: "=").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? afterColon

                parameters.append(MethodParameter(
                    name: paramName,
                    externalName: externalName,
                    type: paramType
                ))
            }
        }

        return parameters
    }

    private func splitByComma(_ str: String) -> [String] {
        var result: [String] = []
        var current = ""
        var depth = 0

        for char in str {
            if char == "<" || char == "[" || char == "(" {
                depth += 1
            } else if char == ">" || char == "]" || char == ")" {
                depth -= 1
            } else if char == "," && depth == 0 {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
                continue
            }
            current.append(char)
        }

        if !current.isEmpty {
            result.append(current.trimmingCharacters(in: .whitespaces))
        }

        return result
    }
}

// MARK: - Code Generator

class MockGenCodeGenerator {

    let protocolDef: ProtocolDefinition
    let authorName: String
    let appName: String
    let moduleName: String

    init(protocolDef: ProtocolDefinition, authorName: String, appName: String, moduleName: String) {
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
        for method in protocolDef.methods {
            if method.returnType.contains("Single<") || method.returnType.contains("Completable") {
                return true
            }
        }
        return false
    }

    func generateMock() -> MockFile {
        let mockName = protocolDef.name.replacingOccurrences(of: "Protocol", with: "") + "Mock"

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

        // Generate property implementations
        var propertyLines: [String] = []

        // Properties from protocol
        for property in protocolDef.properties {
            propertyLines.append("    var \(property.name): \(property.type) = \(property.type)()")
        }

        // Add separator if we have both protocol properties and method properties
        if !propertyLines.isEmpty && !protocolDef.methods.isEmpty {
            propertyLines.append("")
        }

        // Properties for tracking method calls and parameters
        for (index, method) in protocolDef.methods.enumerated() {
            let methodNameCamel = method.name
            let callCountProp = "\(methodNameCamel)CallCount"

            propertyLines.append("    private(set) var \(callCountProp) = 0")

            for param in method.parameters {
                let propName = generatePropertyName(method: method, param: param)
                let propType = makePropertyType(param.type)
                propertyLines.append("    private(set) var \(propName): \(propType)")
            }

            // Add separator between method property groups (but not after last one)
            if index < protocolDef.methods.count - 1 {
                propertyLines.append("")
            }
        }

        code += propertyLines.joined(separator: "\n")

        if !propertyLines.isEmpty {
            code += "\n\n"
        }

        // Generate method implementations
        var methodLines: [String] = []
        for method in protocolDef.methods {
            methodLines.append(generateMethodImplementation(method))
        }

        code += methodLines.joined(separator: "\n")
        code += "\n}"

        return MockFile(name: mockName + ".swift", content: code)
    }

    private func generatePropertyName(method: ProtocolMethod, param: MethodParameter) -> String {
        let baseName = "\(method.name)\(capitalizeFirstLetter(param.name))"

        // Найди все методы с таким же именем
        let sameNameMethods = protocolDef.methods.filter { $0.name == method.name }

        if sameNameMethods.count <= 1 {
            // Нет перегрузок
            return baseName
        }

        // Есть перегрузки, проверь конфликты параметров с таким же именем
        let sameParamNameMethods = sameNameMethods.filter { m in
            m.parameters.contains { $0.name == param.name }
        }

        if sameParamNameMethods.count > 1 {
            // Конфликт - параметр с таким же именем в разных методах перегрузки
            // Добавляю short type
            let shortType = getShortType(param.type)
            return "\(baseName)\(shortType)"
        }

        return baseName
    }

    private func getShortType(_ type: String) -> String {
        var clean = type
        clean = clean.replacingOccurrences(of: "@escaping ", with: "")
        clean = clean.replacingOccurrences(of: "?", with: "")
        clean = clean.replacingOccurrences(of: "[", with: "")
        clean = clean.replacingOccurrences(of: "]", with: "")
        clean = clean.replacingOccurrences(of: "(", with: "")
        clean = clean.replacingOccurrences(of: ")", with: "")
        clean = clean.replacingOccurrences(of: "<", with: "")
        clean = clean.replacingOccurrences(of: ">", with: "")
        clean = clean.replacingOccurrences(of: ":", with: "")
        clean = clean.trimmingCharacters(in: .whitespaces)

        // Get first character
        if let first = clean.first {
            return String(first).uppercased()
        }
        return "T"
    }

    private func makePropertyType(_ paramType: String) -> String {
        // Remove @escaping attribute from closure types
        var cleanType = paramType.replacingOccurrences(of: "@escaping ", with: "")
        
        // Remove trailing ? to normalize
        if cleanType.hasSuffix("?") {
            cleanType = String(cleanType.dropLast())
        }
        
        // Check if it's a closure type (contains ->)
        if cleanType.contains("->") {
            // Wrap closure in parentheses and ALWAYS make optional
            return "(\(cleanType))?"
        }
        
        // For non-closure types, just add ?
        return "\(cleanType)?"
    }

    private func capitalizeFirstLetter(_ str: String) -> String {
        guard !str.isEmpty else { return str }
        return str.prefix(1).uppercased() + str.dropFirst()
    }

    private func generateMethodImplementation(_ method: ProtocolMethod) -> String {
        let methodNameCamel = method.name
        let callCountProp = "\(methodNameCamel)CallCount"

        // Используем оригинальную многострочную сигнатуру если есть
        var sig: String
        if let originalSig = method.originalSignature {
            // Добавляем отступ (4 пробела) к каждой строке оригинальной сигнатуры
            let sigLines = originalSig.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            let indented = sigLines.map { line -> String in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.isEmpty ? "" : "    " + trimmed
            }.joined(separator: "\n")
            sig = indented
        } else {
            sig = "    func \(method.fullSignature)"
        }

        sig += " {\n"

        // Method body
        var body = "        \(callCountProp) += 1\n"

        // Capture parameters
        for param in method.parameters {
            let propName = generatePropertyName(method: method, param: param)
            body += "        \(propName) = \(param.name)\n"
        }

        // Add return logic only if not Void
        if method.returnType != "Void" {
            body += "\n"

            // Return value
            if method.returnType.contains("Single<") {
                let innerType = extractGenericType(method.returnType)
                body += "        return .just(\(innerType)())\n"
            } else if method.returnType.contains("Completable") {
                body += "        return .empty()\n"
            } else if method.isAsync || method.isThrows {
                if isOptional(method.returnType) {
                    body += "        return nil\n"
                } else {
                    body += "        return \(method.returnType)()\n"
                }
            } else {
                if isOptional(method.returnType) {
                    body += "        return nil\n"
                } else {
                    body += "        return \(method.returnType)()\n"
                }
            }
        }

        body += "    }\n"

        return sig + body
    }

    private func extractGenericType(_ type: String) -> String {
        guard let start = type.firstIndex(of: "<"),
              let end = type.lastIndex(of: ">") else {
            return type
        }
        return String(type[type.index(after: start)..<end])
    }

    private func isOptional(_ type: String) -> Bool {
        return type.hasSuffix("?")
    }
}

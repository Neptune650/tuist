import Foundation

enum ProgrammingLanguage {
    case swift
    case objc
}

final class ImportSourceCodeScanner {
    func extractImports(from sourceCode: String, language: ProgrammingLanguage) throws -> [String] {
        switch language {
        case .swift:
            try extractImportedModules(from: sourceCode)
        case .objc:
            try extractAllImportsObjc(from: sourceCode)
        }
    }

    func extractImportedModules(from code: String) throws -> [String] {
        // Регулярное выражение для поиска строк импорта
        let pattern = #"import\s+(?:struct\s+|enum\s+|class\s+)?([\w]+)"#

        // Создаем массив для имен модулей
        var modules: [String] = []

        // Создаем регулярное выражение
        let regex = try NSRegularExpression(pattern: pattern, options: [])

        // Ищем совпадения в коде
        let matches = regex.matches(in: code, options: [], range: NSRange(location: 0, length: code.utf16.count))

        for match in matches {
            if let moduleRange = Range(match.range(at: 1), in: code) {
                let module = String(code[moduleRange])
                // Разделяем по точке и берем только имя верхнеуровневого модуля
                let topLevelModule = module.split(separator: ".").first.map(String.init)
                if let topLevelModule, !modules.contains(topLevelModule) {
                    modules.append(topLevelModule)
                }
            }
        }

        return modules
    }

    func extractAllImportsSwift(from text: String) throws -> [String] {
        let pattern = #"^\s*import\s+([\w\d_]+)\s*$"#

        let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)

        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)

        return matches.compactMap { match -> String? in
            if let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
            return nil
        }
    }

    func extractAllImportsObjc(from text: String) throws -> [String] {
        let pattern = "@import\\s+([A-Za-z_0-9]+)|#(?:import|include)\\s+<([A-Za-z_0-9-]+)/"

        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(
            in: text,
            options: [],
            range: NSRange(
                location: 0,
                length: text.utf16.count
            )
        )

        return matches.compactMap { match in
            if let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            } else if let range = Range(match.range(at: 2), in: text) {
                return String(text[range])
            }
            return nil
        }
    }
}

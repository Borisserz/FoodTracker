import Foundation

/// Pure JSON extraction helpers for handling noisy or markdown-fenced LLM outputs.
nonisolated enum AIResponseParsing {
    /// Strips markdown code fences and extracts the first valid balanced JSON object or array.
    static func extractJSON(from raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        let prefixes = ["```json", "```JSON", "```"]
        for prefix in prefixes where cleaned.hasPrefix(prefix) {
            cleaned = String(cleaned.dropFirst(prefix.count))
            if let newlineIdx = cleaned.firstIndex(of: "\n"), cleaned[..<newlineIdx].trimmingCharacters(in: .whitespaces).isEmpty {
                cleaned = String(cleaned[cleaned.index(after: newlineIdx)...])
            }
            break
        }

        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }

        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if isValidJSON(cleaned) {
            return cleaned
        }

        if let balanced = extractBalancedJSON(from: cleaned) {
            return balanced
        }

        return cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "`"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isValidJSON(_ string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    private static func extractBalancedJSON(from text: String) -> String? {
        var index = text.startIndex
        while index < text.endIndex {
            let opener = text[index]
            if opener == "{" || opener == "[" {
                let closer: Character = (opener == "{") ? "}" : "]"
                var depth = 0
                var inString = false
                var escaped = false
                var cursor = index

                while cursor < text.endIndex {
                    let ch = text[cursor]
                    if inString {
                        if escaped {
                            escaped = false
                        } else if ch == "\\" {
                            escaped = true
                        } else if ch == "\"" {
                            inString = false
                        }
                    } else {
                        if ch == "\"" {
                            inString = true
                        } else if ch == opener {
                            depth += 1
                        } else if ch == closer {
                            depth -= 1
                            if depth == 0 {
                                let candidate = String(text[index...cursor])
                                if isValidJSON(candidate) {
                                    return candidate
                                }
                                break
                            }
                        }
                    }
                    cursor = text.index(after: cursor)
                }
            }
            index = text.index(after: index)
        }
        return nil
    }
}

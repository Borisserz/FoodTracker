import Foundation

/// Pure JSON extraction helpers for handling noisy or markdown-fenced LLM outputs.
nonisolated enum AIResponseParsing {
    /// Strips markdown code fences and extracts the first valid balanced JSON object or array.
    static func extractJSON(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Match fenced code blocks even if preceded/followed by prose (e.g., "Option [1]:\n```json ... ```")
        if let fenced = extractFencedBlock(from: trimmed) {
            if isValidJSON(fenced) {
                return fenced
            }
            if let balancedFenced = extractBalancedJSON(from: fenced) {
                return balancedFenced
            }
        }

        if isValidJSON(trimmed) {
            return trimmed
        }

        if let balanced = extractBalancedJSON(from: trimmed) {
            return balanced
        }

        return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "`"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractFencedBlock(from text: String) -> String? {
        let pattern = #"```(?:json|JSON)?[ \t]*\r?\n([\s\S]*?)```"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isValidJSON(_ string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    static func rateLimitMessage(retryAfter: String?) -> String {
        guard let raw = retryAfter?.trimmingCharacters(in: .whitespacesAndNewlines),
              let seconds = Double(raw),
              seconds > 0 else {
            return String(localized: "You've reached your weekly AI limit. Please try again later.")
        }
        if seconds >= 86_400 {
            let days = max(1, Int(ceil(seconds / 86_400)))
            return String(localized: "You've reached your weekly AI limit. Please try again in \(days)d.")
        }
        if seconds >= 3_600 {
            let hours = max(1, Int(ceil(seconds / 3_600)))
            return String(localized: "You've reached your weekly AI limit. Please try again in \(hours)h.")
        }
        let minutes = max(1, Int(ceil(seconds / 60)))
        return String(localized: "You've reached your weekly AI limit. Please try again in \(minutes)m.")
    }

    private static func extractBalancedJSON(from text: String) -> String? {
        var fallbackArrayCandidate: String?
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
                                    if opener == "{" {
                                        return candidate
                                    }
                                    // Prefer arrays containing structured objects/strings over prose citation brackets like [1].
                                    if candidate.contains("{") || candidate.contains("\"") {
                                        return candidate
                                    }
                                    if fallbackArrayCandidate == nil {
                                        fallbackArrayCandidate = candidate
                                    }
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
        return fallbackArrayCandidate
    }
}

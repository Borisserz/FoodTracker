import Foundation

/// Pure JSON extraction helpers for handling noisy or markdown-fenced LLM outputs.
nonisolated enum AIResponseParsing {
    /// Strips markdown code fences and extracts the first valid balanced JSON object or array.
    static func extractJSON(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Match fenced code blocks even if preceded/followed by prose (e.g., "Option [1]:\n```json ... ```")
        for fenced in extractFencedBlocks(from: trimmed) {
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

    private static func extractFencedBlocks(from text: String) -> [String] {
        let pattern = #"```(?:[a-zA-Z0-9_-]+)?[ \t]*(?:\r?\n)?([\s\S]*?)```"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            let candidate = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            return candidate.isEmpty ? nil : candidate
        }
    }

    private static func isValidJSON(_ string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    private static func retryDurationText(from retryAfter: String?) -> String? {
        guard let raw = retryAfter?.trimmingCharacters(in: .whitespacesAndNewlines),
              let seconds = Double(raw),
              seconds > 0 else {
            return nil
        }
        if seconds >= 86_400 {
            let days = max(1, Int(ceil(seconds / 86_400)))
            return "\(days)d"
        }
        if seconds >= 3_600 {
            let hours = max(1, Int(ceil(seconds / 3_600)))
            return "\(hours)h"
        }
        let minutes = max(1, Int(ceil(seconds / 60)))
        return "\(minutes)m"
    }

    static func rateLimitMessage(retryAfter: String?) -> String {
        guard let duration = retryDurationText(from: retryAfter) else {
            return String(localized: "You've reached your weekly AI limit. Please try again later.")
        }
        return String(localized: "You've reached your weekly AI limit. Please try again in \(duration).")
    }

    static func searchRateLimitMessage(retryAfter: String?) -> String {
        guard let duration = retryDurationText(from: retryAfter) else {
            return String(localized: "Too many food searches right now. Please try again later.")
        }
        return String(localized: "Too many food searches right now. Please try again in \(duration).")
    }

    static func languageDisplayName(forCode rawCode: String?) -> String {
        let base = (rawCode ?? "en")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .first?
            .lowercased() ?? "en"
        switch base {
        case "ru": return "Russian"
        case "es": return "Spanish"
        case "fr": return "French"
        case "de": return "German"
        case "it": return "Italian"
        case "pt": return "Portuguese"
        default: return "English"
        }
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

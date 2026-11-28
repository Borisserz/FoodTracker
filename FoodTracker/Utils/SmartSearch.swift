import Foundation

/// A robust, locale-aware smart search mechanism.
/// Handles diacritic-insensitivity, stemming/plural stripping, and synonyms.
public struct SmartSearch {
    
    // MARK: - Normalization
    
    /// Normalizes a string by lowercasing, folding diacritics, and trimming.
    static func normalize(_ string: String) -> String {
        return string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Synonyms
    
    /// Locale-specific synonym maps. Keys should be normalized.
    static let synonymMaps: [String: [String: [String]]] = [
        "ru": [
            "картошк": ["картофель"],
            "картош": ["картофель"],
            "помидор": ["томат"],
            "томат": ["помидор"],
            "гречк": ["гречневая", "греч"],
            "греч": ["гречневая", "гречка"],
            "макарон": ["паста", "спагетти", "макароны"],
            "паста": ["макарон", "спагетти"],
            "яичниц": ["яицо", "яица"],
            "куриц": ["курин", "петух"],
            "курин": ["куриц", "петух"],
            "мяс": ["говядин", "свинин"],
            "сосиск": ["сосис", "колбас"],
            "колбас": ["сосис", "колбас"]
        ],
        "en": [
            "fries": ["potato"],
            "veggies": ["vegetable"],
            "beef": ["steak", "cow"],
            "pork": ["pig", "bacon"],
            "chicken": ["poultry"]
        ],
        "fr": [
            "patate": ["pomme de terre"],
            "frite": ["pomme de terre", "pommes frites"],
            "poulet": ["volaille"]
        ],
        "de": [
            "kartoffel": ["pommes", "fritten"]
        ],
        "es": [
            "patata": ["papa"],
            "papa": ["patata"],
            "pollo": ["ave"]
        ],
        "it": [
            "patata": ["patatine"],
            "pollo": ["uccello"]
        ],
        "pt": [
            "batata": ["batatas"],
            "frango": ["ave", "galinha"],
            "tomate": ["tomates"],
            "feijao": ["feijoes"],
            "carne": ["bife", "vaca", "novilho"]
        ]
    ]
    
    // MARK: - Core Logic
    
    /// Generates search root variations for a given query based on the provided or current system language.
    static func getRoots(for query: String, languageCode: String? = nil) -> [[String]] {
        let normalizedQuery = normalize(query)
        let words = normalizedQuery.split(separator: " ").map { String($0) }
        var result: [[String]] = []
        
        let rawCode = (languageCode ?? Locale.current.language.languageCode?.identifier ?? "en").lowercased()
        let langCode = rawCode.hasPrefix("pt") ? "pt" : rawCode
        let synonyms = synonymMaps[langCode] ?? [:]
        
        for word in words {
            let root = extractRoot(word: word, langCode: langCode)
            var rootsForWord = [root, word]
            
            // Check synonyms based on the root
            for (key, syns) in synonyms {
                // Avoid short 1-2 character prefixes polluting unrelated words (e.g. "по" -> "томат").
                let prefixMatches = root.count >= 3 && key.starts(with: root)
                if root.starts(with: key) || prefixMatches {
                    rootsForWord.append(contentsOf: syns)
                }
            }
            // Ensure uniqueness
            result.append(Array(Set(rootsForWord)))
        }
        
        return result
    }
    
    /// Matches a raw food name against generated query roots.
    static func matches(name: String, queryRoots: [[String]]) -> Bool {
        matchesFolded(normalizedName: normalize(name), queryRoots: queryRoots)
    }

    /// Matches a pre-folded food name against generated query roots without re-running Unicode normalization.
    static func matchesFolded(normalizedName: String, queryRoots: [[String]]) -> Bool {
        
        // For every word in the query, we must find at least one match in the food name
        for roots in queryRoots {
            let hasMatch = roots.contains { root in
                normalizedName.contains(root)
            }
            if !hasMatch {
                return false
            }
        }
        return true
    }
    
    // MARK: - Language-Specific Stemming
    
    /// Extracts the root form of a word based on language-specific plural/suffix rules.
    private static func extractRoot(word: String, langCode: String) -> String {
        let count = word.count
        guard count > 3 else { return word }
        
        switch langCode {
        case "ru":
            // Russian: drop endings for long words
            let rootLength = count >= 6 ? count - 2 : count - 1
            return String(word.prefix(rootLength))
            
        case "en":
            // English: Basic plural stripping
            if word.hasSuffix("ies") {
                return String(word.dropLast(3)) + "y"
            } else if word.hasSuffix("es") && count > 4 {
                // Wait, "potatoes" -> "potato" is ok, but "boxes" -> "box".
                // We can safely drop "es" for matching purposes
                return String(word.dropLast(2))
            } else if word.hasSuffix("s") && !word.hasSuffix("ss") {
                return String(word.dropLast(1))
            }
            return word
            
        case "fr", "es", "pt":
            // French/Spanish/Portuguese: Plurals often end in 's', 'es', or 'x'
            if word.hasSuffix("es") {
                return String(word.dropLast(2))
            } else if word.hasSuffix("s") || word.hasSuffix("x") {
                return String(word.dropLast(1))
            }
            return word
            
        case "de":
            // German: Compound nouns or plurals (e.g. en, er, e, s)
            if word.hasSuffix("en") || word.hasSuffix("er") {
                return String(word.dropLast(2))
            } else if word.hasSuffix("e") || word.hasSuffix("s") {
                return String(word.dropLast(1))
            }
            return word
            
        case "it":
            // Italian: Plurals usually change final vowel to 'i' or 'e'.
            // Stripping the final vowel provides the root prefix.
            guard let lastChar = word.last else { return word }
            if ["a", "e", "i", "o", "u"].contains(lastChar) {
                return String(word.dropLast(1))
            }
            return word
            
        default:
            // Fallback generic stemming
            let rootLength = count >= 6 ? count - 2 : count - 1
            return String(word.prefix(rootLength))
        }
    }
}

import SwiftUI
import Observation

extension Color {
    // New Custom Theme Colors
    static let mintGreen = Color(red: 0.0, green: 0.8, blue: 0.4)
    static let cyberBlue = Color(red: 0.0, green: 0.5, blue: 1.0)
    static let lavender = Color(red: 0.7, green: 0.4, blue: 1.0)
}

protocol AppTheme: Sendable {
    var name: String { get }
    var background: Color { get }
    var primaryAccent: Color { get }
    var secondaryAccent: Color { get }
    var primaryGradient: LinearGradient { get }
}

struct BerryTheme: AppTheme {
    var name: String { "Berry Pink" }
    var background: Color { .themeBg }
    var primaryAccent: Color { Color(red: 1.0, green: 0.20, blue: 0.40) } // Original themePink
    var secondaryAccent: Color { Color(red: 1.0, green: 0.40, blue: 0.10) } // Original themeOrange
    
    var primaryGradient: LinearGradient {
        LinearGradient(colors: [primaryAccent, secondaryAccent], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct MintTheme: AppTheme {
    var name: String { "Mint Fresh" }
    var background: Color { .themeBg }
    var primaryAccent: Color { .mintGreen }
    var secondaryAccent: Color { .drinkWater }
    
    var primaryGradient: LinearGradient {
        LinearGradient(colors: [.mintGreen, .drinkWater], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct CyberTheme: AppTheme {
    var name: String { "Cyber Blue" }
    var background: Color { .themeBg }
    var primaryAccent: Color { .cyberBlue }
    var secondaryAccent: Color { .lavender }
    
    var primaryGradient: LinearGradient {
        LinearGradient(colors: [.cyberBlue, .lavender], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

@Observable
@MainActor
final class ThemeManager {
    static let shared = ThemeManager()
    
    var currentThemeIndex: Int = 0 {
        didSet {
            UserDefaults.standard.set(currentThemeIndex, forKey: "SelectedThemeIndex")
        }
    }
    
    let themes: [AppTheme] = [BerryTheme(), MintTheme(), CyberTheme()]
    
    var current: AppTheme {
        if currentThemeIndex >= 0 && currentThemeIndex < themes.count {
            return themes[currentThemeIndex]
        }
        return themes[0]
    }
    
    private init() {
        self.currentThemeIndex = UserDefaults.standard.integer(forKey: "SelectedThemeIndex")
    }
}

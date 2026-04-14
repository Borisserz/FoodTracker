import SwiftUI
import Foundation

// MARK: - Theme Colors Extension
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 08) & 0xff) / 255, blue: Double((hex >> 00) & 0xff) / 255, opacity: alpha)
    }
    
    static let themePink   = Color(hex: 0xF25C78)
    static let themeYellow = Color(hex: 0xE5A93B)
    static let themeDarkYellow = Color(hex: 0xC48000) // NEW: Darker gold for better readability on white
    static let themeOrange = Color(hex: 0xF28B66)
    static let themeBg     = Color(hex: 0xF5F2EB) // UPDATED: Slightly warmer and darker to make white cards pop
    static let themePeach  = Color(hex: 0xE06C53)
    
    static let textGray    = Color(hex: 0x595959)
    
    // Drink colors
    static let drinkWater  = Color(hex: 0x4CA3E6)
    static let drinkCoffee = Color(hex: 0x8D6E63)
    static let drinkWine   = Color(hex: 0x9C27B0).opacity(0.8)
    static let drinkMilk   = Color(hex: 0xCFD8DC)
    static let drinkJuice  = Color(hex: 0xFFB74D)
    
    static func fromHex(_ hex: String) -> Color? {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        return Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Premium Card Style
struct PremiumCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4) // Softer, more elegant shadow
    }
}

extension View {
    func premiumCardStyle() -> some View {
        self.modifier(PremiumCardModifier())
    }
}

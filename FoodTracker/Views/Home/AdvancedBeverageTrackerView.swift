import SwiftUI
import SwiftData

struct BeverageOption: Equatable {
    let name: String; let icon: String; let color: Color; let kcal: Int; let hex: String; let volumeMl: Double
}

let beverageOptions = [
    BeverageOption(name: "Water", icon: "drop.fill", color: .drinkWater, kcal: 0, hex: "6BB8F2", volumeMl: 250.0),
    BeverageOption(name: "Coffee", icon: "cup.and.saucer.fill", color: .drinkCoffee, kcal: 40, hex: "8D6E63", volumeMl: 250.0),
    BeverageOption(name: "Milk", icon: "mug.fill", color: .drinkMilk, kcal: 150, hex: "CFD8DC", volumeMl: 250.0),
    BeverageOption(name: "Juice", icon: "orange.fill", color: .drinkJuice, kcal: 110, hex: "FFB74D", volumeMl: 250.0)
]

struct AdvancedBeverageTrackerView: View {
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    
    @Bindable var summary: DailySummary
    @State private var selectedOption: BeverageOption = beverageOptions[0]
    
    // UI states for wave and button interactions
    @State private var phase: Double = 0.0
    @State private var buttonScale: CGFloat = 1.0
    
    let dailyGoalLiters = 2.5
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Hydration").font(.headline)
                    Text("+ \(selectedOption.kcal) kcal / 250ml").font(.caption).foregroundColor(.themeOrange)
                }
                Spacer()
                Text("\(summary.totalHydrationLiters, specifier: "%.2f") / \(dailyGoalLiters, specifier: "%.1f") L")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(selectedOption.color)
            }
            
            // Liquid Wave Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                    
                    let progress = min(summary.totalHydrationLiters / dailyGoalLiters, 1.0)
                    let fillWidth = geo.size.width * CGFloat(progress)
                    
                    // The wave shape mapped precisely to width fill with a smooth 2.5 amplitude
                    WaveShape(phase: phase, waveAmplitude: progress > 0.02 ? 2.5 : 0)
                        .fill(selectedOption.color)
                        .frame(width: max(0, fillWidth))
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(height: 24)
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                }
            }
            
            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(beverageOptions, id: \.name) { opt in
                            Button(action: {
                                HapticManager.shared.impact(style: .light)
                                withAnimation { selectedOption = opt }
                            }) {
                                HStack {
                                    Image(systemName: opt.icon)
                                    Text(opt.name).font(.subheadline).bold()
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(selectedOption == opt ? opt.color : Color.gray.opacity(0.1))
                                .foregroundColor(selectedOption == opt ? .white : .primary)
                                .cornerRadius(20)
                            }
                        }
                    }
                }
                
                Button(action: addBeverage) {
                    Image(systemName: "plus")
                        .font(.title2).bold()
                        .foregroundColor(.white)
                        .padding(10)
                        .background(selectedOption.color)
                        .clipShape(Circle())
                        .shadow(color: selectedOption.color.opacity(0.4), radius: 5, y: 2)
                        .scaleEffect(buttonScale)
                }
            }
        }
        .premiumCardStyle()
    }
    
    private func addBeverage() {
        // Haptic Feedback & Pulse Animation
        HapticManager.shared.impact(style: .medium)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            buttonScale = 0.8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                buttonScale = 1.0
            }
        }
        
        // Local SwiftData Save
        let newBeverage = Beverage(
            name: selectedOption.name,
            icon: selectedOption.icon,
            colorHex: selectedOption.hex,
            caloriesPerGlass: selectedOption.kcal,
            volumeMl: selectedOption.volumeMl
        )
        context.insert(newBeverage)
        summary.beverages.append(newBeverage)
        try? context.save()
        
        // Apple HealthKit Save Integration
        if let user = users.first, user.isHealthKitEnabled {
            HealthKitManager.shared.saveWater(liters: selectedOption.volumeMl / 1000.0, date: Date())
        }
    }
}

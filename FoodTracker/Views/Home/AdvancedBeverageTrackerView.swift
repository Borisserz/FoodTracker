import SwiftUI
import SwiftData

struct BeverageOption: Equatable {
    let name: String; let icon: String; let color: Color; let kcal: Int; let hex: String
}

let beverageOptions = [
    BeverageOption(name: "Water", icon: "drop.fill", color: .drinkWater, kcal: 0, hex: "6BB8F2"),
    BeverageOption(name: "Coffee", icon: "cup.and.saucer.fill", color: .drinkCoffee, kcal: 40, hex: "8D6E63"),
    BeverageOption(name: "Milk", icon: "mug.fill", color: .drinkMilk, kcal: 150, hex: "CFD8DC"),
    BeverageOption(name: "Juice", icon: "orange.fill", color: .drinkJuice, kcal: 110, hex: "FFB74D")
]

struct AdvancedBeverageTrackerView: View {
    @Environment(\.modelContext) private var context
    @Bindable var summary: DailySummary
    @State private var selectedOption: BeverageOption = beverageOptions[0]
    
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
            
            // Динамический прогресс-бар
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                    
                    let progress = min(summary.totalHydrationLiters / dailyGoalLiters, 1.0)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedOption.color)
                        .frame(width: geo.size.width * CGFloat(progress))
                        .animation(.spring(), value: progress)
                }
            }
            .frame(height: 24)
            
            // Кнопка добавления + селектор
            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(beverageOptions, id: \.name) { opt in
                            Button(action: { withAnimation { selectedOption = opt } }) {
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
                        .shadow(radius: 2)
                }
            }
        }
        .premiumCardStyle()
    }
    
    private func addBeverage() {
        let newBeverage = Beverage(
            name: selectedOption.name,
            icon: selectedOption.icon,
            colorHex: selectedOption.hex,
            caloriesPerGlass: selectedOption.kcal
        )
        context.insert(newBeverage)
        summary.beverages.append(newBeverage)
        try? context.save()
    }
}

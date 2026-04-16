import SwiftUI
import UIKit // <-- Важно для HapticManager

// MARK: - Haptic Manager
class HapticManager {
    static let shared = HapticManager()
    
    private init() {} // Гарантирует, что будет только один экземпляр
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

// MARK: - Macro Battery View
struct MacroBatteryView: View {
    let title: String; let current: Int; let total: Int; let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.caption).foregroundColor(.textGray).bold()
                Spacer()
                let textColor = color == .themeYellow ? Color.themeDarkYellow : color
                Text("\(current)/\(total)g").font(.caption.bold()).foregroundColor(textColor)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                    
                    Capsule()
                        .fill(color)
                        .frame(width: min(geometry.size.width * CGFloat(current) / CGFloat(max(total, 1)), geometry.size.width))
                        .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 0)
                }
            }
            .frame(height: 10)
        }
    }
}

struct MacroSummaryView: View {
    let protein: Double; let fats: Double; let carbs: Double
    let targetProtein: Double; let targetFats: Double; let targetCarbs: Double
    
    var body: some View {
        HStack(spacing: 15) {
            MacroBatteryView(title: "Protein", current: Int(protein), total: Int(targetProtein), color: .themePeach)
            MacroBatteryView(title: "Fats", current: Int(fats), total: Int(targetFats), color: .themeYellow)
            MacroBatteryView(title: "Carbs", current: Int(carbs), total: Int(targetCarbs), color: .drinkWater)
        }
    }
}

// MARK: - Вспомогательные компоненты для MealDetailView
struct MiniProgressView: View {
    let title: String
    let progress: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.caption).bold().foregroundColor(.textGray)
            // Добавлено min() и max(), чтобы значение никогда не выходило за рамки 0...1
            ProgressView(value: min(max(progress, 0.0), 1.0)).tint(color)
        }
    }
}
struct FoodItemRow: View {
    let name: String
    let weight: String
    let calories: Int
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.themePink.opacity(0.05)).frame(width: 44, height: 44)
                Image(systemName: "fork.knife").foregroundColor(.themePink.opacity(0.6))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline).bold()
                Text(weight).font(.caption).foregroundColor(.textGray)
            }
            Spacer()
            Text("\(calories) kcal").font(.headline).foregroundColor(.themePink)
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(Color.white)
    }
}

struct EmptyStateView: View {
    let imageName: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: imageName).font(.system(size: 48)).foregroundColor(.gray.opacity(0.3))
            Text(title).font(.headline).foregroundColor(.gray)
            Text(description).font(.subheadline).foregroundColor(.textGray.opacity(0.7)).multilineTextAlignment(.center).padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
struct FoodGradeBadge: View {
    let grade: HealthGrade
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: grade.icon)
                .font(.system(size: 10, weight: .bold))
            Text(grade.title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundColor(grade.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(grade.color.opacity(0.15))
        .cornerRadius(8)
    }
}
struct NutritionCarouselView: View {
    let summary: DailySummary
    let user: User?
    
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 12) {
            // Карусель из 4-х экранов
            TabView(selection: $selectedTab) {
                
                // СЛАЙД 1: Главный круг калорий + Полоски макросов
                EnergyOverviewCard(summary: summary, user: user)
                    .tag(0)
                
                // СЛАЙД 2: Раздельные кольца макросов
                DetailedMacroRingsCard(summary: summary, user: user)
                    .tag(1)
                
                // СЛАЙД 3: Микронутриенты и здоровье
                MicronutrientsFocusCard(summary: summary)
                    .tag(2)
                
                // СЛАЙД 4: Детализация по приемам пищи (По 4-му скриншоту)
                MealBreakdownCard(summary: summary)
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never)) // Скрываем системные точки
            .frame(height: 380) // Чуть увеличили высоту, чтобы все красиво влезло
            
            // Кастомные точки пагинации (Paginator) на 4 точки
            HStack(spacing: 8) {
                ForEach(0..<4) { index in
                    Circle()
                        .fill(selectedTab == index ? Color.themePink : Color.gray.opacity(0.3))
                        .frame(width: selectedTab == index ? 8 : 6, height: selectedTab == index ? 8 : 6)
                        .animation(.spring(), value: selectedTab)
                }
            }
        }
    }
}

// MARK: - Слайд 1: Энергия (Базовый круг + Полоски БЖУ)
struct EnergyOverviewCard: View {
    let summary: DailySummary
    let user: User?
    
    var body: some View {
        let target = (user?.dailyCaloriesGoal ?? 2400) + summary.activeCaloriesBurned
        
        VStack(spacing: 16) {
            Text("Energy Summary")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Твой оригинальный компонент круга (он остался как был)
            BreathingCaloriesDashboard(
                consumed: summary.totalCalories,
                target: target,
                activeBurned: summary.activeCaloriesBurned,
                protein: summary.totalProtein,
                fats: summary.totalFats,
                carbs: summary.totalCarbs
            )
            
            Spacer(minLength: 0)
            
            // ВЕРНУЛИ ПОЛОСКИ МАКРОСОВ НА ПЕРВЫЙ ЭКРАН
            MacroSummaryView(
                protein: summary.totalProtein,
                fats: summary.totalFats,
                carbs: summary.totalCarbs,
                targetProtein: user?.targetProtein ?? 150,
                targetFats: user?.targetFats ?? 70,
                targetCarbs: user?.targetCarbs ?? 250
            )
            .padding(.top, 8)
        }
        .ultraPremiumCardStyle()
        .padding(.horizontal)
    }
}

struct DetailedMacroRingsCard: View {
    let summary: DailySummary
    let user: User?
    
    // Генерируем умный совет на основе макросов
    private var smartInsight: (title: String, text: String, icon: String, color: Color) {
        let p = summary.totalProtein; let targetP = user?.targetProtein ?? 150
        let f = summary.totalFats; let targetF = user?.targetFats ?? 70
        let c = summary.totalCarbs; let targetC = user?.targetCarbs ?? 250
        
        if summary.totalFoodCalories == 0 {
            return ("Fresh Start", "Log your first meal to see your macro balance.", "leaf.fill", .green)
        } else if p < targetP * 0.4 && summary.totalFoodCalories > 800 {
            return ("Protein Alert", "You are low on protein today. Try adding chicken, eggs, or tofu to your next meal.", "dumbbell.fill", .themePeach)
        } else if f > targetF {
            return ("High Fat", "You've exceeded your daily fat limit. Focus on lean proteins and veggies.", "exclamationmark.triangle.fill", .themeYellow)
        } else if c < targetC * 0.3 {
            return ("Low Energy?", "Your carbs are quite low. Complex carbs like oats or rice can boost your energy.", "bolt.fill", .drinkWater)
        } else {
            return ("Perfect Balance", "Your macros are looking great today! Keep it up.", "checkmark.seal.fill", .themePink)
        }
    }
    
    var body: some View {
        let targetP = user?.targetProtein ?? 150
        let targetF = user?.targetFats ?? 70
        let targetC = user?.targetCarbs ?? 250
        
        VStack(spacing: 24) {
            Text("Macronutrients")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 15) {
                IndividualMacroRing(title: "Carbs", current: summary.totalCarbs, target: targetC, color: .drinkWater)
                IndividualMacroRing(title: "Fat", current: summary.totalFats, target: targetF, color: .themeYellow)
                IndividualMacroRing(title: "Protein", current: summary.totalProtein, target: targetP, color: .themePeach)
            }
            .padding(.vertical, 4)
            
            // НОВАЯ КАРТОЧКА: AI INSIGHT (Заполняет пустое место)
            let insight = smartInsight
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(insight.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: insight.icon)
                        .foregroundColor(insight.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(insight.text)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(16)
            .background(Color.gray.opacity(0.04))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(insight.color.opacity(0.3), lineWidth: 1))
            
            Spacer(minLength: 0)
        }
        .ultraPremiumCardStyle()
        .padding(.horizontal)
    }
}
struct IndividualMacroRing: View {
    let title: String
    let current: Double
    let target: Double
    let color: Color
    
    @State private var progress: Double = 0
    
    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 10)
                
                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.4), radius: 3, x: 0, y: 0)
                
                VStack(spacing: 0) {
                    Text("\(Int(current))")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                    Text("/ \(Int(target))g")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 80, height: 80)
            
            Text("\(Int((current/max(target, 1)) * 100))%")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    progress = current / max(target, 1.0)
                }
            }
        }
    }
}
struct MicronutrientsFocusCard: View {
    let summary: DailySummary
    
    // Берем данные из твоей модели (Meal)
    private var totalOmega3: Double { summary.meals.reduce(0) { $0 + $1.totalOmega3 } }
    private var totalMagnesium: Double { summary.meals.reduce(0) { $0 + $1.totalMagnesium } }
    private var totalCalcium: Double { summary.meals.reduce(0) { $0 + $1.totalCalcium } }
    private var totalIron: Double { summary.meals.reduce(0) { $0 + $1.totalIron } }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Health Focus")
                    .font(.headline)
                Spacer()
                Image(systemName: "heart.text.square.fill")
                    .foregroundColor(.themePink)
            }
            
            // СЕТКА НУТРИЕНТОВ (Выглядит гораздо плотнее и премиальнее)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                CompactMicroCard(title: "Omega-3", icon: "fish.fill", current: totalOmega3, target: 1.6, unit: "g", color: .themePink)
                CompactMicroCard(title: "Magnesium", icon: "bolt.heart.fill", current: totalMagnesium, target: 400, unit: "mg", color: .themeYellow)
                CompactMicroCard(title: "Calcium", icon: "bone.fill", current: totalCalcium, target: 1000, unit: "mg", color: .drinkWater)
                CompactMicroCard(title: "Iron", icon: "drop.fill", current: totalIron, target: 18, unit: "mg", color: .red.opacity(0.8))
            }
            
            // БАННЕР С СОВЕТОМ (Заполняет низ карточки)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Boost your minerals")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Text("Add spinach, nuts, or salmon to your next meal to easily hit these goals.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.9))
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .padding(16)
            .background(
                LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(16)
            .shadow(color: Color.themePink.opacity(0.3), radius: 8, y: 4)
            
            Spacer(minLength: 0)
        }
        .ultraPremiumCardStyle()
        .padding(.horizontal)
    }
}

// НОВЫЙ КОМПОНЕНТ ДЛЯ СЕТКИ
struct CompactMicroCard: View {
    let title: String
    let icon: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color
    
    @State private var progress: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                Spacer()
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(current, specifier: "%.1f")")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                Text("/ \(Int(target)) \(unit)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule()
                        .fill(color)
                        .frame(width: min(geo.size.width * CGFloat(progress), geo.size.width))
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    progress = current / max(target, 1.0)
                }
            }
        }
    }
}
struct MicroProgressBar: View {
    let title: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color
    
    @State private var progress: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                Spacer()
                Text("\(current, specifier: "%.1f") / \(Int(target)) \(unit)")
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))
                    
                    Capsule()
                        .fill(
                            LinearGradient(colors: [color.opacity(0.6), color], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: min(geo.size.width * CGFloat(progress), geo.size.width))
                        .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 0)
                }
            }
            .frame(height: 12)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    progress = current / max(target, 1.0)
                }
            }
        }
    }
}

struct MealBreakdownCard: View {
    let summary: DailySummary
    
    @State private var selectedMeal: String = "Breakfast"
    let mealsList = ["Breakfast", "Lunch", "Dinner", "Snack"]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Meals Breakdown")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Чистый Apple-style переключатель
            HStack(spacing: 8) {
                ForEach(mealsList, id: \.self) { meal in
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMeal = meal
                        }
                    }) {
                        Text(meal)
                            .font(.system(size: 13, weight: selectedMeal == meal ? .bold : .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedMeal == meal ? Color.themePink : Color.gray.opacity(0.08))
                            .foregroundColor(selectedMeal == meal ? .white : .gray)
                            .clipShape(Capsule())
                            .shadow(color: selectedMeal == meal ? Color.themePink.opacity(0.3) : .clear, radius: 4, y: 2)
                    }
                }
            }
            
            // Выбор текущего приема пищи из базы
            let currentMealData = summary.meals.first(where: { $0.title == selectedMeal })
            
            // Список данных
            VStack(spacing: 16) {
                MealMacroRow(title: "Calories", value: Double(currentMealData?.totalCalories ?? 0), unit: "kcal", color: .themePink)
                Divider()
                MealMacroRow(title: "Carbs", value: currentMealData?.totalCarbs ?? 0, unit: "g", color: .drinkWater)
                Divider()
                MealMacroRow(title: "Protein", value: currentMealData?.totalProtein ?? 0, unit: "g", color: .themePeach)
                Divider()
                MealMacroRow(title: "Fat", value: currentMealData?.totalFats ?? 0, unit: "g", color: .themeYellow)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.02), radius: 10, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.08), lineWidth: 1)
                    )
            )
            
            Spacer(minLength: 0)
        }
        .ultraPremiumCardStyle()
        .padding(.horizontal)
    }
}

// Строка данных для 4 слайда
struct MealMacroRow: View {
    let title: String
    let value: Double
    let unit: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
            Text("\(Int(value)) \(unit)")
                .font(.subheadline.bold())
                .foregroundColor(color)
                .contentTransition(.numericText())
        }
    }
}

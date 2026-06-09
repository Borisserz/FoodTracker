import SwiftUI
import SwiftData

struct PremiumQuickAddSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var summaries: [DailySummary]

    let selectedDate: Date
    var onSelectDetailedMeal: (String) -> Void

    init(selectedDate: Date, onSelectDetailedMeal: @escaping (String) -> Void) {
        self.selectedDate = selectedDate
        self.onSelectDetailedMeal = onSelectDetailedMeal
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = #Predicate<DailySummary> { $0.date >= startOfDay && $0.date < endOfDay }
        self._summaries = Query(filter: predicate)
    }

    @State private var quickCalories: Double = 300.0

    let mealOptions = [
        ("Breakfast", "sunrise.fill", Color.themeYellow),
        ("Lunch", "sun.max.fill", Color.green),
        ("Snack", "cup.and.saucer.fill", Color.themeOrange),
        ("Dinner", "moon.fill", Color.themePink)
    ]

    var body: some View {
        ZStack {

            Color.themeBg.ignoresSafeArea()

            VStack(spacing: 24) {

                HStack {
                    Text("Quick Add")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                VStack(spacing: 16) {
                    Text("Fast Calorie Entry")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 12) {

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(quickCalories))")
                                .font(.system(size: 56, weight: .heavy, design: .rounded))
                                .foregroundColor(.themePink)
                                .contentTransition(.numericText())

                            Text("kcal")
                                .font(.title3.bold())
                                .foregroundColor(.gray)
                        }

                        Slider(value: Binding(
                            get: { quickCalories },
                            set: { newValue in
                                quickCalories = newValue

                                if Int(newValue) % 50 == 0 {
                                    HapticManager.shared.impact(style: .light)
                                }
                            }
                        ), in: 10...1500, step: 10)
                        .tint(.themePink)

                        HStack(spacing: 12) {
                            QuickPresetButton(label: "-50", color: .gray) { adjustCalories(by: -50) }
                            QuickPresetButton(label: "+50", color: .gray) { adjustCalories(by: 50) }
                            QuickPresetButton(label: "+100", color: .themePink) { adjustCalories(by: 100) }
                            QuickPresetButton(label: "+300", color: .themePink) { adjustCalories(by: 300) }
                        }

                        Button(action: saveQuickCalories) {
                            Text("Log \(Int(quickCalories)) kcal")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.themePink)
                                .cornerRadius(16)
                                .shadow(color: Color.themePink.opacity(0.4), radius: 8, y: 4)
                        }
                        .buttonStyle(BounceButtonStyle())
                        .padding(.top, 8)
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.04), radius: 10, y: 5)
                }
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    Text("Or log a detailed meal")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(mealOptions, id: \.0) { meal in
                            Button(action: {
                                HapticManager.shared.impact(style: .medium)
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    onSelectDetailedMeal(meal.0)
                                }
                            }) {
                                HStack {
                                    Image(systemName: meal.1)
                                        .foregroundColor(meal.2)
                                    Text(meal.0)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
                            }
                            .buttonStyle(BounceButtonStyle())
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()
            }
        }
    }

    private func adjustCalories(by amount: Double) {
        HapticManager.shared.impact(style: .medium)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            quickCalories = max(10, min(1500, quickCalories + amount))
        }
    }

    private func saveQuickCalories() {
        HapticManager.shared.impact(style: .heavy)

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)

        let summary: DailySummary
        if let existing = summaries.first {
            summary = existing
        } else {
            summary = DailySummary(date: startOfDay)
            context.insert(summary)
        }

        let quickFood = FoodItem(name: "Quick Entry", weight: 0, calories: Int(quickCalories), protein: 0, fats: 0, carbs: 0)
        context.insert(quickFood)

        if let snackMeal = summary.meals.first(where: { $0.title == "Snack" }) {
            snackMeal.foodItems.append(quickFood)
        } else {
            let newMeal = Meal(title: "Snack", date: selectedDate, foodItems: [quickFood])
            context.insert(newMeal)
            summary.meals.append(newMeal)
        }

        try? context.save()
        dismiss()
    }
}

struct QuickPresetButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color.opacity(0.1))
                .cornerRadius(12)
        }
    }
}

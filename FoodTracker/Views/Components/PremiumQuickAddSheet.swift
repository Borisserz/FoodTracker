import SwiftUI
import SwiftData

struct PremiumQuickAddSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var summaries: [DailySummary]
    @Query private var users: [User]

    let selectedDate: Date
    var onSelectDetailedMeal: (String) -> Void
    var onSelectActivity: () -> Void

    init(selectedDate: Date, onSelectDetailedMeal: @escaping (String) -> Void, onSelectActivity: @escaping () -> Void = {}) {
        self.selectedDate = selectedDate
        self.onSelectDetailedMeal = onSelectDetailedMeal
        self.onSelectActivity = onSelectActivity
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86_400)
        let predicate = #Predicate<DailySummary> { $0.date >= startOfDay && $0.date < endOfDay }
        self._summaries = Query(filter: predicate)
    }

    @State private var quickCalories: Double = 300.0

    let mealOptions = [
        ("Breakfast", "sunrise.fill", EditorialPalette.warmAmber),
        ("Lunch", "sun.max.fill", EditorialPalette.emerald),
        ("Snack", "leaf.fill", EditorialPalette.oceanSlate),
        ("Dinner", "moon.stars.fill", EditorialPalette.softPeach)
    ]

    var body: some View {
        ZStack {
            DynamicAuroraBackgroundView(pinnedPaletteIndex: 2)
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    HStack {
                        Text("Quick Add")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(EditorialPalette.inkPrimary)
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(EditorialPalette.inkPrimary)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.84))
                                .clipShape(Circle())
                                .overlay(Circle().strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Fast Calorie Entry")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .textCase(.uppercase)
                            .foregroundStyle(EditorialPalette.inkSecondary)
                            .padding(.horizontal, 4)

                        EditorialDarkCard(cornerRadius: 22, padding: 20) {
                            VStack(spacing: 14) {
                                HStack(alignment: .firstTextBaseline, spacing: 5) {
                                    Text("\(Int(quickCalories))")
                                        .font(.system(size: 52, weight: .heavy, design: .rounded).monospacedDigit())
                                        .foregroundStyle(EditorialPalette.oat)
                                        .contentTransition(.numericText())

                                    Text("kcal")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.white.opacity(0.68))
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
                                .tint(EditorialPalette.oat)

                                HStack(spacing: 8) {
                                    QuickPresetButton(label: "-50") { adjustCalories(by: -50) }
                                    QuickPresetButton(label: "+50") { adjustCalories(by: 50) }
                                    QuickPresetButton(label: "+100", emphasized: true) { adjustCalories(by: 100) }
                                    QuickPresetButton(label: "+300", emphasized: true) { adjustCalories(by: 300) }
                                }

                                Button(action: saveQuickCalories) {
                                    Text("Log \(Int(quickCalories)) kcal")
                                }
                                .buttonStyle(EditorialPrimaryCTAButtonStyle(tone: .oat, height: 50, cornerRadius: 14))
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Or log a detailed meal")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .textCase(.uppercase)
                            .foregroundStyle(EditorialPalette.inkSecondary)
                            .padding(.horizontal, 4)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(mealOptions, id: \.0) { meal in
                                Button(action: {
                                    HapticManager.shared.impact(style: .medium)
                                    onSelectDetailedMeal(meal.0)
                                    dismiss()
                                }) {
                                    HStack(spacing: 9) {
                                        Image(systemName: meal.1)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(meal.2)
                                            .frame(width: 30, height: 30)
                                            .background(meal.2.opacity(0.14))
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        Text(LocalizedStringKey(meal.0))
                                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                                            .foregroundStyle(EditorialPalette.inkPrimary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.82))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
                                    )
                                }
                                .buttonStyle(BounceButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Button(action: {
                        HapticManager.shared.impact(style: .medium)
                        onSelectActivity()
                        dismiss()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Log Physical Activity")
                        }
                    }
                    .buttonStyle(EditorialPrimaryCTAButtonStyle(tone: .graphite, height: 52))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
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
        let summary = DailySummary.fetchOrCreate(for: startOfDay, in: context)

        let quickFood = FoodItem(name: "Quick Entry", weight: 0, calories: Int(quickCalories), protein: 0, fats: 0, carbs: 0)
        context.insert(quickFood)

        let mealTimestamp = calendar.isDateInToday(selectedDate) ? Date() : startOfDay
        if let snackMeal = (summary.meals ?? []).first(where: { DailySummary.canonicalMealSlot($0.title) == "Snack" }) {
            snackMeal.addFoodItem(quickFood)
            snackMeal.date = mealTimestamp
        } else {
            let newMeal = Meal(title: "Snack", date: mealTimestamp, foodItems: [quickFood])
            context.insert(newMeal)
            summary.addMeal(newMeal)
        }

        try? context.save()
        WidgetReloader.reloadAll()
        AppReviewManager.shared.userDidLogMeal()
        let addedCals = Int(quickCalories)
        if users.first?.isHealthKitEnabled == true && addedCals > 0 {
            let logDate = Calendar.current.isDateInToday(selectedDate) ? Date() : startOfDay
            let container = context.container
            Task { @MainActor in
                if let uuid = await HealthKitManager.shared.saveDietaryEnergy(calories: addedCals, date: logDate) {
                    quickFood.healthKitSampleID = uuid.uuidString
                    try? container.mainContext.save()
                }
            }
        }
        dismiss()
    }
}

struct QuickPresetButton: View {
    let label: String
    var emphasized: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13.5, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(emphasized ? EditorialPalette.oat : Color.white.opacity(0.76))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(EditorialPalette.chipDark)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(emphasized ? EditorialPalette.oat.opacity(0.28) : Color.white.opacity(0.08), lineWidth: 0.75)
                )
        }
    }
}

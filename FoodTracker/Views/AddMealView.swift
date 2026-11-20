import SwiftUI
import SwiftData

enum MealSlotPersistence {
    struct EditedItemSync {
        let item: FoodItem
        let oldSampleID: String?
        let oldCalories: Int
    }

    struct PersistenceSyncResult {
        let netCaloriesDelta: Int
        let insertedItems: [FoodItem]
        let editedItems: [EditedItemSync]
        let deletedSamples: [DailySummary.DeletedFoodHealthSample]
    }

    @MainActor
    static func persist(
        activeSlot: String,
        activeDrafts: [EditableFoodDraft],
        hasModifiedActiveSlot: Bool,
        draftsBySlot: [String: [EditableFoodDraft]],
        dirtySlots: Set<String>,
        summary: DailySummary,
        timestamp: Date,
        in context: ModelContext
    ) -> Int {
        persistWithSyncOps(
            activeSlot: activeSlot,
            activeDrafts: activeDrafts,
            hasModifiedActiveSlot: hasModifiedActiveSlot,
            draftsBySlot: draftsBySlot,
            dirtySlots: dirtySlots,
            summary: summary,
            timestamp: timestamp,
            in: context
        ).netCaloriesDelta
    }

    @MainActor
    static func persistWithSyncOps(
        activeSlot: String,
        activeDrafts: [EditableFoodDraft],
        hasModifiedActiveSlot: Bool,
        draftsBySlot: [String: [EditableFoodDraft]],
        dirtySlots: Set<String>,
        summary: DailySummary,
        timestamp: Date,
        in context: ModelContext
    ) -> PersistenceSyncResult {
        let canonicalActive = DailySummary.canonicalMealSlot(activeSlot)
        var slotsToCommit: [String: [EditableFoodDraft]] = [:]

        for slot in dirtySlots {
            let canonical = DailySummary.canonicalMealSlot(slot)
            slotsToCommit[canonical] = draftsBySlot[canonical] ?? draftsBySlot[slot] ?? []
        }

        if hasModifiedActiveSlot || dirtySlots.contains(canonicalActive) || (slotsToCommit.isEmpty && !activeDrafts.isEmpty) {
            slotsToCommit[canonicalActive] = activeDrafts
        }

        var netCaloriesDelta = 0
        var insertedItems: [FoodItem] = []
        var editedItems: [EditedItemSync] = []
        var deletedSamples: [DailySummary.DeletedFoodHealthSample] = []

        // Snapshot pre-mutation slot calories BEFORE `draft.apply(to:)` mutates existing `FoodItem`s in place.
        var previousCaloriesBySlot: [String: Int] = [:]
        for meal in summary.meals ?? [] {
            let slot = DailySummary.canonicalMealSlot(meal.title)
            previousCaloriesBySlot[slot, default: 0] += meal.totalCalories
        }

        for canonicalSlot in slotsToCommit.keys.sorted() {
            let drafts = slotsToCommit[canonicalSlot] ?? []
            var persistedItems: [FoodItem] = []
            for draft in drafts {
                if let existingItem = draft.existingItem {
                    let oldCalories = existingItem.calories
                    let oldSampleID = existingItem.healthKitSampleID
                    draft.apply(to: existingItem)
                    if oldCalories != existingItem.calories {
                        editedItems.append(EditedItemSync(item: existingItem, oldSampleID: oldSampleID, oldCalories: oldCalories))
                    }
                    persistedItems.append(existingItem)
                } else {
                    let newItem = draft.makeFoodItem()
                    context.insert(newItem)
                    insertedItems.append(newItem)
                    persistedItems.append(newItem)
                }
            }

            let previousCalories = previousCaloriesBySlot[canonicalSlot] ?? 0
            if let existingMeal = (summary.meals ?? []).first(where: { DailySummary.canonicalMealSlot($0.title) == canonicalSlot }) {
                let keptIDs = Set(persistedItems.map { $0.id })
                for food in (existingMeal.foodItems ?? []).filter({ !keptIDs.contains($0.id) }) {
                    deletedSamples.append(
                        DailySummary.DeletedFoodHealthSample(sampleID: food.healthKitSampleID, calories: food.calories)
                    )
                    context.delete(food)
                }
                if persistedItems.isEmpty {
                    summary.meals?.removeAll { $0.id == existingMeal.id }
                    context.delete(existingMeal)
                } else {
                    existingMeal.foodItems = persistedItems
                    existingMeal.date = timestamp
                }
            } else if !persistedItems.isEmpty {
                let newMeal = Meal(title: canonicalSlot, date: timestamp, foodItems: persistedItems)
                context.insert(newMeal)
                summary.addMeal(newMeal)
            }

            let newCalories = persistedItems.reduce(0) { $0 + $1.calories }
            netCaloriesDelta += (newCalories - previousCalories)
        }
        return PersistenceSyncResult(
            netCaloriesDelta: netCaloriesDelta,
            insertedItems: insertedItems,
            editedItems: editedItems,
            deletedSamples: deletedSamples
        )
    }
}

struct AddMealView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    @Query private var summaries: [DailySummary]
    @Query private var users: [User]
    
    @State private var selectedMealType: String
    @State private var selectedDrafts: [EditableFoodDraft] = []
    @State private var existingMealHadItems: Bool = false
    @State private var showingAddFood = false
    @State private var expandedFoodId: UUID? = nil
    @State private var hasModifiedDrafts = false
    @State private var draftsBySlot: [String: [EditableFoodDraft]] = [:]
    @State private var dirtySlots: Set<String> = []
    
    let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snack"]
    let selectedDate: Date
    
    init(selectedDate: Date, initialMealType: String = "Breakfast") {
        self.selectedDate = selectedDate
        self._selectedMealType = State(initialValue: initialMealType)
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = #Predicate<DailySummary> { $0.date >= startOfDay && $0.date < endOfDay }
        self._summaries = Query(filter: predicate)
    }
    
    // User goal helpers
    private var calorieGoal: Int {
        users.first?.dailyCaloriesGoal ?? 2000
    }
    
    private var proteinGoal: Double {
        users.first?.targetProtein ?? 130
    }
    
    private var carbsGoal: Double {
        users.first?.targetCarbs ?? 250
    }
    
    private var fatsGoal: Double {
        users.first?.targetFats ?? 70
    }
    
    // Current meal nutrients
    private var totalMealCalories: Int {
        selectedDrafts.reduce(0) { $0 + $1.calories }
    }
    
    private var totalMealProtein: Double {
        selectedDrafts.reduce(0) { $0 + $1.protein }
    }
    
    private var totalMealCarbs: Double {
        selectedDrafts.reduce(0) { $0 + $1.carbs }
    }
    
    private var totalMealFats: Double {
        selectedDrafts.reduce(0) { $0 + $1.fats }
    }

    private var otherLoggedCalories: Int {
        guard let summary = summaries.first else { return 0 }
        let activeCanonical = DailySummary.canonicalMealSlot(selectedMealType)
        let otherMeals = (summary.meals ?? []).reduce(0) { sum, meal in
            DailySummary.canonicalMealSlot(meal.title) == activeCanonical ? sum : sum + meal.totalCalories
        }
        let beverageCalories = (summary.beverages ?? []).reduce(0) { $0 + $1.caloriesPerGlass }
        return otherMeals + beverageCalories
    }

    private var remainingDailyCalorieBudget: Int {
        let burned = max(0, summaries.first?.activeCaloriesBurned ?? 0)
        return max(0, (calorieGoal + burned) - otherLoggedCalories)
    }

    private var canSaveMeal: Bool {
        !selectedDrafts.isEmpty || existingMealHadItems || !dirtySlots.isEmpty
    }
    
    func localizedMealType(_ type: String) -> String {
        String(localized: String.LocalizationValue(type))
    }
    
    private func mealIcon(for type: String) -> String {
        switch type {
        case "Breakfast": return "🍳"
        case "Lunch": return "🥗"
        case "Dinner": return "🥩"
        case "Snack": return "🍎"
        default: return "🥘"
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.themeBg.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 1. Dynamic Nutrition Summary Card
                        AddMealSummaryCard(
                            calories: totalMealCalories,
                            protein: totalMealProtein,
                            fats: totalMealFats,
                            carbs: totalMealCarbs,
                            calorieGoal: remainingDailyCalorieBudget,
                            proteinGoal: proteinGoal,
                            fatsGoal: fatsGoal,
                            carbsGoal: carbsGoal
                        )
                        .padding(.top, 8)
                        
                        // 2. Meal Type Carousel Selector
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Meal Type")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            HStack(spacing: 12) {
                                ForEach(mealTypes, id: \.self) { type in
                                    let isSelected = selectedMealType == type
                                    Button(action: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                            selectedMealType = type
                                        }
                                        HapticManager.shared.impact(style: .light)
                                    }) {
                                        VStack(spacing: 8) {
                                            Text(mealIcon(for: type))
                                                .font(.system(size: 26))
                                            Text(LocalizedStringKey(type))
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(isSelected ? ThemeManager.shared.current.primaryGradient : LinearGradient(colors: [Color.white], startPoint: .top, endPoint: .bottom))
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .cornerRadius(18)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(isSelected ? Color.clear : Color.gray.opacity(0.12), lineWidth: 1)
                                        )
                                        .shadow(color: isSelected ? ThemeManager.shared.current.primaryAccent.opacity(0.25) : Color.black.opacity(0.02), radius: 6, y: 3)
                                    }
                                    .buttonStyle(BounceButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // 3. Logged Food Items Section
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Food Items")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                Spacer()
                                if !selectedDrafts.isEmpty {
                                    Text("\(selectedDrafts.count) items")
                                        .font(.caption.bold())
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal)
                            
                            if selectedDrafts.isEmpty {
                                // Empty State View
                                VStack(spacing: 16) {
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 44))
                                        .foregroundColor(.themeOrange.opacity(0.4))
                                        .padding(.top, 20)
                                    
                                    Text("No food items added yet.")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(.gray)
                                    
                                    Button(action: {
                                        HapticManager.shared.impact(style: .medium)
                                        showingAddFood = true
                                    }) {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Add Food Item")
                                        }
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(ThemeManager.shared.current.primaryGradient)
                                        .cornerRadius(20)
                                        .shadow(color: ThemeManager.shared.current.primaryAccent.opacity(0.3), radius: 8, y: 4)
                                    }
                                    .buttonStyle(BounceButtonStyle())
                                    .accessibilityIdentifier("add_meal_add_food_button")
                                    .padding(.top, 4)
                                    .padding(.bottom, 20)
                                }
                                .frame(maxWidth: .infinity)
                                .ultraPremiumCardStyle()
                                .padding(.horizontal)
                            } else {
                                // Food List with inline expansion
                                VStack(spacing: 12) {
                                    LazyVStack(spacing: 12) {
                                        ForEach(selectedDrafts) { draft in
                                            FoodItemRowCard(
                                                draft: draft,
                                                isExpanded: expandedFoodId == draft.id,
                                                onToggleExpand: {
                                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                        if expandedFoodId == draft.id {
                                                            expandedFoodId = nil
                                                        } else {
                                                            expandedFoodId = draft.id
                                                        }
                                                    }
                                                    HapticManager.shared.impact(style: .light)
                                                },
                                                onUpdateWeight: { newWeight in
                                                    updateDraftWeight(draftId: draft.id, newWeight: newWeight)
                                                },
                                                onDelete: {
                                                    withAnimation(.spring()) {
                                                        selectedDrafts.removeAll { $0.id == draft.id }
                                                        hasModifiedDrafts = true
                                                    }
                                                }
                                            )
                                        }
                                    }

                                    // Keep outside LazyVStack so VoiceOver and UITests always discover it when items overflow vertically.
                                    Button(action: {
                                        HapticManager.shared.impact(style: .medium)
                                        showingAddFood = true
                                    }) {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Add Another Food")
                                        }
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(.themePink)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.white)
                                        .cornerRadius(18)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(Color.themePink.opacity(0.2), lineWidth: 1.5)
                                        )
                                        .shadow(color: Color.black.opacity(0.01), radius: 5, y: 2)
                                    }
                                    .buttonStyle(BounceButtonStyle())
                                    .accessibilityIdentifier("add_meal_add_another_button")
                                    .padding(.top, 4)
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        Spacer().frame(height: 24)
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ZStack(alignment: .bottom) {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .frame(height: 92)
                            .mask(LinearGradient(colors: [.white, .white, .clear], startPoint: .bottom, endPoint: .top))
                            .allowsHitTesting(false)
                        
                        HStack(spacing: 16) {
                            Button(action: { dismiss() }) {
                                Text("Cancel")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.white)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(BounceButtonStyle())
                            
                            Button(action: saveMealAndDismiss) {
                                Text("Save Meal")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background {
                                        if !canSaveMeal {
                                            Color.gray.opacity(0.3)
                                        } else {
                                            ThemeManager.shared.current.primaryGradient
                                        }
                                    }
                                    .cornerRadius(20)
                                    .shadow(color: !canSaveMeal ? Color.clear : ThemeManager.shared.current.primaryAccent.opacity(0.35), radius: 8, y: 4)
                            }
                            .disabled(!canSaveMeal)
                            .buttonStyle(BounceButtonStyle())
                            .accessibilityIdentifier("add_meal_save_button")
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle("Log Meal")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.themePink)
            .sheet(isPresented: $showingAddFood) {
                SmartAddFoodView(mealTitle: localizedMealType(selectedMealType), targetDate: selectedDate) { newItems in
                    let newDrafts = newItems.map { EditableFoodDraft(food: $0) }
                    self.selectedDrafts.append(contentsOf: newDrafts)
                    self.hasModifiedDrafts = true
                }
                .presentationDetents([.fraction(0.85), .large])
                .presentationCornerRadius(32)
            }
        }
        .onAppear {
            loadExistingFoods()
        }
        .onChange(of: selectedMealType) { oldSlot, newSlot in
            let canonicalOld = DailySummary.canonicalMealSlot(oldSlot)
            let canonicalNew = DailySummary.canonicalMealSlot(newSlot)
            guard canonicalOld != canonicalNew else { return }

            if hasModifiedDrafts {
                draftsBySlot[canonicalOld] = selectedDrafts
                dirtySlots.insert(canonicalOld)
            }

            if let cachedDrafts = draftsBySlot[canonicalNew] {
                selectedDrafts = cachedDrafts
                existingMealHadItems = existingMealHasItems(for: canonicalNew)
                hasModifiedDrafts = dirtySlots.contains(canonicalNew)
            } else {
                loadExistingFoods()
            }
        }
    }

    private func existingMeal(for mealType: String, in summary: DailySummary? = nil) -> Meal? {
        let canonicalTarget = DailySummary.canonicalMealSlot(mealType)
        return (summary ?? summaries.first)?.meals?.first(where: { DailySummary.canonicalMealSlot($0.title) == canonicalTarget })
    }

    private func existingMealHasItems(for mealType: String) -> Bool {
        !(existingMeal(for: mealType)?.foodItems ?? []).isEmpty
    }
    
    private func loadExistingFoods() {
        if let existingMeal = existingMeal(for: selectedMealType) {
            let items = existingMeal.foodItems ?? []
            selectedDrafts = items.map { EditableFoodDraft(food: $0) }
            existingMealHadItems = !items.isEmpty
        } else {
            selectedDrafts = []
            existingMealHadItems = false
        }
        hasModifiedDrafts = false
    }
    
    // Non-destructive baseline scaling (prevents Int truncation loss & unsaved SwiftData mutations)
    private func updateDraftWeight(draftId: UUID, newWeight: Double) {
        guard newWeight > 0, let index = selectedDrafts.firstIndex(where: { $0.id == draftId }) else { return }
        selectedDrafts[index].weight = newWeight
        hasModifiedDrafts = true
    }
    
    private func saveMealAndDismiss() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let summaryToUse = DailySummary.fetchOrCreate(for: startOfDay, in: modelContext)
        let mealTimestamp = calendar.isDateInToday(selectedDate) ? Date.now : startOfDay

        let syncResult = MealSlotPersistence.persistWithSyncOps(
            activeSlot: selectedMealType,
            activeDrafts: selectedDrafts,
            hasModifiedActiveSlot: hasModifiedDrafts,
            draftsBySlot: draftsBySlot,
            dirtySlots: dirtySlots,
            summary: summaryToUse,
            timestamp: mealTimestamp,
            in: modelContext
        )
        let shouldSyncHealthKit = users.first?.isHealthKitEnabled == true

        do {
            try modelContext.save()
            WidgetReloader.reloadAll()
            AppReviewManager.shared.userDidLogMeal()
            if shouldSyncHealthKit {
                let inserted = syncResult.insertedItems
                let edited = syncResult.editedItems
                let deleted = syncResult.deletedSamples
                let container = modelContext.container
                Task { @MainActor in
                    let hk = HealthKitManager.shared
                    for sample in deleted {
                        await hk.deleteDietaryEnergySample(
                            idString: sample.sampleID,
                            caloriesFallback: sample.calories,
                            date: mealTimestamp
                        )
                    }
                    for op in edited {
                        op.item.healthKitSampleID = await hk.syncEditedDietaryEnergy(
                            oldID: op.oldSampleID,
                            oldCalories: op.oldCalories,
                            newCalories: op.item.calories,
                            date: mealTimestamp
                        )
                    }
                    for item in inserted where item.calories > 0 {
                        if let uuid = await hk.saveDietaryEnergy(calories: item.calories, date: mealTimestamp) {
                            item.healthKitSampleID = uuid.uuidString
                        }
                    }
                    try? container.mainContext.save()
                }
            }
            dismiss()
        } catch {
            print("Failed to save meal: \(error.localizedDescription)")
        }
    }
}

// MARK: - Subviews

private struct AddMealSummaryCard: View {
    let calories: Int
    let protein: Double
    let fats: Double
    let carbs: Double
    
    let calorieGoal: Int
    let proteinGoal: Double
    let fatsGoal: Double
    let carbsGoal: Double
    
    private var progress: Double {
        calorieGoal > 0 ? Double(calories) / Double(calorieGoal) : 0.0
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                // Calorie Ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.1), lineWidth: 10)
                    
                    Circle()
                        .trim(from: 0.0, to: min(progress, 1.0))
                        .stroke(
                            ThemeManager.shared.current.primaryGradient,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 2) {
                        Text("\(calories)")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                        Text("kcal")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 88, height: 88)
                
                // Text info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(calories)")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                        Text("/ \(calorieGoal) kcal")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    
                    let remaining = calorieGoal - calories
                    if remaining >= 0 {
                        Text("Calories Left: **\(remaining)**")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.themeOrange)
                    } else {
                        Text("Over Goal: **\(abs(remaining))**")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.red)
                    }
                }
                Spacer()
            }
            
            Divider()
            
            // Macro Grid/Pills
            HStack(spacing: 12) {
                MacroSummaryMiniProgress(title: "Protein", current: protein, goal: proteinGoal, color: .themePink)
                MacroSummaryMiniProgress(title: "Carbs", current: carbs, goal: carbsGoal, color: .blue)
                MacroSummaryMiniProgress(title: "Fat", current: fats, goal: fatsGoal, color: .orange)
            }
        }
        .padding(20)
        .glassEffect()
        .padding(.horizontal)
    }
}

private struct MacroSummaryMiniProgress: View {
    let title: String
    let current: Double
    let goal: Double
    let color: Color
    
    private var progress: Double {
        goal > 0 ? current / goal : 0.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                Spacer()
                Text("\(Int(current))g")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.12))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(progress, 1.0), height: 6)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FoodItemRowCard: View {
    let draft: EditableFoodDraft
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onUpdateWeight: (Double) -> Void
    let onDelete: () -> Void
    
    @State private var localWeight: Double = 100.0
    @State private var textInput: String = "100"
    @FocusState private var isWeightFieldFocused: Bool
    
    private func emojiForFood(_ name: String) -> String {
        let nameLower = name.lowercased()
        if nameLower.contains("yogurt") || nameLower.contains("йогурт") { return "🥛" }
        if nameLower.contains("granola") || nameLower.contains("гранола") || nameLower.contains("овсян") || nameLower.contains("oat") { return "🥣" }
        if nameLower.contains("coffee") || nameLower.contains("кофе") { return "☕️" }
        if nameLower.contains("apple") || nameLower.contains("яблоко") { return "🍎" }
        if nameLower.contains("chicken") || nameLower.contains("куриц") { return "🍗" }
        if nameLower.contains("avocado") || nameLower.contains("авокадо") { return "🥑" }
        if nameLower.contains("egg") || nameLower.contains("яйцо") || nameLower.contains("яиц") { return "🍳" }
        if nameLower.contains("salad") || nameLower.contains("салат") { return "🥗" }
        if nameLower.contains("meat") || nameLower.contains("мясо") || nameLower.contains("steak") || nameLower.contains("стейк") { return "🥩" }
        if nameLower.contains("banana") || nameLower.contains("банан") { return "🍌" }
        if nameLower.contains("fish") || nameLower.contains("рыба") || nameLower.contains("salmon") || nameLower.contains("лосось") { return "🐟" }
        if nameLower.contains("water") || nameLower.contains("вода") { return "💧" }
        return "🥘"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggleExpand) {
                HStack(spacing: 16) {
                    Text(emojiForFood(draft.name))
                        .font(.system(size: 26))
                        .frame(width: 46, height: 46)
                        .background(Color.themeBg.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(draft.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                        
                        let weightLabel = draft.baseWeight > 0
                            ? "\(Int(draft.scaled.weight))g"
                            : String(localized: "1 serving")
                        Text("\(weightLabel) • \(draft.calories) kcal")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("\(draft.calories) kcal")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.themePink)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)
                
                VStack(spacing: 16) {
                    if draft.baseWeight > 0 {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Portion Weight")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.gray)
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    TextField("100", text: $textInput)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.themePink)
                                        .focused($isWeightFieldFocused)
                                        .frame(width: 80)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(Color.themeBg.opacity(0.5))
                                        .cornerRadius(10)
                                        .onChange(of: textInput) { _, newValue in
                                            if let val = NutritionMath.parsePositiveDecimal(newValue) {
                                                localWeight = val
                                                onUpdateWeight(val)
                                            }
                                        }
                                    
                                    Text("g")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Slider(value: $localWeight, in: 5...1000, step: 5)
                                .tint(.themePink)
                                .onChange(of: localWeight) { _, newValue in
                                    if !isWeightFieldFocused {
                                        let newText = String(format: "%.0f", newValue)
                                        if textInput != newText {
                                            textInput = newText
                                        }
                                    }
                                    onUpdateWeight(newValue)
                                }
                        }
                        
                        HStack(spacing: 8) {
                            ForEach([50, 100, 150, 200], id: \.self) { amount in
                                Button(action: {
                                    HapticManager.shared.impact(style: .medium)
                                    let amountDbl = Double(amount)
                                    localWeight = amountDbl
                                    textInput = "\(amount)"
                                    onUpdateWeight(amountDbl)
                                }) {
                                    Text("\(amount)g")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(draft.weight == Double(amount) ? Color.themePink.opacity(0.15) : Color.gray.opacity(0.06))
                                        .foregroundColor(draft.weight == Double(amount) ? .themePink : .primary)
                                        .cornerRadius(10)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                HapticManager.shared.impact(style: .medium)
                                onDelete()
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red.opacity(0.8))
                                    .padding(8)
                                    .background(Color.red.opacity(0.08))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    } else {
                        HStack {
                            Text("Fixed per serving — nutrition applies as logged.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {
                                HapticManager.shared.impact(style: .medium)
                                onDelete()
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red.opacity(0.8))
                                    .padding(8)
                                    .background(Color.red.opacity(0.08))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(16)
                .background(Color.gray.opacity(0.01))
            }
        }
        .background(Color.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isExpanded ? Color.themePink.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
        .onAppear {
            localWeight = draft.weight > 0 ? draft.weight : 100.0
            textInput = String(format: "%.0f", localWeight)
        }
        .onChange(of: draft.weight) { _, newWeight in
            if localWeight != newWeight {
                localWeight = newWeight
                textInput = String(format: "%.0f", newWeight)
            }
        }
    }
}

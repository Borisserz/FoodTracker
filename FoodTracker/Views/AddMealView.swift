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

enum MealHUDStaging {
    /// A new staged row. The source `FoodItem` stays on its old meal.
    static func appending(_ food: FoodItem, to drafts: [EditableFoodDraft]) -> [EditableFoodDraft] {
        drafts + [EditableFoodDraft(food: food, isNewMealEntry: true)]
    }

    /// Drops the latest staged portion whose name matches, ignoring case.
    static func removingLast(named name: String, from drafts: [EditableFoodDraft]) -> [EditableFoodDraft] {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let index = drafts.lastIndex(where: { $0.name.lowercased() == key }) else { return drafts }
        var copy = drafts
        copy.remove(at: index)
        return copy
    }
}

enum MealQuickLogCommit {
    /// Drafts for an append-only quick log.
    /// Food already in the slot stays on its `FoodItem`.
    /// Each staged row is copied, so a history or catalog item is not moved into the slot.
    static func drafts(existingSlotItems: [FoodItem], staged: [EditableFoodDraft]) -> [EditableFoodDraft] {
        let kept = existingSlotItems.map { EditableFoodDraft(food: $0) }
        let copies = staged.map { $0.detachedCopy() }
        return kept + copies
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
            ZStack {
                DynamicAuroraBackgroundView(pinnedPaletteIndex: EditorialMealTheme.paletteIndex(for: selectedMealType))
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
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
                            
                            // 2. Meal Type Editorial Selector
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Meal Type")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .textCase(.uppercase)
                                    .foregroundStyle(EditorialPalette.inkSecondary)
                                    .padding(.horizontal, 20)
                                
                                HStack(spacing: 8) {
                                    ForEach(mealTypes, id: \.self) { type in
                                        let isSelected = selectedMealType == type
                                        let slotAccent = EditorialMealTheme.accentColor(for: type)
                                        Button(action: {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                                selectedMealType = type
                                            }
                                            HapticManager.shared.impact(style: .light)
                                        }) {
                                            VStack(spacing: 7) {
                                                Image(systemName: EditorialMealTheme.symbolName(for: type))
                                                    .font(.system(size: 18, weight: .semibold))
                                                    .foregroundStyle(isSelected ? slotAccent : EditorialPalette.inkSecondary)
                                                Text(LocalizedStringKey(type))
                                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.75)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(isSelected ? EditorialPalette.cardDark : EditorialPalette.surfaceLight)
                                            .foregroundStyle(isSelected ? Color.white : EditorialPalette.inkPrimary)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .strokeBorder(
                                                        isSelected ? EditorialPalette.cardBorderDarkFocused : EditorialPalette.hairlineLight,
                                                        lineWidth: isSelected ? 1.2 : 0.75
                                                    )
                                            )
                                        }
                                        .buttonStyle(BounceButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                            
                            // 3. Logged Food Items Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Food Items")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundStyle(EditorialPalette.inkPrimary)
                                    Spacer()
                                    if !selectedDrafts.isEmpty {
                                        Text("\(selectedDrafts.count) items")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(EditorialPalette.inkSecondary)
                                    }
                                }
                                .padding(.horizontal, 20)
                                
                                if selectedDrafts.isEmpty {
                                    EditorialLightCard(cornerRadius: 20, padding: 24) {
                                        VStack(spacing: 14) {
                                            Image(systemName: "fork.knife")
                                                .font(.system(size: 32, weight: .medium))
                                                .foregroundStyle(EditorialPalette.inkSecondary.opacity(0.65))
                                            
                                            Text("No food items added yet.")
                                                .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                                                .foregroundStyle(EditorialPalette.inkSecondary)
                                            
                                            Button(action: {
                                                HapticManager.shared.impact(style: .medium)
                                                showingAddFood = true
                                            }) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "plus.circle.fill")
                                                    Text("Add Food Item")
                                                }
                                                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                                                .foregroundStyle(EditorialPalette.oat)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 12)
                                                .background(EditorialPalette.cardDark)
                                                .clipShape(Capsule())
                                                .overlay(Capsule().strokeBorder(EditorialPalette.cardBorderDark, lineWidth: 1))
                                            }
                                            .buttonStyle(BounceButtonStyle())
                                            .accessibilityIdentifier("add_meal_add_food_button")
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .padding(.horizontal, 20)
                                } else {
                                    // Food List with inline expansion
                                    VStack(spacing: 10) {
                                        LazyVStack(spacing: 10) {
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
                                            HStack(spacing: 6) {
                                                Image(systemName: "plus.circle.fill")
                                                Text("Add Another Food")
                                            }
                                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                                            .foregroundStyle(EditorialPalette.inkPrimary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 13)
                                            .background(EditorialPalette.surfaceLight)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
                                            )
                                        }
                                        .buttonStyle(BounceButtonStyle())
                                        .accessibilityIdentifier("add_meal_add_another_button")
                                        .padding(.top, 2)
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            
                            Spacer().frame(height: 16)
                        }
                    }

                    // Pinned footer never overlaps ScrollView content hits
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(EditorialPalette.hairlineLight)
                            .frame(height: 0.5)

                        HStack(spacing: 12) {
                            Button(action: { dismiss() }) {
                                Text("Cancel")
                                    .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(EditorialPalette.inkPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(EditorialPalette.surfaceLight)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
                                    )
                            }
                            .buttonStyle(BounceButtonStyle())
                            
                            Button(action: saveMealAndDismiss) {
                                Text("Save Meal")
                            }
                            .buttonStyle(EditorialPrimaryCTAButtonStyle(tone: .graphite, isEnabled: canSaveMeal, height: 52))
                            .disabled(!canSaveMeal)
                            .accessibilityIdentifier("add_meal_save_button")
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 12)
                    }
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Log Meal")
            .navigationBarTitleDisplayMode(.inline)
            .tint(EditorialPalette.inkPrimary)
            .keyboardDoneToolbar()
            .sheet(isPresented: $showingAddFood) {
                SmartAddFoodView(mealTitle: localizedMealType(selectedMealType), targetDate: selectedDate) { newItems in
                    let newDrafts = newItems.map { EditableFoodDraft(food: $0, isNewMealEntry: true) }
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
            #if DEBUG
            print("Failed to save meal: \(error.localizedDescription)")
            #endif
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
        EditorialDarkCard(cornerRadius: 22, padding: 18) {
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 9)
                        
                        Circle()
                            .trim(from: 0.0, to: min(progress, 1.0))
                            .stroke(EditorialPalette.oat, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 1) {
                            Text("\(calories)")
                                .font(.system(size: 20, weight: .heavy, design: .rounded).monospacedDigit())
                                .foregroundStyle(.white)
                            Text("kcal")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.62))
                        }
                    }
                    .frame(width: 82, height: 82)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(calories)")
                                .font(.system(size: 28, weight: .heavy, design: .rounded).monospacedDigit())
                                .foregroundStyle(EditorialPalette.oat)
                            Text("/ \(calorieGoal) kcal")
                                .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(Color.white.opacity(0.65))
                        }
                        
                        let remaining = calorieGoal - calories
                        if remaining >= 0 {
                            Text("Calories Left: **\(remaining)**")
                                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                                .foregroundStyle(EditorialPalette.emerald)
                        } else {
                            Text("Over Goal: **\(abs(remaining))**")
                                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                                .foregroundStyle(EditorialPalette.softPeach)
                        }
                    }
                    Spacer()
                }
                
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 0.5)
                
                HStack(spacing: 12) {
                    MacroSummaryMiniProgress(title: "Protein", current: protein, goal: proteinGoal, color: EditorialPalette.emerald)
                    MacroSummaryMiniProgress(title: "Carbs", current: carbs, goal: carbsGoal, color: EditorialPalette.oceanSlate)
                    MacroSummaryMiniProgress(title: "Fat", current: fats, goal: fatsGoal, color: EditorialPalette.warmAmber)
                }
            }
        }
        .padding(.horizontal, 20)
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
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Spacer()
                Text("\(Int(current))g")
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 5)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(progress, 1.0), height: 5)
                }
            }
            .frame(height: 5)
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
    
    @AppStorage("useMetricSystem") private var useMetricSystem = true
    @State private var localWeight: Double = 100.0
    @State private var textInput: String = "100"
    @FocusState private var isWeightFieldFocused: Bool

    private func formattedInput(for grams: Double) -> String {
        let display = NutritionMath.displayFoodWeight(grams, useMetric: useMetricSystem)
        return useMetricSystem ? String(format: "%.0f", display) : String(format: "%.1f", display)
    }
    
    var body: some View {
        let meta = EditorialMealTheme.foodCategoryMeta(for: draft.name)

        VStack(spacing: 0) {
            Button(action: onToggleExpand) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(meta.color.opacity(0.14))
                            .frame(width: 42, height: 42)
                        Image(systemName: meta.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(meta.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(draft.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(EditorialPalette.inkPrimary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                        
                        let weightLabel = draft.baseWeight > 0
                            ? NutritionMath.formattedFoodWeight(draft.scaled.weight, useMetric: useMetricSystem)
                            : String(localized: "1 serving")
                        Text("\(weightLabel) • \(draft.calories) kcal")
                            .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundStyle(EditorialPalette.inkSecondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("\(draft.calories) kcal")
                            .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(EditorialPalette.inkPrimary)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(EditorialPalette.inkSecondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Rectangle()
                    .fill(EditorialPalette.hairlineLight)
                    .frame(height: 0.5)
                    .padding(.horizontal, 14)
                
                VStack(spacing: 14) {
                    if draft.baseWeight > 0 {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Portion Weight")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(EditorialPalette.inkSecondary)
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    TextField(useMetricSystem ? "100" : "3.5", text: $textInput)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .font(.system(size: 15.5, weight: .bold, design: .rounded).monospacedDigit())
                                        .foregroundStyle(EditorialPalette.inkPrimary)
                                        .focused($isWeightFieldFocused)
                                        .frame(width: 78)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(Color.black.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .onChange(of: textInput) { _, newValue in
                                            guard isWeightFieldFocused, newValue != formattedInput(for: localWeight) else { return }
                                            if let val = NutritionMath.parsePositiveDecimal(newValue) {
                                                let grams = min(NutritionMath.gramsFromDisplayFoodWeight(val, useMetric: useMetricSystem), 50_000)
                                                localWeight = grams
                                                onUpdateWeight(grams)
                                            }
                                        }
                                    
                                    Text(NutritionMath.foodWeightUnit(useMetric: useMetricSystem))
                                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                        .foregroundStyle(EditorialPalette.inkSecondary)
                                }
                            }
                            
                            Slider(value: $localWeight, in: 5...1000, step: 5)
                                .tint(EditorialPalette.inkPrimary)
                                .onChange(of: localWeight) { _, newValue in
                                    if !isWeightFieldFocused {
                                        let newText = formattedInput(for: newValue)
                                        if textInput != newText {
                                            textInput = newText
                                        }
                                    }
                                    onUpdateWeight(newValue)
                                }
                        }
                        
                        HStack(spacing: 8) {
                            ForEach([50, 100, 150, 200], id: \.self) { amount in
                                let isActive = draft.weight == Double(amount)
                                Button(action: {
                                    HapticManager.shared.impact(style: .medium)
                                    isWeightFieldFocused = false
                                    let amountDbl = Double(amount)
                                    localWeight = amountDbl
                                    textInput = formattedInput(for: amountDbl)
                                    onUpdateWeight(amountDbl)
                                }) {
                                    Text(NutritionMath.formattedFoodWeight(Double(amount), useMetric: useMetricSystem))
                                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(isActive ? EditorialPalette.inkPrimary : Color.black.opacity(0.05))
                                        .foregroundStyle(isActive ? Color.themeBg : EditorialPalette.inkPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                HapticManager.shared.impact(style: .medium)
                                onDelete()
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(EditorialPalette.softPeach)
                                    .frame(width: 32, height: 32)
                                    .background(EditorialPalette.softPeach.opacity(0.12))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    } else {
                        HStack {
                            Text("Fixed per serving — nutrition applies as logged.")
                                .font(.caption)
                                .foregroundStyle(EditorialPalette.inkSecondary)
                            Spacer()
                            Button(action: {
                                HapticManager.shared.impact(style: .medium)
                                onDelete()
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(EditorialPalette.softPeach)
                                    .frame(width: 32, height: 32)
                                    .background(EditorialPalette.softPeach.opacity(0.12))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(14)
            }
        }
        .background(Color.white.opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isExpanded ? EditorialPalette.inkPrimary.opacity(0.24) : EditorialPalette.hairlineLight, lineWidth: isExpanded ? 1.1 : 0.75)
        )
        .onAppear {
            localWeight = draft.weight > 0 ? draft.weight : 100.0
            textInput = formattedInput(for: localWeight)
        }
        .onChange(of: draft.weight) { _, newWeight in
            if localWeight != newWeight {
                localWeight = newWeight
                if !isWeightFieldFocused {
                    textInput = formattedInput(for: newWeight)
                }
            }
        }
        .onChange(of: useMetricSystem) { _, _ in
            if !isWeightFieldFocused {
                let formatted = formattedInput(for: localWeight)
                if textInput != formatted {
                    textInput = formatted
                }
            }
        }
        .onChange(of: isWeightFieldFocused) { _, focused in
            if !focused {
                let formatted = formattedInput(for: localWeight)
                if textInput != formatted {
                    textInput = formatted
                }
            }
        }
    }
}

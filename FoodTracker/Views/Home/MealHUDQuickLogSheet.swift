import SwiftUI
import SwiftData
import UIKit

// MARK: - Meal HUD Quick-Log & Spotlight Search Sheet (Apple HIG HUD Standard)
struct MealHUDQuickLogSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("useMetricSystem") private var useMetricSystem = true
    
    @Query private var summaries: [DailySummary]
    @Query private var users: [User]
    @Query private var customRecipes: [CustomRecipe]
    
    let selectedDate: Date
    @State private var selectedSlot: String
    
    @State private var searchText = ""
    @State private var selectedCategory = "Recent"
    
    // Staged items for 1-tap quick logging
    @State private var stagedDrafts: [EditableFoodDraft] = []
    @State private var expandedDraftId: UUID? = nil
    
    // Modals
    @State private var showingScanner = false
    @State private var showingManualAdd = false
    @State private var pendingScannerFood: FoodItem? = nil
    @State private var pendingManualEntryAfterScanner = false
    @State private var selectedFoodForDeepDetail: FoodItem? = nil
    @State private var showCommitError = false
    
    // Search caches
    @State private var localCatalogResults: [FoodItem] = []
    @State private var apiSearchResults: [FoodItem] = []
    @State private var isSearchingAPI = false
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var cachedAvailableFoods: [FoodItem] = []
    @State private var cachedRecipeFoods: [FoodItem] = []
    @State private var cachedFoodCounts: [String: Int] = [:]
    
    let mealSlots = ["Breakfast", "Lunch", "Dinner", "Snack"]
    let categories = ["Recent", "Frequent", "Often", "My Recipes"]
    
    init(selectedDate: Date, initialMealType: String = "Breakfast") {
        self.selectedDate = selectedDate
        self._selectedSlot = State(initialValue: initialMealType)
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = #Predicate<DailySummary> { $0.date >= startOfDay && $0.date < endOfDay }
        self._summaries = Query(filter: predicate)
    }
    
    private var currentUser: User? { users.first }
    private var activeDietPlan: DietPlan? { currentUser?.activeDietPlan }
    
    // Staged Totals
    private var stagedCalories: Int { stagedDrafts.reduce(0) { $0 + $1.calories } }
    private var stagedProtein: Double { stagedDrafts.reduce(0) { $0 + $1.protein } }
    private var stagedFats: Double { stagedDrafts.reduce(0) { $0 + $1.fats } }
    private var stagedCarbs: Double { stagedDrafts.reduce(0) { $0 + $1.carbs } }
    
    // Localized strings
    private func localizedMealType(_ type: String) -> String {
        String(localized: String.LocalizationValue(type))
    }

    private func categoryFilterSymbol(for category: String) -> String {
        switch category {
        case "Recent": return "clock"
        case "Frequent": return "flame.fill"
        case "Often": return "repeat"
        case "My Recipes": return "book.closed"
        default: return "fork.knife"
        }
    }
    
    // Filtered list
    private var filteredLocalFoods: [FoodItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            var seen = Set<String>()
            var combined: [FoodItem] = []
            for item in cachedAvailableFoods + cachedRecipeFoods {
                if item.name.localizedCaseInsensitiveContains(trimmed),
                   seen.insert(item.name.lowercased()).inserted {
                    combined.append(item)
                }
            }
            return combined
        }
        
        switch selectedCategory {
        case "Recent":
            return cachedAvailableFoods
        case "Frequent":
            return cachedAvailableFoods.sorted {
                let c0 = cachedFoodCounts[$0.name] ?? 0
                let c1 = cachedFoodCounts[$1.name] ?? 0
                return c0 != c1 ? c0 > c1 : $0.name < $1.name
            }
        case "Often":
            return cachedAvailableFoods.filter { (cachedFoodCounts[$0.name] ?? 0) >= 2 }
        case "My Recipes":
            return cachedRecipeFoods
        default:
            return cachedAvailableFoods
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                DynamicAuroraBackgroundView(pinnedPaletteIndex: EditorialMealTheme.paletteIndex(for: selectedSlot))
                    .allowsHitTesting(false)
                
                VStack(spacing: 0) {
                    // 1. Drag Handle & Editorial Control Deck
                    VStack(spacing: 11) {
                        Capsule()
                            .fill(EditorialPalette.inkPrimary.opacity(0.18))
                            .frame(width: 40, height: 5)
                            .padding(.top, 10)
                        
                        // Meal Slot Segment Switcher (Obsidian Active Pill)
                        HStack(spacing: 4) {
                            ForEach(mealSlots, id: \.self) { slot in
                                let isSelected = DailySummary.canonicalMealSlot(selectedSlot) == DailySummary.canonicalMealSlot(slot)
                                let slotAccent = EditorialMealTheme.accentColor(for: slot)
                                Button(action: {
                                    withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.78)) {
                                        selectedSlot = slot
                                    }
                                    HapticManager.shared.impact(style: .light)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: EditorialMealTheme.symbolName(for: slot))
                                            .font(.system(size: 10.5, weight: .bold))
                                            .foregroundStyle(isSelected ? slotAccent : EditorialPalette.inkSecondary)
                                        Text(LocalizedStringKey(slot))
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.72)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 6)
                                    .frame(maxWidth: .infinity)
                                    .background(isSelected ? EditorialPalette.cardDark : Color.clear)
                                    .foregroundStyle(isSelected ? Color.white : EditorialPalette.inkSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(HUDSpringButtonStyle(reduceMotion: reduceMotion))
                            }
                        }
                        .padding(4)
                        .background(EditorialPalette.surfaceLight)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
                        )
                        .padding(.horizontal, 16)
                        
                        // Spotlight Search Bar
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(EditorialPalette.inkSecondary)
                            
                            TextField(String(localized: "Search foods or scan..."), text: $searchText)
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundStyle(EditorialPalette.inkPrimary)
                                .accessibilityIdentifier("hud_quick_log_search_field")
                            
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(EditorialPalette.inkSecondary.opacity(0.55))
                                }
                                .accessibilityLabel(String(localized: "Clear search"))
                            }
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.88))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
                        )
                        .padding(.horizontal, 16)
                        
                        // MARK: - Dual Action Fast Deck (Editorial Obsidian Cards)
                        HStack(spacing: 10) {
                            // 1. AI & Barcode Camera Scanner
                            Button(action: {
                                HapticManager.shared.impact(style: .medium)
                                showingScanner = true
                            }) {
                                HStack(spacing: 9) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(EditorialPalette.emerald.opacity(0.18))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "camera.viewfinder")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(EditorialPalette.emerald)
                                    }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(String(localized: "Scan Barcode"))
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.75)
                                        Text(String(localized: "Barcode or photo"))
                                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                            .foregroundStyle(Color.white.opacity(0.68))
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 9)
                                .background(EditorialPalette.cardDark)
                                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .strokeBorder(EditorialPalette.cardBorderDark, lineWidth: 1)
                                )
                            }
                            .buttonStyle(HUDSpringButtonStyle(reduceMotion: reduceMotion))
                            .accessibilityLabel(String(localized: "Scan food"))
                            .accessibilityIdentifier("hud_quick_log_ai_camera_button")
                            
                            // 2. Create Custom Food
                            Button(action: {
                                HapticManager.shared.impact(style: .light)
                                showingManualAdd = true
                            }) {
                                HStack(spacing: 9) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(EditorialPalette.oat.opacity(0.15))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "plus")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(EditorialPalette.oat)
                                    }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(String(localized: "Custom Food"))
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.75)
                                        Text(String(localized: "Create with macros"))
                                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                            .foregroundStyle(Color.white.opacity(0.68))
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 9)
                                .background(EditorialPalette.cardDark)
                                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .strokeBorder(EditorialPalette.cardBorderDark, lineWidth: 1)
                                )
                            }
                            .buttonStyle(HUDSpringButtonStyle(reduceMotion: reduceMotion))
                            .accessibilityLabel(String(localized: "Add custom food"))
                            .accessibilityIdentifier("hud_quick_log_manual_add_button")
                        }
                        .padding(.horizontal, 16)
                        
                        // Scope Filter Chips (SF Symbols, Edge-Clean)
                        if searchText.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(categories, id: \.self) { cat in
                                        let isSel = selectedCategory == cat
                                        Button(action: {
                                            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.78)) {
                                                selectedCategory = cat
                                            }
                                            HapticManager.shared.impact(style: .light)
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: categoryFilterSymbol(for: cat))
                                                    .font(.system(size: 10.5, weight: .semibold))
                                                Text(LocalizedStringKey(cat))
                                                    .lineLimit(1)
                                            }
                                            .font(.system(size: 11.5, weight: isSel ? .bold : .semibold, design: .rounded))
                                            .padding(.horizontal, 10.5)
                                            .padding(.vertical, 7)
                                            .background(isSel ? EditorialPalette.inkPrimary : EditorialPalette.surfaceLight)
                                            .foregroundStyle(isSel ? Color.themeBg : EditorialPalette.inkSecondary)
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule()
                                                    .strokeBorder(isSel ? Color.clear : EditorialPalette.hairlineLight, lineWidth: 0.75)
                                            )
                                        }
                                        .buttonStyle(HUDSpringButtonStyle(reduceMotion: reduceMotion))
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.bottom, 10)
                    .background(.ultraThinMaterial)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(EditorialPalette.hairlineLight)
                            .frame(height: 0.5)
                    }
                    
                    // 2. Food List with 1-Tap Speed Logging
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 9) {
                            if !searchText.isEmpty {
                                // Direct In-Search Custom Food Creation Banner
                                Button(action: {
                                    HapticManager.shared.impact(style: .medium)
                                    showingManualAdd = true
                                }) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(EditorialPalette.oat.opacity(0.28))
                                                .frame(width: 34, height: 34)
                                            Image(systemName: "plus")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(EditorialPalette.inkPrimary)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(String(format: String(localized: "Can't find '%@'?"), searchText))
                                                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                                .foregroundStyle(EditorialPalette.inkPrimary)
                                                .lineLimit(1)
                                            Text(String(localized: "Tap to create custom food"))
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundStyle(EditorialPalette.inkSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(EditorialPalette.inkSecondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.84))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
                                    )
                                }
                                .buttonStyle(HUDSpringButtonStyle(reduceMotion: reduceMotion))
                                .padding(.bottom, 2)

                                // Search Results
                                if !filteredLocalFoods.isEmpty {
                                    SectionHeaderTitle(title: String(localized: "From History"))
                                    ForEach(Array(filteredLocalFoods.enumerated()), id: \.element.id) { index, food in
                                        foodRow(for: food, index: index)
                                    }
                                }
                                
                                if !localCatalogResults.isEmpty {
                                    SectionHeaderTitle(title: String(localized: "Food Database"))
                                    ForEach(Array(localCatalogResults.enumerated()), id: \.element.id) { index, food in
                                        foodRow(for: food, index: 100 + index)
                                    }
                                }
                                
                                if !apiSearchResults.isEmpty {
                                    SectionHeaderTitle(title: String(localized: "Global Results"))
                                    ForEach(Array(apiSearchResults.enumerated()), id: \.element.id) { index, food in
                                        foodRow(for: food, index: 200 + index)
                                    }
                                }
                                
                                if isSearchingAPI {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                        Text(String(localized: "Searching global database..."))
                                            .font(.caption)
                                            .foregroundStyle(EditorialPalette.inkSecondary)
                                    }
                                    .padding(.vertical, 20)
                                } else if filteredLocalFoods.isEmpty && localCatalogResults.isEmpty && apiSearchResults.isEmpty {
                                    emptySearchState
                                }
                            } else {
                                // Category Results
                                if filteredLocalFoods.isEmpty {
                                    EditorialLightCard(cornerRadius: 18, padding: 24) {
                                        VStack(spacing: 10) {
                                            Image(systemName: "fork.knife")
                                                .font(.system(size: 28, weight: .medium))
                                                .foregroundStyle(EditorialPalette.inkSecondary.opacity(0.65))
                                            Text(String(format: String(localized: "No items in %@ yet"), localizedMealType(selectedCategory)))
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .foregroundStyle(EditorialPalette.inkPrimary)
                                            Text(String(localized: "Search or scan above to add a food"))
                                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                                .foregroundStyle(EditorialPalette.inkSecondary)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .padding(.top, 18)
                                } else {
                                    ForEach(Array(filteredLocalFoods.enumerated()), id: \.element.id) { index, food in
                                        foodRow(for: food, index: index)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, stagedDrafts.isEmpty ? 40 : 120)
                    }
                }
                
                // 3. Floating Obsidian HUD Commit Tray
                if !stagedDrafts.isEmpty {
                    dynamicIslandTray
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(
                isPresented: $showingScanner,
                onDismiss: {
                    if let pendingFood = pendingScannerFood {
                        pendingScannerFood = nil
                        addFoodToStaged(pendingFood)
                    } else if pendingManualEntryAfterScanner {
                        pendingManualEntryAfterScanner = false
                        showingManualAdd = true
                    }
                }
            ) {
                let daySummary = DailySummary.fetchExisting(for: selectedDate, in: modelContext)
                let user = User.deduplicatedPrimary(in: modelContext)
                let remaining = NutritionMath.remainingMacros(user: user, summary: daySummary)
                SmartScannerView(
                    onProductFound: { foundFood in pendingScannerFood = foundFood },
                    onManualEntryRequest: { pendingManualEntryAfterScanner = true },
                    remainingCalories: remaining.calories,
                    remainingProtein: remaining.protein
                )
            }
            .sheet(isPresented: $showingManualAdd) {
                AddIngredientModalView(initialName: searchText) { newCustomItem in
                    addFoodToStaged(newCustomItem)
                }
                .presentationDetents([.fraction(0.85), .large])
                .presentationCornerRadius(32)
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(item: $selectedFoodForDeepDetail) { food in
                FoodDetailNutritionView(food: food, mealTitle: localizedMealType(selectedSlot)) { addedFood in
                    addFoodToStaged(addedFood)
                }
            }
        }
        .onAppear {
            rebuildCaches()
        }
        .task {
            await LocalFoodDatabaseService.shared.waitUntilLoaded()
            if !searchText.isEmpty {
                performSearch(query: searchText)
            }
        }
        .onChange(of: searchText) { _, newValue in
            performSearch(query: newValue)
        }
        .alert(String(localized: "Could not save this meal"), isPresented: $showCommitError) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "Try again."))
        }
    }
    
    // MARK: - Food Row with 1-Tap Quick Log
    private func foodRow(for food: FoodItem, index: Int = 0) -> some View {
        let isStaged = stagedDrafts.contains(where: { $0.name.lowercased() == food.name.lowercased() })
        let stagedCount = stagedDrafts.filter { $0.name.lowercased() == food.name.lowercased() }.count
        return QuickLogFoodRowView(
            food: food,
            index: index,
            useMetricSystem: useMetricSystem,
            reduceMotion: reduceMotion,
            isStaged: isStaged,
            stagedCount: stagedCount,
            onSelectDetail: { selectedFoodForDeepDetail = food },
            onAdd: { addFoodToStaged(food) },
            onRemove: { removeFoodFromStaged(food) }
        )
    }

    // MARK: - Obsidian HUD Tray
    private var dynamicIslandTray: some View {
        VStack {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(stagedDrafts.count == 1
                         ? String(format: String(localized: "%lld item selected"), Int64(stagedDrafts.count))
                         : String(format: String(localized: "%lld items selected"), Int64(stagedDrafts.count)))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(EditorialPalette.oat.opacity(0.76))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text("+\(stagedCalories) kcal")
                            .font(.system(size: 16, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .fixedSize(horizontal: true, vertical: false)

                        if Int(stagedProtein.rounded()) >= 1 {
                            Text("\(Int(stagedProtein))g P")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(EditorialPalette.emerald)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(EditorialPalette.emerald.opacity(0.16))
                                .clipShape(Capsule())
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                }

                Spacer(minLength: 6)

                Button(action: commitStagedMealAndDismiss) {
                    HStack(spacing: 6) {
                        Text(String(format: String(localized: "Log to %@"), localizedMealType(selectedSlot)))
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 15))
                    }
                    .foregroundStyle(EditorialPalette.textOnOat)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 11)
                    .background(EditorialPalette.oat)
                    .clipShape(Capsule())
                }
                .buttonStyle(HUDSpringButtonStyle(reduceMotion: reduceMotion))
                .accessibilityIdentifier("hud_quick_log_commit_tray_button")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(EditorialPalette.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(EditorialPalette.cardBorderDarkFocused, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.26), radius: 18, y: 8)
            .padding(.horizontal, 16)
            .padding(.bottom, 22)
        }
    }
    
    // MARK: - Actions & Persistence
    private func addFoodToStaged(_ food: FoodItem) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7)) {
            stagedDrafts = MealHUDStaging.appending(food, to: stagedDrafts)
        }
        HapticManager.shared.impact(style: .light)
    }

    private func removeFoodFromStaged(_ food: FoodItem) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7)) {
            stagedDrafts = MealHUDStaging.removingLast(named: food.name, from: stagedDrafts)
        }
        HapticManager.shared.impact(style: .light)
    }
    
    private func commitStagedMealAndDismiss() {
        guard !stagedDrafts.isEmpty else { return }
        HapticManager.shared.impact(style: .heavy)
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let summaryToUse = DailySummary.fetchOrCreate(for: startOfDay, in: modelContext)
        let mealTimestamp = calendar.isDateInToday(selectedDate) ? Date.now : startOfDay
        let canonicalSlot = DailySummary.canonicalMealSlot(selectedSlot)
        let existingItems = (summaryToUse.meals ?? [])
            .first { DailySummary.canonicalMealSlot($0.title) == canonicalSlot }?
            .foodItems ?? []
        let draftsToCommit = MealQuickLogCommit.drafts(existingSlotItems: existingItems, staged: stagedDrafts)
        
        let syncResult = MealSlotPersistence.persistWithSyncOps(
            activeSlot: selectedSlot,
            activeDrafts: draftsToCommit,
            hasModifiedActiveSlot: true,
            draftsBySlot: [:],
            dirtySlots: [],
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
            
            HapticManager.shared.notification(type: .success)
            dismiss()
        } catch {
            showCommitError = true
        }
    }
    
    private func rebuildCaches() {
        var descriptor = FetchDescriptor<Meal>(
            sortBy: [SortDescriptor(\Meal.date, order: .reverse)]
        )
        descriptor.fetchLimit = 60
        let recentMeals = (try? modelContext.fetch(descriptor)) ?? []

        var seenNames = Set<String>()
        var results: [FoodItem] = []
        var counts: [String: Int] = [:]
        
        for meal in recentMeals {
            for item in meal.foodItems ?? [] {
                counts[item.name, default: 0] += 1
                if seenNames.insert(item.name).inserted {
                    results.append(item)
                }
            }
        }
        cachedAvailableFoods = results
        cachedRecipeFoods = customRecipes.map { $0.toFoodItem() }.sorted { $0.name < $1.name }
        cachedFoodCounts = counts
    }
    
    private func performSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            localCatalogResults = []
            apiSearchResults = []
            isSearchingAPI = false
            return
        }
        
        searchTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
                
                let localEntries = await Task.detached(priority: .userInitiated) {
                    LocalFoodDatabaseService.shared.searchEntriesSnapshot(query: trimmed, limit: 20)
                }.value
                guard !Task.isCancelled else { return }
                
                let localResults = localEntries.map { $0.toFoodItem() }
                self.localCatalogResults = localResults
                
                guard trimmed.count > 2 else {
                    self.isSearchingAPI = false
                    return
                }
                
                self.isSearchingAPI = localResults.isEmpty && self.filteredLocalFoods.isEmpty
                try await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                
                let remoteResults = await NetworkManager.shared.searchFoodByText(
                    query: trimmed,
                    allowAIFallback: localResults.isEmpty && self.filteredLocalFoods.isEmpty
                )
                guard !Task.isCancelled else { return }
                let existingNames = Set((localResults + self.filteredLocalFoods).map { $0.name.lowercased() })
                let uniqueRemote = remoteResults.filter { !existingNames.contains($0.name.lowercased()) }
                self.apiSearchResults = uniqueRemote
                self.isSearchingAPI = false
            } catch {
                if !Task.isCancelled {
                    self.isSearchingAPI = false
                }
            }
        }
    }
    
    // MARK: - Subviews
    private var emptySearchState: some View {
        EditorialLightCard(cornerRadius: 18, padding: 24) {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(EditorialPalette.inkSecondary.opacity(0.65))
                
                Text(String(format: String(localized: "No food found for '%@'"), searchText))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(EditorialPalette.inkPrimary)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    showingManualAdd = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Custom Food")
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(EditorialPalette.oat)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(EditorialPalette.cardDark)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(EditorialPalette.cardBorderDark, lineWidth: 1))
                }
                .buttonStyle(HUDSpringButtonStyle(reduceMotion: reduceMotion))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Section Header Title
private struct SectionHeaderTitle: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .textCase(.uppercase)
            .foregroundStyle(EditorialPalette.inkSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
            .padding(.horizontal, 4)
    }
}

// MARK: - Spring Button Style
private struct HUDSpringButtonStyle: ButtonStyle {
    var reduceMotion = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1.0 : 0.94)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

private struct QuickLogFoodRowView: View {
    let food: FoodItem
    let index: Int
    let useMetricSystem: Bool
    let reduceMotion: Bool
    let isStaged: Bool
    let stagedCount: Int
    let onSelectDetail: () -> Void
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        let meta = EditorialMealTheme.foodCategoryMeta(for: food.name)
        let weightLabel = food.weight > 0
            ? NutritionMath.formattedFoodWeight(food.weight, useMetric: useMetricSystem)
            : String(localized: "1 serving")

        HStack(spacing: 12) {
            Button(action: onSelectDetail) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(meta.color.opacity(0.14))
                            .frame(width: 40, height: 40)

                        Image(systemName: meta.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(meta.color)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(food.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(EditorialPalette.inkPrimary)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text("\(food.calories) kcal • \(weightLabel)")
                                .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                                .foregroundStyle(EditorialPalette.inkSecondary)

                            if Int(food.protein.rounded()) >= 1 {
                                Text("\(Int(food.protein))g P")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(EditorialPalette.forest)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(EditorialPalette.emerald.opacity(0.14))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("hud_quick_log_detail_row_\(index)")

            Spacer(minLength: 8)

            if stagedCount > 0 {
                Button(action: onRemove) {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(EditorialPalette.inkPrimary)
                        .frame(width: 34, height: 34)
                        .background(EditorialPalette.inkPrimary.opacity(0.07))
                        .clipShape(Circle())
                }
                .buttonStyle(HUDSpringButtonStyle(reduceMotion: reduceMotion))
                .accessibilityLabel(String(format: String(localized: "Remove %@"), food.name))
                .accessibilityIdentifier("hud_quick_log_remove_row_\(index)")
            }

            Button(action: onAdd) {
                ZStack {
                    Circle()
                        .fill(isStaged ? EditorialPalette.forest : EditorialPalette.inkPrimary.opacity(0.08))
                        .frame(width: 34, height: 34)

                    if isStaged {
                        if stagedCount > 1 {
                            Text("×\(stagedCount)")
                                .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(.white)
                        }
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(EditorialPalette.inkPrimary)
                    }
                }
            }
            .buttonStyle(HUDSpringButtonStyle(reduceMotion: reduceMotion))
            .accessibilityLabel(String(format: String(localized: "Add %@"), food.name))
            .accessibilityIdentifier("hud_quick_log_add_row_\(index)")
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(isStaged ? 0.94 : 0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isStaged ? EditorialPalette.emerald.opacity(0.55) : EditorialPalette.hairlineLight,
                    lineWidth: isStaged ? 1.25 : 0.75
                )
        )
    }
}

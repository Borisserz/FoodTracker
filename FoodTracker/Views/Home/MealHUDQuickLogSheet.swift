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
    
    private func slotSymbol(for type: String) -> String {
        switch DailySummary.canonicalMealSlot(type) {
        case "Breakfast": return "sunrise.fill"
        case "Lunch": return "sun.max.fill"
        case "Dinner": return "moon.stars.fill"
        case "Snack": return "leaf.fill"
        default: return "fork.knife"
        }
    }
    
    private func categoryIcon(for foodName: String) -> (symbol: String, color: Color) {
        let lower = foodName.lowercased()
        if lower.contains("coffee") || lower.contains("espresso") || lower.contains("tea") || lower.contains("latte") || lower.contains("кофе") || lower.contains("чай") {
            return ("cup.and.saucer.fill", Color(red: 0.95, green: 0.65, blue: 0.35))
        } else if lower.contains("salmon") || lower.contains("fish") || lower.contains("рыб") || lower.contains("лосось") || lower.contains("тунец") {
            return ("fish.fill", Color(red: 0.40, green: 0.75, blue: 0.95))
        } else if lower.contains("chicken") || lower.contains("beef") || lower.contains("meat") || lower.contains("куриц") || lower.contains("мяс") || lower.contains("стейк") {
            return ("fork.knife", Color(red: 0.95, green: 0.35, blue: 0.40))
        } else if lower.contains("apple") || lower.contains("berry") || lower.contains("blueberr") || lower.contains("fruit") || lower.contains("salad") || lower.contains("ягод") || lower.contains("яблок") || lower.contains("салат") {
            return ("leaf.fill", Color(red: 0.20, green: 0.80, blue: 0.45))
        } else if lower.contains("yogurt") || lower.contains("protein") || lower.contains("milk") || lower.contains("cheese") || lower.contains("йогурт") || lower.contains("протеин") || lower.contains("сыр") || lower.contains("молок") {
            return ("drop.fill", Color(red: 0.35, green: 0.65, blue: 0.95))
        } else if lower.contains("bread") || lower.contains("toast") || lower.contains("oat") || lower.contains("хлеб") || lower.contains("овсян") || lower.contains("каша") {
            return ("takeoutbag.and.cup.and.straw.fill", Color(red: 0.95, green: 0.75, blue: 0.35))
        } else {
            return ("fork.knife", Color(red: 0.60, green: 0.65, blue: 0.75))
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
                Color(UIColor.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 1. Drag Handle & Header
                    VStack(spacing: 12) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.25))
                            .frame(width: 40, height: 5)
                            .padding(.top, 10)
                        
                        // Meal Slot Segment Switcher
                        HStack(spacing: 6) {
                            ForEach(mealSlots, id: \.self) { slot in
                                let isSelected = DailySummary.canonicalMealSlot(selectedSlot) == DailySummary.canonicalMealSlot(slot)
                                Button(action: {
                                    withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.75)) {
                                        selectedSlot = slot
                                    }
                                    HapticManager.shared.impact(style: .light)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: slotSymbol(for: slot))
                                            .font(.system(size: 11, weight: .bold))
                                        Text(LocalizedStringKey(slot))
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 4)
                                    .frame(maxWidth: .infinity)
                                    .background(isSelected ? Color.themePink : Color(UIColor.secondarySystemGroupedBackground))
                                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(HUDSpringButtonStyle(reduceMotion: reduceMotion))
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Spotlight Search Bar with integrated AI Scan & Barcode
                        HStack(spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                TextField(String(localized: "Search foods or scan..."), text: $searchText)
                                    .font(.system(size: 15, weight: .regular, design: .rounded))
                                    .accessibilityIdentifier("hud_quick_log_search_field")
                                
                                if !searchText.isEmpty {
                                    Button(action: { searchText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.secondary.opacity(0.6))
                                    }
                                    .accessibilityLabel(String(localized: "Clear search"))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                            
                        }
                        .padding(.horizontal, 16)
                        
                        // MARK: - Dual Action Fast Deck (Prominent Scan & Custom Food)
                        HStack(spacing: 10) {
                            // 1. AI & Barcode Camera Scanner
                            Button(action: {
                                HapticManager.shared.impact(style: .medium)
                                showingScanner = true
                            }) {
                                HStack(spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(red: 0.10, green: 0.72, blue: 0.50).opacity(0.14))
                                            .frame(width: 34, height: 34)
                                        Image(systemName: "camera.viewfinder")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(Color(red: 0.10, green: 0.72, blue: 0.50))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(String(localized: "Scan Barcode"))
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text(String(localized: "Barcode or photo"))
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
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
                                HStack(spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(red: 0.95, green: 0.70, blue: 0.30).opacity(0.14))
                                            .frame(width: 34, height: 34)
                                        Image(systemName: "plus")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(Color(red: 0.95, green: 0.70, blue: 0.30))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(String(localized: "Create Custom Food"))
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text(String(localized: "Create with macros"))
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                                )
                            }
                            .buttonStyle(HUDSpringButtonStyle(reduceMotion: reduceMotion))
                            .accessibilityLabel(String(localized: "Add custom food"))
                            .accessibilityIdentifier("hud_quick_log_manual_add_button")
                        }
                        .padding(.horizontal, 16)
                        
                        // Scope Filter Chips
                        if searchText.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(categories, id: \.self) { cat in
                                        let isSel = selectedCategory == cat
                                        Button(action: {
                                            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75)) {
                                                selectedCategory = cat
                                            }
                                            HapticManager.shared.impact(style: .light)
                                        }) {
                                            HStack(spacing: 4) {
                                                if cat == "Recent" { Text("⚡") }
                                                else if cat == "Frequent" || cat == "Often" { Text("★") }
                                                else if cat == "My Recipes" { Text("📖") }
                                                Text(LocalizedStringKey(cat))
                                            }
                                            .font(.system(size: 12, weight: isSel ? .bold : .semibold, design: .rounded))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(isSel ? Color.primary : Color(UIColor.secondarySystemGroupedBackground))
                                            .foregroundColor(isSel ? Color(UIColor.systemBackground) : Color.secondary)
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(HUDSpringButtonStyle(reduceMotion: reduceMotion))
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.bottom, 12)
                    .background(
                        Rectangle()
                            .fill(Color(UIColor.systemBackground))
                            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 3)
                    )
                    
                    // 2. Food List with 1-Tap Speed Logging
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            if !searchText.isEmpty {
                                // Direct In-Search Custom Food Creation Banner
                                Button(action: {
                                    HapticManager.shared.impact(style: .medium)
                                    showingManualAdd = true
                                }) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(red: 0.95, green: 0.70, blue: 0.30).opacity(0.15))
                                                .frame(width: 32, height: 32)
                                            Image(systemName: "plus")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(Color(red: 0.95, green: 0.70, blue: 0.30))
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(String(format: String(localized: "Can't find '%@'?"), searchText))
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            Text(String(localized: "Tap to create custom food"))
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
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
                                            .foregroundStyle(Color.secondary)
                                    }
                                    .padding(.vertical, 20)
                                } else if filteredLocalFoods.isEmpty && localCatalogResults.isEmpty && apiSearchResults.isEmpty {
                                    emptySearchState
                                }
                            } else {
                                // Category Results
                                if filteredLocalFoods.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "fork.knife")
                                            .font(.system(size: 36))
                                            .foregroundStyle(Color.secondary.opacity(0.4))
                                            .padding(.top, 40)
                                        Text(String(format: String(localized: "No items in %@ yet"), localizedMealType(selectedCategory)))
                                        Text(String(localized: "Search or scan above to add a food"))
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(Color.secondary.opacity(0.8))
                                            .multilineTextAlignment(.center)
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(Color.secondary)
                                    }
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
                
                // 3. Floating Dynamic Island Bottom Tray
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
                AddIngredientModalView { newCustomItem in
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
    @ViewBuilder
    private func foodRow(for food: FoodItem, index: Int = 0) -> some View {
        let meta = categoryIcon(for: food.name)
        let isStaged = stagedDrafts.contains(where: { $0.name.lowercased() == food.name.lowercased() })
        let stagedCount = stagedDrafts.filter { $0.name.lowercased() == food.name.lowercased() }.count
        let weightLabel = food.weight > 0
            ? NutritionMath.formattedFoodWeight(food.weight, useMetric: useMetricSystem)
            : String(localized: "1 serving")
        
        HStack(spacing: 12) {
            // Category Icon Badge
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(meta.color.opacity(0.14))
                    .frame(width: 42, height: 42)
                
                Image(systemName: meta.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(meta.color)
            }
            
            // Name, Cals & Macros
            VStack(alignment: .leading, spacing: 3) {
                Text(food.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text("\(food.calories) kcal • \(weightLabel)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.secondary)
                    
                    if Int(food.protein.rounded()) >= 1 {
                        Text("\(Int(food.protein))g P")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.16, green: 0.72, blue: 0.50))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.16, green: 0.72, blue: 0.50).opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            
            Spacer()
            
            // 1-Tap Add Button with tactile feedback
            Button(action: {
                addFoodToStaged(food)
            }) {
                ZStack {
                    Circle()
                        .fill(isStaged ? Color(red: 0.16, green: 0.72, blue: 0.50) : Color.primary.opacity(0.08))
                        .frame(width: 36, height: 36)
                    
                    if isStaged {
                        if stagedCount > 1 {
                            Text("×\(stagedCount)")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .black))
                                .foregroundColor(.white)
                        }
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.primary)
                    }
                }
            }
            .buttonStyle(HUDSpringButtonStyle(reduceMotion: reduceMotion))
            .accessibilityLabel(String(format: String(localized: "Add %@"), food.name))
            .accessibilityIdentifier("hud_quick_log_add_row_\(index)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isStaged ? Color(red: 0.16, green: 0.72, blue: 0.50).opacity(0.35) : Color.primary.opacity(0.04), lineWidth: 1.2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedFoodForDeepDetail = food
        }
    }
    
    // MARK: - Dynamic Island Tray
    private var dynamicIslandTray: some View {
        VStack {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(stagedDrafts.count == 1
                         ? String(format: String(localized: "%lld item selected"), Int64(stagedDrafts.count))
                         : String(format: String(localized: "%lld items selected"), Int64(stagedDrafts.count)))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.secondary)
                    
                    HStack(spacing: 6) {
                        Text("+\(stagedCalories) kcal")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.primary)
                        
                        if Int(stagedProtein.rounded()) >= 1 {
                            Text("• \(Int(stagedProtein))g Protein")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(red: 0.16, green: 0.72, blue: 0.50))
                        }
                    }
                }
                
                Spacer()
                
                Button(action: commitStagedMealAndDismiss) {
                    HStack(spacing: 6) {
                        Text(String(format: String(localized: "Log to %@"), localizedMealType(selectedSlot)))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 16))
                    }
                    .foregroundColor(Color(UIColor.systemBackground))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.primary)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                }
                .buttonStyle(HUDSpringButtonStyle(reduceMotion: reduceMotion))
                .accessibilityIdentifier("hud_quick_log_commit_tray_button")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground).opacity(0.96))
                    .background(.ultraThinMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1.2)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 20, y: 8)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Actions & Persistence
    private func addFoodToStaged(_ food: FoodItem) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        let draft = EditableFoodDraft(food: food, isNewMealEntry: true)
        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7)) {
            stagedDrafts.append(draft)
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
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 38))
                .foregroundStyle(Color.secondary.opacity(0.4))
                .padding(.top, 30)
            
            Text(String(format: String(localized: "No food found for '%@'"), searchText))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.secondary)
            
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                showingManualAdd = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Custom Food")
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Color.primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(HUDSpringButtonStyle(reduceMotion: reduceMotion))
        }
        .padding(.vertical, 20)
    }
}

// MARK: - Section Header Title
private struct SectionHeaderTitle: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .textCase(.uppercase)
            .foregroundStyle(Color.secondary.opacity(0.8))
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

import SwiftUI
import SwiftData

// SharedUI components (BounceButtonStyle, UltraPremiumCardModifier) are now available globally

struct HomeDashboardView: View {
    @State private var selectedDate: Date = .now

    var body: some View {
        HomeDashboardContentView(selectedDate: $selectedDate)
    }
}

struct HomeDashboardContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(DIContainer.self) private var di
    @Query private var users: [User]
    @Query private var summaries: [DailySummary]
    @Environment(\.scenePhase) private var scenePhase
    @Binding var selectedDate: Date
    @State private var navigateToProfile = false
    @State private var showDailyLog = false
    @State private var showNoteSheet = false
    @State private var showingQuickAddSheet = false
    @State private var quickAddMealType = "Snack"
    @State private var showingQuickActivitySheet = false
    @State private var selectedMealForDetail: String? = nil
    @State private var showPremiumQuickAdd = false
    @State private var mealToOpenInSmartAdd: IdentifiableString? = nil
    @State private var allTimeCalories: Int = 0
    @State private var showXPPopup = false
    @State private var xpBreakdown: NutritionXPBreakdown? = nil

    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        let startOfDay = Calendar.current.startOfDay(for: selectedDate.wrappedValue)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = #Predicate<DailySummary> { $0.date >= startOfDay && $0.date < endOfDay }
        self._summaries = Query(filter: predicate)
    }

    private var currentUser: User? { users.first }

    private var currentSummary: DailySummary {
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        if let existing = summaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }) {
            return existing
        } else {
            // Never return a detached object. The ensure task below (or callers) will create via the actor repo.
            // Return a transient placeholder; UI code should ensure before heavy mutation.
            return DailySummary(date: startOfDay)
        }
    }

    private func ensureCurrentSummary() async {
        // Route creation through the @ModelActor-powered repository so the write is isolated.
        _ = try? await di.summaryRepository.ensureSummary(for: selectedDate)
    }

    private func getRecommendedCalories(for mealType: String) -> Int {
        let goal = Double(currentUser?.dailyCaloriesGoal ?? 2000)
        switch mealType {
        case "Breakfast": return Int(goal * 0.25)
        case "Lunch":     return Int(goal * 0.35)
        case "Dinner":    return Int(goal * 0.30)
        case "Snack":     return Int(goal * 0.10)
        default:          return 0
        }
    }

    private func localizedMealType(_ type: String) -> String {
        String(localized: String.LocalizationValue(type))
    }

    var body: some View {
          NavigationStack {
              ZStack(alignment: .bottomTrailing) { // Обернули в ZStack для плавающей кнопки
                  Color.themeBg.ignoresSafeArea()

                  // Ensure the day's summary exists via the actor-isolated repo (removes detached main-context creation).
                  .task(id: selectedDate) {
                      await ensureCurrentSummary()
                  }
                  .task {
                      await ensureCurrentSummary()
                  }

                  ScrollView(showsIndicators: false) {
                      VStack(spacing: 24) {
                          HeaderView(selectedDate: selectedDate, onProfileTap: { navigateToProfile = true }, onShareTap: { shareDailySummary() })
                          CalendarCarouselView(selectedDate: $selectedDate)
                          InsightsWidget(summary: currentSummary, user: currentUser)
                          
                          AnalyticsQuickGlanceWidget(summary: currentSummary, user: currentUser)

                          DynamicEnergyDashboard(summary: currentSummary, summaries: summaries, user: currentUser)
                              .padding(.bottom, 8)

                          VStack(spacing: 16) {
                              HStack {
                                  Text("Nutrition")
                                      .font(.title2).bold()
                                  Spacer()
                                  Button(action: {
                                      HapticManager.shared.impact(style: .medium)
                                      showDailyLog = true
                                  }) {
                                      HStack(spacing: 4) {
                                          Text("Daily Log")
                                          Image(systemName: "list.bullet.clipboard")
                                      }
                                      .font(.subheadline.bold())
                                      .foregroundColor(.themePink)
                                  }
                              }
                              .padding(.horizontal, 20)

                              ForEach(["Breakfast", "Lunch", "Snack", "Dinner"], id: \.self) { mealType in
                                  let meal = currentSummary.meals.first(where: { $0.title == mealType })

                                  MealCardView(
                                      title: localizedMealType(mealType),
                                      calories: meal?.totalCalories,
                                      recommendedCalories: getRecommendedCalories(for: mealType),
                                      time: meal?.date,
                                      onCardTap: { self.selectedMealForDetail = mealType },
                                      onQuickAdd: { self.quickAddMealType = mealType; self.showingQuickAddSheet = true }
                                  )
                              }
                              .padding(.horizontal)
                          }

                          WaterGridTrackerView(summary: currentSummary).padding(.horizontal)
                          WeightTrackerCardView(summary: currentSummary).padding(.horizontal)

                          DailyNoteCard(summary: currentSummary) {
                              showNoteSheet = true
                          }
                          
                          Button(action: {
                              finishDayAndCalculateXP()
                          }) {
                              HStack {
                                  Image(systemName: "flag.checkered")
                                  Text("Finish Day")
                              }
                              .font(.headline)
                              .foregroundColor(.black)
                              .frame(maxWidth: .infinity)
                              .padding()
                              .background(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                              .cornerRadius(16)
                              .shadow(color: .themePink.opacity(0.3), radius: 10, y: 5)
                          }
                          .padding(.horizontal)
                          .padding(.top, 16)
                          
                          AllTimeStatsCardView(totalCalories: allTimeCalories)
                      }
                      .padding(.bottom, 120) // Оставили место для плавающей кнопки
                  }
                  
                  // ПЛАВАЮЩАЯ КНОПКА QUICK ADD (ПЕРЕНЕСЕНА СЮДА)
                  Button(action: {
                      HapticManager.shared.impact(style: .medium)
                      showPremiumQuickAdd = true
                  }) {
                      Image(systemName: "plus")
                          .font(.system(size: 26, weight: .bold))
                          .foregroundColor(.white)
                          .frame(width: 64, height: 64)
                          .background(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                          .clipShape(Circle())
                          .shadow(color: .themePink.opacity(0.4), radius: 10, y: 5)
                  }
                  .padding(.trailing, 24)
                  .padding(.bottom, 24)
                  
                  if showXPPopup, let breakdown = xpBreakdown {
                      NutritionXPBreakdownPopup(breakdown: breakdown) {
                          withAnimation {
                              showXPPopup = false
                          }
                      }
                      .transition(.opacity.combined(with: .scale))
                      .zIndex(100)
                  }
              }
              .navigationBarHidden(true)
              .task(id: selectedDate) {
                  await fetchHealthData(for: currentSummary)
              }
              .onAppear {
                  TrackingManager.shared.track(.appOpened(source: "home_dashboard"))
                  Task { allTimeCalories = (try? await di.summaryRepository.fetchAllTimeCalories()) ?? 0 }
              }
              .onChange(of: scenePhase) { _, newPhase in
                  if newPhase == .active {
                      Task { await fetchHealthData(for: currentSummary) }
                  }
              }
              .onChange(of: HealthKitManager.shared.isAuthorized) { _, isAuth in
                  if isAuth { Task { await fetchHealthData(for: currentSummary) } }
              }
              .navigationDestination(isPresented: $navigateToProfile) { ProfileWrapperView() }
              .navigationDestination(isPresented: $showDailyLog) { DailyLogDetailView(summary: currentSummary) }
              .navigationDestination(item: Binding(
                  get: { selectedMealForDetail.map { IdentifiableString(value: $0) } },
                  set: { selectedMealForDetail = $0?.value }
              )) { mealItem in
                  MealDetailView(title: mealItem.value, date: selectedDate)
              }
              .sheet(isPresented: $showNoteSheet) {
                  DailyNoteSheet(summary: currentSummary)
                      .presentationDetents([.height(450)])
                      .presentationCornerRadius(32)
                      .presentationDragIndicator(.visible)
              }
              .sheet(isPresented: $showingQuickAddSheet) {
                  SmartAddFoodView(mealTitle: localizedMealType(quickAddMealType)) { selectedItems in
                      addFoodsToMeal(title: quickAddMealType, items: selectedItems)
                  }
                  .presentationDetents([.fraction(0.85), .large])
                  .presentationCornerRadius(32)
                  .presentationDragIndicator(.hidden)
              }
              .sheet(isPresented: $showPremiumQuickAdd) {
                  PremiumQuickAddSheet(selectedDate: selectedDate, onSelectDetailedMeal: { selectedMeal in
                      self.mealToOpenInSmartAdd = IdentifiableString(value: selectedMeal)
                  }, onSelectActivity: {
                      self.showingQuickActivitySheet = true
                  })
                  .presentationDetents([.height(650)])
                  .presentationCornerRadius(32)
                  .presentationDragIndicator(.visible)
              }
              .sheet(isPresented: $showingQuickActivitySheet) {
                  QuickActivityAddView(summary: currentSummary)
                      .presentationDetents([.fraction(0.85), .large])
                      .presentationCornerRadius(32)
              }
              .fullScreenCover(item: $mealToOpenInSmartAdd) { mealInfo in
                  SmartAddFoodView(mealTitle: mealInfo.value) { selectedItems in
                      addFoodsToMeal(title: mealInfo.value, items: selectedItems)
                  }
              }
          }
      }

    private func fetchHealthData(for summary: DailySummary) async {

            let workoutCals = WorkoutSyncManager.shared.fetchWorkoutCalories(for: summary.date)

            var fetchedSteps = summary.stepsCount
            var fetchedActiveCals = summary.activeCaloriesBurned

            if currentUser?.isHealthKitEnabled == true {
                do {
                    fetchedSteps = try await HealthKitManager.shared.fetchSteps(for: summary.date)
                } catch { print("Steps error: \(error)") }

                do {
                    let totalHealthCals = try await HealthKitManager.shared.fetchTotalActiveCalories(for: summary.date)
                    fetchedActiveCals = max(totalHealthCals, workoutCals, summary.localActivityCalories)
                } catch { print("Health cals error: \(error)") }
            } else {
                fetchedActiveCals = max(workoutCals, summary.localActivityCalories)
            }

            await MainActor.run {
                var needsSave = false

                if summary.workoutCalories != workoutCals {
                    summary.workoutCalories = workoutCals
                    needsSave = true
                }

                if summary.stepsCount != fetchedSteps {
                    summary.stepsCount = fetchedSteps
                    needsSave = true
                }

                if summary.activeCaloriesBurned != fetchedActiveCals {
                    summary.activeCaloriesBurned = fetchedActiveCals
                    needsSave = true
                }

                if needsSave {
                    // Summary should have been ensured via the @ModelActor repo (see .task ensureCurrentSummary).
                    // We still save on the view's main context for @Query reactivity; the actor path owns creation.
                    try? context.save()
                    // Future improvement: await di.summaryRepository.saveSummary(summary) after mapping if needed.
                }
            }
        }
    private func addFoodsToMeal(title: String, items: [FoodItem]) {
        let summary = currentSummary
        var newFoodItems: [FoodItem] = []

        for item in items {
            let copiedItem = FoodItem(
                name: item.name, weight: item.weight, calories: item.calories,
                protein: item.protein, fats: item.fats, carbs: item.carbs,
                omega3: item.omega3, calcium: item.calcium, potassium: item.potassium,
                magnesium: item.magnesium, iron: item.iron, vitaminC: item.vitaminC, vitaminD: item.vitaminD
            )
            context.insert(copiedItem)
            newFoodItems.append(copiedItem)
        }

        if let existingMeal = summary.meals.first(where: { $0.title == title }) {
            existingMeal.foodItems.append(contentsOf: newFoodItems)
            existingMeal.date = .now
        } else {
            let newMeal = Meal(title: title, date: .now, foodItems: newFoodItems)
            context.insert(newMeal)
            summary.meals.append(newMeal)
        }

        // Ensured via repo task; save on main context for live @Query updates.
        try? context.save()
        AppReviewManager.shared.userDidLogMeal()
        
        let addedCals = newFoodItems.reduce(0) { $0 + $1.calories }
        TrackingManager.shared.track(.mealLogged(mealType: title, totalCalories: addedCals))
    }
    
    private func shareDailySummary() {
        let card = MealShareCard(summary: currentSummary)
        ShareSheetManager.renderAndShare(view: card, title: "My Nutrition Day")
    }
    
    private func finishDayAndCalculateXP() {
        HapticManager.shared.impact(style: .medium)
        
        let baseXP = 50
        var proteinXP = 0
        var calorieXP = 0
        
        if let user = currentUser {
            let totalProtein = Int(currentSummary.totalProtein)
            let totalCalories = Int(currentSummary.totalCalories)
            
            if totalProtein >= Int(user.targetProtein) {
                proteinXP = 100
            } else if totalProtein >= Int(user.targetProtein) - 20 {
                proteinXP = 50
            }
            
            if totalCalories <= user.dailyCaloriesGoal {
                calorieXP = 150
            } else if totalCalories <= user.dailyCaloriesGoal + 200 {
                calorieXP = 50
            }
        }
        
        let breakdown = NutritionXPBreakdown(baseXP: baseXP, proteinGoalXP: proteinXP, calorieGoalXP: calorieXP)
        xpBreakdown = breakdown
        showXPPopup = true
        
        if let user = currentUser {
            var manager = NutritionProgressManager(user: user)
            manager.addXP(from: breakdown)
            try? context.save()
        }
    }
}

struct HeaderView: View {
    let selectedDate: Date
    var onProfileTap: () -> Void
    var onShareTap: () -> Void

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }

    private var relativeDateString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) { return "Today" }
        if calendar.isDateInYesterday(selectedDate) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: selectedDate)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(monthYearString).font(.title2.bold())
                Text(relativeDateString).foregroundColor(.textGray)
            }
            Spacer()

            HStack(spacing: 16) {
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    onShareTap()
                }) {
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: Color.themePink.opacity(0.3), radius: 5, y: 2)
                }
                .buttonStyle(BounceButtonStyle())

            Button(action: {
                HapticManager.shared.impact(style: .medium)
                onProfileTap()
            }) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: Color.themePink.opacity(0.3), radius: 5, y: 2)
            }
            .buttonStyle(BounceButtonStyle())
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}

struct InsightsWidget: View {
    let summary: DailySummary
    let user: User?

    private var insightData: (message: String, icon: String, color: Color) {
        let baseGoal = user?.dailyCaloriesGoal ?? 2400
        let remaining = (baseGoal + summary.activeCaloriesBurned) - summary.totalCalories

        if summary.totalCalories == 0 {
            return ("Good morning! Ready to crush your goals?", "sun.max.fill", .themeDarkYellow)
        } else if remaining < 0 {
            return ("Slightly over limit, but tomorrow is a new day!", "exclamationmark.circle.fill", .red)
        } else if summary.totalProtein < (user?.targetProtein ?? 150) * 0.3 && summary.totalCalories > 600 {
            return ("Great start! Try adding more protein to your next meal.", "bolt.fill", .themePeach)
        } else if summary.totalHydrationLiters < 1.0 && summary.totalCalories > 1000 {
            return ("Don't forget to drink water to stay hydrated!", "drop.fill", .drinkWater)
        } else {
            return ("You're on track! Keep up the great work.", "star.fill", .themePink)
        }
    }

    var body: some View {
        let data = insightData
        HStack(spacing: 16) {
            Image(systemName: data.icon)
                .font(.title2)
                .foregroundColor(data.color)

            Text(data.message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(2)

            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
        .padding(.horizontal)
    }
}

struct MealDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var summaries: [DailySummary]
    @Query private var users: [User]

    let title: String
    let date: Date

    init(title: String, date: Date) {
        self.title = title
        self.date = date
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = #Predicate<DailySummary> { $0.date >= startOfDay && $0.date < endOfDay }
        self._summaries = Query(filter: predicate)
    }

    @State private var selectedFoodForDetail: FoodItem? = nil
    @State private var showingAddFood = false
    @State private var isGeneratingRecipe = false
    @State private var generatedRecipe: AIChefRecipe? = nil
    @State private var recipeGenerationError: String? = nil
    @State private var showingRecipeError = false
    @Environment(DIContainer.self) private var di

    private var meal: Meal? {
        return summaries.first?.meals.first { $0.title == title }
    }

    private func deleteFoodItem(_ food: FoodItem) {
        if let meal = meal, let index = meal.foodItems.firstIndex(where: { $0.id == food.id }) {
            withAnimation {
                meal.foodItems.remove(at: index)
                context.delete(food)
                try? context.save()
            }
        }
    }
    
    private func generateRecipe(from meal: Meal) {
        let mealName = title
        let ingredients = meal.foodItems.map { $0.name }
        isGeneratingRecipe = true
        HapticManager.shared.impact(style: .medium)
        
        Task {
            let dto = await AINutritionService.shared.generateCookingSteps(for: mealName, ingredients: ingredients)
            DispatchQueue.main.async {
                isGeneratingRecipe = false
                if let dto = dto {
                    HapticManager.shared.notification(type: .success)
                    self.generatedRecipe = AIChefRecipe(
                        title: dto.title,
                        calories: dto.calories,
                        protein: dto.protein,
                        heroImage: "agent_chef",
                        cookTime: dto.cookTime,
                        difficulty: dto.difficulty,
                        history: dto.history,
                        ingredients: dto.ingredients,
                        steps: dto.steps.map { RecipeStep(instruction: $0.instruction, imageName: "", aiTip: $0.aiTip) },
                        platingTip: dto.platingTip
                    )
                } else {
                    HapticManager.shared.notification(type: .error)
                    self.recipeGenerationError = "AI Chef needs a break! Please check your connection and try again."
                    self.showingRecipeError = true
                }
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                        if let mealDate = meal?.date {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                Text("Logged at \(mealDate.formatted(date: .omitted, time: .shortened))")
                            }
                            .font(.subheadline)
                            .foregroundColor(.themeOrange)
                        } else {
                            Text("No foods logged yet")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    if let meal = meal, !meal.foodItems.isEmpty {
                        VStack(spacing: 16) {
                            Text("\(meal.totalCalories) kcal")
                                .font(.system(size: 48, weight: .heavy, design: .rounded))
                                .foregroundColor(.themePink)

                            HStack(spacing: 20) {
                                let user = users.first
                                let targetP = (user?.targetProtein ?? 150.0) / 3
                                let targetF = (user?.targetFats ?? 70.0) / 3
                                let targetC = (user?.targetCarbs ?? 250.0) / 3

                                MiniProgressView(title: "Protein", progress: meal.totalProtein / max(targetP, 1), color: .themePeach)
                                MiniProgressView(title: "Fats", progress: meal.totalFats / max(targetF, 1), color: .themeYellow)
                                MiniProgressView(title: "Carbs", progress: meal.totalCarbs / max(targetC, 1), color: .drinkWater)
                            }
                        }
                        .ultraPremiumCardStyle()
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("What you ate")
                                .font(.title3.bold())
                                .padding(.horizontal)
                                .padding(.bottom, 12)

                            VStack(spacing: 0) {

                                ForEach(meal.foodItems) { food in
                                    FoodItemDetailedRow(food: food, onDelete: {
                                        deleteFoodItem(food)
                                    })
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        HapticManager.shared.impact(style: .light)
                                        selectedFoodForDetail = food
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            deleteFoodItem(food)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }

                                    if food.id != meal.foodItems.last?.id {
                                        Divider().padding(.leading, 20)
                                    }
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
                        }
                        .padding(.horizontal)
                        
                        if meal.foodItems.count > 2 {
                            Button(action: {
                                generateRecipe(from: meal)
                            }) {
                                HStack {
                                    if isGeneratingRecipe {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "sparkles")
                                    }
                                    Text(isGeneratingRecipe ? "Chef is writing recipe..." : "Cook with Chef")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(
                                    ZStack {
                                        Color.themePink
                                        if isGeneratingRecipe {
                                            Color.white.opacity(0.3)
                                                .blur(radius: 10)
                                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isGeneratingRecipe)
                                        }
                                    }
                                )
                                .cornerRadius(16)
                                .shadow(color: isGeneratingRecipe ? Color.themePink.opacity(0.8) : Color.themePink.opacity(0.3), radius: isGeneratingRecipe ? 15 : 8, y: 4)
                            }
                            .padding(.horizontal)
                            .disabled(isGeneratingRecipe)
                            .animation(.easeInOut, value: isGeneratingRecipe)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            Text("Key Micronutrients")
                                .font(.title3.bold())
                                .padding(.horizontal)

                            MicronutrientRingsView(meal: meal)
                                .padding(.horizontal)
                        }
                    } else {
                        EmptyStateView(
                            imageName: "fork.knife.circle",
                            title: "No Food Logged",
                            description: "Tap 'Add Food' below to log your \(title)."
                        )
                        .frame(height: 300)
                        .ultraPremiumCardStyle()
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 120)
            }

            Button(action: { showingAddFood.toggle() }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Food")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.themePink)
                .cornerRadius(20)
                .shadow(color: Color.themePink.opacity(0.3), radius: 8, y: 4)
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .buttonStyle(BounceButtonStyle())
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showingAddFood) {
            SmartAddFoodView(mealTitle: title) { selectedItems in
                addFoodsToMeal(items: selectedItems)
            }
            .presentationDetents([.fraction(0.85), .large])
            .presentationCornerRadius(32)
        }
        .fullScreenCover(item: $selectedFoodForDetail) { food in
            FoodDetailNutritionView(food: food, mealTitle: title) { addedFood in
                addFoodsToMeal(items: [addedFood])
            }
        }
        .fullScreenCover(item: $generatedRecipe) { recipe in
            NavigationStack {
                PrepChecklistView(
                    recipe: recipe,
                    isFlowPresented: Binding(
                        get: { generatedRecipe != nil },
                        set: { if !$0 { generatedRecipe = nil } }
                    )
                )
            }
        }
        .alert(isPresented: $showingRecipeError) {
            Alert(
                title: Text("Generation Failed"),
                message: Text(recipeGenerationError ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    private func addFoodsToMeal(items: [FoodItem]) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let summary: DailySummary

        if let existingSummary = summaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }) {
            summary = existingSummary
        } else {
            // Creation is now handled by the repo ensure (called from .task on date change).
            // If still missing, the caller should have ensured; fall back to local create + main insert for this flow.
            summary = DailySummary(date: startOfDay)
            context.insert(summary)
        }

        var newFoodItems: [FoodItem] = []
        for item in items {
            let copiedItem = FoodItem(
                name: item.name, weight: item.weight, calories: item.calories,
                protein: item.protein, fats: item.fats, carbs: item.carbs,
                omega3: item.omega3, calcium: item.calcium, potassium: item.potassium,
                magnesium: item.magnesium, iron: item.iron, vitaminC: item.vitaminC, vitaminD: item.vitaminD
            )
            context.insert(copiedItem)
            newFoodItems.append(copiedItem)
        }

        if let existingMeal = summary.meals.first(where: { $0.title == title }) {
            existingMeal.foodItems.append(contentsOf: newFoodItems)
            existingMeal.date = .now
        } else {
            let newMeal = Meal(title: title, date: .now, foodItems: newFoodItems)
            context.insert(newMeal)
            summary.meals.append(newMeal)
        }

        // Ensured via repo task; save on main context for live @Query updates.
        try? context.save()
    }
}

struct FoodItemDetailedRow: View {
    let food: FoodItem
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.themePink.opacity(0.05)).frame(width: 44, height: 44)
                Text(String(food.name.first ?? "🍲")).font(.headline).foregroundColor(.themePink)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name).font(.subheadline).bold()
                HStack(spacing: 8) {
                    Text("\(Int(food.weight))g")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    Text("P:\(Int(food.protein)) F:\(Int(food.fats)) C:\(Int(food.carbs))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            Spacer()

            Text("\(food.calories) kcal").font(.headline).foregroundColor(.themePink)

            if let onDelete = onDelete {
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.leading, 4)
                        .padding(.vertical, 8)
                }
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
    }
}

struct MicronutrientRingsView: View {
    let meal: Meal
    private let targetOmega3: Double = 1.6 / 3
    private let targetPotassium: Double = 3500 / 3
    private let targetMagnesium: Double = 400 / 3

    var body: some View {
        HStack(spacing: 24) {
            ZStack {
                ActivityRing(progress: meal.totalOmega3 / targetOmega3, color: .themePink, radius: 56, thickness: 12)
                ActivityRing(progress: meal.totalPotassium / targetPotassium, color: .themeYellow, radius: 40, thickness: 12)
                ActivityRing(progress: meal.totalMagnesium / targetMagnesium, color: .themeOrange, radius: 24, thickness: 12)
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.linearGradient(colors: [.themePink, .themeOrange], startPoint: .top, endPoint: .bottom))
            }
            .frame(width: 112, height: 112)

            VStack(alignment: .leading, spacing: 16) {
                RingLegendRow(color: .themePink, title: "Omega-3", value: meal.totalOmega3, unit: "g", target: targetOmega3)
                RingLegendRow(color: .themeYellow, title: "Potassium", value: meal.totalPotassium, unit: "mg", target: targetPotassium)
                RingLegendRow(color: .themeOrange, title: "Magnesium", value: meal.totalMagnesium, unit: "mg", target: targetMagnesium)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 6)
    }
}

private struct RingLegendRow: View {
    let color: Color
    let title: String
    let value: Double
    let unit: String
    let target: Double

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Text("\(value, specifier: "%.1f") / \(Int(target)) \(unit)").font(.system(size: 13, weight: .medium)).foregroundColor(.gray)
            }
        }
    }
}

private struct ActivityRing: View {
    let progress: Double
    let color: Color
    let radius: CGFloat
    let thickness: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: thickness)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: radius * 2, height: radius * 2)
        .animation(.spring(response: 0.8), value: progress)
    }
}

private struct RingLegend: View {
    let color: Color; let title: String; let value: Double; let unit: String
    var body: some View {
        VStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).font(.caption).foregroundColor(.gray)
            Text("\(value, specifier: "%.1f")\(unit)").font(.subheadline.bold())
        }
    }
}

struct MealCardView: View {
    let title: String
    let calories: Int?
    let recommendedCalories: Int
    let time: Date?
    var onCardTap: () -> Void
    var onQuickAdd: () -> Void

    var iconAndColor: (String, Color) {
        switch title {
        case "Breakfast": return ("sunrise.fill", .themeYellow)
        case "Lunch":     return ("sun.max.fill", .green)
        case "Dinner":    return ("moon.fill", .themePink)
        case "Snack":     return ("leaf.fill", .themeOrange)
        default:          return ("fork.knife", .gray)
        }
    }

    var body: some View {
        let meta = iconAndColor
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(meta.1.opacity(0.15)).frame(width: 46, height: 46)
                Image(systemName: meta.0).font(.system(size: 20, weight: .semibold)).foregroundColor(meta.1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary)
                HStack(spacing: 6) {
                    if let cals = calories, cals > 0 {
                        Text("\(cals) kcal").font(.subheadline).foregroundColor(meta.1).bold()
                        if let logTime = time {
                            Text("• \(logTime.formatted(date: .omitted, time: .shortened))").font(.caption2).foregroundColor(.gray)
                        }
                    } else {
                        Text("Log Meal").font(.subheadline).foregroundColor(.gray.opacity(0.7))
                    }
                }
            }
            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Target").font(.system(size: 9, weight: .bold)).foregroundColor(.gray.opacity(0.6))
                Text("\(recommendedCalories)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.gray.opacity(0.8))
                Text("kcal").font(.system(size: 7)).foregroundColor(.gray.opacity(0.5))
            }
            .padding(.trailing, 4)

            Button(action: {
                HapticManager.shared.impact(style: .medium)
                onQuickAdd()
            }) {
                ZStack {
                    Circle().fill(meta.1.opacity(0.15)).frame(width: 36, height: 36)
                    Image(systemName: "plus").font(.system(size: 16, weight: .bold)).foregroundColor(meta.1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: meta.1.opacity(0.08), radius: 12, x: 0, y: 6)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(style: .light)
            onCardTap()
        }
    }
}

struct ActionSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("Search foods...", text: $text).font(.body)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray.opacity(0.5))
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
    }
}
struct InteractiveFoodRow: View {
    let food: FoodItem
    let isSelected: Bool
    @State private var weight: Double
    let action: () -> Void

    init(food: FoodItem, isSelected: Bool, action: @escaping () -> Void) {
        self.food = food
        self.isSelected = isSelected
        self.action = action
        self._weight = State(initialValue: food.weight)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 16) {
                    Text("🥘")
                        .font(.system(size: 24))
                        .frame(width: 44, height: 44)
                        .background(isSelected ? Color.white : Color.gray.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name).font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundColor(.primary)
                        let currentCals = Int((Double(food.calories) / food.weight) * weight)
                        Text("\(currentCals) kcal • \(Int(weight))g").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(isSelected ? .themePink : .gray)
                    }
                    Spacer()
                    ZStack {
                        Circle().fill(isSelected ? Color.themePink : Color.gray.opacity(0.1)).frame(width: 32, height: 32)
                        Image(systemName: isSelected ? "checkmark" : "plus").font(.system(size: 14, weight: .black)).foregroundColor(isSelected ? .white : .themePink)
                    }
                }.padding(16)
            }.buttonStyle(PlainButtonStyle())

            if isSelected {
                HStack(spacing: 20) {
                    HStack {
                        Button(action: { weight = max(10, weight - 10); HapticManager.shared.impact(style: .light) }) { Image(systemName: "minus.circle.fill").foregroundColor(.gray.opacity(0.3)) }
                        Text("\(Int(weight)) g").font(.system(size: 15, weight: .bold, design: .monospaced)).frame(width: 70)
                        Button(action: { weight += 10; HapticManager.shared.impact(style: .light) }) { Image(systemName: "plus.circle.fill").foregroundColor(.gray.opacity(0.3)) }
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach([100, 200, 300], id: \.self) { val in
                            Button(action: { withAnimation(.spring()) { weight = Double(val) }; HapticManager.shared.impact(style: .medium) }) {
                                Text("\(val)").font(.system(size: 12, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 4).background(weight == Double(val) ? Color.themePink.opacity(0.2) : Color.gray.opacity(0.1)).cornerRadius(8)
                            }
                        }
                    }
                }.padding(.horizontal, 16).padding(.bottom, 16).transition(.move(edge: .top).combined(with: .opacity))
            }
        }.background(Color.white).cornerRadius(24).overlay(RoundedRectangle(cornerRadius: 24).stroke(isSelected ? Color.themePink.opacity(0.3) : Color.clear, lineWidth: 2)).shadow(color: isSelected ? Color.themePink.opacity(0.1) : Color.black.opacity(0.03), radius: 10, y: 5).padding(.horizontal, 4)
    }
}

struct MacroText: View {
    let title: String; let value: Double; let color: Color
    var body: some View {
        HStack(spacing: 2) {
            Text(title).font(.system(size: 10, weight: .bold)).foregroundColor(color)
            Text("\(Int(value))g").font(.system(size: 11, weight: .medium)).foregroundColor(.gray)
        }
    }
}

struct FloatingCartButton: View {
    let count: Int; let calories: Int; let action: () -> Void
    var body: some View {
        VStack {
            Spacer()
            Button(action: action) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(count) items selected").font(.caption).foregroundColor(.white.opacity(0.8))
                        Text("Add • \(calories) kcal").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.white)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").font(.title).foregroundColor(.white)
                }.padding(.horizontal, 24).padding(.vertical, 16).background(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .leading, endPoint: .trailing)).cornerRadius(24).shadow(color: Color.themePink.opacity(0.4), radius: 15, y: 8)
            }.padding(.horizontal, 20).padding(.bottom, 30)
        }
    }
}

struct MacroDot: View {
    let color: Color; let val: Double
    var body: some View { VStack(spacing: 2) { Circle().fill(color).frame(width: 6, height: 6); Text("\(Int(val))").font(.system(size: 10, weight: .bold)).foregroundColor(.gray) } }
}

struct FoodSearchResultRow: View {
    let food: FoodItem
    let action: () -> Void

    @Query private var users: [User]

    var body: some View {
        let user = users.first
        let compatibility = food.compatibility(with: user?.activeDietPlan)

        Button(action: action) {
            HStack(spacing: 16) {

                ZStack {
                    Circle().fill(Color.gray.opacity(0.05)).frame(width: 48, height: 48)
                    Text("🍲").font(.system(size: 24))

                    if compatibility != .neutral {
                        Image(systemName: compatibility.icon)
                            .font(.system(size: 14))
                            .foregroundColor(compatibility.color)
                            .background(Color.white.clipShape(Circle()))
                            .offset(x: 16, y: 16)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(compatibility == .avoid ? .gray : .primary)
                        .strikethrough(compatibility == .avoid, color: .red.opacity(0.5))

                    HStack {
                        Text("\(food.calories) kcal • 100g")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)

                        if compatibility == .perfect {
                            Text("• Great for \(user?.activeDietPlan?.name ?? "")")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                        } else if compatibility == .avoid {
                            Text("• Avoid on \(user?.activeDietPlan?.name ?? "")")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.red)
                        }
                    }
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(compatibility == .avoid ? .gray.opacity(0.3) : .themePink)
            }
            .padding(16)
            .background(compatibility == .avoid ? Color.red.opacity(0.03) : (compatibility == .perfect ? Color.green.opacity(0.03) : Color.white))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.02), radius: 8, y: 4)
        }
        .buttonStyle(BounceButtonStyle())
    }
}

struct AllTimeStatsCardView: View {
    let totalCalories: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "flame.circle.fill").font(.largeTitle).foregroundStyle(LinearGradient(colors: [.white, .white.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                VStack(alignment: .leading, spacing: 2) {
                    Text("All-Time Total").font(.headline).foregroundColor(.white)
                    Text("Since your first entry").font(.caption).foregroundColor(.white.opacity(0.8))
                }
            }
            Spacer(minLength: 20)
            HStack(alignment: .firstTextBaseline) {
                Text(totalCalories, format: .number).font(.system(size: 44, weight: .heavy, design: .rounded)).contentTransition(.numericText())
                Text("kcal").font(.title2.bold()).foregroundColor(.white.opacity(0.9))
            }.foregroundColor(.white)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(24).background(LinearGradient(colors: [Color.themePink.opacity(0.9), Color.themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing)).cornerRadius(28).shadow(color: .themePink.opacity(0.3), radius: 15, x: 0, y: 8).padding(.horizontal)
    }
}
struct DailyNoteCard: View {
    let summary: DailySummary
    var onEdit: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .medium)
            onEdit()
        }) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Daily Notes")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(.themePink)
                }

                if summary.dayNote.isEmpty && summary.dayMoodEmoji.isEmpty {

                    HStack(spacing: 20) {
                        Text("☀️").font(.system(size: 40))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("How was your day?")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Track your feelings & habits")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }

                        Spacer()
                        Text("🌧️").font(.system(size: 30)).opacity(0.5)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(20)
                } else {

                    HStack(alignment: .top, spacing: 16) {
                        if !summary.dayMoodEmoji.isEmpty {
                            Text(summary.dayMoodEmoji)
                                .font(.system(size: 40))
                                .padding(12)
                                .background(Color.themePink.opacity(0.1))
                                .clipShape(Circle())
                        }

                        Text(summary.dayNote.isEmpty ? "No text added, just a mood!" : summary.dayNote)
                            .font(.body)
                            .foregroundColor(.primary.opacity(0.9))
                            .lineLimit(4)
                            .multilineTextAlignment(.leading)
                            .padding(.top, 8)

                        Spacer()
                    }
                }
            }
            .ultraPremiumCardStyle()
        }
        .buttonStyle(BounceButtonStyle())
    }
}

struct DailyNoteSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var summary: DailySummary

    let moods = [
        ("☀️", "Great Day"),
        ("🍩", "Cheat Day"),
        ("🍔", "Binge Eating"),
        ("🥲", "Bad Mood"),
        ("🏋️", "Active"),
        ("🧘‍♀️", "Relaxed"),
        ("🤢", "Felt Sick")
    ]
    
    @State private var selectedMoodForAI: String? = nil
    @State private var showAIChat = false
    @State private var moodContextForChat: String? = nil
    
    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            HStack {
                Text("Your Day")
                    .font(.title2.bold())
                Spacer()
                Button("Save") {
                    HapticManager.shared.impact(style: .heavy)
                    try? context.save()
                    clearAIMoodStates()
                    dismiss()
                }
                .font(.headline)
                .foregroundColor(.themePink)
            }
            .padding(.horizontal, 24)

            TextField("Write about your meals, feelings, or workouts...", text: $summary.dayNote, axis: .vertical)
                .lineLimit(4...8)
                .padding(16)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 24)
                .accessibilityLabel("Daily note")

            VStack(alignment: .leading, spacing: 12) {
                Text("Tags & Mood")
                    .font(.headline)
                    .padding(.horizontal, 24)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(moods, id: \.1) { mood in
                            Button(action: {
                                HapticManager.shared.impact(style: .light)
                                withAnimation {
                                    if summary.dayMoodEmoji == mood.0 {
                                        summary.dayMoodEmoji = ""
                                        clearAIMoodStates()
                                    } else {
                                        summary.dayMoodEmoji = mood.0
                                        clearAIMoodStates() // prevent stale chat state from previous mood
                                        
                                        // Trigger AI Advice popup with a small delay for nice animation feel
                                        Task {
                                            try? await Task.sleep(for: .milliseconds(250))
                                            await MainActor.run {
                                                selectedMoodForAI = mood.0
                                            }
                                        }
                                    }
                                }
                            }) {
                                VStack(spacing: 8) {
                                    Text(mood.0)
                                        .font(.system(size: 30))
                                        .frame(minWidth: 52, minHeight: 52)
                                        .background(summary.dayMoodEmoji == mood.0 ? Color.themePink.opacity(0.2) : Color.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(summary.dayMoodEmoji == mood.0 ? Color.themePink : Color.gray.opacity(0.2), lineWidth: 2)
                                        )
                                        .cornerRadius(20)

                                    Text(mood.1)
                                        .font(.caption)
                                        .fontWeight(summary.dayMoodEmoji == mood.0 ? .bold : .medium)
                                        .foregroundColor(summary.dayMoodEmoji == mood.0 ? .themePink : .gray)
                                }
                                .frame(minWidth: 64, minHeight: 80) // Ensure good tap target per HIG (44pt minimum)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityLabel("\(mood.1) mood")
                            .accessibilityValue(summary.dayMoodEmoji == mood.0 ? "Selected" : "Not selected")
                            .accessibilityAddTraits(.isButton)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)
                }
            }

            Spacer()
        }
        .background(Color.themeBg.ignoresSafeArea())
        .onDisappear {
            clearAIMoodStates()
        }
        .sheet(item: Binding(
            get: { selectedMoodForAI.map { IdentifiableString(value: $0) } },
            set: { selectedMoodForAI = $0?.value }
        )) { wrappedEmoji in
            let emoji = wrappedEmoji.value
            let moodName = moods.first(where: { $0.0 == emoji })?.1 ?? "Mood"
            AIMoodAdvicePopup(moodEmoji: emoji, moodName: moodName) {
                // Force-clear the advice item BEFORE opening chat to prevent re-presentation loop
                selectedMoodForAI = nil
                moodContextForChat = "I feel \(moodName) \(emoji) right now. Can we talk about it?"
                showAIChat = true
            }
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showAIChat) {
            if let user = try? context.fetch(FetchDescriptor<User>()).first {
                NavigationStack {
                    AICoachChatView(
                        userGoal: user.dailyCaloriesGoal,
                        consumed: summary.totalCalories,
                        activeDiet: user.activeDietPlan?.name ?? "Balanced",
                        initialContext: moodContextForChat
                    )
                }
            }
        }
        .onChange(of: showAIChat) { _, isPresented in
            if !isPresented {
                // Clean up after chat is dismissed so it doesn't re-trigger anything
                moodContextForChat = nil
            }
        }
    }

    private func clearAIMoodStates() {
        selectedMoodForAI = nil
        moodContextForChat = nil
        showAIChat = false
    }
}

struct DailyLogDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    let summary: DailySummary

    private func deleteFoodItem(_ food: FoodItem, from meal: Meal) {
        if let index = meal.foodItems.firstIndex(where: { $0.id == food.id }) {
            withAnimation {
                meal.foodItems.remove(at: index)
                context.delete(food)
                try? context.save()
            }
        }
    }
    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    VStack(spacing: 8) {
                        Text("\(summary.totalFoodCalories) kcal")
                            .font(.system(size: 48, weight: .heavy, design: .rounded))
                            .foregroundColor(.themePink)
                        Text("Total Food Logged Today")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 20)

                    let activeMeals = summary.meals.filter { !$0.foodItems.isEmpty }

                    if activeMeals.isEmpty {
                        EmptyStateView(imageName: "doc.text.magnifyingglass", title: "No Food Logged", description: "You haven't logged any food for this day yet.")
                            .padding(.top, 40)
                    } else {
                        ForEach(activeMeals) { meal in
                            VStack(alignment: .leading, spacing: 0) {

                                HStack {
                                    Text(meal.title)
                                        .font(.title3.bold())
                                    Spacer()
                                    Text("\(meal.totalCalories) kcal")
                                        .font(.headline)
                                        .foregroundColor(.themePink)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .padding(.bottom, 12)

                                VStack(spacing: 0) {
                                    ForEach(meal.foodItems) { food in
                                        HStack(spacing: 16) {
                                            ZStack {
                                                Circle().fill(Color.gray.opacity(0.05)).frame(width: 44, height: 44)
                                                Text(String(food.name.first ?? "🥘")).font(.headline)
                                            }

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(food.name)
                                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                                    .foregroundColor(.primary)

                                                HStack {
                                                    Text("\(Int(food.weight))g")
                                                    Text("•")
                                                    Text("P:\(Int(food.protein)) F:\(Int(food.fats)) C:\(Int(food.carbs))")
                                                }
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                            }
                                            Spacer()

                                            Text("\(food.calories)")
                                                                                           .font(.headline)
                                                                                           .foregroundColor(.primary)

                                                                                       Button(action: {
                                                                                           HapticManager.shared.impact(style: .medium)
                                                                                           deleteFoodItem(food, from: meal)
                                                                                       }) {
                                                                                           Image(systemName: "trash")
                                                                                               .foregroundColor(.red.opacity(0.8))
                                                                                               .padding(.leading, 8)
                                                                                       }
                                                                                   }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)

                                        if food.id != meal.foodItems.last?.id {
                                            Divider().padding(.leading, 70)
                                        }
                                    }
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(24)
                            .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .navigationTitle("Daily Log")
        .navigationBarTitleDisplayMode(.inline)
    }
}
struct ActivitySourceRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let calories: Int

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(iconColor)
                    .bold()
            }

            Spacer()

            Text("\(calories) kcal")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(calories > 0 ? .primary : .gray.opacity(0.5))
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}
struct SmartAddFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var allDatabaseFoods: [FoodItem]
    @Query private var customRecipes: [CustomRecipe]
    @Query(sort: \Meal.date, order: .reverse) private var pastMeals: [Meal]

    @State private var selectedFoodForDetail: FoodItem? = nil
    let mealTitle: String
    var onSave: ([FoodItem]) -> Void

    @State private var showingScanner = false
    @State private var showingManualAdd = false
    @State private var selectedFoods: [FoodItem] = []
    @State private var searchText = ""
    @State private var selectedCategory = "Recent"
    @State private var scannerMode: SmartScannerView.ScannerMode = .barcode

    @State private var apiSearchResults: [FoodItem] = []
    @State private var isSearchingAPI = false
    @State private var searchTask: Task<Void, Never>? = nil

    let categories = ["Recent", "Frequent", "Favorites", "My Recipes"]

    var allAvailableFoods: [FoodItem] {
        var uniqueItems: [String: FoodItem] = [:]
        for meal in pastMeals {
            for item in meal.foodItems {
                if uniqueItems[item.name] == nil { uniqueItems[item.name] = item }
            }
        }
        for item in allDatabaseFoods {
            if uniqueItems[item.name] == nil { uniqueItems[item.name] = item }
        }
        var results = Array(uniqueItems.values)
        if results.isEmpty {
            results = [
                FoodItem(name: "Grilled Chicken Breast", weight: 150, calories: 240, protein: 31, fats: 3.6, carbs: 0),
                FoodItem(name: "Avocado Toast", weight: 120, calories: 220, protein: 5, fats: 12, carbs: 20)
            ]
        }
        return results
    }

    var filteredLocalFoods: [FoodItem] {
        var items: [FoodItem] = []
        var foodCounts: [String: Int] = [:]

        for meal in pastMeals {
            for food in meal.foodItems { foodCounts[food.name, default: 0] += 1 }
        }

        switch selectedCategory {
        case "Recent": items = allAvailableFoods
        case "Frequent": items = allAvailableFoods.sorted { (foodCounts[$0.name] ?? 0) > (foodCounts[$1.name] ?? 0) }
        case "Favorites": items = allAvailableFoods.filter { (foodCounts[$0.name] ?? 0) >= 2 && $0.name != "Quick Entry" }
        case "My Recipes": items = customRecipes.map { $0.toFoodItem() }
        default: items = allAvailableFoods
        }

        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        if selectedCategory == "Recent" || selectedCategory == "My Recipes" {
            items.sort { $0.name < $1.name }
        }
        return items
    }

    var cartCalories: Int { selectedFoods.reduce(0) { $0 + $1.calories } }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()

            VStack(spacing: 0) {

                VStack(spacing: 16) {
                    Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 10)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mealTitle).font(.system(size: 28, weight: .bold, design: .rounded))
                            Text("What did you eat?").font(.subheadline).foregroundColor(.gray)
                        }
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundColor(Color.gray.opacity(0.3))
                        }
                    }.padding(.horizontal, 20)

                    ActionSearchBar(text: $searchText)
                    .padding(.horizontal, 20)

                    if searchText.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                FeatureCard(
                                    title: "Meal AI",
                                    subtitle: "AI Photo Scan - snap a photo of food",
                                    icon: "camera.viewfinder",
                                    gradient: [.themePink, .themeOrange],
                                    action: {
                                        scannerMode = .mealAI
                                        showingScanner = true
                                    }
                                )
                                
                                FeatureCard(
                                    title: "Barcode",
                                    subtitle: "Barcode Scan - scan product package",
                                    icon: "barcode.viewfinder",
                                    gradient: [.cyan, .blue],
                                    action: {
                                        scannerMode = .barcode
                                        showingScanner = true
                                    }
                                )
                                
                                FeatureCard(
                                    title: "Menu AI",
                                    subtitle: "AI Menu Reader - scan restaurant menus",
                                    icon: "text.book.closed.fill",
                                    gradient: [.purple, .indigo],
                                    action: {
                                        scannerMode = .menuAI
                                        showingScanner = true
                                    }
                                )
                                
                                FeatureCard(
                                    title: "Manual Entry",
                                    subtitle: "Log Manually - input custom food",
                                    icon: "pencil.line",
                                    gradient: [.green, .mint],
                                    action: {
                                        showingManualAdd = true
                                    }
                                )
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(categories, id: \.self) { category in
                                    Button(action: {
                                        withAnimation(.spring()) { selectedCategory = category }
                                        HapticManager.shared.impact(style: .light)
                                    }) {
                                        Text(category)
                                            .font(.subheadline).bold()
                                            .padding(.horizontal, 18).padding(.vertical, 10)
                                            .background(selectedCategory == category ? Color.themePink : Color.white)
                                            .foregroundColor(selectedCategory == category ? .white : .primary)
                                            .cornerRadius(20)
                                            .shadow(color: selectedCategory == category ? Color.themePink.opacity(0.3) : Color.black.opacity(0.03), radius: 4, y: 2)
                                    }
                                }
                            }
                            .padding(.horizontal, 20).padding(.vertical, 4)
                        }
                    }
                }
                .padding(.bottom, 10)
                .background(Rectangle().fill(.ultraThinMaterial).ignoresSafeArea().shadow(color: .black.opacity(0.03), radius: 8, y: 4))
                .zIndex(2)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        if !searchText.isEmpty {
                            if isSearchingAPI {
                                ProgressView("Searching global database...")
                                    .padding(.top, 40)
                            } else {
                                if !filteredLocalFoods.isEmpty {
                                    Text("From your history").font(.caption.bold()).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading)
                                    ForEach(filteredLocalFoods, id: \.self) { food in
                                        FoodSearchResultRow(food: food) { selectedFoodForDetail = food }
                                    }
                                }

                                if !apiSearchResults.isEmpty {
                                    Text("Global database").font(.caption.bold()).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)
                                    ForEach(apiSearchResults, id: \.self) { food in
                                        FoodSearchResultRow(food: food) { selectedFoodForDetail = food }
                                    }
                                } else if filteredLocalFoods.isEmpty {

                                    VStack(spacing: 16) {
                                        Image(systemName: "questionmark.folder.fill").font(.system(size: 48)).foregroundColor(.themeOrange.opacity(0.5))
                                        Text("Can't find '\(searchText)'?").font(.headline)
                                        Text("No worries! You can quickly add it to your personal database and use it forever.")
                                            .font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal, 20)

                                        Button(action: {
                                            HapticManager.shared.impact(style: .medium)
                                            showingManualAdd = true
                                        }) {
                                            HStack {
                                                Image(systemName: "plus.circle.fill")
                                                Text("Create Custom Food")
                                            }
                                            .font(.headline).foregroundColor(.white).padding(.vertical, 14).padding(.horizontal, 24)
                                            .background(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .cornerRadius(20).shadow(color: Color.green.opacity(0.3), radius: 8, y: 4)
                                        }
                                        .buttonStyle(BounceButtonStyle())
                                    }
                                    .padding(.top, 40)
                                }
                            }
                        } else {
                            if filteredLocalFoods.isEmpty {
                                EmptyStateView(imageName: "tray", title: "No history", description: "Your recent meals will appear here.")
                                    .padding(.top, 60)
                            } else {
                                ForEach(filteredLocalFoods, id: \.self) { food in
                                    FoodSearchResultRow(food: food) { selectedFoodForDetail = food }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, selectedFoods.isEmpty ? 40 : 120)
                }
            }

            if !selectedFoods.isEmpty {
                FloatingCartButton(count: selectedFoods.count, calories: cartCalories) {
                    HapticManager.shared.impact(style: .heavy)
                    onSave(selectedFoods)
                    dismiss()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity)).zIndex(3)
            }
        }
        .onChange(of: searchText) { _, newValue in performSearch(query: newValue) }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedFoods.isEmpty)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: searchText)
        .fullScreenCover(item: $selectedFoodForDetail) { food in
            FoodDetailNutritionView(food: food, mealTitle: mealTitle) { addedFood in
                withAnimation(.spring()) { selectedFoods.append(addedFood) }
            }
        }
        .fullScreenCover(isPresented: $showingScanner) {
            SmartScannerView(
                initialMode: scannerMode,
                onProductFound: { foundFood in selectedFoodForDetail = foundFood },
                onManualEntryRequest: { showingManualAdd = true }
            )
        }
        .sheet(isPresented: $showingManualAdd) {
            AddIngredientModalView { newCustomItem in
                withAnimation(.spring()) { selectedFoods.append(newCustomItem) }
            }
            .presentationDetents([.fraction(0.85), .large])
            .presentationCornerRadius(32)
            .presentationDragIndicator(.visible)
        }
    }

    private func performSearch(query: String) {
        searchTask?.cancel()
        guard query.count > 2 else {
            apiSearchResults = []
            isSearchingAPI = false
            return
        }
        isSearchingAPI = true
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                let results = await NetworkManager.shared.searchFoodByText(query: query)
                await MainActor.run {
                    if !Task.isCancelled {
                        self.apiSearchResults = results
                        self.isSearchingAPI = false
                    }
                }
            } catch {
                if !Task.isCancelled { await MainActor.run { self.isSearchingAPI = false } }
            }
        }
    }
}

struct FeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .medium)
            action()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.25))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(width: 220, height: 80, alignment: .leading)
            .background(
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(20)
            .shadow(color: gradient.first?.opacity(0.3) ?? .clear, radius: 8, y: 4)
        }
        .buttonStyle(BounceButtonStyle())
    }
}

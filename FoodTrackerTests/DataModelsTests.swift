import XCTest
import SwiftData
@testable import FoodTracker

@MainActor
final class DataModelsTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(
            for: User.self, Beverage.self, FoodItem.self, Meal.self, CustomRecipe.self, ActivityLog.self, DailySummary.self, ShoppingItem.self, WeightLog.self, AIChatSession.self, WeeklyMealPlan.self, MealPlanDay.self, MealPlanItem.self,
            configurations: config
        )
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testUserInitializationAndGoalsCalculation() throws {
        let user = User(name: "TestUser", weight: 70, height: 175, age: 30, gender: "Male")
        context.insert(user)
        
        XCTAssertEqual(user.name, "TestUser")
        XCTAssertEqual(user.weight, 70)
        XCTAssertEqual(user.height, 175)
        XCTAssertEqual(user.age, 30)
        XCTAssertEqual(user.gender, "Male")
        
        // BMR for male: (10 * 70) + (6.25 * 175) - (30 * 5) + 5 = 700 + 1093.75 - 150 + 5 = 1648.75
        // Goal = BMR * 1.3 = 2143
        XCTAssertEqual(user.dailyCaloriesGoal, 2143)
        XCTAssertEqual(user.activeDietKey, "balanced")
    }

    func testFoodItemHealthGrade() throws {
        // High protein, clean
        let chicken = FoodItem(name: "Chicken", weight: 100, calories: 165, protein: 31, fats: 3.6, carbs: 0)
        XCTAssertEqual(chicken.healthGrade, .clean)

        // Low calories, low carbs, clean
        let cucumber = FoodItem(name: "Cucumber", weight: 100, calories: 15, protein: 0.6, fats: 0.1, carbs: 3.6)
        XCTAssertEqual(cucumber.healthGrade, .clean)

        // High calories, low protein, treat
        let cake = FoodItem(name: "Cake", weight: 100, calories: 400, protein: 3, fats: 20, carbs: 50)
        XCTAssertEqual(cake.healthGrade, .treat)

        // Balanced
        let balancedFood = FoodItem(name: "Balanced Meal", weight: 100, calories: 250, protein: 10, fats: 10, carbs: 30)
        XCTAssertEqual(balancedFood.healthGrade, .balanced)
    }

    func testMealTotalCalculations() throws {
        let apple = FoodItem(name: "Apple", weight: 100, calories: 52, protein: 0.3, fats: 0.2, carbs: 14)
        let banana = FoodItem(name: "Banana", weight: 100, calories: 89, protein: 1.1, fats: 0.3, carbs: 23)
        
        let meal = Meal(title: "Breakfast", date: Date(), foodItems: [apple, banana])
        
        XCTAssertEqual(meal.totalCalories, 141)
        XCTAssertEqual(meal.totalProtein, 1.4, accuracy: 0.0001)
        XCTAssertEqual(meal.totalFats, 0.5, accuracy: 0.0001)
        XCTAssertEqual(meal.totalCarbs, 37)
    }

    func testDailySummaryCalculations() throws {
        let summary = DailySummary(date: Date())
        
        let meal = Meal(title: "Lunch", date: Date())
        meal.foodItems = [FoodItem(name: "Rice", weight: 100, calories: 130, protein: 2, fats: 0, carbs: 28)]
        summary.meals = [meal]
        
        let water = Beverage(name: "Water", icon: "drop", colorHex: "blue", caloriesPerGlass: 0, volumeMl: 500)
        let soda = Beverage(name: "Soda", icon: "cup.and.saucer", colorHex: "brown", caloriesPerGlass: 150, volumeMl: 330)
        summary.beverages = [water, soda]
        
        let activity = ActivityLog(title: "Running", icon: "figure.run", durationMinutes: 30, calories: 300)
        summary.activities = [activity]
        
        summary.activeCaloriesBurned = 300
        
        XCTAssertEqual(summary.totalFoodCalories, 130)
        XCTAssertEqual(summary.totalDrinkCalories, 150)
        XCTAssertEqual(summary.totalCalories, 280)
        XCTAssertEqual(summary.totalHydrationLiters, 0.83, accuracy: 0.01)
        XCTAssertEqual(summary.netCalories, -20)
        
        let remaining = summary.remainingCalories(userGoal: 2000)
        // (2000 + 300) - 280 = 2020
        XCTAssertEqual(remaining, 2020)
    }

    func testCloudKitSchemaCompatibility() throws {
        let schema = Schema([
            User.self, Beverage.self, FoodItem.self, Meal.self, CustomRecipe.self,
            ActivityLog.self, DailySummary.self, AIChatSession.self, ShoppingItem.self,
            WeeklyMealPlan.self, MealPlanDay.self, MealPlanItem.self, WeightLog.self
        ])

        for entity in schema.entities {
            XCTAssertTrue(
                entity.uniquenessConstraints.isEmpty,
                "CloudKit forbids @Attribute(.unique) on \(entity.name): \(entity.uniquenessConstraints)"
            )

            for attr in entity.attributes where !attr.isOptional {
                XCTAssertNotNil(
                    attr.defaultValue,
                    "CloudKit requires defaultValue for non-optional attribute \(entity.name).\(attr.name)"
                )
            }

            for rel in entity.relationships {
                XCTAssertTrue(
                    rel.isOptional,
                    "CloudKit requires relationship \(entity.name).\(rel.name) to be optional"
                )
                XCTAssertNotNil(
                    rel.inverseName,
                    "CloudKit requires inverse relationship on \(entity.name).\(rel.name)"
                )
            }
        }
    }

    func testUserCalculateGoalsRespectsActivityAndWeightGoalType() {
        let user = User(name: "Alex", weight: 80, height: 180, age: 30, gender: "Male")
        user.activityMultiplier = 1.55
        user.weightGoalType = "lose"
        user.calculateGoals()

        // BMR = 1780; TDEE = 2759; lose = 2759 - 450 = 2309
        XCTAssertEqual(user.dailyCaloriesGoal, 2309)

        user.recalculateMacrosPreservingRatios(fromPreviousCalories: 2759)
        XCTAssertGreaterThan(user.targetProtein, 0)
        XCTAssertGreaterThan(user.targetFats, 0)
        XCTAssertGreaterThan(user.targetCarbs, 0)
        let macroCals = user.targetProtein * 4.0 + user.targetFats * 9.0 + user.targetCarbs * 4.0
        XCTAssertEqual(macroCals, Double(user.dailyCaloriesGoal), accuracy: 30.0)

        user.weightGoalType = "gain"
        user.calculateGoals()
        XCTAssertEqual(user.dailyCaloriesGoal, 3109) // 2759 + 350
    }

    func testDailySummaryFetchOrCreateMergesDuplicates() throws {
        let day = Calendar.current.startOfDay(for: Date())
        let first = DailySummary(
            date: day,
            meals: [Meal(title: "Breakfast", date: day, foodItems: [FoodItem(name: "Eggs", weight: 100, calories: 155, protein: 13, fats: 11, carbs: 1)])]
        )
        let second = DailySummary(
            date: day,
            beverages: [Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: 300)],
            activities: [ActivityLog(title: "Walk", icon: "figure.walk", durationMinutes: 20, calories: 90)]
        )
        second.stepsCount = 5400

        context.insert(first)
        context.insert(second)
        try context.save()

        let merged = DailySummary.fetchOrCreate(for: day, in: context)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<DailySummary>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(merged.totalFoodCalories, 155)
        XCTAssertEqual(merged.totalHydrationLiters, 0.3, accuracy: 0.01)
        XCTAssertEqual(merged.localActivityCalories, 90)
        XCTAssertEqual(merged.stepsCount, 5400)
    }

    func testSharedModelContainerFallsBackWithoutCrashing() {
        let schema = Schema([User.self, DailySummary.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self])
        let unreachableURL = URL(fileURLWithPath: "/System/Library/NonWritablePath/\(UUID().uuidString)/Food.sqlite")
        let container = SharedModelContainer.makeContainer(schema: schema, url: unreachableURL, enableCloudKit: false)
        XCTAssertNotNil(container)
    }

    func testLocalDataResetServiceWipesSwiftDataAndDefaults() throws {
        let defaultsSuite = "test.LocalDataReset.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }

        defaults.set(true, forKey: "hasCompletedOnboarding_v2")
        defaults.set(true, forKey: "hasCompletedInitialOnboarding_v2")
        defaults.set(true, forKey: "hasCompletedOnboarding")
        defaults.set(["article_1"], forKey: "CompletedAcademyArticles")

        let user = User(name: "DeleteMe", weight: 70, height: 175, age: 30)
        let summary = DailySummary(date: Date(), meals: [Meal(title: "Lunch", date: Date(), foodItems: [FoodItem(name: "Soup", weight: 200, calories: 150, protein: 5, fats: 4, carbs: 20)])])
        let recipe = CustomRecipe(name: "Soup", info: "Warm", foodItems: [], cookingTime: 10, difficulty: "Easy")
        let shopping = ShoppingItem(name: "Milk")
        let weightLog = WeightLog(weight: 70)
        let chat = AIChatSession(title: "Test Chat")
        let plan = WeeklyMealPlan(targetCalories: 2000, dietType: "balanced")

        context.insert(user)
        context.insert(summary)
        context.insert(recipe)
        context.insert(shopping)
        context.insert(weightLog)
        context.insert(chat)
        context.insert(plan)
        try context.save()

        LocalDataResetService.wipeAllData(in: context, defaults: defaults)

        XCTAssertEqual(try context.fetch(FetchDescriptor<User>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DailySummary>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Meal>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FoodItem>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CustomRecipe>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ShoppingItem>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<WeightLog>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AIChatSession>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<WeeklyMealPlan>()).count, 0)
        XCTAssertFalse(defaults.bool(forKey: "hasCompletedOnboarding_v2"))
        XCTAssertFalse(defaults.bool(forKey: "hasCompletedInitialOnboarding_v2"))
        XCTAssertFalse(defaults.bool(forKey: "hasCompletedOnboarding"))
        XCTAssertNil(defaults.array(forKey: "CompletedAcademyArticles"))
    }

    func testLocalDataResetServiceClearsRealSpotlightAndFeatureKeys() {
        let defaultsSuite = "test.SpotlightReset.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }

        defaults.set(true, forKey: "hasCompletedSpotlightTour_v5")
        defaults.set(true, forKey: "remindMeals")
        defaults.set(false, forKey: "useMetricSystem")
        defaults.set(["2026-11-17"], forKey: "xpClaimedDateKeys")
        defaults.set(true, forKey: "healthKitAuthRequested_v1")

        LocalDataResetService.wipeAllData(in: context, defaults: defaults)

        XCTAssertFalse(defaults.bool(forKey: "hasCompletedSpotlightTour_v5"))
        XCTAssertNil(defaults.object(forKey: "remindMeals"))
        XCTAssertNil(defaults.object(forKey: "useMetricSystem"))
        XCTAssertNil(defaults.array(forKey: "xpClaimedDateKeys"))
        XCTAssertNil(defaults.object(forKey: "healthKitAuthRequested_v1"))
    }

    func testCustomRecipeToFoodItemScalesPerServing() {
        let oats = FoodItem(name: "Oats", weight: 200, calories: 600, protein: 20, fats: 10, carbs: 100)
        let recipe = CustomRecipe(
            name: "Oatmeal Bowl",
            info: "Tasty",
            foodItems: [oats],
            cookingTime: 10,
            difficulty: "Easy",
            servings: 2
        )

        let singleServing = recipe.toFoodItem()

        XCTAssertEqual(singleServing.weight, 100, accuracy: 0.01)
        XCTAssertEqual(singleServing.calories, 300)
        XCTAssertEqual(singleServing.protein, 10, accuracy: 0.01)
        XCTAssertEqual(singleServing.fats, 5, accuracy: 0.01)
        XCTAssertEqual(singleServing.carbs, 50, accuracy: 0.01)
    }

    func testNutritionMathZeroWeightDoesNotMultiply100x() {
        let scaled = NutritionMath.scaledValues(
            baseWeight: 0,
            baseCalories: 350,
            baseProtein: 20,
            baseFats: 10,
            baseCarbs: 40,
            targetWeight: 100
        )

        XCTAssertEqual(scaled.calories, 350)
        XCTAssertEqual(scaled.protein, 20, accuracy: 0.01)
        XCTAssertEqual(scaled.fats, 10, accuracy: 0.01)
        XCTAssertEqual(scaled.carbs, 40, accuracy: 0.01)
    }

    func testNutritionMathParsesLocaleDecimalCommaAndRejectsNonPositive() {
        XCTAssertEqual(NutritionMath.parsePositiveDecimal("125,5") ?? -1, 125.5, accuracy: 0.001)
        XCTAssertEqual(NutritionMath.parsePositiveDecimal(" 75.25 ") ?? -1, 75.25, accuracy: 0.001)
        XCTAssertNil(NutritionMath.parsePositiveDecimal("0"))
        XCTAssertNil(NutritionMath.parsePositiveDecimal("-10"))
        XCTAssertNil(NutritionMath.parsePositiveDecimal("abc"))
    }

    func testEditableFoodDraftPreservesBaselineAcrossMultipleResizes() {
        let existing: FoodItem? = nil
        var draft = EditableFoodDraft(
            id: UUID(),
            existingItem: existing,
            name: "Chicken Breast",
            baseWeight: 100,
            baseCalories: 165,
            baseProtein: 31,
            baseFats: 3.6,
            baseCarbs: 0,
            weight: 100
        )

        draft.weight = 5
        XCTAssertEqual(draft.calories, 8)
        draft.weight = 100
        XCTAssertEqual(draft.calories, 165)
        draft.weight = 200
        XCTAssertEqual(draft.calories, 330)
    }

    func testFinishDayXPRequiresNonZeroCaloriesAndSingleClaimPerDay() {
        let emptySummary = DailySummary(date: Date())
        let user = User(name: "Alex", weight: 75, height: 180, age: 28)
        user.dailyCaloriesGoal = 2000
        user.targetProtein = 130

        let breakdown = NutritionMath.finishDayXP(for: emptySummary, user: user)
        XCTAssertEqual(breakdown.calorieGoalXP, 0)

        let defaultsSuite = "test.XPClaim.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }

        let day = Date()
        XCTAssertTrue(NutritionMath.claimFinishDayXP(for: day, defaults: defaults))
        XCTAssertFalse(NutritionMath.claimFinishDayXP(for: day, defaults: defaults))
    }

    func testCanonicalMealTypeNormalization() {
        XCTAssertEqual(NutritionMath.canonicalMealType("Завтрак"), "Breakfast")
        XCTAssertEqual(NutritionMath.canonicalMealType("Обед"), "Lunch")
        XCTAssertEqual(NutritionMath.canonicalMealType("Ужин"), "Dinner")
        XCTAssertEqual(NutritionMath.canonicalMealType("Перекус"), "Snack")
        XCTAssertEqual(NutritionMath.canonicalMealType("Breakfast"), "Breakfast")
    }

    func testPremiumRecipeToAIChefRecipeConversion() {
        let premium = PremiumRecipe(
            title: "Salmon Bowl",
            description: "Fresh omega-rich bowl.",
            time: "25 min",
            caloriesPerServing: 480,
            imageUrl: "https://example.com/salmon.jpg",
            isFavorite: true,
            tags: ["High Protein", "Dinner"],
            baseServings: 2,
            protein: 38.0,
            fat: 18.0,
            carbs: 42.0,
            ingredients: [RecipeIngredient(name: "Salmon", amount: "200 g", weightGrams: 200, calories: 350)],
            directions: ["Season salmon.", "Sear 4 minutes per side."]
        )

        let chefRecipe = premium.toAIChefRecipe()

        XCTAssertEqual(chefRecipe.title, "Salmon Bowl")
        XCTAssertEqual(chefRecipe.calories, 480)
        XCTAssertEqual(chefRecipe.protein, 38)
        XCTAssertEqual(chefRecipe.fat, 18)
        XCTAssertEqual(chefRecipe.carbs, 42)
        XCTAssertEqual(chefRecipe.cookTime, 25)
        XCTAssertEqual(chefRecipe.steps.count, 2)
        XCTAssertEqual(chefRecipe.ingredients.first, "Salmon (200 g)")
    }

    func testRecipeDataLoaderLoadsBundledRecipesOffline() {
        let enRecipes = RecipeDataLoader.loadBundledRecipes(languageCode: "en")
        let ruRecipes = RecipeDataLoader.loadBundledRecipes(languageCode: "ru")
        XCTAssertGreaterThan(enRecipes.count, 10)
        XCTAssertGreaterThan(ruRecipes.count, 10)
    }

    func testNutritionMathRemainingMacrosFromUserAndSummary() {
        let user = User(name: "Alex", weight: 75, height: 180, age: 28)
        user.dailyCaloriesGoal = 2200
        user.targetProtein = 150
        user.targetFats = 70
        user.targetCarbs = 240

        let food = FoodItem(name: "Breakfast", weight: 200, calories: 600, protein: 40, fats: 20, carbs: 65)
        let meal = Meal(title: "Breakfast", date: Date(), foodItems: [food])
        let summary = DailySummary(date: Date(), meals: [meal])

        let remaining = NutritionMath.remainingMacros(user: user, summary: summary)
        XCTAssertEqual(remaining.calories, 1600)
        XCTAssertEqual(remaining.protein, 110)
        XCTAssertEqual(remaining.fat, 50)
        XCTAssertEqual(remaining.carbs, 175)
    }

    func testRecordWeightSynchronizesUserWeightLogSummaryAndGoals() throws {
        let user = User(name: "Alex", weight: 80.0, height: 180.0, age: 30, gender: "Male")
        user.weightGoalType = "lose"
        user.activityMultiplier = 1.55
        user.calculateGoals()
        let initialGoal = user.dailyCaloriesGoal
        context.insert(user)
        try context.save()

        NutritionMath.recordWeight(74.0, date: Date(), for: user, in: context)

        let logs = try context.fetch(FetchDescriptor<WeightLog>())
        let todaySummary = DailySummary.fetchExisting(for: Date(), in: context)
        XCTAssertEqual(user.weight, 74.0, accuracy: 0.01)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.weight ?? -1, 74.0, accuracy: 0.01)
        XCTAssertEqual(todaySummary?.weight ?? -1, 74.0, accuracy: 0.01)
        XCTAssertLessThan(user.dailyCaloriesGoal, initialGoal)
    }

    func testConsecutiveStreakAndSyncAchievementsUnlockExpectedIDs() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -1, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -2, to: today)!

        let s0 = DailySummary(
            date: today,
            meals: [Meal(title: "Lunch", date: today, foodItems: [FoodItem(name: "Salad", weight: 200, calories: 350, protein: 15, fats: 10, carbs: 40)])],
            beverages: [Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: 2600)]
        )
        let s1 = DailySummary(
            date: day1,
            meals: [Meal(title: "Dinner", date: day1, foodItems: [FoodItem(name: "Fish", weight: 150, calories: 300, protein: 30, fats: 12, carbs: 0)])]
        )
        let s2 = DailySummary(
            date: day2,
            meals: [Meal(title: "Breakfast", date: day2, foodItems: [FoodItem(name: "Oats", weight: 60, calories: 210, protein: 7, fats: 4, carbs: 35)])]
        )

        let streak = NutritionMath.consecutiveStreak(from: [s0, s1, s2])
        XCTAssertEqual(streak, 3)

        let user = User(name: "Alex", weight: 75, height: 180, age: 28)
        user.streakDays = 0
        NutritionMath.syncStreakAndAchievements(for: user, summaries: [s0, s1, s2])

        XCTAssertEqual(user.streakDays, 3)
        XCTAssertTrue(user.unlockedAchievements.contains("first_log"))
        XCTAssertTrue(user.unlockedAchievements.contains("streak_3"))
        XCTAssertTrue(user.unlockedAchievements.contains("water_pro"))
    }

    func testAcademyDataLoaderLoadsBundledCategoriesOffline() {
        let en = AcademyDataLoader.loadBundledCategories(languageCode: "en")
        let ru = AcademyDataLoader.loadBundledCategories(languageCode: "ru")

        XCTAssertFalse(en.isEmpty)
        XCTAssertFalse(ru.isEmpty)
        XCTAssertGreaterThan(en.first?.articles.count ?? 0, 0)
    }

    func testLocalFoodDatabaseSearchUsesSmartSearchSynonymsAndStemming() {
        // Plural/stemmed English and Russian synonyms should match bundled database entries
        let tomatoes = LocalFoodDatabaseService.shared.search(query: "tomatoes", limit: 10)
        XCTAssertFalse(tomatoes.isEmpty)
    }

    func testDailyWidgetSnapshotZeroStateAndDynamicScore() {
        let user = User(name: "Maya", weight: 62, height: 168, age: 27, gender: "Female")
        user.dailyCaloriesGoal = 1850
        user.targetProtein = 120
        user.targetFats = 55
        user.targetCarbs = 210

        let zeroSnapshot = DailyWidgetSnapshot.compute(summary: nil, user: user)
        XCTAssertEqual(zeroSnapshot.totalCalories, 0)
        XCTAssertEqual(zeroSnapshot.hydrationLiters, 0, accuracy: 0.001)
        XCTAssertEqual(zeroSnapshot.metabolicScore, 0)
        XCTAssertEqual(zeroSnapshot.proteinGoal, 120)
        XCTAssertEqual(zeroSnapshot.fatGoal, 55)
        XCTAssertEqual(zeroSnapshot.carbGoal, 210)
        XCTAssertEqual(zeroSnapshot.calorieGoal, 1850)

        let summary = DailySummary(
            date: Date(),
            meals: [Meal(title: "Lunch", date: Date(), foodItems: [FoodItem(name: "Bowl", weight: 400, calories: 1850, protein: 120, fats: 55, carbs: 210)])],
            beverages: [Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: 2500)]
        )
        let fullSnapshot = DailyWidgetSnapshot.compute(summary: summary, user: user)
        XCTAssertEqual(fullSnapshot.totalCalories, 1850)
        XCTAssertGreaterThanOrEqual(fullSnapshot.metabolicScore, 95)
    }

    func testFetchOrCreateCoalescesDuplicateSameSlotMealsAndSameDayWeight() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: User.self, WeightLog.self, DailySummary.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self,
            configurations: config
        )
        let context = container.mainContext
        let today = Calendar.current.startOfDay(for: Date())

        let s1 = DailySummary(
            date: today,
            meals: [Meal(title: "Breakfast", date: today, foodItems: [FoodItem(name: "Oats", weight: 80, calories: 300, protein: 10, fats: 5, carbs: 54)])]
        )
        let s2 = DailySummary(
            date: today,
            meals: [Meal(title: "Завтрак", date: today, foodItems: [FoodItem(name: "Eggs", weight: 100, calories: 150, protein: 12, fats: 10, carbs: 1)])]
        )
        context.insert(s1)
        context.insert(s2)
        try context.save()

        let merged = DailySummary.fetchOrCreate(for: today, in: context)
        XCTAssertEqual(merged.meals?.count, 1)
        XCTAssertEqual(merged.totalFoodCalories, 450)

        let user = User(name: "Alex", weight: 80, height: 180, age: 30, gender: "Male")
        context.insert(user)
        NutritionMath.recordWeight(79.5, date: today, for: user, in: context)
        NutritionMath.recordWeight(79.2, date: today, for: user, in: context)

        let weightLogs = try context.fetch(FetchDescriptor<WeightLog>())
        XCTAssertEqual(weightLogs.count, 1)
        XCTAssertEqual(weightLogs.first?.weight ?? -1, 79.2, accuracy: 0.01)
    }
}

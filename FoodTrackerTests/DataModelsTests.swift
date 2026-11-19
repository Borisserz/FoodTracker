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

        // Logging only 100 kcal out of 2000 kcal goal (< 75%) must NOT award full +150 calorieGoalXP.
        let tinySummary = DailySummary(
            date: Date(),
            meals: [Meal(title: "Snack", date: Date(), foodItems: [FoodItem(name: "Apple", weight: 150, calories: 100, protein: 1, fats: 0, carbs: 25)])]
        )
        XCTAssertEqual(NutritionMath.finishDayXP(for: tinySummary, user: user).calorieGoalXP, 0)
        XCTAssertFalse(DailyXPQuestsEvaluator.isQuestSatisfied(.meals, summary: tinySummary), "Log all meals quest must require 3 distinct meal slots, not 1 snack")

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

    func testLocalFoodDatabaseSearchUsesSmartSearchSynonymsAndStemming() async {
        // Plural/stemmed English and Russian synonyms should match bundled database entries
        await LocalFoodDatabaseService.shared.waitUntilLoaded()
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

    func testRemoteCatalogGuardAndUnitFormatting() {
        XCTAssertTrue(AcademyDataLoader.shouldPreferRemoteCatalog(languageCode: "en"))
        XCTAssertFalse(AcademyDataLoader.shouldPreferRemoteCatalog(languageCode: "ru"))
        XCTAssertFalse(AcademyDataLoader.shouldPreferRemoteCatalog(languageCode: "de"))
        XCTAssertTrue(RecipeDataLoader.shouldPreferRemoteCatalog(languageCode: "en"))
        XCTAssertFalse(RecipeDataLoader.shouldPreferRemoteCatalog(languageCode: "fr"))
        XCTAssertFalse(RecipeDataLoader.shouldPreferRemoteCatalog(languageCode: "pt"))

        XCTAssertEqual(NutritionMath.weightUnit(useMetric: true), "kg")
        XCTAssertEqual(NutritionMath.weightUnit(useMetric: false), "lb")
        XCTAssertEqual(NutritionMath.displayWeight(100, useMetric: false), 220.46, accuracy: 0.1)
        XCTAssertEqual(NutritionMath.kgFromDisplayWeight(220.46, useMetric: false), 100.0, accuracy: 0.1)
        XCTAssertEqual(NutritionMath.displayHeight(178, useMetric: false), 70)
        XCTAssertEqual(NutritionMath.cmFromDisplayHeight(70, useMetric: false), 177.8, accuracy: 0.1)
        XCTAssertEqual(NutritionMath.displayFluid(2.0, useMetric: false), 67.63, accuracy: 0.1)
        XCTAssertEqual(NutritionMath.fluidShortUnit(useMetric: false), "fl oz")
        XCTAssertTrue(NutritionMath.formattedHydration(liters: 2.0, useMetric: false).contains("fl oz"))
    }

    @MainActor
    func testDeleteWeightLogRollsBackUserWeightAndClearsSummary() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: User.self, WeightLog.self, DailySummary.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self,
            configurations: config
        )
        let context = container.mainContext
        let user = User(name: "Alex", weight: 80, height: 180, age: 30, gender: "Male")
        context.insert(user)

        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let today = Date()

        NutritionMath.recordWeight(81.0, date: yesterday, for: user, in: context)
        NutritionMath.recordWeight(78.5, date: today, for: user, in: context)
        XCTAssertEqual(user.weight, 78.5, accuracy: 0.01)

        let logs = try context.fetch(FetchDescriptor<WeightLog>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
        XCTAssertEqual(logs.count, 2)
        NutritionMath.deleteWeightLog(logs[0], for: user, in: context)

        let remaining = try context.fetch(FetchDescriptor<WeightLog>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(user.weight, 81.0, accuracy: 0.01)

        let summaries = try context.fetch(FetchDescriptor<DailySummary>())
        let todaySummary = summaries.first { calendar.isDateInToday($0.date) }
        XCTAssertNil(todaySummary?.weight)
    }

    @MainActor
    func testWorkoutSyncManagerReadsWorkoutCaloriesAndReconcilesWater() throws {
        let suiteName = "test.workout.sync.\(UUID().uuidString)"
        let sharedDefaults = UserDefaults(suiteName: suiteName)!
        let localDefaults = UserDefaults(suiteName: "test.local.sync.\(UUID().uuidString)")!
        defer {
            sharedDefaults.removePersistentDomain(forName: suiteName)
        }

        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: User.self, WeightLog.self, DailySummary.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self,
            configurations: config
        )
        let context = container.mainContext
        let today = Calendar.current.startOfDay(for: Date())
        let summary = DailySummary.fetchOrCreate(for: today, in: context)

        // Simulate WorkoutTracker writing burned calories and water liters into shared App Group.
        sharedDefaults.set(420, forKey: WorkoutSyncManager.workoutCaloriesKey(for: today))
        sharedDefaults.set(1.25, forKey: WorkoutSyncManager.waterLitersKey(for: today))

        let wtCals = WorkoutSyncManager.shared.fetchWorkoutCalories(for: today, sharedDefaults: sharedDefaults)
        XCTAssertEqual(wtCals, 420)

        let changedFirst = WorkoutSyncManager.shared.reconcileWater(
            for: summary,
            in: context,
            sharedDefaults: sharedDefaults,
            localDefaults: localDefaults
        )
        XCTAssertTrue(changedFirst)
        XCTAssertEqual(summary.totalHydrationLiters, 1.25, accuracy: 0.01)

        // Second pass with identical shared state must be idempotent.
        let changedSecond = WorkoutSyncManager.shared.reconcileWater(
            for: summary,
            in: context,
            sharedDefaults: sharedDefaults,
            localDefaults: localDefaults
        )
        XCTAssertFalse(changedSecond)

        // Syncing higher local water updates shared key for WorkoutTracker.
        let localDrink = Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: 500)
        context.insert(localDrink)
        summary.addBeverage(localDrink)
        WorkoutSyncManager.shared.syncWater(summary.totalHydrationLiters, for: today, sharedDefaults: sharedDefaults, localDefaults: localDefaults)
        XCTAssertEqual(WorkoutSyncManager.shared.fetchWaterLiters(for: today, sharedDefaults: sharedDefaults) ?? 0, 1.75, accuracy: 0.01)

        // Simulate WorkoutTracker deleting 0.5L (shared drops from 1.75 -> 1.25 while local stays 1.75).
        sharedDefaults.set(1.25, forKey: WorkoutSyncManager.waterLitersKey(for: today))
        let changedOnDelete = WorkoutSyncManager.shared.reconcileWater(
            for: summary,
            in: context,
            sharedDefaults: sharedDefaults,
            localDefaults: localDefaults
        )
        XCTAssertTrue(changedOnDelete)
        XCTAssertEqual(summary.totalHydrationLiters, 1.25, accuracy: 0.01)
        XCTAssertEqual(WorkoutSyncManager.shared.fetchWaterLiters(for: today, sharedDefaults: sharedDefaults) ?? 0, 1.25, accuracy: 0.01)

        // Simulate Widget AddWaterIntent adding 250 ml directly to SwiftData without touching lastSynced/App Group.
        let widgetWater = Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: 250)
        context.insert(widgetWater)
        summary.addBeverage(widgetWater)
        let changedFromWidget = WorkoutSyncManager.shared.reconcileWater(
            for: summary,
            in: context,
            sharedDefaults: sharedDefaults,
            localDefaults: localDefaults
        )
        XCTAssertFalse(changedFromWidget)
        XCTAssertEqual(WorkoutSyncManager.shared.fetchWaterLiters(for: today, sharedDefaults: sharedDefaults) ?? 0, 1.50, accuracy: 0.01)
    }

    func testWorkoutSyncComputeDailyBurnReconciliation() {
        // HealthKit enabled: avoid double counting WorkoutTracker (App Group + HKWorkout), add local activity.
        let withHK = WorkoutSyncManager.computeDailyBurn(
            localActivityCalories: 150,
            workoutTrackerCalories: 400,
            healthKitWorkoutCalories: 400,
            healthKitTotalActiveCalories: 700,
            stepsCount: 6500,
            isHealthKitEnabled: true
        )
        XCTAssertEqual(withHK.workoutCalories, 550)
        XCTAssertEqual(withHK.activeCaloriesBurned, 700)
        XCTAssertEqual(withHK.stepsCount, 6500)

        // HealthKit disabled: clears stale steps and keeps combined workout burn accurately.
        let withoutHK = WorkoutSyncManager.computeDailyBurn(
            localActivityCalories: 150,
            workoutTrackerCalories: 400,
            healthKitWorkoutCalories: 500,
            healthKitTotalActiveCalories: 900,
            stepsCount: 6500,
            isHealthKitEnabled: false
        )
        XCTAssertEqual(withoutHK.workoutCalories, 650)
        XCTAssertEqual(withoutHK.activeCaloriesBurned, 650)
        XCTAssertEqual(withoutHK.stepsCount, 0)
    }

    func testMotionManagerReferenceCountingStartAndStop() {
        let motion = MotionManager.shared
        motion.resetForTesting()
        XCTAssertEqual(motion.activeConsumerCount, 0)

        motion.start()
        motion.start()
        XCTAssertEqual(motion.activeConsumerCount, 2)

        motion.stop()
        XCTAssertEqual(motion.activeConsumerCount, 1)

        motion.stop()
        XCTAssertEqual(motion.activeConsumerCount, 0)

        // Extra stop does not underflow consumer counter.
        motion.stop()
        XCTAssertEqual(motion.activeConsumerCount, 0)
    }

    func testDailyWidgetSnapshotMidnightRolloverSchedule() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 23, minute: 30))!
        let startOfTomorrow = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 0, minute: 0))!

        let snapshot = DailyWidgetSnapshot(
            hydrationLiters: 1.8,
            hydrationGoalLiters: 2.5,
            protein: 110,
            proteinGoal: 140,
            fat: 55,
            fatGoal: 65,
            carbs: 180,
            carbGoal: 220,
            totalCalories: 1650,
            calorieGoal: 2000,
            metabolicScore: 84
        )

        let schedule = DailyWidgetSnapshot.timelineSchedule(for: snapshot, now: now, calendar: calendar)
        XCTAssertEqual(schedule.entries.count, 2)
        XCTAssertEqual(schedule.entries[0].date, now)
        XCTAssertEqual(schedule.entries[0].snapshot, snapshot)

        XCTAssertEqual(schedule.entries[1].date, startOfTomorrow)
        XCTAssertEqual(schedule.entries[1].snapshot.totalCalories, 0)
        XCTAssertEqual(schedule.entries[1].snapshot.protein, 0)
        XCTAssertEqual(schedule.entries[1].snapshot.hydrationLiters, 0, accuracy: 0.001)
        XCTAssertEqual(schedule.entries[1].snapshot.metabolicScore, 0)
        // Goals are preserved across the midnight reset entry.
        XCTAssertEqual(schedule.entries[1].snapshot.calorieGoal, 2000)
        XCTAssertEqual(schedule.entries[1].snapshot.proteinGoal, 140)
        // Reload should trigger right at midnight rather than 23:30 + 1h.
        XCTAssertEqual(schedule.reloadAt, startOfTomorrow)
    }

    func testLocalFoodDatabaseAsyncSearchRanking() async {
        let appleResults = await LocalFoodDatabaseService.shared.searchAsync(query: "apple", limit: 10)
        XCTAssertTrue(LocalFoodDatabaseService.shared.isLoaded)
        XCTAssertFalse(appleResults.isEmpty)
        XCTAssertTrue(LocalFoodDatabaseService.shared.search(query: "   ", limit: 10).isEmpty)
    }

    func testWave4PortugueseFoodCatalogAndRecipeParityAndUnits() {
        XCTAssertEqual(LocalFoodDatabaseService.resolveLanguageCode(for: "pt"), "pt-PT")
        let enFoods = LocalFoodDatabaseService.loadBundledFoods(languageCode: "en")
        let ptFoods = LocalFoodDatabaseService.loadBundledFoods(languageCode: "pt")
        XCTAssertGreaterThanOrEqual(ptFoods.count, enFoods.count)
        let ptIds = Set(ptFoods.map(\.id))
        let missingIds = enFoods.filter { !ptIds.contains($0.id) }
        XCTAssertTrue(missingIds.isEmpty, "Expected 0 missing foods_en IDs in foods_pt-PT.json, got \(missingIds.count)")
        let enCategories = Set(enFoods.map(\.category))
        let ptCategories = Set(ptFoods.map(\.category))
        XCTAssertEqual(ptCategories.intersection(enCategories), enCategories)
        XCTAssertTrue(ptFoods.contains(where: { $0.name == "Bacalhau à Brás" }))

        for code in ["en", "de", "es", "fr", "it", "pt", "ru"] {
            let recipes = RecipeDataLoader.loadBundledRecipes(languageCode: code)
            XCTAssertEqual(recipes.count, 61, "Expected 61 recipes for locale \(code)")
            XCTAssertFalse(recipes.contains(where: { $0.imageUrl.contains("pollinations.ai") }))
        }

        let firstAcademy = AcademyDataLoader.loadBundledCategories(languageCode: "pt")
        let secondAcademy = AcademyDataLoader.loadBundledCategories(languageCode: "pt")
        XCTAssertFalse(firstAcademy.isEmpty)
        XCTAssertEqual(firstAcademy.count, secondAcademy.count)

        XCTAssertEqual(NutritionMath.formattedHydration(liters: 2.5, useMetric: true), "2.5 L")
        XCTAssertEqual(NutritionMath.formattedHydration(liters: 2.5, useMetric: false), "85 fl oz")
    }

    @MainActor
    func testMealSlotPersistenceSavesMultiSlotEditsAndDeletesClearedSlot() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: DailySummary.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self, configurations: config)
        let context = container.mainContext
        let today = Calendar.current.startOfDay(for: .now)
        let summary = DailySummary.fetchOrCreate(for: today, in: context)

        // Pre-existing Dinner (500 kcal) that user clears out before switching back to Lunch
        let steak = FoodItem(name: "Steak", weight: 200, calories: 500, protein: 45, fats: 32, carbs: 0)
        let dinnerMeal = Meal(title: "Dinner", date: today, foodItems: [steak])
        context.insert(steak)
        context.insert(dinnerMeal)
        summary.addMeal(dinnerMeal)
        try context.save()

        let oatsDraft = EditableFoodDraft(name: "Oats", baseWeight: 100, baseCalories: 350, baseProtein: 12, baseFats: 6, baseCarbs: 60)
        let saladDraft = EditableFoodDraft(name: "Salad", baseWeight: 200, baseCalories: 240, baseProtein: 10, baseFats: 14, baseCarbs: 18)

        let delta = MealSlotPersistence.persist(
            activeSlot: "Lunch",
            activeDrafts: [saladDraft],
            hasModifiedActiveSlot: true,
            draftsBySlot: [
                "Breakfast": [oatsDraft],
                "Dinner": []
            ],
            dirtySlots: ["Breakfast", "Dinner"],
            summary: summary,
            timestamp: today,
            in: context
        )
        try context.save()

        // +350 (Breakfast) +240 (Lunch) -500 (Dinner cleared) = +90 kcal net delta
        XCTAssertEqual(delta, 90)
        XCTAssertEqual(summary.totalCalories, 590)
        let mealTitles = Set((summary.meals ?? []).map { DailySummary.canonicalMealSlot($0.title) })
        XCTAssertEqual(mealTitles, ["Breakfast", "Lunch"])
    }

    func testCustomRecipePerServingNutritionDividesByServings() {
        let pasta = FoodItem(name: "Pasta", weight: 400, calories: 800, protein: 28, fats: 8, carbs: 152)
        let recipe = CustomRecipe(
            name: "Pasta Bake",
            info: "Dinner",
            foodItems: [pasta],
            cookingTime: 25,
            difficulty: "Easy",
            servings: 4,
            directions: ["Boil"]
        )

        let perServing = recipe.perServingNutrition
        XCTAssertEqual(perServing.calories, 200)
        XCTAssertEqual(perServing.protein, 7.0, accuracy: 0.01)
        XCTAssertEqual(perServing.fats, 2.0, accuracy: 0.01)
        XCTAssertEqual(perServing.carbs, 38.0, accuracy: 0.01)
    }

    func testRecipeWizardValidatorBlocksStep3WhenPreviousStepsInvalidAndAcceptsCommaDecimalWeight() {
        XCTAssertFalse(RecipeWizardValidator.isStepValid(3, name: "", ingredientsCount: 0, directions: [""]))
        XCTAssertFalse(RecipeWizardValidator.isStepValid(3, name: "Pie", ingredientsCount: 1, directions: ["  "]))
        XCTAssertTrue(RecipeWizardValidator.isStepValid(3, name: "Pie", ingredientsCount: 1, directions: ["Bake"]))

        XCTAssertEqual(
            RecipeWizardValidator.clampedStep(3, current: 0, name: "", ingredientsCount: 0, directions: [""]),
            0
        )
        XCTAssertEqual(
            RecipeWizardValidator.clampedStep(3, current: 1, name: "Omelette", ingredientsCount: 0, directions: ["Cook"]),
            1
        )
        XCTAssertTrue(AddIngredientModalView.isFormValid(name: "Olive Oil", weight: "12,5"))
        XCTAssertFalse(AddIngredientModalView.isFormValid(name: "Olive Oil", weight: "0"))
    }

    func testRussianFoodCatalogHasUniqueIDsAndRoundingToFoodItem() {
        let ruFoods = LocalFoodDatabaseService.loadBundledFoods(languageCode: "ru")
        let uniqueIDs = Set(ruFoods.map(\.id))
        XCTAssertEqual(uniqueIDs.count, ruFoods.count, "foods_ru.json should not contain duplicate IDs")

        let entry = LocalFoodEntry(
            id: "test",
            name: "Test Food",
            calories: 105,
            protein: 10,
            fat: 2,
            carbs: 12,
            category: "Snacks"
        )
        XCTAssertEqual(entry.toFoodItem(weight: 50).calories, 53)
    }

    func testSmartSearchCyrillicYotFoldingAndShortPrefixGuard() {
        let roots = SmartSearch.getRoots(for: "яйцо", languageCode: "ru")
        let flattened = Set(roots.flatMap { $0 })
        XCTAssertTrue(flattened.contains("яичниц") || flattened.contains("яиц"))

        let shortRoots = SmartSearch.getRoots(for: "по", languageCode: "ru").flatMap { $0 }
        XCTAssertFalse(shortRoots.contains("томат"), "2-char prefix 'по' must not inject unrelated 'томат' synonym")
    }

    @MainActor
    func testUserGoalsMatchMetabolicFloorAndDeduplicatedPrimaryMergesDuplicates() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: User.self, DailySummary.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self, WeightLog.self, configurations: config)
        let context = container.mainContext

        let pete = User(name: "Pete", weight: 45, height: 150, age: 40, gender: "Female")
        pete.activityMultiplier = 1.55
        pete.weightGoalType = "maintain"
        pete.calculateGoals()
        // Raw BMR = 10*45 + 6.25*150 - 200 - 161 = 1026.5; TDEE = 1026.5 * 1.55 = 1591.075 -> maintain = max(1200, 1591) = 1591
        XCTAssertEqual(pete.dailyCaloriesGoal, 1591)

        // With lose goal, deficit drops below 1200 so clinical safety floor clamps final dailyCaloriesGoal to 1200.
        pete.weightGoalType = "lose"
        pete.calculateGoals()
        XCTAssertEqual(pete.dailyCaloriesGoal, 1200)
        pete.weightGoalType = "maintain"
        pete.calculateGoals()

        let alex = User(name: "Alex", weight: 75, height: 180, age: 28, gender: "Male")
        context.insert(alex)
        context.insert(pete)
        try context.save()

        let resolved = User.deduplicatedPrimary(in: context)
        let remaining = try context.fetch(FetchDescriptor<User>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(resolved?.name, "Pete")
    }

    func testQuickActivityPriorExternalCaloriesPreventsDoubleCounting() {
        // Suppose prior state had 150 kcal local + 400 kcal external = 550 total workoutCalories.
        let priorExternal = WorkoutSyncManager.priorExternalWorkoutCalories(
            totalWorkoutCalories: 550,
            previousLocalActivityCalories: 150
        )
        XCTAssertEqual(priorExternal, 400)

        // User adds another 200 kcal local activity -> new local total = 350 kcal.
        let reconciled = WorkoutSyncManager.computeDailyBurn(
            localActivityCalories: 350,
            workoutTrackerCalories: 0,
            healthKitWorkoutCalories: priorExternal,
            healthKitTotalActiveCalories: 0,
            stepsCount: 0,
            isHealthKitEnabled: true
        )
        XCTAssertEqual(reconciled.workoutCalories, 750)
    }

    func testWorkoutSyncComputeDailyBurnPreservesAppleWatchAlongsideWorkoutTracker() {
        let burn = WorkoutSyncManager.computeDailyBurn(
            localActivityCalories: 150,
            workoutTrackerCalories: 400,
            healthKitWorkoutCalories: 350,
            otherExternalWorkoutCalories: 300,
            healthKitTotalActiveCalories: 950,
            stepsCount: 8000,
            isHealthKitEnabled: true
        )
        // max(400, 350) = 400 WT + 300 Apple Watch + 150 local = 850
        XCTAssertEqual(burn.workoutCalories, 850)
        XCTAssertEqual(burn.activeCaloriesBurned, 950)
    }

    func testWorkoutSyncWidgetWaterRecordsAndConsumesPendingHealthKitDelta() {
        let sharedSuite = "WorkoutSyncWidgetWater.shared.\(UUID().uuidString)"
        let appSuite = "WorkoutSyncWidgetWater.app.\(UUID().uuidString)"
        let sharedDefaults = UserDefaults(suiteName: sharedSuite)!
        let appDefaults = UserDefaults(suiteName: appSuite)!
        let localDefaults = UserDefaults(suiteName: "WorkoutSyncWidgetWater.local.\(UUID().uuidString)")!
        defer {
            sharedDefaults.removePersistentDomain(forName: sharedSuite)
            appDefaults.removePersistentDomain(forName: appSuite)
        }

        let today = Date()
        WorkoutSyncManager.shared.syncWaterFromWidget(
            totalLiters: 0.75,
            addedMl: 250.0,
            for: today,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: appDefaults,
            localDefaults: localDefaults
        )
        WorkoutSyncManager.shared.syncWaterFromWidget(
            totalLiters: 1.0,
            addedMl: 250.0,
            for: today,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: appDefaults,
            localDefaults: localDefaults
        )

        XCTAssertEqual(WorkoutSyncManager.shared.fetchWaterLiters(for: today, sharedDefaults: sharedDefaults) ?? 0, 1.0, accuracy: 0.001)
        let pendingLiters = WorkoutSyncManager.shared.consumePendingWidgetWaterLiters(for: today, appGroupDefaults: appDefaults)
        XCTAssertEqual(pendingLiters, 0.5, accuracy: 0.001)
        XCTAssertEqual(WorkoutSyncManager.shared.consumePendingWidgetWaterLiters(for: today, appGroupDefaults: appDefaults), 0.0, accuracy: 0.001)
    }

    @MainActor
    func testMealSlotPersistenceWithSyncOpsTracksInsertedEditedAndDeletedItems() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: DailySummary.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self, configurations: config)
        let context = container.mainContext
        let today = Calendar.current.startOfDay(for: .now)
        let summary = DailySummary.fetchOrCreate(for: today, in: context)

        let eggs = FoodItem(name: "Eggs", weight: 100, calories: 200, protein: 14, fats: 14, carbs: 2)
        eggs.healthKitSampleID = "hk-eggs-1"
        let bacon = FoodItem(name: "Bacon", weight: 50, calories: 250, protein: 12, fats: 22, carbs: 0)
        bacon.healthKitSampleID = "hk-bacon-1"
        let breakfast = Meal(title: "Breakfast", date: today, foodItems: [eggs, bacon])
        context.insert(eggs)
        context.insert(bacon)
        context.insert(breakfast)
        summary.addMeal(breakfast)
        try context.save()

        // Edit eggs up to 300 kcal, remove bacon, add toast 150 kcal
        var editedEggsDraft = EditableFoodDraft(food: eggs)
        editedEggsDraft.weight = 150 // 300 kcal
        let toastDraft = EditableFoodDraft(name: "Toast", baseWeight: 50, baseCalories: 150, baseProtein: 5, baseFats: 2, baseCarbs: 28)

        let result = MealSlotPersistence.persistWithSyncOps(
            activeSlot: "Breakfast",
            activeDrafts: [editedEggsDraft, toastDraft],
            hasModifiedActiveSlot: true,
            draftsBySlot: [:],
            dirtySlots: [],
            summary: summary,
            timestamp: today,
            in: context
        )
        try context.save()

        XCTAssertEqual(result.netCaloriesDelta, 0) // (300 + 150) - (200 + 250)
        XCTAssertEqual(result.deletedSamples.count, 1)
        XCTAssertEqual(result.deletedSamples.first?.sampleID, "hk-bacon-1")
        XCTAssertEqual(result.deletedSamples.first?.calories, 250)

        XCTAssertEqual(result.editedItems.count, 1)
        XCTAssertEqual(result.editedItems.first?.oldSampleID, "hk-eggs-1")
        XCTAssertEqual(result.editedItems.first?.oldCalories, 200)
        XCTAssertEqual(result.editedItems.first?.item.calories, 300)

        XCTAssertEqual(result.insertedItems.count, 1)
        XCTAssertEqual(result.insertedItems.first?.name, "Toast")
    }

    @MainActor
    func testDailySummaryRemoveFoodItemDeletesEmptyParentMeal() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: DailySummary.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self, configurations: config)
        let context = container.mainContext
        let today = Calendar.current.startOfDay(for: .now)
        let summary = DailySummary.fetchOrCreate(for: today, in: context)

        let apple = FoodItem(name: "Apple", weight: 150, calories: 78, protein: 0.4, fats: 0.3, carbs: 21)
        apple.healthKitSampleID = "hk-apple-1"
        let snack = Meal(title: "Snack", date: today, foodItems: [apple])
        context.insert(apple)
        context.insert(snack)
        summary.addMeal(snack)
        try context.save()

        let deletedInfo = summary.removeFoodItem(apple, from: snack, in: context)
        try context.save()

        XCTAssertEqual(deletedInfo?.sampleID, "hk-apple-1")
        XCTAssertEqual(deletedInfo?.calories, 78)
        XCTAssertTrue((summary.meals ?? []).isEmpty)
        let remainingMeals = try context.fetch(FetchDescriptor<Meal>())
        XCTAssertTrue(remainingMeals.isEmpty)
    }

    func testLocalFoodDatabaseSearchSupplementsSparseLocaleUpToLimit() {
        let primary = (1...4).map {
            LocalFoodEntry(id: "pt-\($0)", name: "Frango \($0)", calories: 165, protein: 30, fat: 3, carbs: 0, category: "meat")
        }
        let fallback = (1...10).map {
            LocalFoodEntry(id: "en-\($0)", name: "Frango Style \($0)", calories: 180, protein: 25, fat: 5, carbs: 2, category: "meat")
        }

        let results = LocalFoodDatabaseService.searchEntries(
            primary: primary,
            fallback: fallback,
            query: "frango",
            limit: 10,
            primaryLanguageCode: "pt-PT"
        )
        XCTAssertEqual(results.count, 10)
        XCTAssertEqual(results.prefix(4).map(\.id), ["pt-1", "pt-2", "pt-3", "pt-4"])
    }

    func testCustomRecipeToAIChefRecipeUsesPerServingNutrition() {
        let item1 = FoodItem(name: "Chicken Breast", weight: 300, calories: 480, protein: 90, fats: 10, carbs: 0)
        let item2 = FoodItem(name: "Rice", weight: 200, calories: 260, protein: 6, fats: 2, carbs: 56)
        let custom = CustomRecipe(
            name: "Chicken & Rice",
            info: "Post-workout prep",
            foodItems: [item1, item2],
            cookingTime: 25,
            difficulty: "Medium",
            servings: 2,
            directions: ["Cook rice.", "Grill chicken."]
        )

        let chef = custom.toAIChefRecipe()
        XCTAssertEqual(chef.calories, 370)
        XCTAssertEqual(chef.protein, 48)
        XCTAssertEqual(chef.fat, 6)
        XCTAssertEqual(chef.carbs, 28)
    }

    func testMacroFixSnackIdeaDecodesOptionalMacrosAndLegacyPayload() throws {
        let enrichedJSON = #"""
        {
            "title": "Top up Protein",
            "explanation": "Add a lean snack.",
            "suggestedSnacks": [
                {"name": "Greek Yogurt", "calories": 180, "protein": 18, "fats": 4, "carbs": 12, "weight": 200}
            ]
        }
        """#.data(using: .utf8)!
        let enriched = try JSONDecoder().decode(MacroFixAdviceDTO.self, from: enrichedJSON)
        XCTAssertEqual(enriched.suggestedSnacks.count, 1)
        XCTAssertEqual(enriched.suggestedSnacks[0].fats, 4)
        XCTAssertEqual(enriched.suggestedSnacks[0].carbs, 12)
        XCTAssertEqual(enriched.suggestedSnacks[0].weight, 200.0, accuracy: 0.01)

        let legacyJSON = #"""
        {
            "title": "Light Snack",
            "explanation": "Keep it simple.",
            "suggestedSnacks": [
                {"name": "Boiled Egg", "calories": 75, "protein": 6}
            ]
        }
        """#.data(using: .utf8)!
        let legacy = try JSONDecoder().decode(MacroFixAdviceDTO.self, from: legacyJSON)
        XCTAssertEqual(legacy.suggestedSnacks[0].fats, 0)
        XCTAssertEqual(legacy.suggestedSnacks[0].carbs, 0)
        XCTAssertEqual(legacy.suggestedSnacks[0].weight, 100.0, accuracy: 0.01)
    }

    func testNormalizedWeeklyPlanDaysSortsAndDeduplicatesWeek() throws {
        let meal = AIWeeklyPlanItemDTO(
            title: "Oats",
            type: "Breakfast",
            calories: 350,
            protein: 15,
            carbs: 50,
            fat: 8,
            ingredients: "Oats, milk",
            instructions: "Cook for 5 min.",
            prepTimeMinutes: 5
        )
        let dayDup1 = AIWeeklyPlanDayDTO(dayIndex: 1, totalCalories: 350, totalProtein: 15, totalCarbs: 50, totalFat: 8, meals: [meal])
        let dayDup2 = AIWeeklyPlanDayDTO(dayIndex: 1, totalCalories: 400, totalProtein: 20, totalCarbs: 50, totalFat: 10, meals: [meal])
        let day0 = AIWeeklyPlanDayDTO(dayIndex: 0, totalCalories: 350, totalProtein: 15, totalCarbs: 50, totalFat: 8, meals: [meal])

        let normalized = AINutritionService.normalizedPlanDays([dayDup1, dayDup2, day0])
        XCTAssertEqual(normalized.map(\.dayIndex), [0, 1])
    }

    func testShoppingItemInsertDeduplicatedCaseInsensitive() throws {
        let existing = ShoppingItem(name: "Olive Oil", amount: "1 bottle")
        context.insert(existing)
        try context.save()

        let inserted = ShoppingItem.insertDeduplicated(
            items: [
                (name: " olive oil ", amount: "2 tbsp"),
                (name: "Salmon", amount: "400 g"),
                (name: "SALMON", amount: "400 g")
            ],
            recipeTitle: "Salmon Bowl",
            in: context
        )
        try context.save()

        let all = try context.fetch(FetchDescriptor<ShoppingItem>())
        XCTAssertEqual(inserted, 1)
        XCTAssertEqual(all.count, 2)
        XCTAssertTrue(all.contains { $0.name == "Salmon" && $0.addedFromRecipe == "Salmon Bowl" })
    }

    func testMetabolicTDEEGaugeComputeTDEEDoesNotPreFloorBMRBeforeMultiplier() {
        let user = User(name: "Small", weight: 42, height: 150, age: 30, gender: "Female")
        user.activityMultiplier = 1.4
        // Raw female BMR = 420 + 937.5 - 150 - 161 = 1046.5; 1046.5 * 1.4 = 1465 (not pre-floored at 1200 before multiplier)
        XCTAssertEqual(MetabolicTDEEGaugeView.computeTDEE(for: user, currentWeight: 42), 1465)

        user.activityMultiplier = 1.0
        // Physiological TDEE is Int(1046.5 * 1.0) = 1046; 1200 kcal floor applies to calorie goals, not TDEE.
        XCTAssertEqual(MetabolicTDEEGaugeView.computeTDEE(for: user, currentWeight: 42), 1046)
    }

    func testDeleteLastWeightLogPreservesPositiveUserWeight() throws {
        let user = User(name: "Alex", weight: 78.5, height: 178, age: 29, gender: "Male")
        context.insert(user)
        NutritionMath.recordWeight(76.0, date: Date(), for: user, in: context)

        let logs = try context.fetch(FetchDescriptor<WeightLog>())
        XCTAssertEqual(logs.count, 1)

        NutritionMath.deleteWeightLog(logs[0], for: user, in: context)

        let remainingLogs = try context.fetch(FetchDescriptor<WeightLog>())
        XCTAssertTrue(remainingLogs.isEmpty)
        XCTAssertGreaterThan(user.weight, 0)
        XCTAssertEqual(user.weight, 76.0, accuracy: 0.01)
        XCTAssertNil(DailySummary.fetchExisting(for: Date(), in: context)?.weight)
    }

    @MainActor
    func testWorkoutSyncWidgetAndAppShareAppGroupLastSyncedWaterState() throws {
        let sharedSuite = "WorkoutSyncWidgetAppShare.shared.\(UUID().uuidString)"
        let appSuite = "WorkoutSyncWidgetAppShare.app.\(UUID().uuidString)"
        let sharedDefaults = UserDefaults(suiteName: sharedSuite)!
        let appDefaults = UserDefaults(suiteName: appSuite)!
        defer {
            sharedDefaults.removePersistentDomain(forName: sharedSuite)
            appDefaults.removePersistentDomain(forName: appSuite)
        }

        let today = Calendar.current.startOfDay(for: Date())
        let summary = DailySummary.fetchOrCreate(for: today, in: context)
        let glass = Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: 250)
        context.insert(glass)
        summary.addBeverage(glass)

        // Widget writes via App Group without passing an explicit `localDefaults`.
        WorkoutSyncManager.shared.syncWaterFromWidget(
            totalLiters: 0.25,
            addedMl: 250.0,
            for: today,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: appDefaults
        )

        // Simulate WorkoutTracker resetting today's hydration to 0 in the shared App Group.
        sharedDefaults.set(0.0, forKey: WorkoutSyncManager.waterLitersKey(for: today))

        // Main app reconciles via the same App Group without passing `localDefaults`.
        let mutated = WorkoutSyncManager.shared.reconcileWater(
            for: summary,
            in: context,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: appDefaults
        )
        XCTAssertTrue(mutated)
        XCTAssertEqual(summary.totalHydrationLiters, 0.0, accuracy: 0.001)
        XCTAssertEqual(WorkoutSyncManager.shared.fetchWaterLiters(for: today, sharedDefaults: sharedDefaults) ?? -1, 0.0, accuracy: 0.001)
    }

    @MainActor
    func testPendingWidgetWaterEntriesPreserveIndividualSamplesAndAttachDistinctHealthKitIDs() throws {
        let sharedSuite = "PendingWidgetEntries.shared.\(UUID().uuidString)"
        let appSuite = "PendingWidgetEntries.app.\(UUID().uuidString)"
        let sharedDefaults = UserDefaults(suiteName: sharedSuite)!
        let appDefaults = UserDefaults(suiteName: appSuite)!
        defer {
            sharedDefaults.removePersistentDomain(forName: sharedSuite)
            appDefaults.removePersistentDomain(forName: appSuite)
        }

        let today = Calendar.current.startOfDay(for: Date())
        let summary = DailySummary.fetchOrCreate(for: today, in: context)
        let firstGlass = Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: 250)
        let secondGlass = Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: 250)
        context.insert(firstGlass)
        context.insert(secondGlass)
        summary.addBeverage(firstGlass)
        summary.addBeverage(secondGlass)

        WorkoutSyncManager.shared.syncWaterFromWidget(
            totalLiters: 0.25,
            addedMl: 250.0,
            for: today,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: appDefaults
        )
        WorkoutSyncManager.shared.syncWaterFromWidget(
            totalLiters: 0.50,
            addedMl: 250.0,
            for: today,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: appDefaults
        )

        let entries = WorkoutSyncManager.shared.consumePendingWidgetWaterEntriesLiters(for: today, appGroupDefaults: appDefaults)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0], 0.25, accuracy: 0.001)
        XCTAssertEqual(entries[1], 0.25, accuracy: 0.001)
        XCTAssertTrue(WorkoutSyncManager.shared.consumePendingWidgetWaterEntriesLiters(for: today, appGroupDefaults: appDefaults).isEmpty)

        let id1 = UUID()
        let id2 = UUID()
        XCTAssertTrue(WorkoutSyncManager.attachHealthKitSampleID(id1, volumeLiters: entries[0], to: summary))
        XCTAssertTrue(WorkoutSyncManager.attachHealthKitSampleID(id2, volumeLiters: entries[1], to: summary))
        XCTAssertEqual(firstGlass.healthKitSampleID, id1.uuidString)
        XCTAssertEqual(secondGlass.healthKitSampleID, id2.uuidString)
    }

    func testHomeHealthSyncFlushesTodayEvenWhenViewingPastDateAndSkipsEmptySummary() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let datesViewingPast = HomeDashboardHealthSync.pendingWidgetWaterFlushDates(selectedDate: yesterday, today: today, calendar: calendar)
        XCTAssertEqual(datesViewingPast, [yesterday, today])

        let datesViewingToday = HomeDashboardHealthSync.pendingWidgetWaterFlushDates(selectedDate: today, today: today, calendar: calendar)
        XCTAssertEqual(datesViewingToday, [today])

        XCTAssertFalse(
            HomeDashboardHealthSync.shouldPersistSummary(
                existingSummary: nil,
                workoutCalories: 0,
                activeCaloriesBurned: 0,
                stepsCount: 0,
                sharedWaterLiters: nil,
                pendingWidgetWaterEntriesLiters: []
            )
        )
        XCTAssertTrue(
            HomeDashboardHealthSync.shouldPersistSummary(
                existingSummary: nil,
                workoutCalories: 250,
                activeCaloriesBurned: 250,
                stepsCount: 0,
                sharedWaterLiters: nil,
                pendingWidgetWaterEntriesLiters: []
            )
        )
    }

    @MainActor
    func testWeeklyEnergyBankCalculatorIgnoresEmptyAndOutOfWindowSummaries() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: today)!

        let loggedToday = DailySummary(date: today)
        let meal = Meal(title: "Lunch", date: today, foodItems: [FoodItem(name: "Bowl", weight: 400, calories: 1800, protein: 90, fats: 50, carbs: 200)])
        loggedToday.addMeal(meal)

        let emptyYesterday = DailySummary(date: yesterday)
        let emptyTwoDaysAgo = DailySummary(date: twoDaysAgo)
        let emptyTomorrow = DailySummary(date: tomorrow)

        let oldLogged = DailySummary(date: tenDaysAgo)
        let oldMeal = Meal(title: "Dinner", date: tenDaysAgo, foodItems: [FoodItem(name: "Steak", weight: 300, calories: 1000, protein: 70, fats: 50, carbs: 40)])
        oldLogged.addMeal(oldMeal)

        let result = WeeklyEnergyBankCalculator.calculate(
            summaries: [emptyTomorrow, loggedToday, emptyYesterday, emptyTwoDaysAgo, oldLogged],
            dailyGoal: 2000,
            now: today,
            calendar: calendar
        )
        XCTAssertEqual(result.loggedDaysCount, 1)
        XCTAssertEqual(result.bankBalance, 200)

        let emptyOnly = WeeklyEnergyBankCalculator.calculate(
            summaries: [emptyYesterday, emptyTwoDaysAgo],
            dailyGoal: 2000,
            now: today,
            calendar: calendar
        )
        XCTAssertEqual(emptyOnly.loggedDaysCount, 0)
        XCTAssertEqual(emptyOnly.bankBalance, 0)
    }

    @MainActor
    func testAIWeeklyInsightMetricsIgnoresEmptyBrowsedDaysForWaterAverage() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let d1 = calendar.date(byAdding: .day, value: -1, to: today)!
        let d2 = calendar.date(byAdding: .day, value: -2, to: today)!
        let d3 = calendar.date(byAdding: .day, value: -3, to: today)!

        let activeDay = DailySummary(date: today)
        activeDay.addMeal(Meal(title: "Lunch", date: today, foodItems: [FoodItem(name: "Bowl", weight: 400, calories: 1800, protein: 80, fats: 40, carbs: 210)]))
        activeDay.addBeverage(Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: 2000))

        let empty1 = DailySummary(date: d1)
        let empty2 = DailySummary(date: d2)
        let empty3 = DailySummary(date: d3)

        let metrics = AIWeeklyInsightCalculator.metrics(
            summaries: [activeDay, empty1, empty2, empty3],
            period: .week,
            now: today,
            calendar: calendar
        )
        XCTAssertEqual(metrics.avgCalories, 1800)
        XCTAssertEqual(metrics.avgWater, 2.0, accuracy: 0.001)
    }

    @MainActor
    func testHealthKitManagerIncludesBodyMassAndDeduplicatesRecentPull() {
        XCTAssertTrue(HealthKitManager.readTypeIdentifiers.contains(.bodyMass))
        XCTAssertTrue(HealthKitManager.writeTypeIdentifiers.contains(.bodyMass))

        XCTAssertFalse(
            HealthKitWeightSyncHelper.shouldImportHealthKitWeight(
                latestHKWeightKg: 75.02,
                currentUserWeightKg: 75.0,
                existingSameDayLogWeightKg: nil
            )
        )
        XCTAssertFalse(
            HealthKitWeightSyncHelper.shouldImportHealthKitWeight(
                latestHKWeightKg: 74.5,
                currentUserWeightKg: 76.0,
                existingSameDayLogWeightKg: 74.5
            )
        )
        XCTAssertTrue(
            HealthKitWeightSyncHelper.shouldImportHealthKitWeight(
                latestHKWeightKg: 74.2,
                currentUserWeightKg: 75.0,
                existingSameDayLogWeightKg: nil
            )
        )
        // Stale HK sample older than latest local log must NOT overwrite newer local weight.
        let today = Date()
        let yesterday = today.addingTimeInterval(-86_400)
        XCTAssertFalse(
            HealthKitWeightSyncHelper.shouldImportHealthKitWeight(
                latestHKWeightKg: 78.0,
                currentUserWeightKg: 75.0,
                existingSameDayLogWeightKg: nil,
                latestHKSampleDate: yesterday,
                latestLocalLogDate: today
            )
        )
    }

    @MainActor
    func testMetabolicBlueprintMatchesUserCalculateGoalsAndCapsMacroOverflow() throws {
        let bulkMetrics = OnboardingMetrics(
            age: 25,
            height: 175,
            weight: 70,
            targetWeight: 77,
            goal: "Build Muscle",
            activityLevel: .beast,
            gender: "Male"
        )
        let blueprint = MetabolicBlueprintCalculator.calculate(for: bulkMetrics)
        let user = User(name: "Bulk", weight: 70, height: 175, age: 25, gender: "Male")
        user.activityMultiplier = MetabolicBlueprintCalculator.activityMultiplier(for: .beast)
        user.weightGoalType = "gain"
        user.calculateGoals()
        XCTAssertEqual(user.dailyCaloriesGoal, blueprint.dailyCalories)

        // Heavy user on aggressive cut must not receive macros exceeding target daily calories
        let heavyCut = OnboardingMetrics(
            age: 35,
            height: 170,
            weight: 140,
            targetWeight: 95,
            goal: "Lose Weight",
            activityLevel: .office,
            gender: "Male"
        )
        let cutBlueprint = MetabolicBlueprintCalculator.calculate(for: heavyCut)
        let macroCalories = (cutBlueprint.proteinGrams * 4) + (cutBlueprint.fatGrams * 9) + (cutBlueprint.carbsGrams * 4)
        XCTAssertLessThanOrEqual(macroCalories, cutBlueprint.dailyCalories + 15)
        XCTAssertGreaterThan(cutBlueprint.carbsGrams, 0)
    }

    @MainActor
    func testRemainingMacrosIncludesActiveCaloriesBurned() {
        let user = User(name: "Active", weight: 75, height: 180, age: 28, gender: "Male")
        user.dailyCaloriesGoal = 2000
        let summary = DailySummary(date: Date())
        summary.activeCaloriesBurned = 450
        let meal = Meal(title: "Lunch", date: Date(), foodItems: [
            FoodItem(name: "Pasta", weight: 300, calories: 1800, protein: 60, fats: 40, carbs: 260)
        ])
        summary.addMeal(meal)

        let remaining = NutritionMath.remainingMacros(user: user, summary: summary)
        XCTAssertEqual(remaining.calories, 650)
    }

    @MainActor
    func testDailyXPQuestsEvaluatorAndFinishDayXPDateWindow() {
        let summary = DailySummary(date: Date())
        XCTAssertFalse(DailyXPQuestsEvaluator.isQuestSatisfied(.steps, summary: summary))
        XCTAssertFalse(DailyXPQuestsEvaluator.isQuestSatisfied(.meals, summary: summary))
        XCTAssertFalse(DailyXPQuestsEvaluator.isQuestSatisfied(.water, summary: summary))

        summary.stepsCount = 10_250
        summary.addMeal(Meal(title: "Breakfast", date: Date(), foodItems: [
            FoodItem(name: "Oats", weight: 100, calories: 350, protein: 12, fats: 6, carbs: 60)
        ]))
        summary.addBeverage(Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: 2500))

        XCTAssertTrue(DailyXPQuestsEvaluator.isQuestSatisfied(.steps, summary: summary))
        XCTAssertFalse(DailyXPQuestsEvaluator.isQuestSatisfied(.meals, summary: summary))
        XCTAssertTrue(DailyXPQuestsEvaluator.isQuestSatisfied(.water, summary: summary))

        summary.addMeal(Meal(title: "Lunch", date: Date(), foodItems: [
            FoodItem(name: "Salad", weight: 200, calories: 450, protein: 25, fats: 15, carbs: 40)
        ]))
        summary.addMeal(Meal(title: "Dinner", date: Date(), foodItems: [
            FoodItem(name: "Salmon", weight: 200, calories: 550, protein: 40, fats: 25, carbs: 20)
        ]))
        XCTAssertTrue(DailyXPQuestsEvaluator.isQuestSatisfied(.meals, summary: summary))

        let suite = "FinishDayXPWindow.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: today)!

        XCTAssertFalse(NutritionMath.claimFinishDayXP(for: tenDaysAgo, now: today, defaults: defaults))
        XCTAssertTrue(NutritionMath.claimFinishDayXP(for: yesterday, now: today, defaults: defaults))
        XCTAssertFalse(NutritionMath.claimFinishDayXP(for: yesterday, now: today, defaults: defaults))
        XCTAssertTrue(NutritionMath.claimFinishDayXP(for: today, now: today, defaults: defaults))
    }

    func testMidnightRolloverHelperAdvancesOnlyWhenViewingPreviousToday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        XCTAssertEqual(
            MidnightRolloverHelper.resolvedSelection(
                selectedDate: yesterday,
                previousDayStart: yesterday,
                newDayStart: today,
                calendar: calendar
            ),
            today
        )
        XCTAssertEqual(
            MidnightRolloverHelper.resolvedSelection(
                selectedDate: twoDaysAgo,
                previousDayStart: yesterday,
                newDayStart: today,
                calendar: calendar
            ),
            twoDaysAgo
        )
    }

    func testDataExportServiceUsesPOSIXDateAndEscapesCSVFields() throws {
        XCTAssertEqual(DataExportService.escapeCSVField("Plain"), "Plain")
        XCTAssertEqual(DataExportService.escapeCSVField("Oats, \"Organic\""), "\"Oats, \"\"Organic\"\"\"")

        let summary = DailySummary(date: Date(timeIntervalSince1970: 1_767_225_600)) // 2026-01-01 UTC
        summary.addMeal(Meal(title: "Lunch", date: summary.date, foodItems: [
            FoodItem(name: "Bowl", weight: 300, calories: 550, protein: 32, fats: 18, carbs: 60)
        ]))
        let url = try DataExportService.generateCSV(from: [summary])
        defer { try? FileManager.default.removeItem(at: url) }
        let csv = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(csv.contains("Date,Total Calories (kcal),Total Protein (g),Total Carbs (g),Total Fat (g),Total Meals Logged"))
        XCTAssertTrue(csv.contains(",550,32,60,18,1"))
    }

    @MainActor
    func testWorkoutSyncReconcileWaterDetailReturnsDeletedHealthKitSamples() throws {
        let sharedSuite = "ReconcileDetail.shared.\(UUID().uuidString)"
        let appSuite = "ReconcileDetail.app.\(UUID().uuidString)"
        let sharedDefaults = UserDefaults(suiteName: sharedSuite)!
        let appDefaults = UserDefaults(suiteName: appSuite)!
        defer {
            sharedDefaults.removePersistentDomain(forName: sharedSuite)
            appDefaults.removePersistentDomain(forName: appSuite)
        }

        let today = Calendar.current.startOfDay(for: Date())
        let summary = DailySummary.fetchOrCreate(for: today, in: context)
        let sampleUUID = UUID().uuidString
        let drink = Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: 500)
        drink.healthKitSampleID = sampleUUID
        context.insert(drink)
        summary.addBeverage(drink)

        WorkoutSyncManager.shared.syncWater(0.5, for: today, sharedDefaults: sharedDefaults, appGroupDefaults: appDefaults)
        // WorkoutTracker resets hydration to 0
        sharedDefaults.set(0.0, forKey: WorkoutSyncManager.waterLitersKey(for: today))

        let outcome = WorkoutSyncManager.shared.reconcileWaterWithOutcome(
            for: summary,
            in: context,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: appDefaults
        )
        XCTAssertTrue(outcome.mutated)
        XCTAssertEqual(outcome.deletedHealthKitSamples.count, 1)
        XCTAssertEqual(outcome.deletedHealthKitSamples.first?.sampleID, sampleUUID)
        XCTAssertEqual(outcome.deletedHealthKitSamples.first?.volumeMl ?? 0, 500.0, accuracy: 0.01)
    }

    func testReconcileWaterIgnoresCoffeeAndMergesConcurrentAdditions() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: User.self, DailySummary.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self, configurations: config)
        let context = container.mainContext

        let today = Calendar.current.startOfDay(for: Date())
        let suiteName = "test.water.concurrent.\(UUID().uuidString)"
        let sharedDefaults = UserDefaults(suiteName: suiteName)!
        let syncSuite = "test.water.concurrent.sync.\(UUID().uuidString)"
        let syncDefaults = UserDefaults(suiteName: syncSuite)!
        defer {
            sharedDefaults.removePersistentDomain(forName: suiteName)
            syncDefaults.removePersistentDomain(forName: syncSuite)
        }

        // Baseline: 1.0 L of Water synced; user also drank 250 ml Coffee locally (not pure water).
        let summary = DailySummary(date: today)
        context.insert(summary)
        let baselineWater = Beverage(date: today, name: "Water", icon: "drop.fill", colorHex: "#007AFF", caloriesPerGlass: 0, volumeMl: 1000)
        let coffee = Beverage(date: today, name: "Coffee", icon: "cup.and.saucer.fill", colorHex: "#6F4E37", caloriesPerGlass: 5, volumeMl: 250)
        context.insert(baselineWater)
        context.insert(coffee)
        summary.addBeverage(baselineWater)
        summary.addBeverage(coffee)

        XCTAssertEqual(summary.totalHydrationLiters, 1.25, accuracy: 0.001)
        XCTAssertEqual(summary.totalPureWaterLiters, 1.0, accuracy: 0.001)

        // Last synced water was 1.0 L; concurrently WorkoutTracker added +0.5 L (shared = 1.5 L)
        // AND FoodTracker added +0.25 L Water (local pure water = 1.25 L).
        let localWaterAdd = Beverage(date: today, name: "Water", icon: "drop.fill", colorHex: "#007AFF", caloriesPerGlass: 0, volumeMl: 250)
        context.insert(localWaterAdd)
        summary.addBeverage(localWaterAdd)

        sharedDefaults.set(1.5, forKey: WorkoutSyncManager.waterLitersKey(for: today))
        syncDefaults.set(1.0, forKey: WorkoutSyncManager.lastSyncedWaterKey(for: today))

        let outcome = WorkoutSyncManager.shared.reconcileWaterWithOutcome(
            for: summary,
            in: context,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: syncDefaults,
            localDefaults: syncDefaults
        )

        // Merged pure water must preserve BOTH additions: 1.0 + 0.25 (local) + 0.5 (shared) = 1.75 L.
        XCTAssertTrue(outcome.mutated)
        XCTAssertEqual(summary.totalPureWaterLiters, 1.75, accuracy: 0.01)
        XCTAssertEqual(summary.totalHydrationLiters, 2.0, accuracy: 0.01)
    }

    func testReconcileWaterExternalDecreaseNotBlockedByNonWaterBeverage() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: User.self, DailySummary.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self, configurations: config)
        let context = container.mainContext

        let today = Calendar.current.startOfDay(for: Date())
        let suiteName = "test.water.decrease.\(UUID().uuidString)"
        let sharedDefaults = UserDefaults(suiteName: suiteName)!
        let syncSuite = "test.water.decrease.sync.\(UUID().uuidString)"
        let syncDefaults = UserDefaults(suiteName: syncSuite)!
        defer {
            sharedDefaults.removePersistentDomain(forName: suiteName)
            syncDefaults.removePersistentDomain(forName: syncSuite)
        }

        let summary = DailySummary(date: today)
        context.insert(summary)
        let w1 = Beverage(date: today, name: "Water", icon: "drop.fill", colorHex: "#007AFF", caloriesPerGlass: 0, volumeMl: 500)
        let w2 = Beverage(date: today, name: "Water", icon: "drop.fill", colorHex: "#007AFF", caloriesPerGlass: 0, volumeMl: 500)
        let coffee = Beverage(date: today, name: "Coffee", icon: "cup.and.saucer.fill", colorHex: "#6F4E37", caloriesPerGlass: 5, volumeMl: 250)
        context.insert(w1); context.insert(w2); context.insert(coffee)
        summary.addBeverage(w1); summary.addBeverage(w2); summary.addBeverage(coffee)

        // Previously synced 1.0 L pure water; external WorkoutTracker removed 500 ml -> now 0.5 L.
        sharedDefaults.set(0.5, forKey: WorkoutSyncManager.waterLitersKey(for: today))
        syncDefaults.set(1.0, forKey: WorkoutSyncManager.lastSyncedWaterKey(for: today))

        let outcome = WorkoutSyncManager.shared.reconcileWaterWithOutcome(
            for: summary,
            in: context,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: syncDefaults,
            localDefaults: syncDefaults
        )

        XCTAssertEqual(outcome.mutated, true)
        XCTAssertEqual(summary.totalPureWaterLiters, 0.5, accuracy: 0.01)
        XCTAssertEqual((summary.beverages ?? []).filter { $0.name == "Coffee" }.count, 1)
    }

    func testSharedModelContainerFallbackDirectoryUsesApplicationSupportNotTemporary() throws {
        let resolvedNil = SharedModelContainer.resolvedStoreDirectoryURL(appGroupContainerURL: nil)
        XCTAssertTrue(resolvedNil.didUseFallbackDirectory)
        XCTAssertFalse(resolvedNil.url.path.hasPrefix(FileManager.default.temporaryDirectory.path))
        XCTAssertTrue(resolvedNil.url.path.contains("Application Support"))

        let customGroup = FileManager.default.temporaryDirectory.appendingPathComponent("TestGroupContainer", isDirectory: true)
        let resolvedValid = SharedModelContainer.resolvedStoreDirectoryURL(appGroupContainerURL: customGroup)
        XCTAssertFalse(resolvedValid.didUseFallbackDirectory)
        XCTAssertEqual(resolvedValid.url, customGroup)
    }

    func testReconcileWaterPartialTrimClearsSampleIDAndEmitsReplacementVolume() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: User.self, DailySummary.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self, configurations: config)
        let context = container.mainContext

        let today = Calendar.current.startOfDay(for: Date())
        let suiteName = "test.water.partialtrim.\(UUID().uuidString)"
        let sharedDefaults = UserDefaults(suiteName: suiteName)!
        let syncSuite = "test.water.partialtrim.sync.\(UUID().uuidString)"
        let syncDefaults = UserDefaults(suiteName: syncSuite)!
        defer {
            sharedDefaults.removePersistentDomain(forName: suiteName)
            syncDefaults.removePersistentDomain(forName: syncSuite)
        }

        let summary = DailySummary(date: today)
        context.insert(summary)
        let sampleUUID = UUID().uuidString
        let drink = Beverage(date: today, name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: 500)
        drink.healthKitSampleID = sampleUUID
        context.insert(drink)
        summary.addBeverage(drink)

        // Previously synced 0.5 L; WorkoutTracker decreased to 0.25 L (partial trim of 250 ml).
        sharedDefaults.set(0.25, forKey: WorkoutSyncManager.waterLitersKey(for: today))
        syncDefaults.set(0.5, forKey: WorkoutSyncManager.lastSyncedWaterKey(for: today))

        let outcome = WorkoutSyncManager.shared.reconcileWaterWithOutcome(
            for: summary,
            in: context,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: syncDefaults,
            localDefaults: syncDefaults
        )

        XCTAssertTrue(outcome.mutated)
        XCTAssertNil(drink.healthKitSampleID)
        XCTAssertEqual(drink.volumeMl, 250.0, accuracy: 0.01)
        XCTAssertEqual(outcome.deletedHealthKitSamples.count, 1)
        XCTAssertEqual(outcome.deletedHealthKitSamples.first?.sampleID, sampleUUID)
        XCTAssertEqual(outcome.deletedHealthKitSamples.first?.volumeMl ?? 0, 500.0, accuracy: 0.01)
        XCTAssertEqual(outcome.deletedHealthKitSamples.first?.replacementVolumeMl ?? 0, 250.0, accuracy: 0.01)
        XCTAssertEqual(outcome.deletedHealthKitSamples.first?.beverageID, drink.persistentModelID)
    }

    func testReconcileWaterTagsImportedWorkoutTrackerDrinkAsExternal() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: User.self, DailySummary.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self, configurations: config)
        let context = container.mainContext

        let today = Calendar.current.startOfDay(for: Date())
        let suiteName = "test.water.externaltag.\(UUID().uuidString)"
        let sharedDefaults = UserDefaults(suiteName: suiteName)!
        let syncSuite = "test.water.externaltag.sync.\(UUID().uuidString)"
        let syncDefaults = UserDefaults(suiteName: syncSuite)!
        defer {
            sharedDefaults.removePersistentDomain(forName: suiteName)
            syncDefaults.removePersistentDomain(forName: syncSuite)
        }

        let summary = DailySummary(date: today)
        context.insert(summary)
        sharedDefaults.set(0.5, forKey: WorkoutSyncManager.waterLitersKey(for: today))

        let outcome = WorkoutSyncManager.shared.reconcileWaterWithOutcome(
            for: summary,
            in: context,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: syncDefaults,
            localDefaults: syncDefaults
        )

        XCTAssertTrue(outcome.mutated)
        XCTAssertEqual(summary.beverages?.first?.healthKitSampleID, WorkoutSyncManager.externalWaterSentinelID)
    }
}

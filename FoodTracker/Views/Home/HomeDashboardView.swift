import SwiftUI
import SwiftData

enum MidnightRolloverHelper {
    static func resolvedSelection(
        selectedDate: Date,
        previousDayStart: Date,
        newDayStart: Date,
        calendar: Calendar = .current
    ) -> Date {
        if calendar.isDate(selectedDate, inSameDayAs: previousDayStart) {
            return newDayStart
        }
        return selectedDate
    }

    static func secondsUntilNextMidnight(from now: Date = Date(), calendar: Calendar = .current) -> TimeInterval {
        let startOfToday = calendar.startOfDay(for: now)
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now.addingTimeInterval(86_400)
        return max(1.0, nextMidnight.timeIntervalSince(now) + 1.0)
    }
}

enum HomeDashboardHealthSync {
    static func pendingWidgetWaterFlushDates(
        selectedDate: Date,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [Date] {
        let selectedStart = calendar.startOfDay(for: selectedDate)
        let todayStart = calendar.startOfDay(for: today)
        if calendar.isDate(selectedStart, inSameDayAs: todayStart) {
            return [selectedStart]
        }
        return [selectedStart, todayStart]
    }

    static func shouldPersistSummary(
        existingSummary: DailySummary?,
        workoutCalories: Int,
        activeCaloriesBurned: Int,
        stepsCount: Int,
        sharedWaterLiters: Double?,
        pendingWidgetWaterEntriesLiters: [Double]
    ) -> Bool {
        if existingSummary != nil { return true }
        if workoutCalories > 0 || activeCaloriesBurned > 0 || stepsCount > 0 { return true }
        if let sharedWaterLiters, sharedWaterLiters > 0.01 { return true }
        return pendingWidgetWaterEntriesLiters.contains(where: { $0 > 0 })
    }
}

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
    @Environment(AppStateManager.self) private var appState
    @Query private var users: [User]
    @Query(sort: \DailySummary.date, order: .reverse) private var summaries: [DailySummary]
    @Environment(\.scenePhase) private var scenePhase
    @Binding var selectedDate: Date
    @State private var navigateToProfile = false
    @State private var showDailyLog = false
    @State private var showNoteSheet = false
    @State private var quickAddSheetSlot: IdentifiableString? = nil
    @State private var showingQuickActivitySheet = false
    @State private var selectedMealForDetail: String? = nil
    @State private var showPremiumQuickAdd = false
    @State private var pendingQuickAddAction: PendingQuickAddAction? = nil
    @State private var mealToOpenInSmartAdd: IdentifiableString? = nil

    private enum PendingQuickAddAction {
        case meal(String)
        case activity
    }
    @State private var allTimeCalories: Int = 0
    @State private var showXPPopup = false
    @State private var xpBreakdown: NutritionXPBreakdown? = nil
    @State private var finishDayAlertMessage: String? = nil
    
    @State private var showingScanner = false
    @State private var showingManualAdd = false
    @State private var selectedFoodForDetail: FoodItem? = nil
    @State private var pendingScannerFood: FoodItem? = nil
    @State private var pendingManualEntryAfterScanner = false
    @State private var isMenuExpanded = false
    @State private var lastActiveDayStart: Date = Calendar.current.startOfDay(for: Date())
    @State private var isFetchingHealthData = false
    @State private var pendingHealthFetchDate: Date? = nil

    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
    }

    private var currentUser: User? { users.first }

    private var currentSummary: DailySummary {
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        if let existing = summaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }) {
            return existing
        } else {
            return DailySummary(date: startOfDay)
        }
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
                  // Dynamic Ambient Aurora Background System
                  DynamicAuroraBackgroundView(paletteTrigger: appState.selectedTab, tabTag: 0)
                      .allowsHitTesting(false)

                  // Sync HealthKit & WorkoutTracker whenever selectedDate changes without creating empty DailySummary rows on browse
                  .task(id: selectedDate) {
                      await fetchHealthData(for: selectedDate)
                  }

                  ScrollViewReader { scrollProxy in
                  ScrollView(showsIndicators: false) {
                      VStack(spacing: 24) {
                          HeaderView(selectedDate: selectedDate, user: currentUser, onProfileTap: { navigateToProfile = true }, onShareTap: { shareDailySummary() })
                              .id("header_streak")
                          CalendarCarouselView(selectedDate: $selectedDate)
                          
                          // Quick Spotlight Search Button (Apple HIG HUD)
                          Button(action: {
                              HapticManager.shared.impact(style: .medium)
                              self.quickAddSheetSlot = IdentifiableString(value: suggestedMealSlot())
                          }) {
                              HStack(spacing: 10) {
                                  Image(systemName: "magnifyingglass")
                                      .font(.system(size: 15, weight: .semibold))
                                      .foregroundColor(.secondary)
                                  Text(String(localized: "Search foods, scan meal or barcode..."))
                                      .font(.system(size: 14, weight: .medium, design: .rounded))
                                      .foregroundColor(.secondary)
                                  Spacer()
                                  Image(systemName: "camera.viewfinder")
                                      .font(.system(size: 16, weight: .semibold))
                                      .foregroundColor(EditorialPalette.inkPrimary)
                              }
                              .padding(.horizontal, 16)
                              .padding(.vertical, 12)
                              .background(EditorialPalette.surfaceLight)
                              .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                              .overlay(
                                  RoundedRectangle(cornerRadius: 16, style: .continuous)
                                      .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
                              )
                          }
                          .buttonStyle(BounceButtonStyle())
                          .accessibilityIdentifier("home_spotlight_search_button")
                          .padding(.horizontal, 20)
                          InsightsWidget(summary: currentSummary, user: currentUser)

                          DynamicEnergyDashboard(summary: currentSummary, summaries: summaries, user: currentUser)
                              .id("macro_rings")
                              .spotlightTarget(step: .macroRings)
                              .padding(.bottom, 8)

                          VStack(spacing: 16) {
                              HStack {
                                  Text("Nutrition")
                                      .font(.title2).bold()
                                      .foregroundStyle(EditorialPalette.inkPrimary)
                                  Spacer()
                                  Button(action: {
                                      HapticManager.shared.impact(style: .medium)
                                      showDailyLog = true
                                  }) {
                                      HStack(spacing: 5) {
                                          Image(systemName: "list.bullet.clipboard")
                                              .font(.system(size: 12, weight: .semibold))
                                          Text("Daily Log")
                                      }
                                      .font(.system(size: 13, weight: .semibold, design: .rounded))
                                      .foregroundStyle(EditorialPalette.inkPrimary)
                                      .padding(.horizontal, 11)
                                      .padding(.vertical, 6)
                                      .background(EditorialPalette.surfaceLight)
                                      .clipShape(Capsule())
                                      .overlay(
                                          Capsule().strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
                                      )
                                  }
                              }
                              .padding(.horizontal, 20)

                              ForEach(["Breakfast", "Lunch", "Snack", "Dinner"], id: \.self) { mealType in
                                  let canonicalType = DailySummary.canonicalMealSlot(mealType)
                                  let meal = (currentSummary.meals ?? []).first(where: { DailySummary.canonicalMealSlot($0.title) == canonicalType })

                                  BentoMealCardView(
                                      title: localizedMealType(mealType),
                                      calories: meal?.totalCalories,
                                      recommendedCalories: getRecommendedCalories(for: mealType),
                                      protein: meal?.totalProtein,
                                      fats: meal?.totalFats,
                                      carbs: meal?.totalCarbs,
                                      time: meal?.date,
                                      foodItems: meal?.foodItems,
                                      quickAddSlot: mealType,
                                      onCardTap: { self.selectedMealForDetail = mealType },
                                      onQuickAdd: { self.quickAddSheetSlot = IdentifiableString(value: mealType) }
                                  )
                              }
                              .padding(.horizontal)
                          }

                          HydrationFlaskCardView(summary: currentSummary)
                              .id("hydration_card")
                              .spotlightTarget(step: .fastingWater)
                              .padding(.horizontal)
                          WeightTrackerCardView(summary: currentSummary).padding(.horizontal)

                          DailyNoteCard(summary: currentSummary) {
                              showNoteSheet = true
                          }
                          
                          // All-Time Calories Tracked (Tactile Fridge Ledger Sticker)
                          FridgeLedgerStickerView(totalCalories: allTimeCalories)
                              .padding(.top, 8)
                      }
                      .padding(.bottom, 120) // Оставили место для плавающей кнопки
                  }
                  .blur(radius: isMenuExpanded ? 4 : 0)
                  .disabled(isMenuExpanded)
                  .onAppear {
                      handleWidgetScrollIfNeeded(with: scrollProxy)
                      if SpotlightTourManager.shared.isTourActive {
                          handleSpotlightScroll(to: SpotlightTourManager.shared.currentStep, with: scrollProxy)
                      }
                  }
                  .onChange(of: appState.requestedWidgetAction) { _, _ in
                      handleWidgetScrollIfNeeded(with: scrollProxy)
                  }
                  .onChange(of: SpotlightTourManager.shared.isTourActive) { _, isActive in
                      if isActive {
                          handleSpotlightScroll(to: SpotlightTourManager.shared.currentStep, with: scrollProxy)
                      }
                  }
                  .onChange(of: SpotlightTourManager.shared.currentStep) { _, newStep in
                      guard SpotlightTourManager.shared.isTourActive else { return }
                      handleSpotlightScroll(to: newStep, with: scrollProxy)
                  }
                  } // ScrollViewReader
                  
                  if isMenuExpanded {
                      Color.black.opacity(0.25)
                          .ignoresSafeArea()
                          .onTapGesture {
                              withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                  isMenuExpanded = false
                              }
                          }
                          .transition(.opacity)
                      
                      VStack(spacing: 14) {
                          SpeedDialItem(
                              icon: "barcode.viewfinder",
                              label: String(localized: "Scan Barcode"),
                              color: EditorialPalette.oceanSlate,
                              accessibilityId: "speed_dial_scan_barcode"
                          ) {
                              isMenuExpanded = false
                              showingScanner = true
                          }
                          
                          SpeedDialItem(
                              icon: "fork.knife",
                              label: String(localized: "Log Meal"),
                              color: EditorialPalette.oat,
                              iconForeground: EditorialPalette.textOnOat,
                              accessibilityId: "speed_dial_log_meal"
                          ) {
                              isMenuExpanded = false
                              self.mealToOpenInSmartAdd = IdentifiableString(value: "Breakfast")
                          }
                          
                          SpeedDialItem(
                              icon: "bolt.fill",
                              label: String(localized: "Quick Calories"),
                              color: EditorialPalette.warmAmber,
                              iconForeground: EditorialPalette.textOnOat
                          ) {
                              isMenuExpanded = false
                              showPremiumQuickAdd = true
                          }
                          
                          SpeedDialItem(
                              icon: "figure.run",
                              label: String(localized: "Log Activity"),
                              color: EditorialPalette.emerald
                          ) {
                              isMenuExpanded = false
                              showingQuickActivitySheet = true
                          }
                      }
                      .transition(.asymmetric(
                          insertion: .scale.combined(with: .offset(y: 50)).combined(with: .opacity),
                          removal: .scale.combined(with: .offset(y: 50)).combined(with: .opacity)
                      ))
                      .padding(.trailing, 24)
                      .padding(.bottom, 100)
                      .zIndex(99)
                  }
                  
                  // ПЛАВАЮЩАЯ КНОПКА QUICK ADD (ПЕРЕНЕСЕНА СЮДА)
                  Button(action: {
                      HapticManager.shared.impact(style: .medium)
                      withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                          isMenuExpanded.toggle()
                      }
                  }) {
                      Image(systemName: "plus")
                          .font(.system(size: 24, weight: .bold))
                          .foregroundColor(EditorialPalette.oat)
                          .frame(width: 62, height: 62)
                          .background(EditorialPalette.cardDark)
                          .clipShape(Circle())
                          .overlay(
                              Circle()
                                  .strokeBorder(EditorialPalette.cardBorderDarkFocused, lineWidth: 1)
                          )
                          .rotationEffect(.degrees(isMenuExpanded ? 135 : 0))
                          .shadow(color: Color.black.opacity(0.24), radius: 12, y: 6)
                  }
                  .spotlightTarget(step: .addMeal)
                  .accessibilityIdentifier("home_quick_add_fab")
                  .padding(.trailing, 24)
                  .padding(.bottom, 24)
                  .zIndex(100)
                  
                  if showXPPopup, let breakdown = xpBreakdown {
                      ParticleConfettiBurstView(xpEarned: breakdown.totalXP) {
                          withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                              showXPPopup = false
                          }
                      }
                      .transition(.opacity.combined(with: .scale))
                      .zIndex(100)
                  }
              }
              .navigationBarHidden(true)
              .alert(
                  "Daily Summary",
                  isPresented: Binding(
                      get: { finishDayAlertMessage != nil },
                      set: { if !$0 { finishDayAlertMessage = nil } }
                  )
              ) {
                  Button("OK", role: .cancel) { finishDayAlertMessage = nil }
              } message: {
                  Text(finishDayAlertMessage ?? "")
              }
              .onAppear {
                  TrackingManager.shared.track(.appOpened(source: "home_dashboard"))
                  Task { allTimeCalories = (try? await di.summaryRepository.fetchAllTimeCalories()) ?? 0 }
                  syncStreakAndAchievements()
              }
              .onChange(of: currentSummary.totalCalories) { _, _ in
                  syncStreakAndAchievements()
                  Task { allTimeCalories = (try? await di.summaryRepository.fetchAllTimeCalories()) ?? 0 }
              }
              .onChange(of: summaries.count) { _, _ in
                  syncStreakAndAchievements()
              }
              .onChange(of: currentSummary.totalPureWaterLiters) { _, _ in
                  syncStreakAndAchievements()
              }
              .onChange(of: scenePhase) { _, newPhase in
                  if newPhase == .active {
                      let todayStart = Calendar.current.startOfDay(for: Date())
                      if todayStart != lastActiveDayStart {
                          selectedDate = MidnightRolloverHelper.resolvedSelection(
                              selectedDate: selectedDate,
                              previousDayStart: lastActiveDayStart,
                              newDayStart: todayStart
                          )
                          lastActiveDayStart = todayStart
                      }
                      syncStreakAndAchievements()
                      Task { await fetchHealthData(for: selectedDate) }
                  }
              }
              .task(id: lastActiveDayStart) {
                  let delay = MidnightRolloverHelper.secondsUntilNextMidnight()
                  try? await Task.sleep(for: .seconds(delay))
                  guard !Task.isCancelled else { return }
                  let freshStart = Calendar.current.startOfDay(for: Date())
                  if freshStart != lastActiveDayStart {
                      selectedDate = MidnightRolloverHelper.resolvedSelection(
                          selectedDate: selectedDate,
                          previousDayStart: lastActiveDayStart,
                          newDayStart: freshStart
                      )
                      lastActiveDayStart = freshStart
                      await fetchHealthData(for: selectedDate)
                  }
              }
              .onChange(of: HealthKitManager.shared.isAuthorized) { _, isAuth in
                  if isAuth {
                      Task { await fetchHealthData(for: selectedDate) }
                  }
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
                      .presentationDetents([.fraction(0.65), .large])
                      .presentationCornerRadius(32)
                      .presentationDragIndicator(.visible)
              }
              .sheet(item: $quickAddSheetSlot) { slot in
                  MealHUDQuickLogSheet(selectedDate: selectedDate, initialMealType: slot.value)
                      .presentationDetents([.fraction(0.85), .large])
                      .presentationCornerRadius(32)
                      .presentationDragIndicator(.hidden)
              }
              .sheet(isPresented: $showPremiumQuickAdd, onDismiss: {
                  guard let action = pendingQuickAddAction else { return }
                  pendingQuickAddAction = nil
                  switch action {
                  case .meal(let selectedMeal):
                      self.mealToOpenInSmartAdd = IdentifiableString(value: selectedMeal)
                  case .activity:
                      self.showingQuickActivitySheet = true
                  }
              }) {
                  PremiumQuickAddSheet(selectedDate: selectedDate, onSelectDetailedMeal: { selectedMeal in
                      self.pendingQuickAddAction = .meal(selectedMeal)
                  }, onSelectActivity: {
                      self.pendingQuickAddAction = .activity
                  })
                  .presentationDetents([.fraction(0.82), .large])
                  .presentationCornerRadius(32)
                  .presentationDragIndicator(.visible)
              }
              .onChange(of: appState.spotlightTourRestartToken) { _, newToken in
                  guard newToken > 0 else { return }
                  navigateToProfile = false
                  showDailyLog = false
                  showPremiumQuickAdd = false
                  Task { @MainActor in
                      try? await Task.sleep(for: .milliseconds(320))
                      SpotlightTourManager.shared.resetTour()
                  }
              }
              .sheet(isPresented: $showingQuickActivitySheet) {
                  QuickActivityAddView(summary: currentSummary)
                      .presentationDetents([.fraction(0.85), .large])
                      .presentationCornerRadius(32)
              }
              .fullScreenCover(item: $mealToOpenInSmartAdd) { mealInfo in
                  AddMealView(selectedDate: selectedDate, initialMealType: mealInfo.value)
              }
              .fullScreenCover(
                  isPresented: $showingScanner,
                  onDismiss: {
                      if let pendingFood = pendingScannerFood {
                          pendingScannerFood = nil
                          selectedFoodForDetail = pendingFood
                      } else if pendingManualEntryAfterScanner {
                          pendingManualEntryAfterScanner = false
                          showingManualAdd = true
                      }
                  }
              ) {
                  // Guideline 5.1.3(i): Menu AI prompt budget excludes HealthKit activeCaloriesBurned.
                  let aiRemaining = NutritionMath.aiSafeRemainingMacros(user: currentUser, summary: currentSummary)
                  SmartScannerView(
                      onProductFound: { foundFood in pendingScannerFood = foundFood },
                      onManualEntryRequest: { pendingManualEntryAfterScanner = true },
                      remainingCalories: aiRemaining.calories,
                      remainingProtein: aiRemaining.protein
                  )
              }
              .fullScreenCover(item: $selectedFoodForDetail) { food in
                  FoodDetailNutritionView(food: food, mealTitle: "Snack") { addedFood in
                      addFoodsToMeal(title: "Snack", items: [addedFood])
                  }
              }
              .sheet(isPresented: $showingManualAdd) {
                  AddIngredientModalView { newCustomItem in
                      addFoodsToMeal(title: "Snack", items: [newCustomItem])
                  }
                  .presentationDetents([.fraction(0.85), .large])
                  .presentationCornerRadius(32)
                  .presentationDragIndicator(.visible)
              }
          }
      }

    @MainActor
    private func fetchHealthData(for targetDateInput: Date) async {
        // Serialize concurrent health sync triggers so queued widget water entries are never double-flushed.
        if isFetchingHealthData {
            pendingHealthFetchDate = targetDateInput
            return
        }
        isFetchingHealthData = true
        defer { isFetchingHealthData = false }

        var nextDate: Date? = targetDateInput
        while let currentTarget = nextDate {
            pendingHealthFetchDate = nil
            await performFetchHealthData(for: currentTarget)
            nextDate = pendingHealthFetchDate
        }
    }

    @MainActor
    private func performFetchHealthData(for targetDateInput: Date) async {
            let targetDate = Calendar.current.startOfDay(for: targetDateInput)
            let isHKEnabled = currentUser?.isHealthKitEnabled == true

            // Flush any queued widget hydration deletions/additions as distinct HealthKit operations.
            var selectedDayPendingEntries: [Double] = []
            if isHKEnabled {
                let pendingDeletions = WorkoutSyncManager.shared.consumePendingWidgetWaterDeletions(for: targetDate)
                for deletion in pendingDeletions {
                    await HealthKitManager.shared.deleteWaterSample(
                        idString: deletion.sampleID,
                        litersFallback: deletion.volumeMl / 1000.0,
                        date: deletion.date
                    )
                }

                let flushDates = WorkoutSyncManager.shared.allPendingWidgetWaterFlushDates(selectedDate: targetDate)
                for flushDate in flushDates {
                    let entries = WorkoutSyncManager.shared.peekPendingWidgetWaterEntriesLiters(for: flushDate)
                    if Calendar.current.isDate(flushDate, inSameDayAs: targetDate) {
                        selectedDayPendingEntries = entries
                    }
                    guard !entries.isEmpty else { continue }
                    SharedModelContainer.refreshMainContext(context)
                    let flushSummary = DailySummary.fetchOrCreate(for: flushDate, in: context)
                    let sampleDate = Calendar.current.isDateInToday(flushDate) ? Date() : flushDate
                    var attachedAny = false
                    var syncedIndices: Set<Int> = []
                    for (idx, entryLiters) in entries.enumerated() {
                        guard !Task.isCancelled else { break }
                        if let sampleUUID = await HealthKitManager.shared.saveWater(liters: entryLiters, date: sampleDate) {
                            syncedIndices.insert(idx)
                            if WorkoutSyncManager.attachHealthKitSampleID(sampleUUID, volumeLiters: entryLiters, to: flushSummary) {
                                attachedAny = true
                            }
                        }
                    }
                    if !syncedIndices.isEmpty {
                        WorkoutSyncManager.shared.acknowledgePendingWidgetWaterEntries(
                            syncedIndices: syncedIndices,
                            for: flushDate
                        )
                        if attachedAny {
                            try? context.save()
                        }
                    }
                }
            } else {
                WorkoutSyncManager.shared.clearPendingWidgetWaterQueues()
            }

            let existingSummary = DailySummary.fetchExisting(for: targetDate, in: context)
            let wtAppGroupCals = WorkoutSyncManager.shared.fetchWorkoutCalories(for: targetDate)
            let sharedWater = WorkoutSyncManager.shared.fetchWaterLiters(for: targetDate)
            let localCals = existingSummary?.localActivityCalories ?? 0

            var fetchedSteps = existingSummary?.stepsCount ?? 0
            var hkTotalActiveCals = existingSummary?.activeCaloriesBurned ?? 0
            var hkWorkoutBreakdown = HealthKitManager.ExternalWorkoutCaloriesBreakdown(
                workoutTrackerCalories: 0,
                otherExternalCalories: 0
            )

            if isHKEnabled {
                do {
                    fetchedSteps = try await HealthKitManager.shared.fetchSteps(for: targetDate)
                } catch {
                    #if DEBUG
                    print("Steps error: \(error)")
                    #endif
                }

                do {
                    hkTotalActiveCals = try await HealthKitManager.shared.fetchTotalActiveCalories(for: targetDate)
                } catch {
                    #if DEBUG
                    print("Health cals error: \(error)")
                    #endif
                }

                do {
                    hkWorkoutBreakdown = try await HealthKitManager.shared.fetchExternalWorkoutBreakdown(for: targetDate)
                } catch {
                    #if DEBUG
                    print("HK workout cals error: \(error)")
                    #endif
                }

                if Calendar.current.isDateInToday(targetDate),
                   let hkSample = try? await HealthKitManager.shared.fetchLatestBodyMassSample() {
                    if let user = currentUser {
                        let existingLogs = (try? context.fetch(FetchDescriptor<WeightLog>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
                        let sameDayLog = existingLogs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: targetDate) })
                        if HealthKitWeightSyncHelper.shouldImportHealthKitWeight(
                            latestHKWeightKg: hkSample.kg,
                            currentUserWeightKg: user.weight,
                            existingSameDayLogWeightKg: sameDayLog?.weight,
                            latestHKSampleDate: hkSample.date,
                            latestLocalLogDate: existingLogs.first?.date
                        ) {
                            // Record HealthKit body mass on its original sample date without silently
                            // overwriting user-set calorie/macro targets (Guideline 5.1.3(i): prevents
                            // HealthKit-derived values from flowing into third-party AI prompts).
                            NutritionMath.recordWeight(
                                hkSample.kg,
                                date: hkSample.date,
                                for: user,
                                in: context,
                                recalculateUserGoals: false,
                                syncToHealthKit: false
                            )
                        }
                    }
                }
            }

            let reconciled = WorkoutSyncManager.computeDailyBurn(
                localActivityCalories: localCals,
                workoutTrackerCalories: wtAppGroupCals,
                healthKitWorkoutCalories: hkWorkoutBreakdown.workoutTrackerCalories,
                otherExternalWorkoutCalories: hkWorkoutBreakdown.otherExternalCalories,
                healthKitTotalActiveCalories: hkTotalActiveCals,
                stepsCount: fetchedSteps,
                isHealthKitEnabled: isHKEnabled
            )

            let shouldPersist = HomeDashboardHealthSync.shouldPersistSummary(
                existingSummary: existingSummary,
                workoutCalories: reconciled.workoutCalories,
                activeCaloriesBurned: reconciled.activeCaloriesBurned,
                stepsCount: reconciled.stepsCount,
                sharedWaterLiters: sharedWater,
                pendingWidgetWaterEntriesLiters: selectedDayPendingEntries
            )
            guard shouldPersist else { return }

            let persistedSummary = existingSummary ?? DailySummary.fetchOrCreate(for: targetDate, in: context)
            let waterOutcome = WorkoutSyncManager.shared.reconcileWaterWithOutcome(for: persistedSummary, in: context)
            var needsSave = waterOutcome.mutated

            if isHKEnabled && !waterOutcome.deletedHealthKitSamples.isEmpty {
                let deletedSamples = waterOutcome.deletedHealthKitSamples
                let container = context.container
                Task { @MainActor in
                    await WorkoutSyncManager.shared.syncHealthKitWaterChanges(
                        deletedSamples: deletedSamples,
                        logDate: targetDate,
                        summaryDate: targetDate,
                        summary: persistedSummary,
                        container: container
                    )
                }
            }

            if persistedSummary.workoutCalories != reconciled.workoutCalories {
                persistedSummary.workoutCalories = reconciled.workoutCalories
                needsSave = true
            }

            if persistedSummary.stepsCount != reconciled.stepsCount {
                persistedSummary.stepsCount = reconciled.stepsCount
                needsSave = true
            }

            if persistedSummary.activeCaloriesBurned != reconciled.activeCaloriesBurned {
                persistedSummary.activeCaloriesBurned = reconciled.activeCaloriesBurned
                needsSave = true
            }

            if needsSave {
                try? context.save()
                WidgetReloader.reloadAll()
            }
        }
    private func addFoodsToMeal(title: String, items: [FoodItem]) {
        let canonicalTitle = NutritionMath.canonicalMealType(title)
        let summary = DailySummary.fetchOrCreate(for: selectedDate, in: context)
        let mealTimestamp = Calendar.current.isDateInToday(selectedDate) ? Date.now : Calendar.current.startOfDay(for: selectedDate)
        var newFoodItems: [FoodItem] = []

        for item in items {
            let copiedItem = DailySummary.duplicateFoodItem(item)
            context.insert(copiedItem)
            newFoodItems.append(copiedItem)
        }

        if let existingMeal = (summary.meals ?? []).first(where: { DailySummary.canonicalMealSlot($0.title) == canonicalTitle }) {
            existingMeal.addFoodItems(newFoodItems)
            existingMeal.date = mealTimestamp
        } else {
            let newMeal = Meal(title: canonicalTitle, date: mealTimestamp, foodItems: newFoodItems)
            context.insert(newMeal)
            summary.addMeal(newMeal)
        }

        try? context.save()
        WidgetReloader.reloadAll()
        AppReviewManager.shared.userDidLogMeal()
        
        let addedCals = newFoodItems.reduce(0) { $0 + $1.calories }
        TrackingManager.shared.track(.mealLogged(mealType: canonicalTitle, totalCalories: addedCals))
        if currentUser?.isHealthKitEnabled == true {
            let itemsToSync = newFoodItems.filter { $0.calories > 0 }
            let container = context.container
            Task { @MainActor in
                for item in itemsToSync {
                    if let uuid = await HealthKitManager.shared.saveDietaryEnergy(calories: item.calories, date: mealTimestamp) {
                        item.healthKitSampleID = uuid.uuidString
                    }
                }
                if !itemsToSync.isEmpty {
                    try? container.mainContext.save()
                }
            }
        }
    }
    
    private func shareDailySummary() {
        let card = MealShareCard(summary: currentSummary)
        ShareSheetManager.renderAndShare(view: card, title: "My Nutrition Day")
    }

    private func syncStreakAndAchievements() {
        guard let user = currentUser else { return }
        NutritionMath.syncStreakAndAchievements(for: user, summaries: summaries)
        if context.hasChanges {
            try? context.save()
        }
    }

    private func handleWidgetScrollIfNeeded(with proxy: ScrollViewProxy) {
        guard let action = appState.requestedWidgetAction else { return }
        switch action {
        case "home":
            appState.requestedWidgetAction = nil
            selectedDate = Calendar.current.startOfDay(for: Date())
        case "hydration":
            appState.requestedWidgetAction = nil
            selectedDate = Calendar.current.startOfDay(for: Date())
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                proxy.scrollTo("hydration_card", anchor: .center)
            }
        case "macros":
            appState.requestedWidgetAction = nil
            selectedDate = Calendar.current.startOfDay(for: Date())
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                proxy.scrollTo("macro_rings", anchor: .center)
            }
        default:
            break
        }
    }

    private func suggestedMealSlot(for date: Date = .now) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<11: return "Breakfast"
        case 11..<16: return "Lunch"
        case 16..<21: return "Dinner"
        default: return "Snack"
        }
    }

    private func handleSpotlightScroll(to step: SpotlightStep, with proxy: ScrollViewProxy) {
        guard let anchor = step.homeScrollAnchorID else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
            proxy.scrollTo(anchor, anchor: .top)
        }
    }
    
    private func finishDayAndCalculateXP() {
        guard currentSummary.totalCalories > 0 else {
            HapticManager.shared.notification(type: .warning)
            finishDayAlertMessage = String(localized: "Log at least one meal before finishing the day.")
            return
        }
        guard let user = currentUser else { return }
        guard NutritionMath.claimFinishDayXP(for: selectedDate) else {
            HapticManager.shared.impact(style: .light)
            let isEligibleWindow = Calendar.current.isDateInToday(selectedDate) || Calendar.current.isDateInYesterday(selectedDate)
            finishDayAlertMessage = isEligibleWindow
                ? String(localized: "Daily XP has already been claimed for this date.")
                : String(localized: "Daily XP can only be claimed for today or yesterday.")
            return
        }

        HapticManager.shared.impact(style: .medium)
        let breakdown = NutritionMath.finishDayXP(for: currentSummary, user: user)
        xpBreakdown = breakdown
        showXPPopup = true

        let manager = NutritionProgressManager(user: user)
        manager.addXP(from: breakdown)
        try? context.save()
    }
}

struct HeaderView: View {
    let selectedDate: Date
    let user: User?
    var onProfileTap: () -> Void
    var onShareTap: () -> Void

    private var greetingString: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = user?.name ?? String(localized: "Friend")

        switch hour {
        case 5..<12:
            return String(localized: "Good morning, \(name)! 🌅")
        case 12..<18:
            return String(localized: "Good afternoon, \(name)! 🥗")
        case 18..<23:
            return String(localized: "Good evening, \(name)! 🌙")
        default:
            return String(localized: "Hello, \(name)! 🌌")
        }
    }

    private static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = .current
        return formatter
    }()

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = .current
        return formatter
    }()

    private var relativeDateString: String {
        let calendar = Calendar.current
        let relativeDay: String
        if calendar.isDateInToday(selectedDate) {
            relativeDay = String(localized: "Today")
        } else if calendar.isDateInYesterday(selectedDate) {
            relativeDay = String(localized: "Yesterday")
        } else {
            relativeDay = Self.mediumDateFormatter.string(from: selectedDate)
        }

        let monthString = Self.monthYearFormatter.string(from: selectedDate)
        return "\(relativeDay) • \(monthString)"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingString)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                HStack(spacing: 8) {
                    Text(relativeDateString)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.textGray)
                    
                    StreakFireBadgeView(streakDays: user?.streakDays ?? 0)
                        .spotlightTarget(step: .streakFire)
                }
            }
            Spacer()

            HStack(spacing: 12) {
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    onShareTap()
                }) {
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(
                            LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: Color.themePink.opacity(0.25), radius: 5, y: 2)
                }
                .buttonStyle(BounceButtonStyle())

                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    onProfileTap()
                }) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(
                            LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: Color.themePink.opacity(0.25), radius: 5, y: 2)
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
            return (String(localized: "Good morning! Ready to crush your goals?"), "sun.max.fill", .themeDarkYellow)
        } else if remaining < 0 {
            return (String(localized: "Slightly over limit, but tomorrow is a new day!"), "exclamationmark.circle.fill", .red)
        } else if summary.totalProtein < (user?.targetProtein ?? 150) * 0.3 && summary.totalCalories > 600 {
            return (String(localized: "Great start! Try adding more protein to your next meal."), "bolt.fill", .themePeach)
        } else if summary.totalPureWaterLiters < 1.0 && summary.totalCalories > 1000 {
            return (String(localized: "Don't forget to drink water to stay hydrated!"), "drop.fill", .drinkWater)
        } else {
            return (String(localized: "You're on track! Keep up the great work."), "star.fill", .themePink)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var summaries: [DailySummary]
    @Query private var users: [User]

    let title: String
    let date: Date

    init(title: String, date: Date) {
        self.title = title
        self.date = date
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86_400)
        let predicate = #Predicate<DailySummary> { $0.date >= startOfDay && $0.date < endOfDay }
        self._summaries = Query(filter: predicate)
    }

    @State private var selectedFoodForDetail: FoodItem? = nil
    @State private var showingAddFood = false
    @State private var isGeneratingRecipe = false
    @State private var generatedRecipe: AIChefRecipe? = nil
    @State private var recipeGenerationError: String? = nil
    @State private var showingRecipeError = false
    @State private var pendingRecipeMeal: Meal? = nil
    @State private var showAIConsentSheet = false
    @State private var copiedFeedbackText: String? = nil
    @Environment(DIContainer.self) private var di

    private var meal: Meal? {
        let canonical = DailySummary.canonicalMealSlot(title)
        return summaries.first?.meals?.first { DailySummary.canonicalMealSlot($0.title) == canonical }
    }

    private func deleteFoodItem(_ food: FoodItem) {
        guard let summary = summaries.first, let meal = meal else { return }
        let shouldSyncHK = users.first?.isHealthKitEnabled == true
        let logDate = meal.date
        var deletedInfo: DailySummary.DeletedFoodHealthSample?
        withAnimation {
            deletedInfo = summary.removeFoodItem(food, from: meal, in: context)
            try? context.save()
            WidgetReloader.reloadAll()
        }
        if shouldSyncHK, let deletedInfo {
            Task {
                await HealthKitManager.shared.deleteDietaryEnergySample(
                    idString: deletedInfo.sampleID,
                    caloriesFallback: deletedInfo.calories,
                    date: logDate
                )
            }
        }
    }
    
    private func generateRecipe(from meal: Meal) {
        guard AIPhotoConsentManager.shared.hasConsented else {
            pendingRecipeMeal = meal
            showAIConsentSheet = true
            return
        }
        let mealName = title
        let ingredients = (meal.foodItems ?? []).map { $0.name }
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
                        fat: dto.fat,
                        carbs: dto.carbs,
                        heroImage: "fork.knife",
                        cookTime: dto.cookTime,
                        difficulty: dto.difficulty,
                        history: dto.history,
                        ingredients: dto.ingredients,
                        steps: dto.steps.map { RecipeStep(instruction: $0.instruction, imageName: "", aiTip: $0.aiTip) },
                        platingTip: dto.platingTip
                    )
                } else {
                    HapticManager.shared.notification(type: .error)
                    self.recipeGenerationError = GeminiProxyClient.consumeRateLimitAlertMessage()
                        ?? String(localized: "AI Chef needs a break! Please check your connection and try again.")
                    self.showingRecipeError = true
                }
            }
        }
    }

    var body: some View {
        let slotAccent = EditorialMealTheme.accentColor(for: title)
        let coverName = EditorialMealTheme.coverImageName(for: title)

        ZStack {
            DynamicAuroraBackgroundView(pinnedPaletteIndex: EditorialMealTheme.paletteIndex(for: title))
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Editorial Navigation Bar
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(EditorialPalette.inkPrimary)
                                .frame(width: 42, height: 42)
                                .background(Color.white.opacity(0.84))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
                                )
                        }
                        Spacer()
                        if let meal, !(meal.foodItems ?? []).isEmpty {
                            Menu {
                                Button {
                                    copyCurrentMeal(meal, to: Date())
                                } label: {
                                    Label("Copy to Today", systemImage: "doc.on.doc")
                                }
                                if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) {
                                    Button {
                                        copyCurrentMeal(meal, to: tomorrow)
                                    } label: {
                                        Label("Copy to Tomorrow", systemImage: "calendar.badge.plus")
                                    }
                                }
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(EditorialPalette.inkPrimary)
                                    .frame(width: 42, height: 42)
                                    .background(Color.white.opacity(0.84))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
                                    )
                            }
                            .accessibilityLabel("Copy Meal")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    if let copiedFeedbackText {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text(copiedFeedbackText)
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(EditorialPalette.emerald)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(EditorialPalette.cardDark)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(EditorialPalette.emerald.opacity(0.35), lineWidth: 1)
                        )
                    }

                    // Editorial Photographic Meal Telemetry Hero
                    EditorialPhotoBackdropCard(
                        imageName: coverName,
                        minHeight: (meal?.foodItems?.isEmpty == false) ? 236 : 172,
                        cornerRadius: 24,
                        scrimBottomOpacity: 0.92,
                        alignment: .topLeading
                    ) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: EditorialMealTheme.symbolName(for: title))
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(slotAccent)
                                    Text(LocalizedStringKey(title))
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(EditorialPalette.chipDark.opacity(0.88))
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75))

                                Spacer()

                                if let mealDate = meal?.date, !(meal?.foodItems ?? []).isEmpty {
                                    HStack(spacing: 5) {
                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 10, weight: .semibold))
                                        Text("Logged at \(mealDate.formatted(date: .omitted, time: .shortened))")
                                    }
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(EditorialPalette.oat)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(EditorialPalette.chipDark.opacity(0.82))
                                    .clipShape(Capsule())
                                }
                            }

                            Spacer(minLength: 8)

                            if let meal = meal, let items = meal.foodItems, !items.isEmpty {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("\(meal.totalCalories)")
                                        .font(.system(size: 44, weight: .heavy, design: .rounded).monospacedDigit())
                                        .foregroundStyle(EditorialPalette.oat)
                                        .contentTransition(.numericText())
                                    Text("kcal")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.white.opacity(0.76))
                                }

                                let user = users.first
                                let targetP = (user?.targetProtein ?? 150.0) / 3
                                let targetF = (user?.targetFats ?? 70.0) / 3
                                let targetC = (user?.targetCarbs ?? 250.0) / 3

                                HStack(spacing: 8) {
                                    MealDetailHeroMacroChip(
                                        title: "Protein",
                                        value: meal.totalProtein,
                                        target: max(targetP, 1),
                                        accent: EditorialPalette.emerald
                                    )
                                    MealDetailHeroMacroChip(
                                        title: "Fats",
                                        value: meal.totalFats,
                                        target: max(targetF, 1),
                                        accent: EditorialPalette.warmAmber
                                    )
                                    MealDetailHeroMacroChip(
                                        title: "Carbs",
                                        value: meal.totalCarbs,
                                        target: max(targetC, 1),
                                        accent: EditorialPalette.oceanSlate
                                    )
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(LocalizedStringKey(title))
                                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("No foods logged yet")
                                        .font(.system(size: 13.5, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.white.opacity(0.76))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    if let meal = meal, let items = meal.foodItems, !items.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("What you ate")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(EditorialPalette.inkPrimary)
                                Spacer()
                                Text("\(items.count)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(EditorialPalette.inkSecondary)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 3)
                                    .background(EditorialPalette.surfaceLight)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75))
                            }
                            .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                ForEach(items) { food in
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

                                    if food.id != items.last?.id {
                                        Rectangle()
                                            .fill(EditorialPalette.hairlineLight)
                                            .frame(height: 0.5)
                                            .padding(.leading, 68)
                                    }
                                }
                            }
                            .background(Color.white.opacity(0.80))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
                            )
                        }
                        .padding(.horizontal, 20)

                        if (meal.foodItems ?? []).count > 2 {
                            Button(action: {
                                generateRecipe(from: meal)
                            }) {
                                HStack(spacing: 8) {
                                    if isGeneratingRecipe {
                                        ProgressView()
                                            .tint(EditorialPalette.oat)
                                    } else {
                                        Image(systemName: "sparkles")
                                            .foregroundStyle(EditorialPalette.oat)
                                    }
                                    Text(isGeneratingRecipe ? "Chef is writing recipe..." : "Cook with Chef")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                    Spacer()
                                    if !isGeneratingRecipe {
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(EditorialPalette.oat.opacity(0.8))
                                    }
                                }
                                .padding(.horizontal, 18)
                            }
                            .buttonStyle(
                                EditorialSecondaryDarkButtonStyle(
                                    height: 52,
                                    cornerRadius: 16,
                                    fillColor: EditorialPalette.cardDark,
                                    borderColor: EditorialPalette.cardBorderDark
                                )
                            )
                            .padding(.horizontal, 20)
                            .disabled(isGeneratingRecipe)
                            .animation(.easeInOut, value: isGeneratingRecipe)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Key Micronutrients")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(EditorialPalette.inkPrimary)
                                .padding(.horizontal, 4)

                            MicronutrientRingsView(meal: meal)
                        }
                        .padding(.horizontal, 20)
                    } else {
                        EditorialLightCard(cornerRadius: 20, padding: 24) {
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(EditorialPalette.inkPrimary.opacity(0.06))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(EditorialPalette.inkSecondary)
                                }
                                Text("No Food Logged")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(EditorialPalette.inkPrimary)
                                Text("Tap 'Add Food' below to log your \(String(localized: String.LocalizationValue(title))).")
                                    .font(.system(size: 13.5, weight: .regular, design: .rounded))
                                    .foregroundStyle(EditorialPalette.inkSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(action: { showingAddFood.toggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Add Food")
                }
            }
            .buttonStyle(EditorialPrimaryCTAButtonStyle(tone: .graphite, height: 54))
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(.ultraThinMaterial)
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showingAddFood) {
            MealHUDQuickLogSheet(selectedDate: date, initialMealType: title)
                .presentationDetents([.fraction(0.85), .large])
                .presentationCornerRadius(32)
        }
        .fullScreenCover(item: $selectedFoodForDetail) { food in
            FoodDetailNutritionView(food: food, mealTitle: title, isEditing: true) { updatedFood in
                let oldCalories = food.calories
                let oldSampleID = food.healthKitSampleID
                food.name = updatedFood.name
                food.weight = updatedFood.weight
                food.calories = updatedFood.calories
                food.protein = updatedFood.protein
                food.fats = updatedFood.fats
                food.carbs = updatedFood.carbs
                food.fiber = updatedFood.fiber
                food.sugar = updatedFood.sugar
                food.omega3 = updatedFood.omega3
                food.calcium = updatedFood.calcium
                food.potassium = updatedFood.potassium
                food.magnesium = updatedFood.magnesium
                food.iron = updatedFood.iron
                food.vitaminC = updatedFood.vitaminC
                food.vitaminD = updatedFood.vitaminD
                try? context.save()
                WidgetReloader.reloadAll()
                if users.first?.isHealthKitEnabled == true && oldCalories != updatedFood.calories {
                    let logDate = meal?.date ?? date
                    let container = context.container
                    Task { @MainActor in
                        food.healthKitSampleID = await HealthKitManager.shared.syncEditedDietaryEnergy(
                            oldID: oldSampleID,
                            oldCalories: oldCalories,
                            newCalories: updatedFood.calories,
                            date: logDate
                        )
                        try? container.mainContext.save()
                    }
                }
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
        .sheet(isPresented: $showAIConsentSheet) {
            AIPhotoConsentSheet(
                onAllow: {
                    if let pending = pendingRecipeMeal {
                        pendingRecipeMeal = nil
                        generateRecipe(from: pending)
                    }
                },
                onDecline: {
                    pendingRecipeMeal = nil
                }
            )
        }
    }
    private func copyCurrentMeal(_ sourceMeal: Meal, to targetDate: Date) {
        let copiedItems = DailySummary.copyMealReturningItems(sourceMeal, toDate: targetDate, targetSlot: title, in: context)
        let count = copiedItems.count
        guard count > 0 else { return }
        try? context.save()
        WidgetReloader.reloadAll()
        if users.first?.isHealthKitEnabled == true {
            let syncDate = Calendar.current.isDateInToday(targetDate) ? Date() : targetDate
            let container = context.container
            Task { @MainActor in
                var didAttach = false
                for item in copiedItems where item.calories > 0 {
                    if let uuid = await HealthKitManager.shared.saveDietaryEnergy(calories: item.calories, date: syncDate) {
                        item.healthKitSampleID = uuid.uuidString
                        didAttach = true
                    }
                }
                if didAttach {
                    try? container.mainContext.save()
                }
            }
        }
        HapticManager.shared.notification(type: .success)
        let message = Calendar.current.isDateInToday(targetDate)
            ? String(localized: "Copied \(count) items to Today")
            : String(localized: "Copied \(count) items to Tomorrow")
        withAnimation { copiedFeedbackText = message }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation { copiedFeedbackText = nil }
        }
    }

    private func addFoodsToMeal(items: [FoodItem]) {
        let canonicalTitle = NutritionMath.canonicalMealType(title)
        let startOfDay = Calendar.current.startOfDay(for: date)
        let summary = DailySummary.fetchOrCreate(for: startOfDay, in: context)
        let mealTimestamp = Calendar.current.isDateInToday(date) ? Date.now : startOfDay

        var newFoodItems: [FoodItem] = []
        for item in items {
            let copiedItem = DailySummary.duplicateFoodItem(item)
            context.insert(copiedItem)
            newFoodItems.append(copiedItem)
        }

        if let existingMeal = (summary.meals ?? []).first(where: { DailySummary.canonicalMealSlot($0.title) == canonicalTitle }) {
            existingMeal.addFoodItems(newFoodItems)
            existingMeal.date = mealTimestamp
        } else {
            let newMeal = Meal(title: canonicalTitle, date: mealTimestamp, foodItems: newFoodItems)
            context.insert(newMeal)
            summary.addMeal(newMeal)
        }

        try? context.save()
        WidgetReloader.reloadAll()

        let shouldSyncHK = (try? context.fetch(FetchDescriptor<User>()).first?.isHealthKitEnabled) == true
        let itemsToSync = newFoodItems.filter { $0.calories > 0 }
        if shouldSyncHK && !itemsToSync.isEmpty {
            let syncDate = mealTimestamp
            Task { @MainActor in
                var didAttach = false
                for item in itemsToSync {
                    if let uuid = await HealthKitManager.shared.saveDietaryEnergy(calories: item.calories, date: syncDate) {
                        item.healthKitSampleID = uuid.uuidString
                        didAttach = true
                    }
                }
                if didAttach {
                    try? context.save()
                }
            }
        }
    }
}

struct MealDetailHeroMacroChip: View {
    let title: LocalizedStringKey
    let value: Double
    let target: Double
    let accent: Color

    var body: some View {
        let ratio = min(max(value / max(target, 1), 0), 1)
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text("\(Int(value.rounded()))g")
                    .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 4)
                    Capsule()
                        .fill(accent)
                        .frame(width: max(ratio > 0 ? 4 : 0, geo.size.width * ratio), height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(EditorialPalette.chipDark)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.75)
        )
    }
}

struct FoodItemDetailedRow: View {
    let food: FoodItem
    var onDelete: (() -> Void)? = nil
    @AppStorage("useMetricSystem") private var useMetricSystem = true

    var body: some View {
        let meta = EditorialMealTheme.foodCategoryMeta(for: food.name)
        let weightText = food.weight > 0
            ? NutritionMath.formattedFoodWeight(food.weight, useMetric: useMetricSystem)
            : String(localized: "1 serving")

        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(meta.color.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: meta.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(meta.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(EditorialPalette.inkPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text(weightText)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(EditorialPalette.inkPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    Text("P:\(Int(food.protein)) F:\(Int(food.fats)) C:\(Int(food.carbs))")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(EditorialPalette.inkSecondary)
                }
            }
            Spacer(minLength: 8)

            Text("\(food.calories) kcal")
                .font(.system(size: 14.5, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(EditorialPalette.inkPrimary)

            if let onDelete = onDelete {
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
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(EditorialPalette.inkSecondary.opacity(0.45))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

struct MicronutrientRingsView: View {
    let meal: Meal
    private let targetOmega3: Double = 1.6 / 3
    private let targetPotassium: Double = 3500 / 3
    private let targetMagnesium: Double = 400 / 3

    var body: some View {
        EditorialDarkCard(cornerRadius: 22, padding: 18) {
            HStack(spacing: 22) {
                ZStack {
                    ActivityRing(progress: meal.totalOmega3 / targetOmega3, color: EditorialPalette.emerald, radius: 54, thickness: 11)
                    ActivityRing(progress: meal.totalPotassium / targetPotassium, color: EditorialPalette.warmAmber, radius: 39, thickness: 11)
                    ActivityRing(progress: meal.totalMagnesium / targetMagnesium, color: EditorialPalette.oceanSlate, radius: 24, thickness: 11)
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(EditorialPalette.oat)
                }
                .frame(width: 110, height: 110)

                VStack(alignment: .leading, spacing: 14) {
                    RingLegendRow(color: EditorialPalette.emerald, title: "Omega-3", value: meal.totalOmega3, unit: "g", target: targetOmega3)
                    RingLegendRow(color: EditorialPalette.warmAmber, title: "Potassium", value: meal.totalPotassium, unit: "mg", target: targetPotassium)
                    RingLegendRow(color: EditorialPalette.oceanSlate, title: "Magnesium", value: meal.totalMagnesium, unit: "mg", target: targetMagnesium)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct RingLegendRow: View {
    let color: Color
    let title: String
    let value: Double
    let unit: String
    let target: Double

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                let formattedTarget = target < 10 ? String(format: "%.1f", target) : "\(Int(target.rounded()))"
                Text("\(value, specifier: "%.1f") / \(formattedTarget) \(unit)")
                    .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.white.opacity(0.66))
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
            Circle().stroke(color.opacity(0.18), lineWidth: thickness)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: radius * 2, height: radius * 2)
        .animation(.spring(response: 0.8), value: progress)
    }
}

struct ActionSearchBar: View {
    @Binding var text: String
    var onBarcodeTap: () -> Void
    var onManualAddTap: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            // Dual Action Fast Deck: Scan & Custom Food (Editorial Dark Cards)
            HStack(spacing: 10) {
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    onBarcodeTap()
                }) {
                    HStack(spacing: 9) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(EditorialPalette.emerald.opacity(0.16))
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
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(EditorialPalette.cardBorderDark, lineWidth: 1)
                    )
                }
                .buttonStyle(BounceButtonStyle())

                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    onManualAddTap()
                }) {
                    HStack(spacing: 9) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(EditorialPalette.oat.opacity(0.14))
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
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(EditorialPalette.cardBorderDark, lineWidth: 1)
                    )
                }
                .buttonStyle(BounceButtonStyle())
            }

            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(EditorialPalette.inkSecondary)
                    .font(.system(size: 15, weight: .medium))
                TextField(String(localized: "Search foods..."), text: $text)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(EditorialPalette.inkPrimary)
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(EditorialPalette.inkSecondary.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
            )
        }
    }
}

struct FloatingCartButton: View {
    let count: Int; let calories: Int; let action: () -> Void
    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) items selected")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(EditorialPalette.oat.opacity(0.76))
                    Text("\(calories) kcal")
                        .font(.system(size: 18, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                }
                Spacer()
                Button(action: action) {
                    HStack(spacing: 6) {
                        Text("Add")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 15))
                    }
                    .foregroundStyle(EditorialPalette.textOnOat)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(EditorialPalette.oat)
                    .clipShape(Capsule())
                }
                .buttonStyle(BounceButtonStyle())
                .accessibilityIdentifier("smart_add_confirm_cart_button")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .background(EditorialPalette.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(EditorialPalette.cardBorderDarkFocused, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.24), radius: 18, y: 8)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}

struct FoodSearchResultRow: View {
    let food: FoodItem
    var activeDietPlan: DietPlan? = nil
    let action: () -> Void
    @AppStorage("useMetricSystem") private var useMetricSystem = true

    var body: some View {
        let compatibility = food.compatibility(with: activeDietPlan)
        let meta = EditorialMealTheme.foodCategoryMeta(for: food.name)

        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(meta.color.opacity(0.14))
                        .frame(width: 42, height: 42)
                    Image(systemName: meta.symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(meta.color)

                    if compatibility != .neutral {
                        Image(systemName: compatibility.icon)
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(compatibility.color)
                            .padding(3.5)
                            .background(Color.white)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.5))
                            .offset(x: 16, y: 16)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(food.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(compatibility == .avoid ? EditorialPalette.inkSecondary : EditorialPalette.inkPrimary)
                        .strikethrough(compatibility == .avoid, color: EditorialPalette.softPeach.opacity(0.6))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        let weightLabel = food.weight > 0
                            ? NutritionMath.formattedFoodWeight(food.weight, useMetric: useMetricSystem)
                            : String(localized: "1 serving")
                        Text("\(food.calories) kcal • \(weightLabel)")
                            .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundStyle(EditorialPalette.inkSecondary)

                        if compatibility == .perfect {
                            Text("Great option")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundStyle(EditorialPalette.forest)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(EditorialPalette.emerald.opacity(0.14))
                                .clipShape(Capsule())
                        } else if compatibility == .avoid {
                            Text("Avoid")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundStyle(EditorialPalette.softPeach)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(EditorialPalette.softPeach.opacity(0.14))
                                .clipShape(Capsule())
                        }
                    }
                }
                Spacer()

                ZStack {
                    Circle()
                        .fill(compatibility == .avoid ? Color.black.opacity(0.05) : EditorialPalette.inkPrimary.opacity(0.08))
                        .frame(width: 34, height: 34)

                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(compatibility == .avoid ? EditorialPalette.inkSecondary : EditorialPalette.inkPrimary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        compatibility == .avoid ? EditorialPalette.softPeach.opacity(0.28) :
                        (compatibility == .perfect ? EditorialPalette.emerald.opacity(0.32) : EditorialPalette.hairlineLight),
                        lineWidth: 0.9
                    )
            )
        }
        .buttonStyle(BounceButtonStyle())
    }
}

struct FridgeLedgerStickerView: View {
    let totalCalories: Int
    @State private var isTapped = false

    var body: some View {
        ZStack(alignment: .top) {
            // Main Sticker Body
            VStack(alignment: .leading, spacing: 14) {
                // Sticker Header with Ledger Serial
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Image(systemName: "refrigerator.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.42, green: 0.38, blue: 0.32))
                        Text("KITCHEN LEDGER")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.4)
                            .foregroundColor(Color(red: 0.42, green: 0.38, blue: 0.32))
                    }
                    
                    Spacer()
                    
                    Text("ALL-TIME LOG")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.30, green: 0.28, blue: 0.24).opacity(0.12))
                        .clipShape(Capsule())
                        .foregroundColor(Color(red: 0.35, green: 0.32, blue: 0.28))
                }
                .padding(.top, 14) // Room for top magnet pin
                
                // Perforated / Dashed dividing line
                HStack(spacing: 4) {
                    ForEach(0..<28, id: \.self) { _ in
                        Rectangle()
                            .fill(Color(red: 0.35, green: 0.32, blue: 0.28).opacity(0.22))
                            .frame(height: 1)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Big Calorie Counter
                VStack(alignment: .leading, spacing: 2) {
                    Text("All-Time Total")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .textCase(.uppercase)
                        .tracking(1.0)
                        .foregroundColor(Color(red: 0.50, green: 0.46, blue: 0.40))
                    
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(totalCalories, format: .number)
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.14))
                        
                        Text("KCAL")
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .foregroundColor(Color(red: 0.70, green: 0.32, blue: 0.18))
                        
                        Spacer()
                        
                        // Stamped verified badge
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("TOTAL LOGGED")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundColor(Color(red: 0.18, green: 0.45, blue: 0.28))
                            Text("NUTRITION LOG")
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(red: 0.45, green: 0.42, blue: 0.38))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color(red: 0.18, green: 0.45, blue: 0.28).opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                                .background(Color(red: 0.18, green: 0.45, blue: 0.28).opacity(0.06))
                        )
                    }
                }
                
                // Footer: Decorative Barcode & Date Stamp
                HStack(alignment: .center) {
                    // Micro barcode
                    HStack(spacing: 2) {
                        ForEach([3, 1, 4, 1, 5, 2, 6, 1, 3, 2, 4, 1, 2, 5, 1, 3, 2, 4], id: \.self) { barWidth in
                            Rectangle()
                                .fill(Color(red: 0.25, green: 0.24, blue: 0.22).opacity(0.55))
                                .frame(width: CGFloat(barWidth), height: 14)
                        }
                    }
                    
                    Spacer()
                    
                    Text("NO. FT-MAGNET-RECORD")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(red: 0.50, green: 0.46, blue: 0.40))
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.97, green: 0.95, blue: 0.91), // Vintage warm ivory
                                Color(red: 0.93, green: 0.90, blue: 0.85)  // Aged paper edge
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color(red: 0.78, green: 0.74, blue: 0.68).opacity(0.6), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.20), radius: 14, x: 0, y: 7)
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            .rotationEffect(.degrees(isTapped ? 1.0 : -1.4))
            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: isTapped)
            .onTapGesture {
                HapticManager.shared.impact(style: .light)
                withAnimation {
                    isTapped.toggle()
                }
            }
            
            // Realistic Brushed Stainless Steel Fridge Magnet Pin
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(white: 0.98),
                            Color(white: 0.78),
                            Color(white: 0.60)
                        ],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: 18
                    )
                )
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.45).opacity(0.8), lineWidth: 1)
                )
                .overlay(
                    // Magnet specular highlight
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 6, height: 6)
                        .offset(x: -3, y: -3)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 3)
                .offset(y: -8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
}

typealias AllTimeStatsCardView = FridgeLedgerStickerView
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
    let summary: DailySummary

    let moods = [
        ("☀️", "Great Day"),
        ("🍩", "Cheat Day"),
        ("🍔", "Binge Eating"),
        ("🥲", "Bad Mood"),
        ("🏋️", "Active"),
        ("🧘‍♀️", "Relaxed"),
        ("🤢", "Felt Sick")
    ]

    @State private var draftNote: String
    @State private var draftMoodEmoji: String
    @State private var selectedMoodForAI: String? = nil
    @State private var showAIChat = false
    @State private var moodContextForChat: String? = nil

    init(summary: DailySummary) {
        self.summary = summary
        self._draftNote = State(initialValue: summary.dayNote)
        self._draftMoodEmoji = State(initialValue: summary.dayMoodEmoji)
    }

    var body: some View {
        ZStack {
            DynamicAuroraBackgroundView(pinnedPaletteIndex: 2)
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    HStack {
                        Text("Your Day")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(EditorialPalette.inkPrimary)
                        Spacer()
                        Button("Save") {
                            HapticManager.shared.impact(style: .heavy)
                            let persisted = summary.modelContext != nil
                                ? summary
                                : DailySummary.fetchOrCreate(for: summary.date, in: context)
                            persisted.dayNote = draftNote
                            persisted.dayMoodEmoji = draftMoodEmoji
                            try? context.save()
                            clearAIMoodStates()
                            dismiss()
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.themeBg)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(EditorialPalette.inkPrimary)
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    TextField("Write about your meals, feelings, or workouts...", text: $draftNote, axis: .vertical)
                        .lineLimit(4...8)
                        .padding(16)
                        .background(Color.white.opacity(0.84))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
                        )
                        .padding(.horizontal, 20)
                        .accessibilityLabel("Daily note")

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tags & Mood")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(EditorialPalette.inkPrimary)
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(moods, id: \.1) { mood in
                                    let isSelected = draftMoodEmoji == mood.0
                                    Button(action: {
                                        HapticManager.shared.impact(style: .light)
                                        withAnimation {
                                            if isSelected {
                                                draftMoodEmoji = ""
                                                clearAIMoodStates()
                                            } else {
                                                draftMoodEmoji = mood.0
                                                clearAIMoodStates()

                                                let tappedMood = mood.0
                                                Task {
                                                    try? await Task.sleep(for: .milliseconds(250))
                                                    await MainActor.run {
                                                        if draftMoodEmoji == tappedMood {
                                                            selectedMoodForAI = tappedMood
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }) {
                                        VStack(spacing: 7) {
                                            Text(mood.0)
                                                .font(.system(size: 28))
                                                .frame(width: 54, height: 54)
                                                .background(isSelected ? EditorialPalette.cardDark : Color.white.opacity(0.82))
                                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .strokeBorder(
                                                            isSelected ? EditorialPalette.cardBorderDarkFocused : EditorialPalette.hairlineLight,
                                                            lineWidth: isSelected ? 1.5 : 0.75
                                                        )
                                                )

                                            Text(LocalizedStringKey(mood.1))
                                                .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                                                .foregroundStyle(isSelected ? EditorialPalette.inkPrimary : EditorialPalette.inkSecondary)
                                                .lineLimit(1)
                                        }
                                        .frame(minWidth: 64, minHeight: 80)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .accessibilityLabel(Text("\(String(localized: String.LocalizationValue(mood.1))) mood"))
                                    .accessibilityValue(isSelected ? String(localized: "Selected") : String(localized: "Not selected"))
                                    .accessibilityAddTraits(.isButton)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .onDisappear {
            clearAIMoodStates()
        }
        .sheet(item: Binding(
            get: { selectedMoodForAI.map { IdentifiableString(value: $0) } },
            set: { selectedMoodForAI = $0?.value }
        )) { wrappedEmoji in
            moodAdviceSheet(for: wrappedEmoji.value)
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showAIChat) {
            let fetchedUser = try? context.fetch(FetchDescriptor<User>()).first
            NavigationStack {
                AICoachChatView(
                    userGoal: fetchedUser?.dailyCaloriesGoal ?? 2000,
                    consumed: summary.totalCalories,
                    activeDiet: fetchedUser?.activeDietPlan?.name ?? "Balanced",
                    initialContext: moodContextForChat,
                    consumedProtein: summary.totalProtein,
                    targetProtein: fetchedUser?.targetProtein ?? 0,
                    consumedFats: summary.totalFats,
                    targetFats: fetchedUser?.targetFats ?? 0,
                    consumedCarbs: summary.totalCarbs,
                    targetCarbs: fetchedUser?.targetCarbs ?? 0,
                    hydrationLiters: summary.totalPureWaterLiters
                )
            }
        }
        .onChange(of: showAIChat) { _, isPresented in
            if !isPresented {
                // Clean up after chat is dismissed so it doesn't re-trigger anything
                moodContextForChat = nil
            }
        }
    }

    @ViewBuilder
    private func moodAdviceSheet(for emoji: String) -> some View {
        let moodName = moods.first(where: { $0.0 == emoji })?.1 ?? "Mood"
        let user: User? = try? context.fetch(FetchDescriptor<User>()).first
        AIMoodAdvicePopup(
            moodEmoji: emoji,
            moodName: moodName,
            dayNote: draftNote,
            consumedCalories: Int(summary.totalCalories),
            goalCalories: user?.dailyCaloriesGoal ?? 2000,
            waterLiters: summary.totalPureWaterLiters,
            activeDiet: user?.activeDietKey ?? "Balanced"
        ) {
            let localizedMoodName = String(localized: String.LocalizationValue(moodName))
            selectedMoodForAI = nil
            moodContextForChat = String(localized: "I feel \(localizedMoodName) \(emoji) right now. Can we talk about it?")
            showAIChat = true
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
    @Query private var users: [User]
    @AppStorage("useMetricSystem") private var useMetricSystem = true
    let summary: DailySummary
    @State private var copiedBannerText: String? = nil

    private func deleteActivity(_ activity: ActivityLog) {
        let shouldSyncHK = users.first?.isHealthKitEnabled == true
        let title = activity.title
        let date = activity.date
        let calories = activity.calories
        let durationMinutes = activity.durationMinutes
        let hkIDs = WorkoutSyncManager.shared.consumeActivityHealthKitIDs(
            title: title,
            date: date,
            calories: calories,
            durationMinutes: durationMinutes
        )
        withAnimation {
            _ = summary.removeActivity(activity, in: context)
            try? context.save()
            WidgetReloader.reloadAll()
        }
        if shouldSyncHK {
            Task {
                await HealthKitManager.shared.deleteWorkoutAndEnergySamples(
                    workoutID: hkIDs.workoutID,
                    energySampleID: hkIDs.energySampleID,
                    caloriesFallback: calories,
                    date: date
                )
            }
        }
    }

    private func copyDay(to targetDate: Date) {
        let copiedItems = DailySummary.copyDayReturningItems(from: summary, toDate: targetDate, in: context)
        let count = copiedItems.count
        guard count > 0 else { return }
        try? context.save()
        WidgetReloader.reloadAll()
        if users.first?.isHealthKitEnabled == true {
            let syncDate = Calendar.current.isDateInToday(targetDate) ? Date() : targetDate
            let container = context.container
            Task { @MainActor in
                var didAttach = false
                for item in copiedItems where item.calories > 0 {
                    if let uuid = await HealthKitManager.shared.saveDietaryEnergy(calories: item.calories, date: syncDate) {
                        item.healthKitSampleID = uuid.uuidString
                        didAttach = true
                    }
                }
                if didAttach {
                    try? container.mainContext.save()
                }
            }
        }
        HapticManager.shared.notification(type: .success)
        let message = Calendar.current.isDateInToday(targetDate)
            ? String(localized: "Copied \(count) items to Today")
            : String(localized: "Copied \(count) items to Tomorrow")
        withAnimation { copiedBannerText = message }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation { copiedBannerText = nil }
        }
    }

    private func deleteFoodItem(_ food: FoodItem, from meal: Meal) {
        let shouldSyncHK = users.first?.isHealthKitEnabled == true
        let logDate = meal.date
        var deletedInfo: DailySummary.DeletedFoodHealthSample?
        withAnimation {
            deletedInfo = summary.removeFoodItem(food, from: meal, in: context)
            try? context.save()
            WidgetReloader.reloadAll()
        }
        if shouldSyncHK, let deletedInfo {
            Task {
                await HealthKitManager.shared.deleteDietaryEnergySample(
                    idString: deletedInfo.sampleID,
                    caloriesFallback: deletedInfo.calories,
                    date: logDate
                )
            }
        }
    }
    var body: some View {
        ZStack {
            DynamicAuroraBackgroundView(pinnedPaletteIndex: 0)
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    EditorialDarkCard(cornerRadius: 22, padding: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(
                                    Calendar.current.isDateInToday(summary.date)
                                    ? String(localized: "Total Logged Today")
                                    : summary.date.formatted(date: .abbreviated, time: .omitted)
                                )
                                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(EditorialPalette.oat.opacity(0.78))
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("\(summary.totalCalories)")
                                        .font(.system(size: 40, weight: .heavy, design: .rounded).monospacedDigit())
                                        .foregroundStyle(EditorialPalette.oat)
                                    Text("kcal")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.white.opacity(0.72))
                                }
                            }
                            Spacer()
                            EditorialMetricChip(
                                label: "Active",
                                value: "\(summary.localActivityCalories) kcal",
                                accent: EditorialPalette.warmAmber
                            )
                            .frame(width: 112)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    let activeMeals = (summary.meals ?? []).filter { !($0.foodItems ?? []).isEmpty }
                    let loggedActivities = summary.activities ?? []
                    let loggedBeverages = (summary.beverages ?? []).filter { $0.volumeMl > 0 || $0.caloriesPerGlass > 0 }

                    if let copiedBannerText {
                        Text(copiedBannerText)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(EditorialPalette.emerald)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(EditorialPalette.cardDark)
                            .clipShape(Capsule())
                    }

                    if activeMeals.isEmpty && loggedActivities.isEmpty && loggedBeverages.isEmpty {
                        EditorialLightCard(cornerRadius: 20, padding: 28) {
                            VStack(spacing: 10) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundStyle(EditorialPalette.inkSecondary)
                                Text("No Food Logged")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(EditorialPalette.inkPrimary)
                                Text("You haven't logged any food for this day yet.")
                                    .font(.system(size: 13.5, weight: .regular, design: .rounded))
                                    .foregroundStyle(EditorialPalette.inkSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 20)
                    } else {
                        ForEach(activeMeals) { meal in
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 8) {
                                    Image(systemName: EditorialMealTheme.symbolName(for: meal.title))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(EditorialMealTheme.accentColor(for: meal.title))
                                    Text(LocalizedStringKey(meal.title))
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(EditorialPalette.inkPrimary)
                                    Spacer()
                                    Text("\(meal.totalCalories) kcal")
                                        .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                                        .foregroundStyle(EditorialPalette.inkPrimary)
                                }
                                .padding(.horizontal, 18)
                                .padding(.top, 16)
                                .padding(.bottom, 10)

                                VStack(spacing: 0) {
                                    ForEach(meal.foodItems ?? []) { food in
                                        let meta = EditorialMealTheme.foodCategoryMeta(for: food.name)
                                        HStack(spacing: 12) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(meta.color.opacity(0.14))
                                                    .frame(width: 38, height: 38)
                                                Image(systemName: meta.symbol)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundStyle(meta.color)
                                            }

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(food.name)
                                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                    .foregroundStyle(EditorialPalette.inkPrimary)
                                                    .lineLimit(1)

                                                HStack(spacing: 5) {
                                                    Text(food.weight > 0 ? NutritionMath.formattedFoodWeight(food.weight, useMetric: useMetricSystem) : String(localized: "1 serving"))
                                                    Text("•")
                                                    Text("P:\(Int(food.protein)) F:\(Int(food.fats)) C:\(Int(food.carbs))")
                                                }
                                                .font(.system(size: 11.5, weight: .medium, design: .rounded).monospacedDigit())
                                                .foregroundStyle(EditorialPalette.inkSecondary)
                                            }
                                            Spacer()

                                            Text("\(food.calories)")
                                                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                                                .foregroundStyle(EditorialPalette.inkPrimary)

                                            Button(action: {
                                                HapticManager.shared.impact(style: .medium)
                                                deleteFoodItem(food, from: meal)
                                            }) {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(EditorialPalette.softPeach)
                                                    .frame(width: 30, height: 30)
                                                    .background(EditorialPalette.softPeach.opacity(0.12))
                                                    .clipShape(Circle())
                                            }
                                        }
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 11)

                                        if food.id != meal.foodItems?.last?.id {
                                            Rectangle()
                                                .fill(EditorialPalette.hairlineLight)
                                                .frame(height: 0.5)
                                                .padding(.leading, 68)
                                        }
                                    }
                                }
                                .padding(.bottom, 6)
                            }
                            .background(Color.white.opacity(0.80))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
                            )
                            .padding(.horizontal, 20)
                        }

                        if !loggedActivities.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text("Logged Activities")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(EditorialPalette.inkPrimary)
                                    Spacer()
                                    Text("\(summary.localActivityCalories) kcal")
                                        .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                                        .foregroundStyle(EditorialPalette.warmAmber)
                                }
                                .padding(.horizontal, 18)
                                .padding(.top, 16)
                                .padding(.bottom, 10)

                                VStack(spacing: 0) {
                                    ForEach(loggedActivities) { activity in
                                        HStack(spacing: 12) {
                                            Image(systemName: activity.icon)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(EditorialPalette.warmAmber)
                                                .frame(width: 38, height: 38)
                                                .background(EditorialPalette.warmAmber.opacity(0.14))
                                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(LocalizedStringKey(activity.title))
                                                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                                                    .foregroundStyle(EditorialPalette.inkPrimary)
                                                Text("\(activity.durationMinutes) min")
                                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                                    .foregroundStyle(EditorialPalette.inkSecondary)
                                            }
                                            Spacer()
                                            Text("-\(activity.calories) kcal")
                                                .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                                                .foregroundStyle(EditorialPalette.inkPrimary)
                                            Button {
                                                HapticManager.shared.impact(style: .medium)
                                                deleteActivity(activity)
                                            } label: {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(EditorialPalette.softPeach)
                                                    .frame(width: 30, height: 30)
                                                    .background(EditorialPalette.softPeach.opacity(0.12))
                                                    .clipShape(Circle())
                                            }
                                        }
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 11)
                                        if activity.persistentModelID != loggedActivities.last?.persistentModelID {
                                            Rectangle()
                                                .fill(EditorialPalette.hairlineLight)
                                                .frame(height: 0.5)
                                                .padding(.leading, 68)
                                        }
                                    }
                                }
                                .padding(.bottom, 6)
                            }
                            .background(Color.white.opacity(0.80))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
                            )
                            .padding(.horizontal, 20)
                        }

                        if !loggedBeverages.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text("Logged Drinks")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(EditorialPalette.inkPrimary)
                                    Spacer()
                                    Text("\(summary.totalDrinkCalories) kcal")
                                        .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                                        .foregroundStyle(EditorialPalette.oceanSlate)
                                }
                                .padding(.horizontal, 18)
                                .padding(.top, 16)
                                .padding(.bottom, 10)

                                VStack(spacing: 0) {
                                    ForEach(loggedBeverages) { beverage in
                                        HStack(spacing: 12) {
                                            Image(systemName: beverage.icon)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(EditorialPalette.oceanSlate)
                                                .frame(width: 38, height: 38)
                                                .background(EditorialPalette.oceanSlate.opacity(0.14))
                                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(LocalizedStringKey(beverage.name))
                                                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                                                    .foregroundStyle(EditorialPalette.inkPrimary)
                                                Text(NutritionMath.formattedHydration(liters: beverage.volumeMl / 1000.0, useMetric: useMetricSystem))
                                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                                    .foregroundStyle(EditorialPalette.inkSecondary)
                                            }
                                            Spacer()
                                            if beverage.caloriesPerGlass > 0 {
                                                Text("\(beverage.caloriesPerGlass) kcal")
                                                    .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                                                    .foregroundStyle(EditorialPalette.inkPrimary)
                                            }
                                        }
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 11)
                                        if beverage.persistentModelID != loggedBeverages.last?.persistentModelID {
                                            Rectangle()
                                                .fill(EditorialPalette.hairlineLight)
                                                .frame(height: 0.5)
                                                .padding(.leading, 68)
                                        }
                                    }
                                }
                                .padding(.bottom, 6)
                            }
                            .background(Color.white.opacity(0.80))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
                            )
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.bottom, 48)
            }
        }
        .navigationTitle("Daily Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !(summary.meals ?? []).allSatisfy({ ($0.foodItems ?? []).isEmpty }) {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if !Calendar.current.isDateInToday(summary.date) {
                            Button {
                                copyDay(to: Date())
                            } label: {
                                Label("Copy Day to Today", systemImage: "doc.on.doc")
                            }
                        }
                        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) {
                            Button {
                                copyDay(to: tomorrow)
                            } label: {
                                Label("Copy Day to Tomorrow", systemImage: "calendar.badge.plus")
                            }
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(EditorialPalette.inkPrimary)
                    }
                    .accessibilityLabel("Copy Day")
                }
            }
        }
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
                Text(LocalizedStringKey(title))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(LocalizedStringKey(subtitle))
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
    @Query private var users: [User]
    @Query private var allDatabaseFoods: [FoodItem]
    @Query private var customRecipes: [CustomRecipe]
    @Query(sort: \Meal.date, order: .reverse) private var pastMeals: [Meal]
    @AppStorage(FavoriteFoodStore.storageKey) private var favoriteFoodNamesRaw: String = ""

    @State private var selectedFoodForDetail: FoodItem? = nil
    let mealTitle: String
    var targetDate: Date = Date()
    var onSave: ([FoodItem]) -> Void

    @State private var showingScanner = false
    @State private var showingManualAdd = false
    @State private var showingAIConsentSheet = false
    @State private var pendingScannerFood: FoodItem? = nil
    @State private var pendingManualEntryAfterScanner = false
    @State private var selectedFoods: [FoodItem] = []
    @State private var searchText = ""
    @State private var selectedCategory = "Recent"

    @State private var localCatalogResults: [FoodItem] = []
    @State private var apiSearchResults: [FoodItem] = []
    @State private var isSearchingAPI = false
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var cachedAvailableFoods: [FoodItem] = []
    @State private var cachedRecipeFoods: [FoodItem] = []
    @State private var cachedFoodCounts: [String: Int] = [:]

    let categories = ["Recent", "Frequent", "Favorites", "My Recipes"]

    private var activeDietPlan: DietPlan? {
        users.first?.activeDietPlan
    }

    static func shouldOfferAIConsentPrompt(
        query: String,
        hasConsented: Bool,
        hasAnyResults: Bool,
        isSearching: Bool
    ) -> Bool {
        FoodSearchConsentPolicy.shouldOfferAIConsentPrompt(
            query: query,
            hasConsented: hasConsented,
            hasAnyResults: hasAnyResults,
            isSearching: isSearching
        )
    }

    var filteredLocalFoods: [FoodItem] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            var seen = Set<String>()
            var combined: [FoodItem] = []
            for item in cachedAvailableFoods + cachedRecipeFoods {
                if item.name.localizedCaseInsensitiveContains(trimmedSearch),
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
        case "Favorites":
            let starred = FavoriteFoodStore.namesSet(from: favoriteFoodNamesRaw)
            var seen = Set<String>()
            var starredItems: [FoodItem] = []
            var frequentItems: [FoodItem] = []
            for item in cachedAvailableFoods + cachedRecipeFoods {
                let normalizedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard item.name != "Quick Entry",
                      seen.insert(normalizedName).inserted else { continue }
                if starred.contains(normalizedName) {
                    starredItems.append(item)
                } else if (cachedFoodCounts[item.name] ?? 0) >= 2 {
                    frequentItems.append(item)
                }
            }
            return starredItems + frequentItems
        case "My Recipes":
            return cachedRecipeFoods
        default:
            return cachedAvailableFoods
        }
    }

    private func rebuildFoodCaches() {
        var seenNames = Set<String>()
        var results: [FoodItem] = []
        var counts: [String: Int] = [:]

        for meal in pastMeals.prefix(80) {
            for item in meal.foodItems ?? [] where item.parentRecipe == nil {
                counts[item.name, default: 0] += 1
                if seenNames.insert(item.name).inserted {
                    results.append(item)
                }
            }
        }
        for item in allDatabaseFoods where item.parentRecipe == nil && results.count < 150 {
            if seenNames.insert(item.name).inserted {
                results.append(item)
            }
        }
        if results.isEmpty {
            results = [
                FoodItem(name: "Grilled Chicken Breast", weight: 150, calories: 240, protein: 31, fats: 3.6, carbs: 0),
                FoodItem(name: "Avocado Toast", weight: 120, calories: 220, protein: 5, fats: 12, carbs: 20)
            ]
        }
        cachedAvailableFoods = results
        cachedRecipeFoods = customRecipes.map { $0.toFoodItem() }.sorted { $0.name < $1.name }
        cachedFoodCounts = counts
    }

    var cartCalories: Int { selectedFoods.reduce(0) { $0 + $1.calories } }

    var body: some View {
        ZStack(alignment: .bottom) {
            DynamicAuroraBackgroundView(pinnedPaletteIndex: EditorialMealTheme.paletteIndex(for: mealTitle))
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                VStack(spacing: 14) {
                    Capsule()
                        .fill(EditorialPalette.inkPrimary.opacity(0.18))
                        .frame(width: 40, height: 5)
                        .padding(.top, 10)

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(LocalizedStringKey(mealTitle))
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(EditorialPalette.inkPrimary)
                            Text("What did you eat?")
                                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                                .foregroundStyle(EditorialPalette.inkSecondary)
                        }
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

                    ActionSearchBar(
                        text: $searchText,
                        onBarcodeTap: { showingScanner = true },
                        onManualAddTap: { showingManualAdd = true }
                    )
                    .padding(.horizontal, 20)

                    if searchText.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categories, id: \.self) { category in
                                    let isSel = selectedCategory == category
                                    Button(action: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selectedCategory = category }
                                        HapticManager.shared.impact(style: .light)
                                    }) {
                                        Text(LocalizedStringKey(category))
                                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(isSel ? EditorialPalette.inkPrimary : EditorialPalette.surfaceLight)
                                            .foregroundStyle(isSel ? Color.themeBg : EditorialPalette.inkPrimary)
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule()
                                                    .strokeBorder(isSel ? Color.clear : EditorialPalette.hairlineLight, lineWidth: 0.75)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.bottom, 10)
                .background(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(EditorialPalette.hairlineLight).frame(height: 0.5)
                }
                .zIndex(2)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        if !searchText.isEmpty {
                            if !filteredLocalFoods.isEmpty {
                                Text("From your history")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .textCase(.uppercase)
                                    .foregroundStyle(EditorialPalette.inkSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                ForEach(filteredLocalFoods, id: \.id) { food in
                                    FoodSearchResultRow(food: food, activeDietPlan: activeDietPlan) { selectedFoodForDetail = food }
                                }
                            }

                            if !localCatalogResults.isEmpty {
                                Text("Local database")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .textCase(.uppercase)
                                    .foregroundStyle(EditorialPalette.inkSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 10)
                                ForEach(localCatalogResults, id: \.id) { food in
                                    FoodSearchResultRow(food: food, activeDietPlan: activeDietPlan) { selectedFoodForDetail = food }
                                }
                            }

                            if !apiSearchResults.isEmpty {
                                Text("Global database")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .textCase(.uppercase)
                                    .foregroundStyle(EditorialPalette.inkSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 10)
                                ForEach(apiSearchResults, id: \.id) { food in
                                    FoodSearchResultRow(food: food, activeDietPlan: activeDietPlan) { selectedFoodForDetail = food }
                                }
                            }

                            if isSearchingAPI {
                                ProgressView("Searching global database...")
                                    .padding(.top, 24)
                            } else if filteredLocalFoods.isEmpty && localCatalogResults.isEmpty && apiSearchResults.isEmpty {
                                let offersAIConsent = Self.shouldOfferAIConsentPrompt(
                                    query: searchText,
                                    hasConsented: AIPhotoConsentManager.shared.hasConsented,
                                    hasAnyResults: false,
                                    isSearching: false
                                )
                                VStack(spacing: 14) {
                                    Image(systemName: offersAIConsent ? "sparkles.rectangle.stack.fill" : "magnifyingglass")
                                        .font(.system(size: 38, weight: .medium))
                                        .foregroundStyle(offersAIConsent ? EditorialPalette.forest : EditorialPalette.inkSecondary)
                                    Text("Can't find '\(searchText)'?")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(EditorialPalette.inkPrimary)
                                    Text(
                                        offersAIConsent
                                            ? "Enable AI Food Search to estimate calories and macros for unlisted dishes, or create a custom entry."
                                            : "No worries! You can quickly add it to your personal database and use it forever."
                                    )
                                        .font(.system(size: 13.5, weight: .regular, design: .rounded))
                                        .foregroundStyle(EditorialPalette.inkSecondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 16)

                                    if offersAIConsent {
                                        Button(action: {
                                            HapticManager.shared.impact(style: .medium)
                                            showingAIConsentSheet = true
                                        }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "sparkles")
                                                Text("Enable AI Food Search")
                                            }
                                        }
                                        .buttonStyle(EditorialPrimaryCTAButtonStyle(tone: .graphite, height: 48))
                                    }

                                    Button(action: {
                                        HapticManager.shared.impact(style: .medium)
                                        showingManualAdd = true
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Create Custom Food")
                                        }
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(EditorialPalette.inkPrimary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 48)
                                        .background(EditorialPalette.surfaceLight)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
                                        )
                                    }
                                    .buttonStyle(BounceButtonStyle())
                                }
                                .padding(.top, 32)
                            }
                        } else {
                            if filteredLocalFoods.isEmpty {
                                EmptyStateView(imageName: "tray", title: "No history", description: "Your recent meals will appear here.")
                                    .padding(.top, 60)
                            } else {
                                ForEach(Array(filteredLocalFoods.enumerated()), id: \.element.id) { index, food in
                                    FoodSearchResultRow(food: food, activeDietPlan: activeDietPlan) { selectedFoodForDetail = food }
                                        .accessibilityIdentifier("smart_add_food_row_\(index)")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, selectedFoods.isEmpty ? 40 : 120)
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
        .onAppear {
            rebuildFoodCaches()
        }
        .task {
            await LocalFoodDatabaseService.shared.waitUntilLoaded()
            if !searchText.isEmpty {
                performSearch(query: searchText)
            }
        }
        .onChange(of: pastMeals.count) { _, _ in rebuildFoodCaches() }
        .onChange(of: allDatabaseFoods.count) { _, _ in rebuildFoodCaches() }
        .onChange(of: customRecipes.count) { _, _ in rebuildFoodCaches() }
        .onChange(of: searchText) { _, newValue in performSearch(query: newValue) }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedFoods.isEmpty)
        .fullScreenCover(item: $selectedFoodForDetail) { food in
            FoodDetailNutritionView(food: food, mealTitle: mealTitle) { addedFood in
                withAnimation(.spring()) { selectedFoods.append(addedFood) }
            }
        }
        .fullScreenCover(
            isPresented: $showingScanner,
            onDismiss: {
                if let pendingFood = pendingScannerFood {
                    pendingScannerFood = nil
                    selectedFoodForDetail = pendingFood
                } else if pendingManualEntryAfterScanner {
                    pendingManualEntryAfterScanner = false
                    showingManualAdd = true
                }
            }
        ) {
            let daySummary = DailySummary.fetchExisting(for: targetDate, in: context)
            let user = users.first
            // Guideline 5.1.3(i): Menu AI prompt budget excludes HealthKit activeCaloriesBurned.
            let aiRemaining = NutritionMath.aiSafeRemainingMacros(user: user, summary: daySummary)
            SmartScannerView(
                onProductFound: { foundFood in pendingScannerFood = foundFood },
                onManualEntryRequest: { pendingManualEntryAfterScanner = true },
                remainingCalories: aiRemaining.calories,
                remainingProtein: aiRemaining.protein
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
        .sheet(isPresented: $showingAIConsentSheet) {
            AIPhotoConsentSheet(
                onAllow: {
                    AIPhotoConsentManager.shared.grantConsent()
                    if !searchText.isEmpty {
                        performSearch(query: searchText)
                    }
                },
                onDecline: {}
            )
        }
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

        apiSearchResults = []
        isSearchingAPI = trimmed.count > 2 && filteredLocalFoods.isEmpty

        searchTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(150))
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
                try await Task.sleep(for: .milliseconds(250))
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
}

struct SpeedDialItem: View {
    let icon: String
    let label: String
    let color: Color
    var iconForeground: Color = .white
    var accessibilityId: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .medium)
            action()
        }) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(EditorialPalette.cardDark)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(EditorialPalette.cardBorderDark, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.16), radius: 6, y: 3)
                
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 46, height: 46)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.20), radius: 6, y: 3)
                    
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(iconForeground)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(accessibilityId ?? "")
    }
}

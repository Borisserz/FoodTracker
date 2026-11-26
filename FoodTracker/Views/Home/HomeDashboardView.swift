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
    @State private var showingQuickAddSheet = false
    @State private var quickAddMealType = "Snack"
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
                              self.quickAddMealType = suggestedMealSlot()
                              self.showingQuickAddSheet = true
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
                                      .foregroundColor(.primary)
                              }
                              .padding(.horizontal, 16)
                              .padding(.vertical, 12)
                              .background(.ultraThinMaterial)
                              .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                              .overlay(
                                  RoundedRectangle(cornerRadius: 16, style: .continuous)
                                      .strokeBorder(Color.themePink.opacity(0.18), lineWidth: 1)
                              )
                              .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
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
                                      onQuickAdd: { self.quickAddMealType = mealType; self.showingQuickAddSheet = true }
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
                  .onChange(of: SpotlightTourManager.shared.currentStep) { _, newStep in
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
                              color: .blue,
                              accessibilityId: "speed_dial_scan_barcode"
                          ) {
                              isMenuExpanded = false
                              showingScanner = true
                          }
                          
                          SpeedDialItem(
                              icon: "fork.knife",
                              label: String(localized: "Log Meal"),
                              color: .themePink,
                              accessibilityId: "speed_dial_log_meal"
                          ) {
                              isMenuExpanded = false
                              self.mealToOpenInSmartAdd = IdentifiableString(value: "Breakfast")
                          }
                          
                          SpeedDialItem(
                              icon: "bolt.fill",
                              label: String(localized: "Quick Calories"),
                              color: .themeOrange
                          ) {
                              isMenuExpanded = false
                              showPremiumQuickAdd = true
                          }
                          
                          SpeedDialItem(
                              icon: "figure.run",
                              label: String(localized: "Log Activity"),
                              color: .green
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
                          .font(.system(size: 26, weight: .bold))
                          .foregroundColor(.white)
                          .frame(width: 64, height: 64)
                          .background(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                          .clipShape(Circle())
                          .rotationEffect(.degrees(isMenuExpanded ? 135 : 0))
                          .shadow(color: .themePink.opacity(0.4), radius: 10, y: 5)
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
              .sheet(isPresented: $showingQuickAddSheet) {
                  MealHUDQuickLogSheet(selectedDate: selectedDate, initialMealType: quickAddMealType)
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
                      await Task.yield()
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
                  let remainingCals = max(0, currentSummary.remainingCalories(userGoal: currentUser?.dailyCaloriesGoal ?? 2000))
                  let remainingProt = max(0, Int(currentUser?.targetProtein ?? 130) - Int(currentSummary.totalProtein))
                  SmartScannerView(
                      onProductFound: { foundFood in pendingScannerFood = foundFood },
                      onManualEntryRequest: { pendingManualEntryAfterScanner = true },
                      remainingCalories: remainingCals,
                      remainingProtein: remainingProt
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

    private func fetchHealthData(for targetDateInput: Date) async {
            let targetDate = Calendar.current.startOfDay(for: targetDateInput)
            let isHKEnabled = currentUser?.isHealthKitEnabled == true

            // Flush any queued widget hydration deltas (including today's when browsing a past date) as distinct HealthKit samples.
            var selectedDayPendingEntries: [Double] = []
            if isHKEnabled {
                let flushDates = HomeDashboardHealthSync.pendingWidgetWaterFlushDates(selectedDate: targetDate)
                for flushDate in flushDates {
                    let entries = WorkoutSyncManager.shared.peekPendingWidgetWaterEntriesLiters(for: flushDate)
                    if Calendar.current.isDate(flushDate, inSameDayAs: targetDate) {
                        selectedDayPendingEntries = entries
                    }
                    guard !entries.isEmpty else { continue }
                    let flushSummary = await MainActor.run {
                        SharedModelContainer.refreshMainContext(context)
                        return DailySummary.fetchOrCreate(for: flushDate, in: context)
                    }
                    let sampleDate = Calendar.current.isDateInToday(flushDate) ? Date() : flushDate
                    var attachedAny = false
                    var syncedIndices: Set<Int> = []
                    for (idx, entryLiters) in entries.enumerated() {
                        guard !Task.isCancelled else { break }
                        if let sampleUUID = await HealthKitManager.shared.saveWater(liters: entryLiters, date: sampleDate) {
                            syncedIndices.insert(idx)
                            let attached = await MainActor.run {
                                WorkoutSyncManager.attachHealthKitSampleID(sampleUUID, volumeLiters: entryLiters, to: flushSummary)
                            }
                            if attached { attachedAny = true }
                        }
                    }
                    if !syncedIndices.isEmpty {
                        await MainActor.run {
                            WorkoutSyncManager.shared.acknowledgePendingWidgetWaterEntries(
                                syncedIndices: syncedIndices,
                                for: flushDate
                            )
                            if attachedAny {
                                try? context.save()
                            }
                        }
                    }
                }
            }

            let existingSummary = await MainActor.run {
                DailySummary.fetchExisting(for: targetDate, in: context)
            }
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
                } catch { print("Steps error: \(error)") }

                do {
                    hkTotalActiveCals = try await HealthKitManager.shared.fetchTotalActiveCalories(for: targetDate)
                } catch { print("Health cals error: \(error)") }

                do {
                    hkWorkoutBreakdown = try await HealthKitManager.shared.fetchExternalWorkoutBreakdown(for: targetDate)
                } catch { print("HK workout cals error: \(error)") }

                if Calendar.current.isDateInToday(targetDate),
                   let hkSample = try? await HealthKitManager.shared.fetchLatestBodyMassSample() {
                    await MainActor.run {
                        guard let user = currentUser else { return }
                        let existingLogs = (try? context.fetch(FetchDescriptor<WeightLog>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
                        let sameDayLog = existingLogs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: targetDate) })
                        if HealthKitWeightSyncHelper.shouldImportHealthKitWeight(
                            latestHKWeightKg: hkSample.kg,
                            currentUserWeightKg: user.weight,
                            existingSameDayLogWeightKg: sameDayLog?.weight,
                            latestHKSampleDate: hkSample.date,
                            latestLocalLogDate: existingLogs.first?.date
                        ) {
                            NutritionMath.recordWeight(
                                hkSample.kg,
                                date: targetDate,
                                for: user,
                                in: context,
                                recalculateUserGoals: true,
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

            await MainActor.run {
                let persistedSummary = existingSummary ?? DailySummary.fetchOrCreate(for: targetDate, in: context)
                let waterOutcome = WorkoutSyncManager.shared.reconcileWaterWithOutcome(for: persistedSummary, in: context)
                var needsSave = waterOutcome.mutated

                if isHKEnabled && !waterOutcome.deletedHealthKitSamples.isEmpty {
                    let deletedSamples = waterOutcome.deletedHealthKitSamples
                    let container = context.container
                    Task { @MainActor in
                        for sample in deletedSamples {
                            await HealthKitManager.shared.deleteWaterSample(
                                idString: sample.sampleID,
                                litersFallback: sample.volumeMl / 1000.0,
                                date: targetDate
                            )
                            if sample.replacementVolumeMl > 0,
                               let uuid = await HealthKitManager.shared.saveWater(
                                   liters: sample.replacementVolumeMl / 1000.0,
                                   date: targetDate
                               ),
                               let beverageID = sample.beverageID,
                               let surviving = (persistedSummary.beverages ?? []).first(where: { $0.persistentModelID == beverageID }) {
                                surviving.healthKitSampleID = uuid.uuidString
                                try? container.mainContext.save()
                            }
                        }
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
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            switch step {
            case .streakFire:
                proxy.scrollTo("header_streak", anchor: .top)
            case .macroRings:
                proxy.scrollTo("macro_rings", anchor: .center)
            case .fastingWater:
                proxy.scrollTo("hydration_card", anchor: .center)
            case .addMeal, .aiChef:
                break
            }
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

        var manager = NutritionProgressManager(user: user)
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
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.themePink)
                                    .frame(width: 44, height: 44)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
                            }
                            .accessibilityLabel("Copy Meal")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)

                    if let copiedFeedbackText {
                        Text(copiedFeedbackText)
                            .font(.caption.bold())
                            .foregroundColor(.green)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(title))
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

                    if let meal = meal, let items = meal.foodItems, !items.isEmpty {
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
                                        Divider().padding(.leading, 20)
                                    }
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
                        }
                        .padding(.horizontal)
                        
                        if (meal.foodItems ?? []).count > 2 {
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
                                                .animation(reduceMotion ? nil : .easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isGeneratingRecipe)
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
                Text(LocalizedStringKey(title)).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.primary)
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

struct ActionSearchBar: View {
    @Binding var text: String
    var onBarcodeTap: () -> Void
    var onManualAddTap: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            // Dual Action Fast Deck: Scan & Custom Food
            HStack(spacing: 10) {
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    onBarcodeTap()
                }) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(red: 0.10, green: 0.72, blue: 0.50).opacity(0.14))
                                .frame(width: 32, height: 32)
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color(red: 0.10, green: 0.72, blue: 0.50))
                        }
                        VStack(alignment: .leading, spacing: 1) {
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
                .buttonStyle(BounceButtonStyle())

                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    onManualAddTap()
                }) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(red: 0.95, green: 0.70, blue: 0.30).opacity(0.14))
                                .frame(width: 32, height: 32)
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color(red: 0.95, green: 0.70, blue: 0.30))
                        }
                        VStack(alignment: .leading, spacing: 1) {
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
                .buttonStyle(BounceButtonStyle())
            }

            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 15, weight: .medium))
                TextField(String(localized: "Search foods..."), text: $text)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
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
            }
            .accessibilityIdentifier("smart_add_confirm_cart_button")
            .padding(.horizontal, 20).padding(.bottom, 30)
        }
    }
}

struct FoodSearchResultRow: View {
    let food: FoodItem
    var activeDietPlan: DietPlan? = nil
    let action: () -> Void

    var body: some View {
        let compatibility = food.compatibility(with: activeDietPlan)

        Button(action: action) {
            HStack(spacing: 16) {

                ZStack {
                    Circle()
                        .fill(Color.themeBg.opacity(0.8))
                        .frame(width: 48, height: 48)
                    Text("🍲")
                        .font(.system(size: 24))

                    if compatibility != .neutral {
                        Image(systemName: compatibility.icon)
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(compatibility.color)
                            .padding(4)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 3)
                            .offset(x: 16, y: 16)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(compatibility == .avoid ? .gray : .primary)
                        .strikethrough(compatibility == .avoid, color: .red.opacity(0.5))

                    HStack(spacing: 6) {
                        let weightLabel = food.weight > 0 ? "\(Int(food.weight))g" : String(localized: "1 serving")
                        Text("\(food.calories) kcal • \(weightLabel)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)

                        if compatibility == .perfect {
                            Text("Great option")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.08))
                                .cornerRadius(6)
                        } else if compatibility == .avoid {
                            Text("Avoid")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.08))
                                .cornerRadius(6)
                        }
                    }
                }
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(compatibility == .avoid ? Color.gray.opacity(0.1) : Color.themePink.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(compatibility == .avoid ? .gray : .themePink)
                }
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        compatibility == .avoid ? Color.red.opacity(0.15) :
                        (compatibility == .perfect ? Color.green.opacity(0.15) : Color.gray.opacity(0.08)),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.015), radius: 6, x: 0, y: 3)
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
        ScrollView(showsIndicators: false) {
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
                        let persisted = summary.modelContext != nil
                            ? summary
                            : DailySummary.fetchOrCreate(for: summary.date, in: context)
                        persisted.dayNote = draftNote
                        persisted.dayMoodEmoji = draftMoodEmoji
                        try? context.save()
                        clearAIMoodStates()
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.themePink)
                }
                .padding(.horizontal, 24)

                TextField("Write about your meals, feelings, or workouts...", text: $draftNote, axis: .vertical)
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
                                        if draftMoodEmoji == mood.0 {
                                            draftMoodEmoji = ""
                                            clearAIMoodStates()
                                        } else {
                                            draftMoodEmoji = mood.0
                                            clearAIMoodStates() // prevent stale chat state from previous mood

                                            // Trigger AI Advice popup with a small delay for nice animation feel
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
                                    VStack(spacing: 8) {
                                        Text(mood.0)
                                            .font(.system(size: 30))
                                            .frame(minWidth: 52, minHeight: 52)
                                            .background(draftMoodEmoji == mood.0 ? Color.themePink.opacity(0.2) : Color.white)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(draftMoodEmoji == mood.0 ? Color.themePink : Color.gray.opacity(0.2), lineWidth: 2)
                                            )
                                            .cornerRadius(20)

                                        Text(LocalizedStringKey(mood.1))
                                            .font(.caption)
                                            .fontWeight(draftMoodEmoji == mood.0 ? .bold : .medium)
                                            .foregroundColor(draftMoodEmoji == mood.0 ? .themePink : .gray)
                                    }
                                    .frame(minWidth: 64, minHeight: 80) // Ensure good tap target per HIG (44pt minimum)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityLabel(Text("\(String(localized: String.LocalizationValue(mood.1))) mood"))
                                .accessibilityValue(draftMoodEmoji == mood.0 ? String(localized: "Selected") : String(localized: "Not selected"))
                                .accessibilityAddTraits(.isButton)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 10)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.themeBg.ignoresSafeArea())
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
                    hydrationLiters: summary.totalPureWaterLiters,
                    activeCaloriesBurned: summary.activeCaloriesBurned
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

                    let activeMeals = (summary.meals ?? []).filter { !($0.foodItems ?? []).isEmpty }
                    let loggedActivities = summary.activities ?? []

                    if let copiedBannerText {
                        Text(copiedBannerText)
                            .font(.caption.bold())
                            .foregroundColor(.green)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    if activeMeals.isEmpty && loggedActivities.isEmpty {
                        EmptyStateView(imageName: "doc.text.magnifyingglass", title: "No Food Logged", description: "You haven't logged any food for this day yet.")
                            .padding(.top, 40)
                    } else {
                        ForEach(activeMeals) { meal in
                            VStack(alignment: .leading, spacing: 0) {

                                HStack {
                                    Text(LocalizedStringKey(meal.title))
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
                                    ForEach(meal.foodItems ?? []) { food in
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

                                        if food.id != meal.foodItems?.last?.id {
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

                        if !loggedActivities.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text("Logged Activities")
                                        .font(.title3.bold())
                                    Spacer()
                                    Text("\(summary.localActivityCalories) kcal")
                                        .font(.headline)
                                        .foregroundColor(.themeOrange)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .padding(.bottom, 12)

                                VStack(spacing: 0) {
                                    ForEach(loggedActivities) { activity in
                                        HStack(spacing: 14) {
                                            Image(systemName: activity.icon)
                                                .font(.title3)
                                                .foregroundColor(.themeOrange)
                                                .frame(width: 40, height: 40)
                                                .background(Color.themeOrange.opacity(0.12))
                                                .clipShape(Circle())
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(LocalizedStringKey(activity.title))
                                                    .font(.subheadline.bold())
                                                Text("\(activity.durationMinutes) min")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Text("-\(activity.calories) kcal")
                                                .font(.subheadline.bold())
                                                .foregroundColor(.themeOrange)
                                            Button {
                                                HapticManager.shared.impact(style: .medium)
                                                deleteActivity(activity)
                                            } label: {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.red.opacity(0.8))
                                                    .padding(.leading, 8)
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        if activity.persistentModelID != loggedActivities.last?.persistentModelID {
                                            Divider().padding(.leading, 74)
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
                            .foregroundColor(.themePink)
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
        !isSearching
            && !hasAnyResults
            && !hasConsented
            && query.trimmingCharacters(in: .whitespacesAndNewlines).count > 2
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
            return cachedAvailableFoods.filter { (cachedFoodCounts[$0.name] ?? 0) >= 2 && $0.name != "Quick Entry" }
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

        for meal in pastMeals {
            for item in meal.foodItems ?? [] {
                counts[item.name, default: 0] += 1
                if seenNames.insert(item.name).inserted {
                    results.append(item)
                }
            }
        }
        for item in allDatabaseFoods {
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
            Color.themeBg.ignoresSafeArea()

            VStack(spacing: 0) {

                VStack(spacing: 16) {
                    Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 10)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey(mealTitle)).font(.system(size: 28, weight: .bold, design: .rounded))
                            Text("What did you eat?").font(.subheadline).foregroundColor(.gray)
                        }
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundColor(Color.gray.opacity(0.3))
                        }
                    }.padding(.horizontal, 20)

                    ActionSearchBar(
                        text: $searchText,
                        onBarcodeTap: { showingScanner = true },
                        onManualAddTap: { showingManualAdd = true }
                    )
                    .padding(.horizontal, 20)

                    if searchText.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(categories, id: \.self) { category in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selectedCategory = category }
                                        HapticManager.shared.impact(style: .light)
                                    }) {
                                        Text(LocalizedStringKey(category))
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 18).padding(.vertical, 10)
                                            .background(selectedCategory == category ? ThemeManager.shared.current.primaryGradient : LinearGradient(colors: [Color.white], startPoint: .top, endPoint: .bottom))
                                            .foregroundColor(selectedCategory == category ? .white : .primary)
                                            .cornerRadius(18)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18)
                                                    .stroke(selectedCategory == category ? Color.clear : Color.gray.opacity(0.12), lineWidth: 1)
                                            )
                                            .shadow(color: selectedCategory == category ? ThemeManager.shared.current.primaryAccent.opacity(0.2) : Color.black.opacity(0.015), radius: 5, y: 2)
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
                            if !filteredLocalFoods.isEmpty {
                                Text("From your history").font(.caption.bold()).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading)
                                ForEach(filteredLocalFoods, id: \.id) { food in
                                    FoodSearchResultRow(food: food, activeDietPlan: activeDietPlan) { selectedFoodForDetail = food }
                                }
                            }

                            if !localCatalogResults.isEmpty {
                                Text("Local database").font(.caption.bold()).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)
                                ForEach(localCatalogResults, id: \.id) { food in
                                    FoodSearchResultRow(food: food, activeDietPlan: activeDietPlan) { selectedFoodForDetail = food }
                                }
                            }

                            if !apiSearchResults.isEmpty {
                                Text("Global database").font(.caption.bold()).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)
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
                                VStack(spacing: 16) {
                                    Image(systemName: offersAIConsent ? "sparkles.rectangle.stack.fill" : "questionmark.folder.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(offersAIConsent ? .themePink.opacity(0.75) : .themeOrange.opacity(0.5))
                                    Text("Can't find '\(searchText)'?").font(.headline)
                                    Text(
                                        offersAIConsent
                                            ? "Enable AI Food Search to estimate calories and macros for unlisted dishes, or create a custom entry."
                                            : "No worries! You can quickly add it to your personal database and use it forever."
                                    )
                                        .font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal, 20)

                                    if offersAIConsent {
                                        Button(action: {
                                            HapticManager.shared.impact(style: .medium)
                                            showingAIConsentSheet = true
                                        }) {
                                            HStack {
                                                Image(systemName: "sparkles")
                                                Text("Enable AI Food Search")
                                            }
                                            .font(.headline).foregroundColor(.white).padding(.vertical, 14).padding(.horizontal, 24)
                                            .background(ThemeManager.shared.current.primaryGradient)
                                            .cornerRadius(20).shadow(color: ThemeManager.shared.current.primaryAccent.opacity(0.3), radius: 8, y: 4)
                                        }
                                        .buttonStyle(BounceButtonStyle())
                                    }

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
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.08), radius: 5, y: 2)
                
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 48, height: 48)
                        .shadow(color: color.opacity(0.35), radius: 5, y: 3)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(accessibilityId ?? "")
    }
}

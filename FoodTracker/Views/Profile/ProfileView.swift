import SwiftUI
import SwiftData
import Charts
import FirebaseAuth
import UserNotifications
import AuthenticationServices

struct ProfileWrapperView: View {
    @Query private var users: [User]

    var body: some View {
        if let user = users.first {
            ProfileView(user: user)
        } else {

            VStack {
                ProgressView()
                Text("Loading Profile...")
            }
            .navigationTitle("Profile")
        }
    }
}

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Environment(DIContainer.self) private var di
    @Environment(ThemeManager.self) private var themeManager
    @Bindable var user: User

    @State private var viewModel: ProfileViewModel?
    @AppStorage("useMetricSystem") private var useMetricSystem = true

    @State private var showingEditProfile = false
    @State private var showingNutritionSettings = false
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            ProfileBreathingBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .foregroundStyle(themeManager.current.primaryGradient)
                            .shadow(color: themeManager.current.primaryAccent.opacity(0.3), radius: 10, y: 5)

                        VStack(spacing: 4) {
                            Text(user.name)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            
                            let progressManager = NutritionProgressManager(user: user)
                            Text(progressManager.currentTitle)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.themeOrange)
                            
                            Text("Active Goal: \(user.dailyCaloriesGoal) kcal")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        NutritionLevelProgressBar(progressManager: NutritionProgressManager(user: user))
                            .padding(.vertical, 8)

                        Button(action: { showingEditProfile = true }) {
                        Text("Edit Profile")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(themeManager.current.primaryAccent)
                            .clipShape(Capsule())
                            .shadow(color: themeManager.current.primaryAccent.opacity(0.3), radius: 5, y: 3)
                    }
                    .buttonStyle(BounceButtonStyle())

                    HStack(spacing: 0) {
                        ProfileStatItem(
                            value: String(format: "%.1f", NutritionMath.displayWeight(user.weight, useMetric: useMetricSystem)),
                            unit: NutritionMath.weightUnit(useMetric: useMetricSystem),
                            title: "Weight"
                        )
                        Divider().frame(height: 40)
                        ProfileStatItem(
                            value: "\(NutritionMath.displayHeight(user.height, useMetric: useMetricSystem))",
                            unit: NutritionMath.heightUnit(useMetric: useMetricSystem),
                            title: "Height"
                        )
                        Divider().frame(height: 40)
                        ProfileStatItem(value: "\(user.age)", unit: "y.o", title: "Age")
                    }
                    .padding(.top, 8)
                }
                .premiumCardStyle()
                
                let heightM = user.height / 100.0
                let bmi = heightM > 0 ? user.weight / (heightM * heightM) : 0
                BMICardView(bmi: bmi)

                NutritionMethodologyDisclaimerView(citations: [.bmi, .bmrAndTdee], compact: true)

                Button(action: { showingNutritionSettings = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nutrition Targets")
                                .font(.headline)
                                .foregroundColor(.primary)

                            HStack(spacing: 12) {
                                MacroDotLabel(color: .themePeach, title: "P: \(Int(user.targetProtein))g")
                                MacroDotLabel(color: .themeYellow, title: "F: \(Int(user.targetFats))g")
                                MacroDotLabel(color: .drinkWater, title: "C: \(Int(user.targetCarbs))g")
                            }
                        }
                        Spacer()
                        Image(systemName: "chart.pie.fill")
                            .font(.title2)
                            .foregroundColor(themeManager.current.primaryAccent)
                            .padding(12)
                            .background(themeManager.current.primaryAccent.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .premiumCardStyle()
                }
                .buttonStyle(BounceButtonStyle())

                DailyXPQuestsCardView(user: user)

                StreakCardView(streak: viewModel?.currentStreak ?? 0)

                NutritionAchievementsCarousel(user: user)

            }
            .padding(20)
            .padding(.bottom, 40)
        }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.gray)
                }
                .accessibilityIdentifier("profile_settings_button")
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileSheet(user: user)
        }
        .sheet(isPresented: $showingNutritionSettings) {
            NutritionSettingsEditor(user: user)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(user: user)
        }
        .onAppear {
            NutritionProgressManager(user: user).syncLevel()
            if viewModel == nil {
                viewModel = di.makeProfileViewModel()
            }
            viewModel?.loadData()
        }
    }
}

struct EditProfileSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var user: User
    @AppStorage("useMetricSystem") private var useMetricSystem = true

    @State private var name: String
    @State private var weight: Double
    @State private var height: Double
    @State private var age: Int
    @State private var gender: String
    @State private var activityMultiplier: Double

    private let activityOptions: [(label: String, value: Double)] = [
        ("Sedentary", 1.2),
        ("Light", 1.375),
        ("Moderate", 1.55),
        ("Active", 1.725)
    ]

    init(user: User) {
        self._user = Bindable(user)
        _name = State(initialValue: user.name)
        _weight = State(initialValue: user.weight)
        _height = State(initialValue: user.height)
        _age = State(initialValue: user.age)
        _gender = State(initialValue: user.gender == "Female" ? "Female" : "Male")
        let validMultipliers = [1.2, 1.375, 1.55, 1.725]
        let closest = validMultipliers.min(by: { abs($0 - user.activityMultiplier) < abs($1 - user.activityMultiplier) }) ?? 1.375
        _activityMultiplier = State(initialValue: user.activityMultiplier > 0 ? closest : 1.375)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Details") {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Name", text: $name).multilineTextAlignment(.trailing).foregroundColor(.gray)
                    }
                    Picker("Biological Sex", selection: $gender) {
                        Text("Male").tag("Male")
                        Text("Female").tag("Female")
                    }
                    Stepper("Age: \(age) years", value: $age, in: 10...100)
                }

                Section {
                    Stepper(
                        "Height: \(NutritionMath.displayHeight(height, useMetric: useMetricSystem)) \(NutritionMath.heightUnit(useMetric: useMetricSystem))",
                        value: $height.heightDisplayBinding(useMetric: useMetricSystem),
                        in: useMetricSystem ? 100...250 : 39...98
                    )
                    Stepper(
                        "Weight: \(NutritionMath.formattedWeight(weight, useMetric: useMetricSystem))",
                        value: $weight.weightDisplayBinding(useMetric: useMetricSystem),
                        in: useMetricSystem ? 30...250 : 66...550,
                        step: useMetricSystem ? 0.1 : 0.5
                    )
                    Picker("Activity Level", selection: $activityMultiplier) {
                        ForEach(activityOptions, id: \.value) { option in
                            Text(String(localized: String.LocalizationValue(option.label))).tag(option.value)
                        }
                    }
                } header: {
                    Text("Body Metrics")
                } footer: {
                    Text("Updating these metrics will automatically recalculate your recommended daily calorie goal.")
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }.bold().foregroundColor(.themePink)
                }
            }
        }
    }

    private func saveChanges() {
        HapticManager.shared.impact(style: .medium)
        let previousCalories = user.dailyCaloriesGoal
        let weightChanged = abs(user.weight - weight) > 0.01

        user.name = name
        user.weight = weight
        user.height = height
        user.age = age
        user.gender = gender
        user.activityMultiplier = activityMultiplier
        user.calculateGoals()
        user.recalculateMacrosPreservingRatios(fromPreviousCalories: previousCalories)

        if weightChanged {
            NutritionMath.recordWeight(weight, date: Date(), for: user, in: context, recalculateUserGoals: false)
        } else {
            try? context.save()
            WidgetReloader.reloadAll()
        }
    }
}

struct NutritionSettingsEditor: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var user: User

    @State private var dailyCals: Int
    @State private var pPct: Double
    @State private var fPct: Double
    @State private var cPct: Double

    init(user: User) {
        self._user = Bindable(user)
        let cals = user.dailyCaloriesGoal
        _dailyCals = State(initialValue: cals)
        let normalized = Self.normalizedInitialPercentages(
            dailyCalories: cals,
            proteinGrams: user.targetProtein,
            fatGrams: user.targetFats,
            carbsGrams: user.targetCarbs
        )
        _pPct = State(initialValue: normalized.protein)
        _fPct = State(initialValue: normalized.fat)
        _cPct = State(initialValue: normalized.carbs)
    }

    static func normalizedInitialPercentages(
        dailyCalories: Int,
        proteinGrams: Double,
        fatGrams: Double,
        carbsGrams: Double
    ) -> (protein: Double, fat: Double, carbs: Double) {
        let totalCals = Double(dailyCalories > 0 ? dailyCalories : 1)
        let rawP = max(0, (proteinGrams * 4.0 / totalCals) * 100.0)
        let rawF = max(0, (fatGrams * 9.0 / totalCals) * 100.0)
        let rawC = max(0, (carbsGrams * 4.0 / totalCals) * 100.0)

        if rawP + rawF <= 100.0 {
            return (rawP, rawF, max(0, 100.0 - rawP - rawF))
        }

        let sum = rawP + rawF + rawC
        guard sum > 0 else { return (30, 30, 40) }
        let p = (rawP / sum) * 100.0
        let f = (rawF / sum) * 100.0
        let c = max(0, 100.0 - p - f)
        return (p, f, c)
    }

    private var isBalanced: Bool { Int((pPct + fPct + cPct).rounded()) == 100 }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.themeBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 8) {
                            Text("Daily Calories").foregroundColor(.gray)
                            HStack {
                                Button(action: { adjustCals(-50) }) { Image(systemName: "minus.circle.fill").font(.title).foregroundColor(.gray.opacity(0.3)) }
                                Text("\(dailyCals)").font(.system(size: 48, weight: .heavy, design: .rounded)).frame(width: 140).contentTransition(.numericText())
                                Button(action: { adjustCals(50) }) { Image(systemName: "plus.circle.fill").font(.title).foregroundColor(.themePink) }
                            }
                        }.padding(.top, 20)

                        ZStack {
                            Chart {
                                SectorMark(angle: .value("Carbs", cPct), innerRadius: .ratio(0.75), angularInset: 2).foregroundStyle(Color.drinkWater.gradient)
                                SectorMark(angle: .value("Fat", fPct), innerRadius: .ratio(0.75), angularInset: 2).foregroundStyle(Color.themeYellow.gradient)
                                SectorMark(angle: .value("Protein", pPct), innerRadius: .ratio(0.75), angularInset: 2).foregroundStyle(Color.themePeach.gradient)
                            }
                            VStack {
                                Text("\(Int((pPct + fPct + cPct).rounded()))%").font(.title.bold()).foregroundColor(isBalanced ? .primary : .red)
                                Text(isBalanced ? "Balanced" : "Adjust to 100%").font(.caption).foregroundColor(isBalanced ? .gray : .red)
                            }
                        }.frame(height: 220)

                        VStack(spacing: 24) {
                            MacroAdjusterRow(title: "Protein", color: .themePeach, pct: $pPct, grams: calculateGrams(pct: pPct, multiplier: 4), onAdjust: { adjustMacros(changed: .protein) })
                            MacroAdjusterRow(title: "Fat", color: .themeYellow, pct: $fPct, grams: calculateGrams(pct: fPct, multiplier: 9), onAdjust: { adjustMacros(changed: .fat) })
                            MacroAdjusterRow(title: "Carbs", color: .drinkWater, pct: $cPct, grams: calculateGrams(pct: cPct, multiplier: 4), onAdjust: { adjustMacros(changed: .carbs) })
                        }.padding(20).background(Color.white).cornerRadius(24).shadow(color: .black.opacity(0.04), radius: 10, y: 5).padding(.horizontal, 20)

                        NutritionMethodologyDisclaimerView(
                            citations: [.bmrAndTdee, .dietaryGuidelines],
                            compact: true
                        )
                        .padding(.horizontal, 20)

                        Spacer().frame(height: 100)
                    }
                }

                Button(action: saveSettings) {
                    Text("Save Plan").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 18).background(isBalanced ? Color.themePink : Color.gray).cornerRadius(24)
                }
                .disabled(!isBalanced).padding(.horizontal, 24).padding(.bottom, 30).buttonStyle(BounceButtonStyle())
            }
            .navigationTitle("Nutrition Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func adjustCals(_ amount: Int) { withAnimation { dailyCals = max(1000, dailyCals + amount) } }
    private func calculateGrams(pct: Double, multiplier: Double) -> Int { Int((Double(dailyCals) * (pct / 100)) / multiplier) }

    enum MacroType { case protein, fat, carbs }

    static func rebalanceMacroPercentages(
        protein: Double,
        fat: Double,
        carbs: Double,
        changed: MacroType
    ) -> (protein: Double, fat: Double, carbs: Double) {
        var p = min(100, max(0, protein))
        var f = min(100, max(0, fat))
        var c = min(100, max(0, carbs))
        var diff = (p + f + c) - 100.0
        guard abs(diff) > 1e-6 else { return (p, f, c) }

        func apply(_ delta: inout Double, to value: inout Double) {
            if delta > 0 {
                let take = min(value, delta)
                value -= take
                delta -= take
            } else if delta < 0 {
                let room = 100.0 - value
                let add = min(room, -delta)
                value += add
                delta += add
            }
        }

        switch changed {
        case .protein:
            apply(&diff, to: &c)
            apply(&diff, to: &f)
        case .fat:
            apply(&diff, to: &c)
            apply(&diff, to: &p)
        case .carbs:
            apply(&diff, to: &p)
            apply(&diff, to: &f)
        }
        return (min(100, max(0, p)), min(100, max(0, f)), min(100, max(0, c)))
    }

    private func adjustMacros(changed: MacroType) {
        let balanced = Self.rebalanceMacroPercentages(protein: pPct, fat: fPct, carbs: cPct, changed: changed)
        pPct = balanced.protein
        fPct = balanced.fat
        cPct = balanced.carbs
    }

    private func saveSettings() {
        user.dailyCaloriesGoal = dailyCals

        let fInt = Int(fPct.rounded())
        let pInt = Int(pPct.rounded())
        let cInt = max(0, 100 - fInt - pInt)
        user.applyDietBreakdown(fatPercent: fInt, proteinPercent: pInt, carbsPercent: cInt, dietKey: "custom")
        try? context.save()
        WidgetReloader.reloadAll()
        dismiss()
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppStateManager.self) private var appState
    @Bindable var user: User

    @AppStorage("useMetricSystem") private var useMetricSystem = true
    @State private var consentManager = AIPhotoConsentManager.shared
    @State private var showLegalOptions = false
    @State private var exportErrorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        VStack(spacing: 0) {
                            NavigationLink(destination: AccountSettingsView(user: user)) {
                                SettingsRowView(icon: "person.fill", iconColor: themeManager.current.primaryAccent, title: "Account")
                            }
                            .accessibilityIdentifier("settings_account_row")
                            Divider().padding(.leading, 56)

                            NavigationLink(destination: RemindersSettingsView()) {
                                SettingsRowView(icon: "bell.fill", iconColor: .themeYellow, title: "Reminders")
                            }
                            Divider().padding(.leading, 56)

                            NavigationLink(destination: AppleHealthSettingsView(user: user)) {
                                SettingsRowView(icon: "heart.fill", iconColor: .red, title: "Apple Health")
                            }
                            Divider().padding(.leading, 56)

                            NavigationLink(destination: AIPhotoPrivacySettingsView()) {
                                SettingsRowView(
                                    icon: "hand.raised.fill",
                                    iconColor: .indigo,
                                    title: "AI Photo Privacy",
                                    value: consentManager.hasConsented ? String(localized: "Enabled") : String(localized: "Off")
                                )
                            }
                            Divider().padding(.leading, 56)

                            NavigationLink(destination: UnitsSettingsView(useMetric: $useMetricSystem)) {
                                SettingsRowView(
                                    icon: "ruler.fill",
                                    iconColor: .blue,
                                    title: "Units settings",
                                    value: useMetricSystem ? String(localized: "Metric") : String(localized: "Imperial")
                                )
                            }
                            Divider().padding(.leading, 56)
                            
                            NavigationLink(destination: ThemeSettingsView()) {
                                SettingsRowView(
                                    icon: "paintpalette.fill",
                                    iconColor: themeManager.current.secondaryAccent,
                                    title: "App Theme",
                                    value: String(localized: String.LocalizationValue(themeManager.current.name))
                                )
                            }
                            Divider().padding(.leading, 56)

                            Button(action: {
                                dismiss()
                                appState.selectedTab = 0
                                appState.requestSpotlightTourRestart()
                            }) {
                                SettingsRowView(icon: "sparkles", iconColor: .cyan, title: "Interactive Feature Tour")
                            }
                            Divider().padding(.leading, 56)

                            Button(action: { exportData() }) {
                                SettingsRowView(icon: "square.and.arrow.up.fill", iconColor: .green, title: "Export Data to CSV")
                            }
                        }
                        .premiumCardStyle()
                        .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            Button(action: { rateApp() }) {
                                SettingsRowView(icon: "star.fill", iconColor: .themeOrange, title: "Rate the app")
                            }
                            Divider().padding(.leading, 56)

                            Button(action: { contactSupport() }) {
                                SettingsRowView(icon: "questionmark.circle.fill", iconColor: .green, title: "Help")
                            }
                            Divider().padding(.leading, 56)

                            Button(action: { showLegalOptions = true }) {
                                SettingsRowView(icon: "doc.text.fill", iconColor: .gray, title: "Terms of Service & Privacy")
                            }
                            .confirmationDialog(
                                "Terms of Service & Privacy",
                                isPresented: $showLegalOptions,
                                titleVisibility: .visible
                            ) {
                                Button("Privacy Policy") {
                                    UIApplication.shared.open(Constants.Legal.privacyPolicyURL)
                                }
                                Button("Terms of Use") {
                                    UIApplication.shared.open(Constants.Legal.eulaURL)
                                }
                                Button("Cancel", role: .cancel) {}
                            }
                        }
                        .premiumCardStyle()
                        .padding(.horizontal, 20)

                        VStack(spacing: 4) {
                            Text("version \(appVersionString)")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .textCase(.lowercase)

                            Text("Made with ❤️ for your health")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                "Export Failed",
                isPresented: Binding(
                    get: { exportErrorMessage != nil },
                    set: { if !$0 { exportErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { exportErrorMessage = nil }
            } message: {
                Text(exportErrorMessage ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
            }
        }
    }
    
    private func exportData() {
        do {
            let summaries = try context.fetch(
                FetchDescriptor<DailySummary>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            )
            let weightLogs = try context.fetch(
                FetchDescriptor<WeightLog>(sortBy: [SortDescriptor(\.date, order: .forward)])
            )
            let fileURL = try DataExportService.generateCSV(from: summaries, weightLogs: weightLogs)
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                exportErrorMessage = String(localized: "Unable to open the share sheet right now. Please try again.")
                return
            }

            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }

            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            topVC.present(activityVC, animated: true)
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func rateApp() {
        HapticManager.shared.impact(style: .medium)
        AppReviewManager.openAppStoreReview()
    }

    private var appVersionString: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    private func contactSupport() {
        HapticManager.shared.impact(style: .medium)
        UIApplication.shared.open(Constants.Legal.supportURL)
    }
}

struct SettingsRowView: View {
    let icon: String
    let iconColor: Color
    let title: LocalizedStringKey
    var value: String? = nil

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.primary)

            Spacer()

            if let value = value {
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray.opacity(0.4))
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct AccountSettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var loggedDaysCount = 0
    let user: User

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showDeleteConfirmation = false
    @State private var showSignOutConfirmation = false

    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()

            VStack(spacing: 24) {

                VStack(alignment: .leading, spacing: 16) {
                    AccountInfoRow(title: "User ID", value: String(authManager.currentUserId.prefix(8)))
                    Divider()
                    AccountInfoRow(title: "Account type", value: authManager.isAnonymous ? String(localized: "Guest") : String(localized: "Registered"), valueColor: authManager.isAnonymous ? .gray : .themePink)
                    Divider()
                    if !authManager.isAnonymous, let email = authManager.currentUserEmail {
                        AccountInfoRow(title: "Email", value: email)
                    } else {
                        AccountInfoRow(title: "Total logged days", value: "\(loggedDaysCount)")
                    }
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .task {
                    loggedDaysCount = (try? context.fetchCount(FetchDescriptor<DailySummary>())) ?? 0
                }

                Spacer()

                VStack(spacing: 16) {
                    if authManager.isAnonymous {
                        SignInWithAppleButton(.signIn) { request in
                            SocialAuthService.shared.prepareAppleRequest(request)
                        } onCompletion: { result in
                            Task {
                                isLoading = true
                                defer { isLoading = false }
                                do {
                                    try await SocialAuthService.shared.handleAppleAuthorization(result)
                                } catch {
                                    if !SocialAuthService.isCancellationError(error) {
                                        errorMessage = error.localizedDescription
                                        showError = true
                                    }
                                }
                            }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        Button(action: {
                            Task {
                                isLoading = true
                                defer { isLoading = false }
                                do {
                                    try await SocialAuthService.shared.signInWithGoogle()
                                } catch {
                                    if !SocialAuthService.isCancellationError(error) {
                                        errorMessage = error.localizedDescription
                                        showError = true
                                    }
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                Text("Sign in with Google")
                            }
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
                        }
                        .buttonStyle(BounceButtonStyle())
                    } else {
                        Button(action: {
                            showSignOutConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Log out")
                            }
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
                        }
                        .buttonStyle(BounceButtonStyle())
                        .confirmationDialog(
                            "Log out of your account?",
                            isPresented: $showSignOutConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Log out", role: .destructive) {
                                Task {
                                    isLoading = true
                                    do {
                                        try await SocialAuthService.shared.signOut()
                                        LocalDataResetService.wipeAllData(in: context)
                                        dismiss()
                                    } catch {
                                        errorMessage = error.localizedDescription
                                        showError = true
                                    }
                                    isLoading = false
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Signing out switches to a fresh guest session and clears local device records so personal data is not shared across accounts.")
                        }
                    }

                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete account")
                        }
                        .font(.headline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(20)
                    }
                    .buttonStyle(BounceButtonStyle())
                    .accessibilityIdentifier("profile_delete_account_button")
                    .confirmationDialog(
                        "Delete account and all local data?",
                        isPresented: $showDeleteConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Delete Account", role: .destructive) {
                            isLoading = true
                            Task {
                                defer { isLoading = false }
                                // Let the confirmation dialog finish dismissing before presenting Google/Apple auth.
                                try? await Task.sleep(for: .milliseconds(250))
                                do {
                                    try await AuthManager.runDeletionSequence(
                                        reauthenticate: { try await SocialAuthService.shared.reauthenticateForDeletion() },
                                        deleteAccount: { try await authManager.deleteCurrentUser() },
                                        revokeAppleToken: { code in
                                            try await SocialAuthService.shared.revokeAppleAuthorizationCode(code)
                                        }
                                    )
                                    LocalDataResetService.wipeAllData(in: context)
                                    _ = try? await AnonymousAuthBootstrap.shared.ensureSignedIn()
                                    dismiss()
                                } catch let deletionError as AccountDeletionError {
                                    if case .appleTokenRevocationFailed = deletionError {
                                        // Server account deletion already succeeded; still wipe local state,
                                        // then surface the revocation warning so the user can revoke in iOS Settings.
                                        LocalDataResetService.wipeAllData(in: context)
                                        _ = try? await AnonymousAuthBootstrap.shared.ensureSignedIn()
                                    }
                                    errorMessage = deletionError.localizedDescription
                                    showError = true
                                } catch {
                                    if !SocialAuthService.isCancellationError(error) {
                                        errorMessage = error.localizedDescription
                                        showError = true
                                    }
                                }
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text(AccountDeletionDialogCopy.confirmationMessage(isAnonymous: authManager.isAnonymous))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            if isLoading {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView().controlSize(.large).tint(.white)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(errorMessage ?? "Unknown error")
        })
    }
}

struct AccountInfoRow: View {
    let title: LocalizedStringKey
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(valueColor)
        }
    }
}

protocol ReminderNotificationCenterProtocol: Sendable {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func add(_ request: UNNotificationRequest) async throws
}

extension UNUserNotificationCenter: ReminderNotificationCenterProtocol {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }
}

enum ReminderNotificationScheduler {
    static let mealIDs = ["ft_remind_meals_lunch", "ft_remind_meals_dinner"]
    static let waterID = "ft_remind_water"
    static let weightID = "ft_remind_weight"
    static let hasPromptedKey = "hasPromptedDefaultReminders_v1"

    @MainActor private static var tailSyncTask: Task<Void, Never>?

    static var allReminderIDs: [String] {
        mealIDs + [waterID, weightID]
    }

    @MainActor
    private static func serialized(_ work: @escaping @Sendable () async -> Void) async {
        let previous = tailSyncTask
        let next = Task { @MainActor in
            _ = await previous?.value
            await work()
        }
        tailSyncTask = next
        await next.value
    }

    static func currentPreferences(defaults: UserDefaults = .standard) -> (meals: Bool, water: Bool, weight: Bool) {
        let meals = defaults.object(forKey: "remindMeals") as? Bool ?? true
        let water = defaults.object(forKey: "remindWater") as? Bool ?? true
        let weight = defaults.object(forKey: "remindWeight") as? Bool ?? false
        return (meals, water, weight)
    }

    static func sync(
        mealsEnabled: Bool,
        waterEnabled: Bool,
        weightEnabled: Bool,
        center: any ReminderNotificationCenterProtocol = UNUserNotificationCenter.current()
    ) {
        Task {
            await syncAsync(
                mealsEnabled: mealsEnabled,
                waterEnabled: waterEnabled,
                weightEnabled: weightEnabled,
                center: center,
                requestAuthorizationIfNotDetermined: true
            )
        }
    }

    static func syncOnAppActive(
        defaults: UserDefaults = .standard,
        center: any ReminderNotificationCenterProtocol = UNUserNotificationCenter.current(),
        forcePrompt: Bool = false
    ) async {
        await serialized {
            await performSyncOnAppActive(defaults: defaults, center: center, forcePrompt: forcePrompt)
        }
    }

    private static func performSyncOnAppActive(
        defaults: UserDefaults,
        center: any ReminderNotificationCenterProtocol,
        forcePrompt: Bool
    ) async {
        let prefs = currentPreferences(defaults: defaults)
        guard prefs.meals || prefs.water || prefs.weight else {
            center.removePendingNotificationRequests(withIdentifiers: allReminderIDs)
            return
        }

        let status = await center.authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            await performSyncAsync(
                mealsEnabled: prefs.meals,
                waterEnabled: prefs.water,
                weightEnabled: prefs.weight,
                center: center,
                requestAuthorizationIfNotDetermined: false
            )
        case .notDetermined:
            let hasPrompted = defaults.bool(forKey: hasPromptedKey)
            guard forcePrompt || !hasPrompted else { return }
            defaults.set(true, forKey: hasPromptedKey)
            await performSyncAsync(
                mealsEnabled: prefs.meals,
                waterEnabled: prefs.water,
                weightEnabled: prefs.weight,
                center: center,
                requestAuthorizationIfNotDetermined: true
            )
        case .denied:
            center.removePendingNotificationRequests(withIdentifiers: allReminderIDs)
        @unknown default:
            break
        }
    }

    static func syncAsync(
        mealsEnabled: Bool,
        waterEnabled: Bool,
        weightEnabled: Bool,
        center: any ReminderNotificationCenterProtocol = UNUserNotificationCenter.current(),
        requestAuthorizationIfNotDetermined: Bool = true
    ) async {
        await serialized {
            await performSyncAsync(
                mealsEnabled: mealsEnabled,
                waterEnabled: waterEnabled,
                weightEnabled: weightEnabled,
                center: center,
                requestAuthorizationIfNotDetermined: requestAuthorizationIfNotDetermined
            )
        }
    }

    private static func performSyncAsync(
        mealsEnabled: Bool,
        waterEnabled: Bool,
        weightEnabled: Bool,
        center: any ReminderNotificationCenterProtocol,
        requestAuthorizationIfNotDetermined: Bool
    ) async {
        center.removePendingNotificationRequests(withIdentifiers: allReminderIDs)

        guard mealsEnabled || waterEnabled || weightEnabled else { return }

        let status = await center.authorizationStatus()
        let granted: Bool
        switch status {
        case .authorized, .provisional, .ephemeral:
            granted = true
        case .notDetermined:
            guard requestAuthorizationIfNotDetermined else { return }
            granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied:
            granted = false
        @unknown default:
            granted = false
        }

        guard granted else { return }

        if mealsEnabled {
            await schedule(
                center: center,
                id: mealIDs[0],
                title: String(localized: "Time for Lunch"),
                body: String(localized: "Log your midday meal to keep your macros balanced."),
                hour: 13,
                minute: 0
            )
            await schedule(
                center: center,
                id: mealIDs[1],
                title: String(localized: "Dinner Check-In"),
                body: String(localized: "Log your dinner to complete today's nutrition diary."),
                hour: 19,
                minute: 0
            )
        }

        if waterEnabled {
            await schedule(
                center: center,
                id: waterID,
                title: String(localized: "Hydration Reminder"),
                body: String(localized: "Drink a glass of water to stay on track with your daily goal."),
                hour: 15,
                minute: 0
            )
        }

        if weightEnabled {
            await schedule(
                center: center,
                id: weightID,
                title: String(localized: "Weekly Weigh-In"),
                body: String(localized: "Step on the scale this morning and update your progress."),
                hour: 9,
                minute: 0,
                weekday: 1
            )
        }
    }

    private static func schedule(
        center: any ReminderNotificationCenterProtocol,
        id: String,
        title: String,
        body: String,
        hour: Int,
        minute: Int,
        weekday: Int? = nil
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        if let weekday {
            components.weekday = weekday
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }
}

struct RemindersSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("remindMeals") private var remindMeals = true
    @AppStorage("remindWater") private var remindWater = true
    @AppStorage("remindWeight") private var remindWeight = false
    @State private var isNotificationsDenied = false

    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    if isNotificationsDenied {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Notifications Disabled in iOS Settings", systemImage: "bell.slash.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(.orange)
                            Text("Enable notifications in Settings to receive meal, hydration, and weigh-in reminders.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button("Open iOS Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption.bold())
                            .foregroundColor(.themePink)
                        }
                        .premiumCardStyle()
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Daily reminders help you log lunch (13:00), dinner (19:00), and afternoon hydration (15:00) consistently.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.bottom, 8)

                        Toggle("Meals", isOn: $remindMeals).tint(.themePink)
                        Divider()
                        Toggle("Water", isOn: $remindWater).tint(.cyan)
                    }
                    .premiumCardStyle()
                    .padding(.horizontal, 20)
                    .padding(.top, isNotificationsDenied ? 0 : 24)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("It's best to track your measurements on the same day each week, at the same time and under the same circumstances.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.bottom, 8)

                        Toggle("Weigh-in", isOn: $remindWeight).tint(.themeOrange)
                    }
                    .premiumCardStyle()
                    .padding(.horizontal, 20)
                }
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshAuthorizationBanner()
            syncNotifications()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await refreshAuthorizationBanner()
                syncNotifications()
            }
        }
        .onChange(of: remindMeals) { _, _ in
            syncNotifications()
        }
        .onChange(of: remindWater) { _, _ in
            syncNotifications()
        }
        .onChange(of: remindWeight) { _, _ in
            syncNotifications()
        }
    }

    private func refreshAuthorizationBanner() async {
        let status = await UNUserNotificationCenter.current().authorizationStatus()
        isNotificationsDenied = (status == .denied)
    }

    private func syncNotifications() {
        ReminderNotificationScheduler.sync(
            mealsEnabled: remindMeals,
            waterEnabled: remindWater,
            weightEnabled: remindWeight
        )
    }
}

struct AppleHealthSettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var user: User

    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 80, height: 80)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                    }
                    .padding(.top, 20)

                    Text("Sync with Apple Health")
                        .font(.title2.bold())

                    Text("Sync nutrition, activity and body measurement with Apple Health app. Data from Apple Health will help give you more accurate recommendations.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    Button(action: toggleHealthKit) {
                        Text(user.isHealthKitEnabled ? "Disconnect" : "Connect")
                            .font(.headline)
                            .foregroundColor(user.isHealthKitEnabled ? .red : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(user.isHealthKitEnabled ? Color.red.opacity(0.1) : Color.green)
                            .cornerRadius(20)
                    }
                    .buttonStyle(BounceButtonStyle())
                    .padding(.top, 10)

                    if user.isHealthKitEnabled && !HealthKitManager.shared.isAuthorized {
                        VStack(spacing: 8) {
                            Text("Apple Health permissions are currently restricted. Open iOS Settings -> Health -> Data Access & Devices to allow sync.")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                            Button("Open iOS Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption.bold())
                            .foregroundColor(.themePink)
                        }
                        .padding(.top, 4)
                    }
                }
                .premiumCardStyle()
                .padding(20)

                Spacer()
            }
        }
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, user.isHealthKitEnabled else { return }
            Task { try? await HealthKitManager.shared.requestAuthorization() }
        }
    }

    private func toggleHealthKit() {
        HapticManager.shared.impact(style: .medium)
        user.isHealthKitEnabled.toggle()
        if user.isHealthKitEnabled {
            Task { try? await HealthKitManager.shared.requestAuthorization() }
        }
        try? context.save()
    }
}

struct AIPhotoPrivacySettingsView: View {
    @State private var consentManager = AIPhotoConsentManager.shared

    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(
                            "Allow AI Data & Photo Analysis",
                            isOn: Binding(
                                get: { consentManager.hasConsented },
                                set: { enabled in
                                    HapticManager.shared.impact(style: .light)
                                    if enabled {
                                        consentManager.grantConsent()
                                    } else {
                                        consentManager.revokeConsent()
                                    }
                                }
                            )
                        )
                        .tint(.themePink)

                        Divider()

                        Text("When enabled, downsampled photos you choose to scan and the nutrition goals, meals, mood notes, or chat prompts needed for AI requests are sent over encrypted HTTPS via FoodTracker's proxy to OpenRouter and third-party AI providers. Requests are processed transiently with provider data retention disabled.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .premiumCardStyle()
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                }
            }
        }
        .navigationTitle("AI Photo Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct UnitsSettingsView: View {
    @Binding var useMetric: Bool

    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {
                        withAnimation { useMetric = true }
                        UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)?.set(true, forKey: "useMetricSystem")
                        WidgetReloader.reloadAll()
                        HapticManager.shared.impact(style: .light)
                    }) {
                        HStack {
                            Text("Metric (kg, cm, ml)")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.primary)
                            Spacer()
                            if useMetric { Image(systemName: "checkmark").foregroundColor(.themePink).font(.headline) }
                        }
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                    }

                    Divider()

                    Button(action: {
                        withAnimation { useMetric = false }
                        UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)?.set(false, forKey: "useMetricSystem")
                        WidgetReloader.reloadAll()
                        HapticManager.shared.impact(style: .light)
                    }) {
                        HStack {
                            Text("Imperial (lb, in, fl oz)")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.primary)
                            Spacer()
                            if !useMetric { Image(systemName: "checkmark").foregroundColor(.themePink).font(.headline) }
                        }
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, 20)
                .background(Color.white)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
                .padding(20)

                Spacer()
            }
        }
        .navigationTitle("Units")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ProfileStatItem: View {
    let value: String; let unit: String; let title: String
    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 20, weight: .bold, design: .rounded))
                Text(unit).font(.caption).foregroundColor(.gray)
            }
            Text(LocalizedStringKey(title)).font(.caption).foregroundColor(.gray)
        }.frame(maxWidth: .infinity)
    }
}

struct MacroDotLabel: View {
    let color: Color; let title: LocalizedStringKey
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(.gray)
        }
    }
}

struct MacroAdjusterRow: View {
    let title: String; let color: Color; @Binding var pct: Double; let grams: Int; let onAdjust: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(LocalizedStringKey(title)).font(.headline).foregroundColor(color)
                Spacer()
                Text("\(Int(pct))%").font(.headline.bold())
                Text(" / \(grams)g").font(.subheadline).foregroundColor(.gray)
            }
            Slider(value: Binding(get: { pct }, set: { pct = $0; onAdjust() }), in: 0...100, step: 1).tint(color)
        }
    }
}

struct StreakCardView: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.themeOrange.opacity(0.1))
                    .frame(width: 60, height: 60)

                Image(systemName: "flame.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        streak > 0
                            ? LinearGradient(colors: [.themeOrange, .red], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [.gray.opacity(0.5), .gray], startPoint: .top, endPoint: .bottom)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(streak) Day Streak!")
                    .font(.title3)
                    .bold()

                Text(streak > 0 ? "Keep it up! You're doing great." : "Start logging meals to build your streak.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .premiumCardStyle()
    }
}

struct ThemeSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(0..<themeManager.themes.count, id: \.self) { index in
                        let theme = themeManager.themes[index]
                        Button(action: {
                            themeManager.currentThemeIndex = index
                            HapticManager.shared.impact(style: .medium)
                        }) {
                            HStack {
                                Circle()
                                    .fill(theme.primaryGradient)
                                    .frame(width: 40, height: 40)
                                
                                Text(LocalizedStringKey(theme.name))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if themeManager.currentThemeIndex == index {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(theme.primaryAccent)
                                        .font(.title3)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(themeManager.currentThemeIndex == index ? theme.primaryAccent : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("App Theme")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BMIScaleView: View {
    let bmi: Double

    var body: some View {
        GeometryReader { geo in
            let minBMI = 15.0
            let maxBMI = 40.0
            let clampedBMI = max(minBMI, min(maxBMI, bmi))
            let percentage = (clampedBMI - minBMI) / (maxBMI - minBMI)

            ZStack(alignment: .leading) {
                // Background Gradient
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        stops: [
                            .init(color: .blue, location: 0.0),
                            .init(color: .green, location: 0.25),
                            .init(color: .orange, location: 0.6),
                            .init(color: .red, location: 0.9)
                        ],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(height: 12)

                // Indicator
                VStack(spacing: 0) {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                    Spacer().frame(height: 12)
                }
                .offset(x: geo.size.width * CGFloat(percentage) - 7, y: -10)
            }
        }
        .frame(height: 24)
    }
}

struct BMICardView: View {
    let bmi: Double
    
    var category: (text: String, color: Color) {
        switch bmi {
        case ..<18.5: return (String(localized: "Underweight"), .blue)
        case 18.5..<25.0: return (String(localized: "Normal"), .green)
        case 25.0..<30.0: return (String(localized: "Overweight"), .orange)
        default: return (String(localized: "Obese"), .red)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Body Mass Index")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Healthy range: 18.5 - 24.9")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Text(String(format: "%.1f", bmi))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(category.color)
            }
            
            BMIScaleView(bmi: bmi)
            
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(category.color)
                Text("Your BMI indicates you are ")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                + Text(category.text)
                    .font(.subheadline).bold()
                    .foregroundColor(category.color)
                + Text(".")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .premiumCardStyle()
    }
}

import SwiftUI
import SwiftData
import Charts
import FirebaseAuth

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
                        ProfileStatItem(value: "\(String(format: "%.1f", user.weight))", unit: String(localized: "kg"), title: String(localized: "Body Weight"))
                        Divider().frame(height: 40)
                        ProfileStatItem(value: "\(Int(user.height))", unit: String(localized: "cm"), title: String(localized: "Body Height"))
                        Divider().frame(height: 40)
                        ProfileStatItem(value: "\(user.age)", unit: String(localized: "y.o"), title: String(localized: "Age"))
                    }
                    .padding(.top, 8)
                }
                .premiumCardStyle()
                
                let heightM = user.height / 100.0
                let bmi = heightM > 0 ? user.weight / (heightM * heightM) : 0
                BMICardView(bmi: bmi)

                Button(action: { showingNutritionSettings = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nutrition Targets")
                                .font(.headline)
                                .foregroundColor(.primary)

                            HStack(spacing: 12) {
                                MacroDotLabel(color: .themePeach, title: String(localized: "P: \(Int(user.targetProtein))g"))
                                MacroDotLabel(color: .themeYellow, title: String(localized: "F: \(Int(user.targetFats))g"))
                                MacroDotLabel(color: .drinkWater, title: String(localized: "C: \(Int(user.targetCarbs))g"))
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

    @State private var name: String
    @State private var weight: Double
    @State private var height: Double
    @State private var age: Int

    init(user: User) {
        self._user = Bindable(user)
        _name = State(initialValue: user.name)
        _weight = State(initialValue: user.weight)
        _height = State(initialValue: user.height)
        _age = State(initialValue: user.age)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Personal Details Card
                        VStack(spacing: 16) {
                            HStack {
                                Text("Name")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                Spacer()
                                TextField("Name", text: $name)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                            }
                            
                            Divider()
                            
                            PremiumMetricSlider(
                                title: "Age",
                                value: Binding(get: { Double(age) }, set: { age = Int($0) }),
                                range: 10...100,
                                step: 1,
                                unit: "y.o.",
                                icon: "calendar",
                                color: .themeOrange
                            )
                        }
                        .premiumCardStyle()
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        
                        // Body Metrics Card
                        VStack(spacing: 16) {
                            PremiumMetricSlider(
                                title: "Body Height",
                                value: $height,
                                range: 100...250,
                                step: 1,
                                unit: "cm",
                                icon: "ruler.fill",
                                color: .blue
                            )
                            
                            Divider()
                            
                            PremiumMetricSlider(
                                title: "Body Weight",
                                value: $weight,
                                range: 30...250,
                                step: 0.1,
                                unit: "kg",
                                icon: "scalemass.fill",
                                color: .themePink
                            )
                        }
                        .premiumCardStyle()
                        .padding(.horizontal, 20)
                        
                        Text("Updating these metrics will automatically recalculate your recommended daily calorie goal.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 40)
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
        user.name = name
        user.weight = weight
        user.height = height
        user.age = age
        user.calculateGoals()

        let totalCals = Double(user.dailyCaloriesGoal)
        let pRatio = (user.targetProtein * 4.0) / totalCals
        let fRatio = (user.targetFats * 9.0) / totalCals
        let cRatio = 1.0 - pRatio - fRatio

        user.applyDietBreakdown(fatPercent: Int(fRatio * 100), proteinPercent: Int(pRatio * 100), carbsPercent: Int(cRatio * 100), dietKey: user.activeDietKey)

        try? context.save()
    }
}

struct PremiumMetricSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Text(LocalizedStringKey(title))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: step == 1 ? "%.0f" : "%.1f", value))
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(color)
                        .contentTransition(.numericText(value: value))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: value)
                    
                    Text(unit)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
            
            Slider(value: $value, in: range, step: step)
                .tint(color)
        }
        .padding(.vertical, 4)
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
        let totalCals = Double(cals > 0 ? cals : 1)
        let p = (user.targetProtein * 4 / totalCals) * 100
        let f = (user.targetFats * 9 / totalCals) * 100
        let c = (user.targetCarbs * 4 / totalCals) * 100
        _pPct = State(initialValue: p)
        _fPct = State(initialValue: f)
        _cPct = State(initialValue: c)
    }

    private var isBalanced: Bool { Int(round(pPct)) + Int(round(fPct)) + Int(round(cPct)) == 100 }

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
                                Text("\(Int(round(pPct)) + Int(round(fPct)) + Int(round(cPct)))%").font(.title.bold()).foregroundColor(isBalanced ? .primary : .red)
                                Text(isBalanced ? "Balanced" : "Adjust to 100%").font(.caption).foregroundColor(isBalanced ? .gray : .red)
                            }
                        }.frame(height: 220)

                        VStack(spacing: 24) {
                            MacroAdjusterRow(title: String(localized: "Protein"), color: .themePeach, pct: $pPct, grams: calculateGrams(pct: pPct, multiplier: 4), onAdjust: { adjustMacros(changed: .protein) })
                            MacroAdjusterRow(title: String(localized: "Fats"), color: .themeYellow, pct: $fPct, grams: calculateGrams(pct: fPct, multiplier: 9), onAdjust: { adjustMacros(changed: .fat) })
                            MacroAdjusterRow(title: String(localized: "Carbs"), color: .drinkWater, pct: $cPct, grams: calculateGrams(pct: cPct, multiplier: 4), onAdjust: { adjustMacros(changed: .carbs) })
                        }.padding(20).background(Color.white).cornerRadius(24).shadow(color: .black.opacity(0.04), radius: 10, y: 5).padding(.horizontal, 20)

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
    private func adjustMacros(changed: MacroType) {
        let diff = (pPct + fPct + cPct) - 100; guard diff != 0 else { return }
        switch changed {
        case .protein: if cPct - diff >= 0 { cPct -= diff } else { fPct -= diff }
        case .fat: if cPct - diff >= 0 { cPct -= diff } else { pPct -= diff }
        case .carbs: if pPct - diff >= 0 { pPct -= diff } else { fPct -= diff }
        }
        pPct = max(0, pPct); fPct = max(0, fPct); cPct = max(0, cPct)
    }

    private func saveSettings() {
        user.dailyCaloriesGoal = dailyCals

        user.applyDietBreakdown(fatPercent: Int(round(fPct)), proteinPercent: Int(round(pPct)), carbsPercent: Int(round(cPct)), dietKey: "custom")
        try? context.save()
        dismiss()
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ThemeManager.self) private var themeManager
    @Bindable var user: User

    @AppStorage("useMetricSystem") private var useMetricSystem = true
    @Query private var summaries: [DailySummary]
    @State private var showingWidgetPromo = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        VStack(spacing: 0) {
                            NavigationLink(destination: AccountSettingsView(user: user, loggedDaysCount: summaries.count)) {
                                SettingsRowView(icon: "person.fill", iconColor: themeManager.current.primaryAccent, title: String(localized: "Account"))
                            }
                            Divider().padding(.leading, 56)

                            NavigationLink(destination: RemindersSettingsView()) {
                                SettingsRowView(icon: "bell.fill", iconColor: .themeYellow, title: String(localized: "Reminders"))
                            }
                            Divider().padding(.leading, 56)

                            NavigationLink(destination: AppleHealthSettingsView(user: user)) {
                                SettingsRowView(icon: "heart.fill", iconColor: .red, title: String(localized: "Apple Health"))
                            }
                            Divider().padding(.leading, 56)

                            NavigationLink(destination: UnitsSettingsView(useMetric: $useMetricSystem)) {
                                SettingsRowView(icon: "ruler.fill", iconColor: .blue, title: String(localized: "Units settings"), value: useMetricSystem ? String(localized: "Metric") : String(localized: "Imperial"))
                            }
                            Divider().padding(.leading, 56)
                            
                            NavigationLink(destination: ThemeSettingsView()) {
                                SettingsRowView(icon: "paintpalette.fill", iconColor: themeManager.current.secondaryAccent, title: String(localized: "App Theme"), value: String(localized: String.LocalizationValue(themeManager.current.name)))
                            }
                            Divider().padding(.leading, 56)

                            Button(action: { exportData() }) {
                                SettingsRowView(icon: "square.and.arrow.up.fill", iconColor: .green, title: String(localized: "Export Data to CSV"))
                            }
                        }
                        .premiumCardStyle()
                        .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            Button(action: { rateApp() }) {
                                SettingsRowView(icon: "star.fill", iconColor: .themeOrange, title: String(localized: "Rate the app"))
                            }
                            Divider().padding(.leading, 56)

                            Button(action: { contactSupport() }) {
                                SettingsRowView(icon: "questionmark.circle.fill", iconColor: .green, title: String(localized: "Help"))
                            }
                            Divider().padding(.leading, 56)

                            Button(action: { showingWidgetPromo = true }) {
                                SettingsRowView(icon: "rectangle.3.group.fill", iconColor: .themePink, title: String(localized: "Widgets Guide"))
                            }
                            Divider().padding(.leading, 56)

                            Button(action: { openPrivacyPolicy() }) {
                                SettingsRowView(icon: "hand.raised.fill", iconColor: .gray, title: String(localized: "Privacy Policy"))
                            }
                            Divider().padding(.leading, 56)

                            Button(action: { openTerms() }) {
                                SettingsRowView(icon: "doc.text.fill", iconColor: .gray, title: String(localized: "Terms of Service"))
                            }
                        }
                        .premiumCardStyle()
                        .padding(.horizontal, 20)

                        VStack(spacing: 4) {
                            Text("version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") global")
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
            .sheet(isPresented: $showingWidgetPromo) {
                WidgetPromoView()
            }
        }
    }
    
    private func exportData() {
        do {
            let fileURL = try DataExportService.generateCSV(from: summaries)
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                
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
            }
        } catch {
            print("Failed to export data: \(error)")
        }
    }

    private func rateApp() {
        HapticManager.shared.impact(style: .medium)
        if let url = URL(string: "itms-apps://itunes.apple.com/app/id6778506345?action=write-review") {
            UIApplication.shared.open(url)
        }
    }

    private func contactSupport() {
        HapticManager.shared.impact(style: .medium)
        if let url = URL(string: "https://borisserz.github.io/workouttracker-privacy/Support-%20FoodTracker.html") {
            UIApplication.shared.open(url)
        }
    }

    private func openPrivacyPolicy() {
        HapticManager.shared.impact(style: .light)
        if let url = URL(string: "https://borisserz.github.io/workouttracker-privacy/Privacy%20Policy%20-%20FoodTracker.html") {
            UIApplication.shared.open(url)
        }
    }

    private func openTerms() {
        HapticManager.shared.impact(style: .light)
        if let url = URL(string: "https://borisserz.github.io/workouttracker-privacy/Terms%20of%20Use%20-%20FoodTracker.html") {
            UIApplication.shared.open(url)
        }
    }
}

struct SettingsRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
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
    let user: User
    let loggedDaysCount: Int

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()

            VStack(spacing: 24) {

                VStack(alignment: .leading, spacing: 16) {
                    AccountInfoRow(title: String(localized: "User ID"), value: String(authManager.currentUserId.prefix(8)))
                    Divider()
                    AccountInfoRow(title: String(localized: "Account type"), value: authManager.isAnonymous ? "Guest" : "Registered", valueColor: authManager.isAnonymous ? .gray : .themePink)
                    Divider()
                    if !authManager.isAnonymous, let email = authManager.currentUserEmail {
                        AccountInfoRow(title: String(localized: "Email"), value: email)
                    } else {
                        AccountInfoRow(title: String(localized: "Total logged days"), value: "\(loggedDaysCount)")
                    }
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
                .padding(.horizontal, 20)
                .padding(.top, 24)

                Spacer()

                VStack(spacing: 16) {
                    if authManager.isAnonymous {
                        Button(action: {
                            Task {
                                isLoading = true
                                do {
                                    try await SocialAuthService.shared.signInWithApple()
                                } catch {
                                    errorMessage = error.localizedDescription
                                    showError = true
                                }
                                isLoading = false
                            }
                        }) {
                            HStack {
                                Image(systemName: "applelogo")
                                Text("Sign in with Apple")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .cornerRadius(20)
                        }
                        .buttonStyle(BounceButtonStyle())

                        Button(action: {
                            Task {
                                isLoading = true
                                do {
                                    try await SocialAuthService.shared.signInWithGoogle()
                                } catch {
                                    errorMessage = error.localizedDescription
                                    showError = true
                                }
                                isLoading = false
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
                            Task {
                                isLoading = true
                                do {
                                    try await SocialAuthService.shared.signOut()
                                } catch {
                                    errorMessage = error.localizedDescription
                                    showError = true
                                }
                                isLoading = false
                            }
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
                    }

                    Button(action: {
                        Task {
                            isLoading = true
                            do {
                                try await SocialAuthService.shared.reauthenticateForDeletion()
                                try await authManager.deleteCurrentUser()
                                try await AnonymousAuthBootstrap.shared.ensureSignedIn()
                            } catch {
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                            isLoading = false
                        }
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
    let title: String
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

struct RemindersSettingsView: View {
    @AppStorage("remindMeals") private var remindMeals = true
    @AppStorage("remindWater") private var remindWater = true
    @AppStorage("remindWeight") private var remindWeight = false

    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Water and meals reminders adapt to your habits. Keep using the app and times will be personalized.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.bottom, 8)

                        Toggle("Meals", isOn: $remindMeals).tint(.themePink)
                        Divider()
                        Toggle("Water", isOn: $remindWater).tint(.cyan)
                    }
                    .premiumCardStyle()
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("It's best to track your measurements on the same day each week, at the same time and under the same circumstances.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.bottom, 8)

                        Toggle("Weight-in", isOn: $remindWeight).tint(.themeOrange)
                    }
                    .premiumCardStyle()
                    .padding(.horizontal, 20)
                }
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AppleHealthSettingsView: View {
    @Environment(\.modelContext) private var context
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
                }
                .premiumCardStyle()
                .padding(20)

                Spacer()
            }
        }
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
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

struct UnitsSettingsView: View {
    @Binding var useMetric: Bool

    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: { withAnimation { useMetric = true }; HapticManager.shared.impact(style: .light) }) {
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

                    Button(action: { withAnimation { useMetric = false }; HapticManager.shared.impact(style: .light) }) {
                        HStack {
                            Text("Imperial (lb, ft, oz)")
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
            Text(title).font(.caption).foregroundColor(.gray)
        }.frame(maxWidth: .infinity)
    }
}

struct MacroDotLabel: View {
    let color: Color; let title: String
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
                Text(title).font(.headline).foregroundColor(color)
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
                Text("^[\(streak) Day Streak!](inflect: true)")
                    .font(.title3)
                    .bold()

                Text(streak > 0 ? LocalizedStringKey("Keep it up! You're doing great.") : LocalizedStringKey("Start logging meals to build your streak."))
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
                                
                                Text(theme.name)
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
                            .background(Color.white.opacity(0.05))
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
                Text("Your BMI indicates: ")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                + Text(category.text)
                    .font(.subheadline).bold()
                    .foregroundColor(category.color)

            }
        }
        .premiumCardStyle()
    }
}

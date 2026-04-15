// FoodTracker/Views/Profile/ProfileView.swift

import SwiftUI
import SwiftData
import Charts

// MARK: - 1. WRAPPER (Оболочка для безопасной загрузки данных)
// Этот View будет точкой входа из Navigation. Он загружает данные и передает их основному View.
struct ProfileWrapperView: View {
    @Query private var users: [User]
    @Query private var summaries: [DailySummary]

    var body: some View {
        if let user = users.first {
            // Передаем пользователя и его историю в основной View
            ProfileView(user: user, summaries: summaries)
        } else {
            // Заглушка на случай, если данные еще не загрузились
            VStack {
                ProgressView()
                Text("Loading Profile...")
            }
            .navigationTitle("Profile")
        }
    }
}

// MARK: - 2. MAIN PROFILE VIEW (Основной экран профиля)
struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Bindable var user: User
    let summaries: [DailySummary]
    
    @State private var currentStreak: Int = 0
    
    // Стейты для навигации по модальным окнам
    @State private var showingEditProfile = false
    @State private var showingNutritionSettings = false
    @State private var showingSettings = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // 1. HEADER: Аватар и базовая инфа
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .foregroundStyle(
                            LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: .themePink.opacity(0.3), radius: 10, y: 5)
                    
                    VStack(spacing: 4) {
                        Text(user.name)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("Active Goal: \(user.dailyCaloriesGoal) kcal")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Button(action: { showingEditProfile = true }) {
                        Text("Edit Profile")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.themePink)
                            .clipShape(Capsule())
                            .shadow(color: Color.themePink.opacity(0.3), radius: 5, y: 3)
                    }
                    .buttonStyle(BounceButtonStyle())
                    
                    // Stats Row
                    HStack(spacing: 0) {
                        ProfileStatItem(value: "\(String(format: "%.1f", user.weight))", unit: "kg", title: "Weight")
                        Divider().frame(height: 40)
                        ProfileStatItem(value: "\(Int(user.height))", unit: "cm", title: "Height")
                        Divider().frame(height: 40)
                        ProfileStatItem(value: "\(user.age)", unit: "y.o", title: "Age")
                    }
                    .padding(.top, 8)
                }
                .premiumCardStyle()
                
                // 2. NUTRITION WIDGET (Карточка для макросов)
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
                            .foregroundColor(.themePink)
                            .padding(12)
                            .background(Color.themePink.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .premiumCardStyle()
                }
                .buttonStyle(BounceButtonStyle())
                
                // 3. STREAK
                StreakCardView(streak: currentStreak)
                
                // 4. APPLE-STYLE ACHIEVEMENTS
                AchievementsSectionView(user: user)
                
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(Color.themeBg.ignoresSafeArea())
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
            currentStreak = calculateStreak()
        }
    }
    
    private func calculateStreak() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)
        let activeDates = summaries.filter { $0.totalCalories > 0 }.map { calendar.startOfDay(for: $0.date) }.sorted(by: >)
        guard let mostRecent = activeDates.first else { return 0 }
        let daysFromToday = calendar.dateComponents([.day], from: mostRecent, to: today).day ?? 0
        if daysFromToday > 1 { return 0 }
        var streak = 1; var previousDate = mostRecent
        for i in 1..<activeDates.count {
            let currentDate = activeDates[i]
            let diff = calendar.dateComponents([.day], from: currentDate, to: previousDate).day ?? 0
            if diff == 1 { streak += 1; previousDate = currentDate } else if diff == 0 { continue } else { break }
        }
        return streak
    }
}

// MARK: - 3. EDIT PROFILE SHEET (Модальное окно редактирования)
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
            Form {
                Section("Personal Details") {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Name", text: $name).multilineTextAlignment(.trailing).foregroundColor(.gray)
                    }
                    Stepper("Age: \(age) years", value: $age, in: 10...100)
                }
                
                // Исправлен синтаксис Section для поддержки footer-а
                Section {
                    Stepper("Height: \(Int(height)) cm", value: $height, in: 100...250)
                    Stepper("Weight: \(String(format: "%.1f", weight)) kg", value: $weight, in: 30...250, step: 0.1)
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
        user.name = name
        user.weight = weight
        user.height = height
        user.age = age
        user.calculateGoals()
        // Находим текущее соотношение макросов
        let totalCals = Double(user.dailyCaloriesGoal)
        let pRatio = (user.targetProtein * 4.0) / totalCals
        let fRatio = (user.targetFats * 9.0) / totalCals
        let cRatio = 1.0 - pRatio - fRatio
        
        user.applyDietBreakdown(fatPercent: Int(fRatio * 100), proteinPercent: Int(pRatio * 100), carbsPercent: Int(cRatio * 100), dietName: user.activeDietName)
        
        try? context.save()
    }
}

// MARK: - 4. NUTRITION SETTINGS EDITOR (Редактор макросов)
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
        _pPct = State(initialValue: p)
        _fPct = State(initialValue: f)
        _cPct = State(initialValue: 100 - p - f)
    }
    
    private var isBalanced: Bool { Int(pPct + fPct + cPct) == 100 }
    
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
                                Text("\(Int(pPct + fPct + cPct))%").font(.title.bold()).foregroundColor(isBalanced ? .primary : .red)
                                Text(isBalanced ? "Balanced" : "Adjust to 100%").font(.caption).foregroundColor(isBalanced ? .gray : .red)
                            }
                        }.frame(height: 220)
                        
                        VStack(spacing: 24) {
                            MacroAdjusterRow(title: "Protein", color: .themePeach, pct: $pPct, grams: calculateGrams(pct: pPct, multiplier: 4), onAdjust: { adjustMacros(changed: .protein) })
                            MacroAdjusterRow(title: "Fat", color: .themeYellow, pct: $fPct, grams: calculateGrams(pct: fPct, multiplier: 9), onAdjust: { adjustMacros(changed: .fat) })
                            MacroAdjusterRow(title: "Carbs", color: .drinkWater, pct: $cPct, grams: calculateGrams(pct: cPct, multiplier: 4), onAdjust: { adjustMacros(changed: .carbs) })
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
        user.applyDietBreakdown(fatPercent: Int(fPct), proteinPercent: Int(pPct), carbsPercent: Int(cPct), dietName: "Custom")
        try? context.save()
        dismiss()
    }
}


struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var user: User
    
    // В реальном приложении это можно хранить в @AppStorage
    @AppStorage("useMetricSystem") private var useMetricSystem = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // ГРУППА 1: Основные настройки (Preferences)
                        VStack(spacing: 0) {
                            NavigationLink(destination: AccountSettingsView(user: user)) {
                                SettingsRowView(icon: "person.fill", iconColor: .themePink, title: "Account")
                            }
                            Divider().padding(.leading, 56)
                            
                            NavigationLink(destination: RemindersSettingsView()) {
                                SettingsRowView(icon: "bell.fill", iconColor: .themeYellow, title: "Reminders")
                            }
                            Divider().padding(.leading, 56)
                            
                            NavigationLink(destination: AppleHealthSettingsView(user: user)) {
                                SettingsRowView(icon: "heart.fill", iconColor: .red, title: "Apple Health")
                            }
                            Divider().padding(.leading, 56)
                            
                            NavigationLink(destination: UnitsSettingsView(useMetric: $useMetricSystem)) {
                                SettingsRowView(icon: "ruler.fill", iconColor: .blue, title: "Units settings", value: useMetricSystem ? "Metric" : "Imperial")
                            }
                        }
                        .premiumCardStyle()
                        .padding(.horizontal, 20)
                        
                        // ГРУППА 2: Поддержка и Информация (Support & About)
                        VStack(spacing: 0) {
                            Button(action: { rateApp() }) {
                                SettingsRowView(icon: "star.fill", iconColor: .themeOrange, title: "Rate the app")
                            }
                            Divider().padding(.leading, 56)
                            
                            Button(action: { contactSupport() }) {
                                SettingsRowView(icon: "questionmark.circle.fill", iconColor: .green, title: "Help")
                            }
                            Divider().padding(.leading, 56)
                            
                            Button(action: { openTerms() }) {
                                SettingsRowView(icon: "doc.text.fill", iconColor: .gray, title: "Terms of Service & Privacy")
                            }
                        }
                        .premiumCardStyle()
                        .padding(.horizontal, 20)
                        
                        // FOOTER: Версия приложения
                        VStack(spacing: 4) {
                            Text("version 1.0.0 global")
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
        }
    }
    
    // MARK: - Actions
    private func rateApp() {
        HapticManager.shared.impact(style: .medium)
        // В реальном приложении вызываем SKStoreReviewController
        print("Rate App Tapped")
    }
    
    private func contactSupport() {
        HapticManager.shared.impact(style: .medium)
        let subject = "Help Needed - FoodTracker User ID: 372026"
        let body = "Please describe your issue here...\n\n\n--- App Info ---\nVersion: 1.0.0"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "mailto:support@foodbok.com?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openTerms() {
        HapticManager.shared.impact(style: .light)
        if let url = URL(string: "https://yourwebsite.com/terms") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Вспомогательный компонент строки (UI/UX)
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
        .contentShape(Rectangle()) // Чтобы нажималась вся строка
    }
}

// MARK: - SUB-SCREENS

// 1. ACCOUNT SETTINGS (С кнопками выхода и удаления)
struct AccountSettingsView: View {
    let user: User
    
    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Карточка с инфой
                VStack(alignment: .leading, spacing: 16) {
                    AccountInfoRow(title: "User ID", value: "372 026")
                    Divider()
                    AccountInfoRow(title: "Account type", value: "Premium", valueColor: .themePink)
                    Divider()
                    AccountInfoRow(title: "Total logged days", value: "42")
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                
                Spacer()
                
                // Опасные кнопки
                VStack(spacing: 16) {
                    Button(action: { /* Log out logic */ }) {
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
                    
                    Button(action: { /* Delete account logic */ }) {
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
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
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

// 2. REMINDERS SETTINGS
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

// 3. APPLE HEALTH SETTINGS
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

// 4. UNITS SETTINGS
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

// MARK: - 6. Вспомогательные компоненты
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

struct AchievementsSectionView: View {
    let user: User
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Awards").font(.title2).bold()
                Spacer()
                Text("\(user.unlockedAchievements.count) Unlocked").font(.caption).foregroundColor(.gray)
            }.padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(Achievement.all) { achievement in
                        let isUnlocked = user.unlockedAchievements.contains(achievement.id)
                        AppleStyleBadge(achievement: achievement, isUnlocked: isUnlocked)
                    }
                }.padding(.horizontal, 20).padding(.bottom, 10)
            }
        }
        .padding(.vertical, 16).background(Color.white).cornerRadius(24).shadow(color: .black.opacity(0.04), radius: 10, y: 5)
    }
}

struct AppleStyleBadge: View {
    let achievement: Achievement; let isUnlocked: Bool
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(LinearGradient(colors: isUnlocked ? [Color(white: 0.9), Color(white: 0.7)] : [Color(white: 0.95), Color(white: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 80, height: 80).shadow(color: isUnlocked ? achievement.color.opacity(0.3) : .clear, radius: 8, y: 4)
                Circle().fill(isUnlocked ? LinearGradient(colors: [achievement.color.opacity(0.8), achievement.color], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [Color(white: 0.85)], startPoint: .top, endPoint: .bottom)).frame(width: 68, height: 68)
                Image(systemName: achievement.icon).font(.system(size: 32, weight: .bold)).foregroundColor(isUnlocked ? .white : .gray.opacity(0.5)).shadow(color: isUnlocked ? .black.opacity(0.2) : .clear, radius: 2, y: 1)
            }
            VStack(spacing: 2) {
                Text(achievement.title).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(isUnlocked ? .primary : .gray).lineLimit(1)
                Text(achievement.description).font(.system(size: 10)).foregroundColor(.gray).multilineTextAlignment(.center).lineLimit(2).frame(height: 24)
            }.frame(width: 90)
        }.opacity(isUnlocked ? 1.0 : 0.6).grayscale(isUnlocked ? 0 : 1)
    }
}

// Убрана лишняя скобка, которая ломала компиляцию

// MARK: - STREAK CARD VIEW
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

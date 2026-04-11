import SwiftUI
import Combine

// MARK: - DATA MODELS & MANAGER
struct Beverage: Equatable, Hashable {
    let name: String; let icon: String; let color: Color; let caloriesPerGlass: Int
}

class UserDataManager: ObservableObject {
    @Published var weight: Double = 75.0 { didSet { calculateCalories() } }
    @Published var height: Double = 180.0 { didSet { calculateCalories() } }
    @Published var age: Int = 28 { didSet { calculateCalories() } }
    
    @Published var dailyCaloriesGoal: Int = 2400
    @Published var baseFoodCalories: Int = 1200
    @Published var consumedDrinks: [Beverage?] = Array(repeating: nil, count: 10)
    
    var totalEatenCalories: Int {
        baseFoodCalories + consumedDrinks.compactMap { $0?.caloriesPerGlass }.reduce(0, +)
    }
    var totalHydration: Double {
        Double(consumedDrinks.compactMap { $0 }.count) * 0.25
    }
    
    init() { calculateCalories() }
    
    func calculateCalories() {
        self.dailyCaloriesGoal = Int(((10 * weight) + (6.25 * height) - (Double(age) * 5) + 5) * 1.3)
    }
}

// MARK: - APP ENTRY
@main
struct PremiumTrackerApp: App {
    @StateObject var userData = UserDataManager()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userData)
                .preferredColorScheme(.light) // Убираем возможные баги с темной темой
        }
    }
}

// MARK: - COLORS
extension Color {
    init(hex: UInt, alpha: Double = 1) { self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 08) & 0xff) / 255, blue: Double((hex >> 00) & 0xff) / 255, opacity: alpha) }
    
    static let themePink   = Color(hex: 0xF25C78)
    static let themeYellow = Color(hex: 0xF2CF66)
    static let themeOrange = Color(hex: 0xF2C36B)
    static let themeBg     = Color(hex: 0xF2EDE4)
    static let themePeach  = Color(hex: 0xF2B6A0)
    
    static let drinkWater  = Color(hex: 0x6BB8F2)
    static let drinkCoffee = Color(hex: 0x8D6E63)
    static let drinkWine   = Color(hex: 0x9C27B0).opacity(0.8)
    static let drinkMilk   = Color(hex: 0xCFD8DC)
    static let drinkJuice  = Color(hex: 0xFFB74D)
}

let availableBeverages = [
    Beverage(name: "Water", icon: "drop.fill", color: .drinkWater, caloriesPerGlass: 0),
    Beverage(name: "Coffee", icon: "cup.and.saucer.fill", color: .drinkCoffee, caloriesPerGlass: 40),
    Beverage(name: "Milk", icon: "mug.fill", color: .drinkMilk, caloriesPerGlass: 150),
    Beverage(name: "Juice", icon: "orange.fill", color: .drinkJuice, caloriesPerGlass: 110),
    Beverage(name: "Wine", icon: "wineglass.fill", color: .drinkWine, caloriesPerGlass: 180)
]

struct PremiumCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(16).background(Color.white).cornerRadius(12).shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
extension View { func premiumCardStyle() -> some View { self.modifier(PremiumCardModifier()) } }

// MARK: - MAIN TAB VIEW
struct ContentView: View {
    var body: some View {
        TabView {
            HomeDashboardView().tabItem { Label("Home", systemImage: "house.fill") }
            HistoryView().tabItem { Label("History", systemImage: "clock.fill") }
            ChefPremiumView().tabItem { Label("Chefs", systemImage: "star.circle.fill") }
            SuperFoodsView().tabItem { Label("Foods", systemImage: "leaf.arrow.circlepath") }
            ProfileView().tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
        .tint(.themePink)
    }
}

// MARK: - 1. HOME DASHBOARD
struct HomeDashboardView: View {
    @EnvironmentObject var userData: UserDataManager
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    CalendarHeaderView()
                    
                    // Блок калорий
                    VStack(spacing: 8) {
                        Text("\(userData.totalEatenCalories) / \(userData.dailyCaloriesGoal) kcal")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                        Text("Food: \(userData.baseFoodCalories) kcal | Drinks: \(userData.totalEatenCalories - userData.baseFoodCalories) kcal")
                            .font(.subheadline).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .premiumCardStyle()
                    
                    // Блок макросов
                    HStack(spacing: 15) {
                        MacroBatteryView(title: "Protein", current: 80, total: 150, color: .themePeach)
                        MacroBatteryView(title: "Fats", current: 40, total: 70, color: .themeYellow)
                        MacroBatteryView(title: "Carbs", current: 120, total: 250, color: .themeOrange)
                    }
                    .frame(maxWidth: .infinity)
                    .premiumCardStyle()
                    
                    // ПРИЕМЫ ПИЩИ (НАД ВОДОЙ)
                    VStack(spacing: 16) {
                        MealCardView(title: "Breakfast", calories: 400, isBalanced: true, destination: MealDetailView(title: "Breakfast"))
                        MealCardView(title: "Lunch", calories: 650, isBalanced: false, destination: MealDetailView(title: "Lunch"))
                        MealCardView(title: "Dinner", calories: nil, isBalanced: false, destination: MealDetailView(title: "Dinner"))
                    }
                    
                    // УМНАЯ ВОДА (ПОД ЕДОЙ)
                    AdvancedBeverageTrackerView()
                }
                .padding()
            }
            .background(Color.themeBg)
            .navigationTitle("Today")
        }
    }
}

// МЕНЮ НАПИТКОВ
struct AdvancedBeverageTrackerView: View {
    @EnvironmentObject var userData: UserDataManager
    @State private var selectedBeverage: Beverage = availableBeverages[0]
    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Hydration").font(.headline)
                    Text("+ \(selectedBeverage.caloriesPerGlass) kcal / glass").font(.caption).foregroundColor(.themeOrange)
                }
                Spacer()
                Text("\(userData.totalHydration, specifier: "%.2f") / 2.5 L")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(selectedBeverage.color)
            }
            
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(0..<10, id: \.self) { index in
                    PrettyGlassView(beverage: userData.consumedDrinks[index])
                        .onTapGesture {
                            withAnimation(.spring()) { toggleGlass(at: index) }
                        }
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(availableBeverages, id: \.name) { bev in
                        Button(action: { withAnimation { selectedBeverage = bev } }) {
                            HStack {
                                Image(systemName: bev.icon)
                                Text(bev.name).font(.subheadline).bold()
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(selectedBeverage == bev ? bev.color : Color.gray.opacity(0.1))
                            .foregroundColor(selectedBeverage == bev ? .white : .primary)
                            .cornerRadius(20)
                        }
                    }
                }
            }
        }.premiumCardStyle()
    }
    
    private func toggleGlass(at index: Int) {
        if userData.consumedDrinks[index] != nil {
            for i in index..<10 { userData.consumedDrinks[i] = nil }
        } else {
            for i in 0...index {
                if userData.consumedDrinks[i] == nil { userData.consumedDrinks[i] = selectedBeverage }
            }
        }
    }
}

struct PrettyGlassView: View {
    let beverage: Beverage?
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 2).background(Color.white)
            if let drink = beverage {
                RoundedRectangle(cornerRadius: 4).fill(drink.color).padding(2)
                Image(systemName: drink.icon).font(.system(size: 10)).foregroundColor(.white.opacity(0.8)).padding(.bottom, 6)
            }
        }.frame(height: 50)
    }
}

// MARK: - 2. HISTORY VIEW
struct HistoryView: View {
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Text("My Custom Recipes").font(.title3).bold(); Spacer(); Image(systemName: "plus.circle.fill").foregroundColor(.themePink).font(.title2) }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                CustomRecipeCard(title: "Oatmeal Bowl", kcal: "320 kcal", items: "Oats, Milk, Berries")
                                CustomRecipeCard(title: "Protein Shake", kcal: "250 kcal", items: "Whey, Banana")
                            }
                        }
                    }.padding(.top)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Frequent Combinations").font(.title3).bold()
                        VStack(spacing: 12) {
                            FrequentMealRow(timeTag: "Breakfast", title: "Classic Eggs & Bacon", ingredients: "2x Fried Eggs, 3x Bacon slices", kcal: "450", color: .themeYellow)
                            FrequentMealRow(timeTag: "Lunch", title: "Chicken & Rice Combo", ingredients: "150g Breast, 100g Rice, Broccoli", kcal: "520", color: .themePeach)
                            FrequentMealRow(timeTag: "Dinner", title: "Salmon Salad", ingredients: "120g Salmon, Mixed Greens", kcal: "380", color: .themeOrange)
                        }
                    }
                }.padding(.horizontal)
            }
            .background(Color.themeBg)
            .navigationTitle("History")
        }
    }
}

// MARK: - 3. CHEFS VIEW (PRO)
struct ChefPremiumView: View {
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PRO Feature").font(.caption).bold().padding(4).background(Color.white.opacity(0.3)).cornerRadius(8)
                            Text("Unlock Chef Recipes").font(.title3).bold()
                        }.foregroundColor(.white)
                        Spacer()
                        Image(systemName: "lock.open.fill").font(.title).foregroundColor(.white)
                    }
                    .padding()
                    .background(LinearGradient(gradient: Gradient(colors: [.themePink, .themeOrange]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .cornerRadius(16)
                    .padding(.top)
                    
                    ChefSectionView(chefName: "Gordon Ramsay", icon: "flame.fill", recipes: [("Fit Beef Wellington", "550 kcal", true), ("Scrambled Eggs", "320 kcal", false)])
                    ChefSectionView(chefName: "Jamie Oliver", icon: "leaf.fill", recipes: [("15-Min Healthy Pasta", "480 kcal", true), ("Veggie Salad", "290 kcal", false)])
                }.padding(.horizontal)
            }
            .background(Color.themeBg)
            .navigationTitle("Chef's Specials")
        }
    }
}

// MARK: - 4. FOODS & DIETS VIEW
struct DietPlan: Identifiable {
    let id = UUID()
    let name: String; let tagline: String; let desc: String; let macros: String
    let goodFoods: [String]; let warnings: [String]; let color: Color
}

let dietDatabase = [
    DietPlan(name: "Keto", tagline: "High fat, extremely low carb", desc: "Forces your body to burn fat for fuel instead of carbohydrates.", macros: "70% Fat | 25% Protein | 5% Carb", goodFoods: ["Avocados", "Meat & Fish", "Cheese", "Nuts"], warnings: ["Liver conditions", "Pregnant women", "Gallbladder issues"], color: .themeYellow),
    DietPlan(name: "Paleo", tagline: "Eat like our ancestors", desc: "Focuses on whole foods humans ate during the Paleolithic era.", macros: "40% Fat | 30% Protein | 30% Carb", goodFoods: ["Grass-fed Meat", "Fruits & Veggies", "Seeds"], warnings: ["Calcium deficiency risk", "Hard for vegetarians"], color: .themeOrange),
    DietPlan(name: "Mediterranean", tagline: "Heart-healthy and balanced", desc: "Inspired by the traditional eating habits of Italy and Greece.", macros: "35% Fat | 15% Protein | 50% Carb", goodFoods: ["Olive Oil", "Fish", "Whole Grains", "Wine (moderate)"], warnings: ["Iron deficiency if meat is strictly avoided"], color: .themePeach),
    DietPlan(name: "Vegan", tagline: "100% Plant-Based", desc: "Eliminates all animal products. Great for the environment and digestion.", macros: "20% Fat | 15% Protein | 65% Carb", goodFoods: ["Tofu", "Lentils", "Leafy Greens", "Quinoa"], warnings: ["B12 Deficiency", "Low Protein if not planned"], color: .green),
    DietPlan(name: "High Protein", tagline: "Best for muscle building", desc: "Maximizes muscle synthesis and keeps you feeling full longer.", macros: "30% Fat | 40% Protein | 30% Carb", goodFoods: ["Chicken Breast", "Whey Protein", "Eggs", "Greek Yogurt"], warnings: ["Pre-existing kidney conditions"], color: .themePink),
    DietPlan(name: "Intermittent Fasting", tagline: "16:8 Time-restricted eating", desc: "Focuses on WHEN you eat rather than exactly WHAT you eat.", macros: "Flexible Macros", goodFoods: ["Black Coffee during fast", "Balanced meals in window"], warnings: ["History of eating disorders", "Diabetes (without doctor consult)"], color: .gray)
]

struct SuperFoodsView: View {
    @State private var expandedSection: String? = "Proteins" // Какая секция открыта по умолчанию
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // Блок супер-еды
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Best Foods for Fat Loss").font(.title2).bold()
                        FoodCategorySection(title: "Lean Proteins", icon: "bolt.fill", color: .themePeach, isExpanded: Binding(get: { expandedSection == "Proteins" }, set: { if $0 { expandedSection = "Proteins" } else { expandedSection = nil } }), foods: [("Chicken Breast", "165 kcal / 100g"), ("Eggs", "70 kcal / egg")])
                        FoodCategorySection(title: "Healthy Fats", icon: "drop.fill", color: .themeYellow, isExpanded: Binding(get: { expandedSection == "Fats" }, set: { if $0 { expandedSection = "Fats" } else { expandedSection = nil } }), foods: [("Avocado", "160 kcal / 100g"), ("Almonds", "580 kcal / 100g")])
                    }
                    
                    // БЛОК ДИЕТ (ТЕПЕРЬ ОНИ ЗДЕСЬ)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Popular Diet Plans").font(.title2).bold().padding(.top, 10)
                        
                        ForEach(dietDatabase) { diet in
                            NavigationLink(destination: DietDetailView(diet: diet)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(diet.name).font(.headline).foregroundColor(.primary)
                                        Text(diet.tagline).font(.caption).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(diet.color)
                                }
                                .premiumCardStyle()
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.themeBg)
            .navigationTitle("Foods & Diets")
        }
    }
}

// ЭКРАН ОПИСАНИЯ ДИЕТЫ (Больше никаких белых экранов!)
struct DietDetailView: View {
    let diet: DietPlan
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(diet.desc)
                    .font(.body)
                    .lineSpacing(4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Macros").font(.headline)
                    Text(diet.macros)
                        .font(.subheadline).bold()
                        .foregroundColor(diet.color)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(diet.color.opacity(0.1))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text("Best Foods to Eat").font(.headline)
                    }
                    ForEach(diet.goodFoods, id: \.self) { f in
                        Text("• \(f)").font(.subheadline).foregroundColor(.gray)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.05))
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                        Text("Contraindications").font(.headline)
                    }
                    ForEach(diet.warnings, id: \.self) { w in
                        Text("• \(w)").font(.subheadline).foregroundColor(.gray)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.05))
                .cornerRadius(12)
                
            }
            .padding()
        }
        .background(Color.themeBg)
        .navigationTitle(diet.name)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - 5. PROFILE (УДАЛЕНЫ ССЫЛКИ НА ПУСТЫЕ ЭКРАНЫ)
struct ProfileView: View {
    @EnvironmentObject var userData: UserDataManager
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack {
                        Image(systemName: "person.crop.circle.fill").resizable().frame(width: 80, height: 80).foregroundColor(.gray)
                        Text("Alexey").font(.title2).bold()
                    }
                    
                    VStack(alignment: .leading) {
                        DisclosureGroup("Health Metrics & Calibration") {
                            VStack(spacing: 16) {
                                Divider()
                                HStack { Text("Weight"); Spacer(); Stepper("\(userData.weight, specifier: "%.1f") kg", value: $userData.weight, in: 40...150) }
                                HStack { Text("Height"); Spacer(); Stepper("\(userData.height, specifier: "%.0f") cm", value: $userData.height, in: 140...220) }
                                HStack { Text("Age"); Spacer(); Stepper("\(userData.age)", value: $userData.age, in: 10...100) }
                            }.font(.subheadline)
                        }.font(.headline)
                    }.premiumCardStyle()
                    
                }.padding()
            }
            .background(Color.themeBg)
            .navigationTitle("Profile")
        }
    }
}

// MARK: - MEAL DETAILS & ADD FOOD (ПРИЕМЫ ПИЩИ И ДОБАВЛЕНИЕ ЕДЫ)
struct MealDetailView: View {
    let title: String
    @Environment(\.dismiss) var dismiss
    @State private var showingAddFood = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 20) {
                    VStack {
                        Text("650 kcal").font(.system(size: 32, weight: .bold, design: .rounded))
                        HStack(spacing: 20) {
                            MiniProgress(title: "P", progress: 0.4, color: .themePeach)
                            MiniProgress(title: "F", progress: 0.6, color: .themeYellow)
                            MiniProgress(title: "C", progress: 0.9, color: .themeOrange)
                        }
                    }.premiumCardStyle()
                    
                    VStack(spacing: 0) {
                        FoodRowView(name: "Grilled Chicken", weight: "150g", kcal: "240 kcal")
                        Divider()
                        FoodRowView(name: "White Rice", weight: "200g", kcal: "260 kcal")
                    }.background(Color.white).cornerRadius(12)
                }.padding().padding(.bottom, 80)
            }
            .background(Color.themeBg)
            
            Button(action: { showingAddFood.toggle() }) {
                HStack { Image(systemName: "plus"); Text("Add Food") }
                    .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity)
                    .padding().background(Color.themePink).cornerRadius(12).padding()
            }
        }
        .navigationTitle(title)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) { HStack { Image(systemName: "chevron.left"); Text("Back") }.foregroundColor(.themePink) }
            }
        }
        .sheet(isPresented: $showingAddFood) { AddFoodModalView() }
    }
}

struct AddFoodModalView: View {
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("Search food...", text: $searchText).padding(10)
                    Image(systemName: "camera.viewfinder").padding(.trailing)
                }
                .background(Color.black.opacity(0.05)).cornerRadius(8).padding()
                
                ScrollView {
                    VStack {
                        SearchResultRow(name: "Avocado", details: "160 kcal/100g", badge: "Fats", color: .themeYellow)
                        SearchResultRow(name: "Greek Yogurt", details: "100 kcal/100g", badge: "Protein", color: .themePeach)
                    }.padding(.horizontal)
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() }.foregroundColor(.themePink) } }
        }
    }
}

// MARK: - REUSABLE UI COMPONENTS
struct CalendarHeaderView: View { var body: some View { ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(12..<19) { i in VStack { Text("Day").font(.caption).foregroundColor(.gray); Text("\(i)").font(.headline).foregroundColor(i==15 ? .white : .primary) }.padding(10).background(i==15 ? Color.themePink : Color.white).cornerRadius(12) } } } } }
struct MacroBatteryView: View { let title: String; let current: Int; let total: Int; let color: Color; var body: some View { VStack(alignment: .leading) { Text(title).font(.caption).foregroundColor(.gray); GeometryReader { g in ZStack(alignment: .leading) { RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.05)); RoundedRectangle(cornerRadius: 4).fill(color).frame(width: g.size.width * CGFloat(current) / CGFloat(total)) } }.frame(height: 8); Text("\(current)/\(total)g").font(.system(size: 12, weight: .bold)) } } }
struct MealCardView<Dest: View>: View { let title: String; let calories: Int?; let isBalanced: Bool; let destination: Dest; var body: some View { NavigationLink(destination: destination) { HStack { VStack(alignment: .leading) { Text(title).font(.headline); if let c = calories { Text("\(c) kcal").font(.title3.bold()) } else { Text("Not logged").font(.subheadline).foregroundColor(.gray) } }; Spacer(); Image(systemName: "chevron.right").foregroundColor(.gray) }.foregroundColor(.primary).premiumCardStyle() } } }
struct MiniProgress: View { let title: String; let progress: Double; let color: Color; var body: some View { VStack { Text(title).font(.caption).bold(); ProgressView(value: progress).tint(color) } } }
struct FoodRowView: View { let name: String; let weight: String; let kcal: String; var body: some View { HStack { VStack(alignment: .leading) { Text(name).font(.subheadline).bold(); Text(weight).font(.caption).foregroundColor(.gray) }; Spacer(); Text(kcal).font(.headline) }.padding() } }
struct SearchResultRow: View { let name: String; let details: String; let badge: String; let color: Color; var body: some View { HStack { VStack(alignment: .leading) { HStack { Text(name).font(.headline); Text(badge).font(.system(size: 10)).foregroundColor(color).padding(4).background(color.opacity(0.2)).cornerRadius(4) }; Text(details).font(.caption).foregroundColor(.gray) }; Spacer(); Image(systemName: "plus").foregroundColor(.white).padding(8).background(Color.themePink).clipShape(Circle()) }.padding().background(Color.white).cornerRadius(12) } }
struct CustomRecipeCard: View { let title: String; let kcal: String; let items: String; var body: some View { VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline); Text(items).font(.caption).foregroundColor(.gray).lineLimit(2); Spacer(); Text(kcal).font(.headline).foregroundColor(.themePink) }.padding().frame(width: 160, height: 120).background(Color.white).cornerRadius(12) } }
struct FrequentMealRow: View { let timeTag: String; let title: String; let ingredients: String; let kcal: String; let color: Color; var body: some View { HStack { VStack(alignment: .leading) { Text(timeTag).font(.system(size: 10, weight: .bold)).foregroundColor(color).padding(4).background(color.opacity(0.2)).cornerRadius(4); Text(title).font(.headline); Text(ingredients).font(.caption).foregroundColor(.gray).lineLimit(1) }; Spacer(); Text("\(kcal) kcal").font(.headline) }.premiumCardStyle() } }
struct ChefSectionView: View { let chefName: String; let icon: String; let recipes: [(String, String, Bool)]; var body: some View { VStack(alignment: .leading) { HStack { Image(systemName: icon).foregroundColor(.themeOrange); Text(chefName).font(.title3).bold() }; ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(recipes, id: \.0) { r in VStack(alignment: .leading) { Rectangle().fill(Color.gray.opacity(0.1)).frame(height: 100).cornerRadius(8).overlay(Image(systemName: "fork.knife").foregroundColor(.gray)); Text(r.0).font(.subheadline).bold().lineLimit(1); HStack { Text(r.1).font(.caption).foregroundColor(.gray); Spacer(); if r.2 { Text("PRO").font(.caption2.bold()).foregroundColor(.themeOrange) } } }.padding(12).frame(width: 180).background(Color.white).cornerRadius(12) } } } } } }
struct FoodCategorySection: View { let title: String; let icon: String; let color: Color; @Binding var isExpanded: Bool; let foods: [(String, String)]; var body: some View { VStack { Button(action: { withAnimation { isExpanded.toggle() } }) { HStack { Image(systemName: icon).foregroundColor(color); Text(title).font(.headline).foregroundColor(.primary); Spacer(); Image(systemName: "chevron.right").rotationEffect(.degrees(isExpanded ? 90 : 0)) }.padding() }; if isExpanded { VStack { ForEach(foods, id: \.0) { f in HStack { Text(f.0).font(.subheadline).bold(); Spacer(); Text(f.1).font(.caption).bold().foregroundColor(color) }.padding(12).background(Color.black.opacity(0.03)).cornerRadius(8) } }.padding(.horizontal).padding(.bottom) } }.background(Color.white).cornerRadius(12) } }

// ПРЕВЬЮ
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(UserDataManager())
    }
}


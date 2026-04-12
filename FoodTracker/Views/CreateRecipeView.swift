//
//  CreateRecipeView.swift
//  FoodTracker
//
//  Created by Boris Serzhanovich on 12.04.26.
//

import SwiftUI
import SwiftData

// MARK: - ЗАГЛУШКА НАВИГАЦИИ (Для демонстрации Root-контроллера)
struct RecipeFlowCoordinator: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            CreateRecipeView(path: $path)
                .navigationDestination(for: CustomRecipe.self) { recipe in
                    RecipeDetailView(recipe: recipe, path: $path)
                }
        }
    }
}

// MARK: - 1. CREATE RECIPE VIEW
struct CreateRecipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var path: NavigationPath
    
    // Form State
    @State private var recipeName: String = ""
    @State private var recipeInfo: String = ""
    @State private var difficulty: String = "Easy"
    @State private var cookingTime: Int = 15
    @State private var ingredients: [FoodItem] = []
    
    // Modal State
    @State private var showingAddIngredient = false
    
    let difficulties = ["Easy", "Medium", "Hard", "Pro"]
    
    // Dynamic Macros Calculation
    var totalCalories: Int { ingredients.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { ingredients.reduce(0) { $0 + $1.protein } }
    var totalFats: Double { ingredients.reduce(0) { $0 + $1.fats } }
    var totalCarbs: Double { ingredients.reduce(0) { $0 + $1.carbs } }
    
    // Validation
    var isFormValid: Bool {
        !recipeName.trimmingCharacters(in: .whitespaces).isEmpty && !ingredients.isEmpty
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                
                // 1. DYNAMIC DASHBOARD
                VStack(spacing: 16) {
                    Text("Total Macros")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("\(totalCalories) kcal")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText()) // Плавная анимация изменения чисел
                    
                    HStack(spacing: 15) {
                        // Для max(total) берем условную норму одного плотного блюда, чтобы прогрессбар заполнялся логично
                        MacroBatteryView(title: "Protein", current: Int(totalProtein), total: 60, color: .themePeach)
                        MacroBatteryView(title: "Fats", current: Int(totalFats), total: 40, color: .themeYellow)
                        MacroBatteryView(title: "Carbs", current: Int(totalCarbs), total: 100, color: .themeOrange)
                    }
                }
                .premiumCardStyle()
                .animation(.spring(), value: totalCalories)
                
                // 2. RECIPE DETAILS FORM
                VStack(spacing: 16) {
                    TextField("Recipe Name", text: $recipeName)
                        .font(.headline)
                        .padding()
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(10)
                    
                    TextField("Short Info / Description", text: $recipeInfo)
                        .padding()
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(10)
                    
                    HStack {
                        Text("Difficulty")
                        Spacer()
                        Picker("Difficulty", selection: $difficulty) {
                            ForEach(difficulties, id: \.self) { Text($0) }
                        }
                        .tint(.themePink)
                    }
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(10)
                    
                    HStack {
                        Stepper(value: $cookingTime, in: 5...180, step: 5) {
                            Text("Time: ") + Text("\(cookingTime) min").bold()
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(10)
                }
                .premiumCardStyle()
                
                // 3. INGREDIENTS LIST
                VStack(alignment: .leading, spacing: 16) {
                    Text("Ingredients")
                        .font(.title3)
                        .bold()
                    
                    if ingredients.isEmpty {
                        EmptyStateView(
                            imageName: "leaf.arrow.circlepath",
                            title: "No Ingredients Yet",
                            description: "Add your first ingredient to start building the recipe."
                        )
                        .frame(height: 150)
                        .premiumCardStyle()
                    } else {
                        ForEach(ingredients) { item in
                            CustomIngredientCard(item: item)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    
                    Button(action: { showingAddIngredient = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add New Ingredient")
                                .bold()
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.themePink)
                        .cornerRadius(12)
                    }
                }
                
            }
            .padding()
        }
        .background(Color.themeBg)
        .navigationTitle("Create Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveAndNavigate()
                }
                .foregroundColor(isFormValid ? .themePink : .gray)
                .disabled(!isFormValid)
                .bold()
            }
        }
        .sheet(isPresented: $showingAddIngredient) {
            AddIngredientModalView { newIngredient in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    ingredients.append(newIngredient)
                }
            }
        }
    }
    
    // MARK: - Save Logic
    private func saveAndNavigate() {
          let newRecipe = CustomRecipe(
              name: recipeName,
              info: recipeInfo,
              foodItems: ingredients,
              cookingTime: cookingTime,
              difficulty: difficulty
          )
          
          modelContext.insert(newRecipe)
          
          do {
              try modelContext.save()
              // ВОТ ЗДЕСЬ ИСПРАВЛЕНИЕ:
              // Оборачиваем newRecipe в наш enum RecipeRoute
              path.append(RecipeRoute.detail(newRecipe))
          } catch {
              print("Failed to save recipe: \(error.localizedDescription)")
          }
      }
}

// MARK: - 2. ADD INGREDIENT MODAL
struct AddIngredientModalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var onSave: (FoodItem) -> Void
    
    @State private var name: String = ""
    @State private var weight: Double?
    
    // Data per 100g
    @State private var calsPer100: Int?
    @State private var protPer100: Double?
    @State private var fatsPer100: Double?
    @State private var carbsPer100: Double?
    
    var isFormValid: Bool {
        !name.isEmpty && (weight ?? 0) > 0 && (calsPer100 != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Ingredient Details") {
                    TextField("Name (e.g. Chicken Breast)", text: $name)
                    TextField("Weight added to recipe (g)", value: $weight, format: .number)
                        .keyboardType(.decimalPad)
                }
                
                Section(header: Text("Nutritional Value per 100g").foregroundColor(.themePink)) {
                    TextField("Calories (kcal)", value: $calsPer100, format: .number)
                        .keyboardType(.numberPad)
                    TextField("Protein (g)", value: $protPer100, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Fats (g)", value: $fatsPer100, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Carbs (g)", value: $carbsPer100, format: .number)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("New Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { createAndSaveIngredient() }
                        .disabled(!isFormValid)
                        .foregroundColor(isFormValid ? .themePink : .gray)
                }
            }
        }
    }
    
    private func createAndSaveIngredient() {
        guard let w = weight, let c100 = calsPer100 else { return }
        
        let p100 = protPer100 ?? 0
        let f100 = fatsPer100 ?? 0
        let cb100 = carbsPer100 ?? 0
        
        // Пересчет на реальный введенный вес:
        let multiplier = w / 100.0
        
        let actualCalories = Int(Double(c100) * multiplier)
        let actualProtein = p100 * multiplier
        let actualFats = f100 * multiplier
        let actualCarbs = cb100 * multiplier
        
        // Создаем глобальный FoodItem, который будет доступен и в других местах
        let newItem = FoodItem(
            name: name,
            weight: w,
            calories: actualCalories,
            protein: actualProtein,
            fats: actualFats,
            carbs: actualCarbs
        )
        
        // Сохраняем в БД (Global Logic)
        modelContext.insert(newItem)
        
        // Возвращаем в локальный стейт рецепта
        onSave(newItem)
        dismiss()
    }
}

// MARK: - 3. CUSTOM INGREDIENT CARD
struct CustomIngredientCard: View {
    let item: FoodItem
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle().fill(Color.themePink.opacity(0.1)).frame(width: 50, height: 50)
                Image(systemName: "leaf.fill").foregroundColor(.themePink)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.headline)
                HStack(spacing: 8) {
                    Text("\(Int(item.weight))g")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2)).cornerRadius(4)
                    
                    Text("\(item.calories) kcal")
                        .font(.caption).foregroundColor(.themePink).bold()
                }
            }
            
            Spacer()
            
            // Macros Mini-Display
            VStack(alignment: .trailing, spacing: 2) {
                Text("P: \(item.protein, specifier: "%.1f")g").font(.caption2).foregroundColor(.themePeach)
                Text("F: \(item.fats, specifier: "%.1f")g").font(.caption2).foregroundColor(.themeYellow)
                Text("C: \(item.carbs, specifier: "%.1f")g").font(.caption2).foregroundColor(.themeOrange)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 3, y: 2)
    }
}

// MARK: - 4. RECIPE DETAIL VIEW (Навигация после сохранения)
struct RecipeDetailView: View {
    let recipe: CustomRecipe
    @Binding var path: NavigationPath
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                VStack(spacing: 8) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.themeYellow)
                        .padding(.top)
                    
                    Text(recipe.name)
                        .font(.title).bold()
                    
                    Text(recipe.info)
                        .font(.subheadline).foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 20) {
                        Label("\(recipe.cookingTime) min", systemImage: "clock")
                        Label(recipe.difficulty, systemImage: "flame")
                    }
                    .font(.caption).bold().foregroundColor(.themeOrange)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 5)
                
                // Total Kcal Big Badge
                HStack {
                    Text("Total Energy")
                    Spacer()
                    Text("\(recipe.totalCalories) kcal")
                        .font(.title2).bold().foregroundColor(.themePink)
                }
                .premiumCardStyle()
                
                VStack(alignment: .leading) {
                    Text("Ingredients").font(.title3).bold().padding(.bottom, 8)
                    ForEach(recipe.foodItems) { item in
                        CustomIngredientCard(item: item)
                            .padding(.bottom, 4)
                    }
                }
            }
            .padding()
        }
        .background(Color.themeBg)
        .navigationTitle("Recipe Saved!")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Кнопка, чтобы вернуться в самый корень
                Button("Done") {
                    path.removeLast(path.count)
                }.bold()
            }
        }
    }
}

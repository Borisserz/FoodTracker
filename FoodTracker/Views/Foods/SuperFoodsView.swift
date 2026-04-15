//
//  SuperFoodsView.swift
//  FoodTracker
//

import SwiftUI
import SwiftData

// MARK: - МОДЕЛИ ДАННЫХ ДЛЯ КАТЕГОРИЙ
struct FoodItemDetail: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let calories: Int
    let icon: String
}

struct FoodCategory: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let items: [FoodItemDetail]
}

// MARK: - ГЛАВНЫЙ ЭКРАН ДИЕТ (Вызывается из Foods Hub)
struct DietsListView: View {
    @State private var selectedDiet: DietPlan = DietPlan.allDiets[0]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // 1. DIET SELECTOR
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(DietPlan.allDiets) { diet in
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    selectedDiet = diet
                                }
                            }) {
                                Text(diet.name)
                                    .font(.subheadline)
                                    .bold()
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 10)
                                    .background(selectedDiet.id == diet.id ? diet.color : Color.gray.opacity(0.1))
                                    .foregroundColor(selectedDiet.id == diet.id ? .white : .primary)
                                    .cornerRadius(20)
                                    .shadow(color: selectedDiet.id == diet.id ? diet.color.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                // 2. DYNAMIC DASHBOARD
                NavigationLink(destination: DietDetailView(diet: selectedDiet)) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(selectedDiet.name)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text(selectedDiet.tagline)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                            }
                            Spacer()
                            
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(selectedDiet.color)
                        }
                        
                        Divider()
                        
                        HStack(spacing: 24) {
                            DietMacroMiniView(title: "Fat", value: selectedDiet.macroBreakdown.fat, color: .themeYellow)
                            DietMacroMiniView(title: "Protein", value: selectedDiet.macroBreakdown.protein, color: .themePeach)
                            DietMacroMiniView(title: "Carbs", value: selectedDiet.macroBreakdown.carbs, color: .themeOrange)
                            Spacer()
                        }
                    }
                    .premiumCardStyle()
                }
                .padding(.horizontal)
                .buttonStyle(PlainButtonStyle())
                
                // 3. FOOD CATEGORIES
                VStack(alignment: .leading, spacing: 16) {
                    Text("Top Foods")
                        .font(.title2)
                        .bold()
                        .padding(.horizontal)
                    
                    ForEach(selectedDiet.categories) { category in
                        FoodCategorySection(category: category)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 30)
                
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedDiet)
        }
        .background(Color.themeBg.edgesIgnoringSafeArea(.bottom))
        .navigationTitle("Diet Plans")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - UI КОМПОНЕНТЫ ДЛЯ ДИЕТ

struct DietMacroMiniView: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)%")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .bold()
        }
    }
}

struct FoodCategorySection: View {
    let category: FoodCategory
    @State private var isExpanded: Bool = true
    
    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                VStack(spacing: 0) {
                    ForEach(category.items.indices, id: \.self) { index in
                        let item = category.items[index]
                        
                        HStack(spacing: 16) {
                            Text(item.icon)
                                .font(.system(size: 24))
                                .frame(width: 40, height: 40)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                            
                            Text(item.name)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                            
                            Spacer()
                            
                            Text("\(item.calories) kcal")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.themePink)
                        }
                        .padding(.vertical, 12)
                        
                        if index < category.items.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.top, 8)
            },
            label: {
                Text(category.title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        )
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}


// MARK: - DIET DETAIL VIEW

struct DietDetailView: View {
    let diet: DietPlan
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(diet.name).font(.title).bold()
                    Text(diet.tagline).font(.subheadline).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(diet.description)
                    .font(.body)
                    .lineSpacing(4)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Target Macros").font(.headline)
                    HStack(spacing: 16) {
                        MacroBreakdownCircle(percentage: diet.macroBreakdown.fat, label: "Fat", color: .themeYellow)
                        MacroBreakdownCircle(percentage: diet.macroBreakdown.protein, label: "Protein", color: .themePeach)
                        MacroBreakdownCircle(percentage: diet.macroBreakdown.carbs, label: "Carbs", color: .themeOrange)
                        Spacer()
                    }
                }
                .premiumCardStyle()
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text("Best Foods").font(.headline)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                        ForEach(diet.bestFoods, id: \.self) { food in
                            Text(food)
                                .font(.caption).bold().padding(8).frame(maxWidth: .infinity)
                                .background(diet.color.opacity(0.1)).foregroundColor(diet.color).cornerRadius(8)
                        }
                    }
                }
                .padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(diet.color.opacity(0.05)).cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                        Text("Contraindications").font(.headline)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(diet.contraindications, id: \.self) { warning in
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle.fill").font(.caption).foregroundColor(.red)
                                Text(warning).font(.subheadline).foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.05)).cornerRadius(12)
                
                // КНОПКА АКТИВАЦИИ ДИЕТЫ
                if let user = users.first {
                    let isCurrentDiet = user.activeDietName == diet.name
                    
                    Button(action: {
                        if !isCurrentDiet {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                user.applyDietBreakdown(
                                    fatPercent: diet.macroBreakdown.fat,
                                    proteinPercent: diet.macroBreakdown.protein,
                                    carbsPercent: diet.macroBreakdown.carbs,
                                    dietName: diet.name
                                )
                                try? context.save()
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            if isCurrentDiet {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Current Diet")
                            } else {
                                Text("Start \(diet.name) Diet")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isCurrentDiet ? Color.gray.opacity(0.6) : diet.color)
                        .cornerRadius(12)
                        .shadow(color: isCurrentDiet ? .clear : diet.color.opacity(0.4), radius: 5, y: 2)
                    }
                    .disabled(isCurrentDiet)
                    .padding(.top, 10)
                }
            }
            .padding()
            .padding(.bottom, 20)
        }
        .background(Color.themeBg)
        .navigationTitle(diet.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MacroBreakdownCircle: View {
    let percentage: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(color.opacity(0.1))
                VStack(spacing: 2) {
                    Text("\(percentage)%").font(.headline).foregroundColor(color)
                    Text(label).font(.caption2).foregroundColor(.gray)
                }
            }
            .frame(width: 60, height: 60)
        }
    }
}

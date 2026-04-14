//
//  ChefRecipesView.swift
//  FoodTracker
//

import SwiftUI

// MARK: - 1. Data Model & Mock Data
struct ChefRecipe: Identifiable, Equatable {
    let id = UUID()
    let chef: String
    let name: String
    let calories: String
    let time: String
    let isPro: Bool
    let color1: Color
    let color2: Color
    let icon: String
    let description: String
}

let mockChefRecipes: [ChefRecipe] = [
    // Gordon Ramsay
    ChefRecipe(
        chef: "Gordon Ramsay", name: "Fit Beef Wellington", calories: "550 kcal", time: "45m", isPro: true,
        color1: .themePink, color2: .themeOrange, icon: "flame.fill",
        description: "A lean and protein-packed take on the classic Wellington. We substitute the heavy pastry for a lighter whole-grain wrap and use extra lean beef cut to keep your macros perfectly balanced."
    ),
    ChefRecipe(
        chef: "Gordon Ramsay", name: "Mediterranean Salmon", calories: "420 kcal", time: "30m", isPro: true,
        color1: .blue, color2: .cyan, icon: "fish.fill",
        description: "Fresh Atlantic salmon pan-seared with a drizzle of olive oil, served over a bed of quinoa and roasted cherry tomatoes. Heart-healthy and rich in Omega-3s."
    ),
    ChefRecipe(
        chef: "Gordon Ramsay", name: "Scrambled Eggs", calories: "320 kcal", time: "10m", isPro: false,
        color1: .themeYellow, color2: .themeOrange, icon: "fork.knife",
        description: "The perfect scrambled eggs. Cooked low and slow for a creamy texture without the need for heavy cream. A staple for any healthy morning routine."
    ),
    
    // Jamie Oliver
    ChefRecipe(
        chef: "Jamie Oliver", name: "15-Min Healthy Pasta", calories: "480 kcal", time: "15m", isPro: true,
        color1: .green, color2: .mint, icon: "leaf.fill",
        description: "Quick, simple, and packed with hidden veggies. This whole wheat pasta dish uses a vibrant spinach and basil pesto that comes together in minutes."
    ),
    ChefRecipe(
        chef: "Jamie Oliver", name: "Veggie Salad Supreme", calories: "290 kcal", time: "20m", isPro: false,
        color1: .green, color2: .themeYellow, icon: "carrot.fill",
        description: "A beautiful, colorful bowl of goodness. Crunchy bell peppers, cucumber, chickpeas, and a light lemon-tahini dressing make this the perfect lunch."
    ),
    ChefRecipe(
        chef: "Jamie Oliver", name: "Green Smoothie Bowl", calories: "350 kcal", time: "10m", isPro: true,
        color1: .mint, color2: .teal, icon: "cup.and.saucer.fill",
        description: "Start your day right with this refreshing smoothie bowl. Blended with avocado, spinach, and a scoop of your favorite plant protein."
    )
]

// MARK: - Custom Button Style
struct RecipeCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - 2. Chef Recipes View (Hero Animation Core)
struct ChefRecipesView: View {
    @Namespace private var animation
    @State private var selectedRecipe: ChefRecipe? = nil
    @State private var showDetail: Bool = false
    
    var body: some View {
        ZStack {
            // BASE STATE (List / Grid)
            NavigationStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Pro Badge
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Premium Feature")
                                    .font(.caption)
                                    .bold()
                                    .padding(4)
                                    .background(Color.white.opacity(0.3))
                                    .cornerRadius(8)
                                
                                Text("Unlock Chef Recipes")
                                    .font(.title3)
                                    .bold()
                            }
                            .foregroundColor(.white)
                            
                            Spacer()
                            
                            Image(systemName: "lock.open.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.themePink, .themeOrange]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                        .padding()
                        
                        // Chef Sections
                        ChefSectionView(
                            chefName: "Gordon Ramsay",
                            sectionIcon: "flame.fill",
                            recipes: mockChefRecipes.filter { $0.chef == "Gordon Ramsay" },
                            animation: animation,
                            selectedRecipe: $selectedRecipe,
                            showDetail: $showDetail
                        )
                        .padding(.horizontal)
                        
                        ChefSectionView(
                            chefName: "Jamie Oliver",
                            sectionIcon: "leaf.fill",
                            recipes: mockChefRecipes.filter { $0.chef == "Jamie Oliver" },
                            animation: animation,
                            selectedRecipe: $selectedRecipe,
                            showDetail: $showDetail
                        )
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .background(Color.themeBg)
                .navigationTitle("Chef's Specials")
            }
            
            // FULLSCREEN DETAIL STATE (Overlay)
            if showDetail, let recipe = selectedRecipe {
                ChefRecipeDetailView(
                    recipe: recipe,
                    animation: animation,
                    onDismiss: dismissDetail
                )
                .transition(.identity) // Keeps structural matching seamless
                .zIndex(1)
            }
        }
    }
    
    private func dismissDetail() {
        // Транзиция закрытия с требуемыми параметрами
        withAnimation(.spring(response: 0.55, dampingFraction: 0.75, blendDuration: 0)) {
            showDetail = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            selectedRecipe = nil
        }
    }
}

// MARK: - 3. Chef Section View
struct ChefSectionView: View {
    let chefName: String
    let sectionIcon: String
    let recipes: [ChefRecipe]
    
    var animation: Namespace.ID
    @Binding var selectedRecipe: ChefRecipe?
    @Binding var showDetail: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: sectionIcon)
                    .foregroundColor(.themeOrange)
                Text(chefName)
                    .font(.title3)
                    .bold()
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recipes) { recipe in
                        RecipeCard(
                            recipe: recipe,
                            animation: animation,
                            selectedRecipe: $selectedRecipe,
                            showDetail: $showDetail
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

// MARK: - 4. Expanding Recipe Card (Base Model)
struct RecipeCard: View {
    let recipe: ChefRecipe
    var animation: Namespace.ID
    @Binding var selectedRecipe: ChefRecipe?
    @Binding var showDetail: Bool
    
    var body: some View {
        Button {
            HapticManager.shared.impact(style: .medium)
            selectedRecipe = recipe
            // Вызов транзиции по заданным Apple Design параметрам
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75, blendDuration: 0)) {
                showDetail = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                
                // Hero Image Gradient
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [recipe.color1, recipe.color2], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .matchedGeometryEffect(id: "bg_\(recipe.id)", in: animation)
                    
                    Image(systemName: recipe.icon)
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
                        .matchedGeometryEffect(id: "icon_\(recipe.id)", in: animation)
                }
                .frame(height: 100)
                
                // Title (БЕЗ matchedGeometryEffect, чтобы текст не прыгал)
                Text(recipe.name)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Metadata
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundColor(.themeOrange)
                        Text(recipe.calories)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.themeYellow)
                        Text(recipe.time)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if recipe.isPro {
                        Text("PRO")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.themeOrange)
                            .cornerRadius(4)
                    }
                }
            }
            .padding(10)
            .frame(width: 180)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2)
        }
        .buttonStyle(RecipeCardButtonStyle()) // Кастомная анимация уменьшения при нажатии
        .opacity(selectedRecipe?.id == recipe.id && showDetail ? 0 : 1)
    }
}

// MARK: - 5. Fullscreen Overlay (Detail View)
struct ChefRecipeDetailView: View {
    let recipe: ChefRecipe
    var animation: Namespace.ID
    var onDismiss: () -> Void
    
    // Стейт для каскадного появления текста и кнопки "назад"
    @State private var showContent = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                
                // Hero Header Area (Parallax)
                GeometryReader { geo in
                    let minY = geo.frame(in: .global).minY
                    let isScrollingDown = minY > 0
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(LinearGradient(colors: [recipe.color1, recipe.color2], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .matchedGeometryEffect(id: "bg_\(recipe.id)", in: animation)
                        
                        Image(systemName: recipe.icon)
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                            .scaleEffect(1.0 + (isScrollingDown ? minY / 500 : 0)) // Parallax увеличение иконки
                            .matchedGeometryEffect(id: "icon_\(recipe.id)", in: animation)
                    }
                    // Увеличиваем высоту и смещаем вверх при pull down (Rubber-banding)
                    .frame(height: 380 + (isScrollingDown ? minY : 0))
                    .offset(y: isScrollingDown ? -minY : 0)
                }
                .frame(height: 380)
                .zIndex(1)
                
                // Content Information (Cascaded Animation)
                VStack(alignment: .leading, spacing: 20) {
                    
                    Text(recipe.name)
                        .font(.title)
                        .bold()
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 16) {
                        Label(recipe.calories, systemImage: "flame.fill")
                            .foregroundColor(.themeOrange)
                        Label(recipe.time, systemImage: "clock.fill")
                            .foregroundColor(.themeYellow)
                        if recipe.isPro {
                            Label("Pro Feature", systemImage: "star.fill")
                                .foregroundColor(.themePink)
                        }
                    }
                    .font(.subheadline.bold())
                    
                    Divider()
                    
                    // Recipe Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About this recipe")
                            .font(.title3)
                            .bold()
                        
                        Text(recipe.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineSpacing(6)
                    }
                    .premiumCardStyle()
                    
                    // Call to Action
                    Button {
                        HapticManager.shared.impact(style: .medium)
                    } label: {
                        HStack {
                            Text(recipe.isPro ? "Unlock Pro to Cook" : "Start Cooking")
                            Image(systemName: "chevron.right")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(recipe.isPro ? Color.themeOrange : Color.themePink)
                        .cornerRadius(12)
                        .shadow(color: recipe.isPro ? Color.themeOrange.opacity(0.4) : Color.themePink.opacity(0.4), radius: 6, y: 3)
                    }
                    .padding(.top, 10)
                }
                .padding(24)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
            }
        }
        .background(Color.themeBg.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .onAppear {
            // Каскадное появление контента после транзиции Hero-шапки
            withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
                showContent = true
            }
        }
        .overlay(alignment: .topTrailing) {
            // App Store-style Blur Dismiss Button
            Button {
                HapticManager.shared.impact(style: .rigid) // Rigid haptic on close
                
                // Скрываем текст мгновенно, чтобы он не мелькал при возвращении карточки
                withAnimation(.easeOut(duration: 0.15)) {
                    showContent = false
                }
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding(.trailing, 20)
            .padding(.top, 50)
            // Появляется плавно вместе с контентом
            .opacity(showContent ? 1 : 0)
            .scaleEffect(showContent ? 1 : 0.8)
        }
    }
}

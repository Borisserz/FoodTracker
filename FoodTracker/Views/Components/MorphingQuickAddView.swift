//
//  MorphingQuickAddView.swift
//  FoodTracker
//
//  Created by Boris Serzhanovich on 14.04.26.
//

//
//  MorphingQuickAddView.swift
//  FoodTracker
//

import SwiftUI

struct MorphingQuickAddView: View {
    @State private var isExpanded = false
    @State private var isBreathing = false
    
    var onSelectMeal: (String) -> Void
    
    let mealOptions = [
        ("Breakfast", "sunrise.fill"),
        ("Lunch", "sun.max.fill"),
        ("Snack", "cup.and.saucer.fill"),
        ("Dinner", "moon.fill")
    ]
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Невидимый слой на весь экран для закрытия по тапу вне панели
            if isExpanded {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeMenu()
                    }
            }
            
            // Основной контейнер, который будет морфировать
            VStack(alignment: .trailing, spacing: 0) {
                if isExpanded {
                    VStack(spacing: 12) {
                        ForEach(mealOptions, id: \.0) { meal, icon in
                            Button(action: {
                                HapticManager.shared.impact(style: .heavy)
                                onSelectMeal(meal)
                                closeMenu()
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: icon)
                                        .font(.title3)
                                        .foregroundColor(.themePink)
                                        .frame(width: 30)
                                    
                                    Text(meal)
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(Color.white.opacity(0.6))
                                .cornerRadius(16)
                            }
                            // Анимация появления кнопок
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .frame(width: 220)
                }
                
                // Кнопка (иконка меняется с + на крестик)
                Button(action: {
                    isExpanded ? closeMenu() : openMenu()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(isExpanded ? .primary : .white)
                        .rotationEffect(.degrees(isExpanded ? 135 : 0)) // Превращение плюса в крестик
                        .frame(width: 60, height: 60)
                        .contentShape(Rectangle())
                }
                .background(
                    ZStack {
                        if isExpanded {
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                                .padding(8)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                )
            }
            // Единый морфирующий фон
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: isExpanded ? 28 : 30)
                        .fill(.ultraThinMaterial)
                        .opacity(isExpanded ? 1 : 0)
                    
                    RoundedRectangle(cornerRadius: isExpanded ? 28 : 30)
                        .fill(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .opacity(isExpanded ? 0 : 1)
                }
                // Тень увеличивается при раскрытии
                .shadow(color: isExpanded ? Color.black.opacity(0.15) : .themePink.opacity(0.4), radius: 10, y: 5)
            )
            // Пульсация
            .scaleEffect(!isExpanded && isBreathing ? 1.05 : 1.0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }
    
    private func openMenu() {
        HapticManager.shared.impact(style: .medium)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isExpanded = true
        }
    }
    
    private func closeMenu() {
        HapticManager.shared.impact(style: .light)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isExpanded = false
        }
    }
}

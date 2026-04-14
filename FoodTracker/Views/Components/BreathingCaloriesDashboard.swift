//
//  BreathingCaloriesDashboard.swift
//  FoodTracker
//
//  Created by Boris Serzhanovich on 14.04.26.
//

//
//  BreathingCaloriesDashboard.swift
//  FoodTracker
//

import SwiftUI

struct BreathingCaloriesDashboard: View {
    let consumed: Int
    let target: Int
    let activeBurned: Int
    
    @State private var isBreathing = false
    @State private var showRemaining = false
    
    // Стейт для плавной стартовой анимации заполнения кольца
    @State private var animatedProgress: Double = 0.0
    
    private var progress: Double {
        // Ограничиваем прогресс единицей, чтобы кольцо не ломалось при переедании
        min(Double(consumed) / Double(max(target, 1)), 1.0)
    }
    
    private var remaining: Int {
        target - consumed
    }
    
    private var isOver: Bool {
        consumed > target
    }
    
    // Бесшовный круговой градиент в стиле Apple Fitness
    private let ringGradient = AngularGradient(
        gradient: Gradient(colors: [.themeYellow, .themeOrange, .themePink, .themeYellow]),
        center: .center,
        startAngle: .degrees(-90),
        endAngle: .degrees(270)
    )
    
    // Градиент при превышении лимита калорий
    private let overeatingGradient = AngularGradient(
        gradient: Gradient(colors: [.red, .themePink, .red]),
        center: .center,
        startAngle: .degrees(-90),
        endAngle: .degrees(270)
    )
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // 1. Фоновое кольцо
                Circle()
                    .stroke(Color.gray.opacity(0.12), lineWidth: 22)
                
                // 2. Кольцо прогресса
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        isOver ? overeatingGradient : ringGradient,
                        style: StrokeStyle(lineWidth: 22, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    // Анимация "Дыхания" через тень
                    .shadow(
                        color: (isOver ? Color.red : Color.themePink).opacity(0.4),
                        radius: isBreathing ? 15 : 5,
                        x: 0,
                        y: isBreathing ? 8 : 2
                    )
                    // Пружинная анимация при изменении значения калорий
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: animatedProgress)
                
                // 3. Внутренний контент (Интерактивный)
                VStack(spacing: 4) {
                    Text(showRemaining ? "\(abs(remaining))" : "\(consumed)")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundColor(isOver && showRemaining ? .red : .primary)
                        .contentTransition(.numericText())
                    
                    Text(showRemaining ? (isOver ? "kcal over" : "kcal left") : "kcal eaten")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    if showRemaining && !isOver {
                        Text("of \(target)")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.6))
                    } else if !showRemaining {
                        Text("Goal: \(target)")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }
            }
            .frame(width: 220, height: 220)
            .padding(.top, 10)
            // Интерактив по тапу
            .onTapGesture {
                HapticManager.shared.impact(style: .rigid)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showRemaining.toggle()
                }
            }
            
            // 4. Плашка сожженных калорий (Интеграция Apple Health)
            if activeBurned > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.themeOrange)
                    Text("+\(activeBurned) kcal burned")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.themeOrange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.themeOrange.opacity(0.1))
                .cornerRadius(20)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            // Запуск "дыхания" при появлении экрана
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
            // Задержка запуска прогресса для красивого эффекта заполнения (Fill-up Animation)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            animatedProgress = newValue
        }
    }
}

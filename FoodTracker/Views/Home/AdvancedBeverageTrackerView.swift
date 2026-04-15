//============================================================
// FILE: FoodTracker/Views/Home/AdvancedBeverageTrackerView.swift
//============================================================

import SwiftUI
import SwiftData

struct WaterGridTrackerView: View {
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    
    @Bindable var summary: DailySummary
    
    let dailyGoalLiters = 2.5
    let volumePerGlassMl: Double = 250.0
    
    var totalGlassesNeeded: Int {
        Int((dailyGoalLiters * 1000) / volumePerGlassMl)
    }
    
    var waterBeverages: [Beverage] {
        summary.beverages.filter { $0.name == "Water" }.sorted { $0.date < $1.date }
    }
    
    var waterLiters: Double {
        waterBeverages.reduce(0) { $0 + $1.volumeMl } / 1000.0
    }
    
    var filledGlassesCount: Int {
        Int((waterLiters * 1000) / volumePerGlassMl)
    }
    
    var isGoalReached: Bool { waterLiters >= dailyGoalLiters }
    
    var body: some View {
        VStack(spacing: 24) {
            
            // 1. ПРЕМИАЛЬНАЯ ШАПКА
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Water balance")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(waterLiters, specifier: "%.2f")")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundColor(isGoalReached ? .blue : .cyan)
                            .contentTransition(.numericText(value: waterLiters))
                        
                        Text("L")
                            .font(.title3.bold())
                            .foregroundColor(isGoalReached ? .blue : .cyan)
                        
                        Text("/ \(dailyGoalLiters, specifier: "%.2f") L goal")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.8))
                            .fontWeight(.medium)
                    }
                }
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: isGoalReached ? "drop.fill" : "drop")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.cyan)
                        .symbolEffect(.bounce, value: filledGlassesCount)
                }
                .shadow(color: Color.cyan.opacity(isGoalReached ? 0.4 : 0), radius: 8, x: 0, y: 4)
            }
            
            // 2. СЕТКА СТАКАНОВ
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 16) {
                ForEach(0..<totalGlassesNeeded, id: \.self) { index in
                    let isFilled = index < filledGlassesCount
                    let isNext = index == filledGlassesCount
                    let isLastFilled = isFilled && index == filledGlassesCount - 1
                    
                    WaterGlassItemView(
                        isFilled: isFilled,
                        isNext: isNext,
                        isLastFilled: isLastFilled
                    ) {
                        if isLastFilled {
                            removeLastWaterGlass()
                        } else if isNext {
                            addWaterGlass()
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [.white, Color.cyan.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(28)
        .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 8)
        .shadow(color: isGoalReached ? Color.cyan.opacity(0.1) : .clear, radius: 20, y: 10)
    }
    
    // MARK: - Логика действий
    private func addWaterGlass() {
        HapticManager.shared.impact(style: .medium)
        let newBeverage = Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: volumePerGlassMl)
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            context.insert(newBeverage)
            summary.beverages.append(newBeverage)
            try? context.save()
        }
        
        if let user = users.first, user.isHealthKitEnabled {
            HealthKitManager.shared.saveWater(liters: volumePerGlassMl / 1000.0, date: Date())
        }
    }
    
    private func removeLastWaterGlass() {
        HapticManager.shared.impact(style: .light)
        guard let lastWater = waterBeverages.last else { return }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            if let index = summary.beverages.firstIndex(of: lastWater) {
                summary.beverages.remove(at: index)
            }
            context.delete(lastWater)
            try? context.save()
        }
    }
}

// MARK: - View отдельного стакана
struct WaterGlassItemView: View {
    let isFilled: Bool
    let isNext: Bool
    let isLastFilled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            GlassContentView(isFilled: isFilled, isNext: isNext, isLastFilled: isLastFilled)
        }
        .buttonStyle(WaterGlassButtonStyle())
        .disabled(!isNext && !isLastFilled) // Доступен только следующий для плюса и последний для минуса
    }
}

// MARK: - Отрисовка стакана (Полностью переделан визуал)
struct GlassContentView: View {
    let isFilled: Bool
    let isNext: Bool
    let isLastFilled: Bool
    
    @State private var isPulsing = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            // 1. Форма стакана (Фон)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isNext ? Color.cyan.opacity(0.08) : Color.gray.opacity(0.04))
            
            // 2. Вода (Анимированная заливка снизу вверх)
            GeometryReader { geo in
                VStack {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.8), Color.blue.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: isFilled ? geo.size.height : 0)
                        .opacity(isFilled ? 1 : 0)
                }
            }
            .padding(3) // Внутренний отступ воды от краев стакана
            
            // 3. Обводка
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isNext ? Color.cyan.opacity(0.6) : (isFilled ? .clear : Color.gray.opacity(0.15)),
                    lineWidth: isNext ? 2 : 1
                )
            
            // 4. Иконки действий
            if isNext {
                // Плюсик для следующего стакана
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.cyan)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .scaleEffect(isPulsing ? 1.15 : 0.9)
                    .opacity(isPulsing ? 1.0 : 0.5)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            isPulsing = true
                        }
                    }
            } else if isLastFilled {
                // НОВОЕ: Очевидная иконка минуса на последнем стакане
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                // Легкое появление иконки минуса
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: 70)
        .contentShape(Rectangle()) // Чтобы нажималась вся область
    }
}

// MARK: - Чистый стиль кнопки
struct WaterGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0) // Приятное пружинящее сжатие при тапе
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

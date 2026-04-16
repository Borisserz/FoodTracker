//
//  WeightTrackerCardView.swift
//  FoodTracker
//
//  Created by Boris Serzhanovich on 15.04.26.
//

// FILE: FoodTracker/Views/Home/WeightTrackerCardView.swift

import SwiftUI
import SwiftData
import Charts

struct WeightTrackerCardView: View {
    @Environment(\.modelContext) private var context
    
    // Используем @Bindable для прямого изменения summary
    @Bindable var summary: DailySummary
    
    // Запрос всех записей для построения графика
    @Query(sort: \DailySummary.date, order: .reverse)
    private var allSummaries: [DailySummary]
    
    @State private var showingWeightInputSheet = false
    
    // 1. ГОТОВИМ ДАННЫЕ ДЛЯ ГРАФИКА
    private var chartData: [(date: Date, weight: Double)] {
        // Берем последние 7 дней с записями о весе
        allSummaries
            .filter { $0.weight != nil && $0.weight! > 0 }
            .prefix(7)
            .map { (date: $0.date, weight: $0.weight!) }
            .reversed() // Переворачиваем для правильного отображения на графике
    }
    
    // 2. ВЫЧИСЛЯЕМ ТРЕНД (ВВЕРХ/ВНИЗ/СТАБИЛЬНО)
    private var weightTrend: (value: Double, icon: String, color: Color) {
        // Находим индекс текущего дня в отсортированном массиве
        guard let currentIndex = allSummaries.firstIndex(where: { $0.id == summary.id }) else {
            return (0, "minus", .gray)
        }
        
        // Находим предыдущую запись с весом
        let previousEntry = allSummaries
            .suffix(from: currentIndex + 1)
            .first(where: { $0.weight != nil && $0.weight! > 0 })
        
        guard let currentWeight = summary.weight, let previousWeight = previousEntry?.weight else {
            return (0, "minus", .gray)
        }
        
        let diff = currentWeight - previousWeight
        
        if abs(diff) < 0.1 {
            return (diff, "minus", .gray)
        } else if diff > 0 {
            return (diff, "arrow.up.right", .red)
        } else {
            return (diff, "arrow.down.right", .green)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 3. ШАПКА КАРТОЧКИ
            HStack {
                Text("Weight Progress")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "figure.walk")
                    .font(.title2)
                    .foregroundColor(.themeOrange)
            }
            
            // 4. ГЛАВНЫЙ БЛОК С ЦИФРАМИ
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading) {
                    if let weight = summary.weight, weight > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", weight))
                                .font(.system(size: 40, weight: .heavy, design: .rounded))
                                .foregroundColor(.themeOrange)
                                .contentTransition(.numericText(value: weight))
                            Text("kg")
                                .font(.title3.bold())
                                .foregroundColor(.gray.opacity(0.8))
                        }
                    } else {
                        Text("Log Weight")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                    
                    let trend = weightTrend
                    if trend.value != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: trend.icon)
                            Text(String(format: "%+.1f kg", trend.value))
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(trend.color)
                        .padding(.top, 4)
                    }
                }
                
                Spacer()
                
                // 5. МИНИ-ГРАФИК
                if !chartData.isEmpty {
                    Chart {
                        ForEach(chartData, id: \.date) { item in
                            // Линия тренда
                            LineMark(
                                x: .value("Date", item.date),
                                y: .value("Weight", item.weight)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.themeOrange)
                            .symbol(Circle().strokeBorder(lineWidth: 2))
                            
                            // Градиентная область под линией
                            AreaMark(
                                x: .value("Date", item.date),
                                y: .value("Weight", item.weight)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.themeOrange.opacity(0.3), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 60)
                } else {
                    // Состояние, если данных для графика еще нет
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.1))
                }
            }
        }
        .ultraPremiumCardStyle()
        .onTapGesture {
            HapticManager.shared.impact(style: .medium)
            showingWeightInputSheet = true
        }
        .sheet(isPresented: $showingWeightInputSheet) {
                    WeightInputSheet(
                        currentWeight: $summary.weight,
                        onSave: {
                            // ✅ ИСПРАВЛЕНО: Безопасное сохранение веса
                            if summary.modelContext == nil {
                                context.insert(summary)
                            }
                            try? context.save()
                        }
                    )
                    .presentationDetents([.fraction(0.4), .medium])
                    .presentationCornerRadius(32)
                }
    }
}


// MARK: - Шторка для ввода веса
private struct WeightInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var currentWeight: Double?
    var onSave: () -> Void
    
    @State private var weightValue: Double
    
    init(currentWeight: Binding<Double?>, onSave: @escaping () -> Void) {
        self._currentWeight = currentWeight
        self.onSave = onSave
        self._weightValue = State(initialValue: currentWeight.wrappedValue ?? 75.0)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
            
            Text("Enter Today's Weight")
                .font(.headline)
            
            // Большой дисплей с весом
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", weightValue))
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                Text("kg")
                    .font(.title.bold())
                    .foregroundColor(.gray)
            }
            
            // Кастомный степпер
            HStack(spacing: 20) {
                WeightStepperButton(icon: "minus") { adjustWeight(by: -0.1) }
                WeightStepperButton(icon: "plus") { adjustWeight(by: 0.1) }
            }
            
            // Кнопка сохранения
            Button(action: {
                HapticManager.shared.impact(style: .heavy)
                currentWeight = weightValue
                onSave()
                dismiss()
            }) {
                Text("Save Weight")
                    .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity)
                    .padding().background(Color.themeOrange).cornerRadius(16)
            }
            .buttonStyle(BounceButtonStyle())
            
            Spacer()
        }
        .padding()
        .background(Color.themeBg.ignoresSafeArea())
    }
    
    private func adjustWeight(by amount: Double) {
        HapticManager.shared.impact(style: .light)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            weightValue = max(30, weightValue + amount) // Ограничение на минимальный вес
        }
    }
}

// MARK: - Вспомогательные компоненты для шторки
private struct WeightStepperButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title.bold())
                .foregroundColor(.themeOrange)
                .frame(width: 100, height: 60)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
        }
    }
}

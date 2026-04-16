import SwiftUI
struct BreathingCaloriesDashboard: View {
    let consumed: Int
    let target: Int
    let activeBurned: Int
    
    let protein: Double
    let fats: Double
    let carbs: Double
    
    @State private var showRemaining = false
    
    @State private var animC: Double = 0
    @State private var animF: Double = 0
    @State private var animP: Double = 0
    @State private var animOther: Double = 0 // ✅ НОВОЕ: Анимация для быстрых калорий
    
    // 1. Считаем калории, которые пришли строго из БЖУ
    private var macroTotal: Double {
        max(protein * 4.0 + fats * 9.0 + carbs * 4.0, 0)
    }
    
    // 2. Вычисляем "пустые" (быстрые) калории: Общие калории минус калории из БЖУ
    private var otherTotal: Double {
        max(Double(consumed) - macroTotal, 0)
    }
    
    // 3. База для расчета процентов кольца (Цель ИЛИ сколько съели, если перебор)
    private var displayTotal: Double {
        max(Double(target), max(Double(consumed), 1.0))
    }
    
    // 4. Считаем доли (проценты) для каждого куска пирога
    private var cFrac: Double { (carbs * 4.0) / displayTotal }
    private var fFrac: Double { (fats * 9.0) / displayTotal }
    private var pFrac: Double { (protein * 4.0) / displayTotal }
    private var otherFrac: Double { otherTotal / displayTotal } // ✅ НОВОЕ: Доля быстрых калорий
    
    private var remaining: Int { target - consumed }
    private var isOver: Bool { consumed > target }
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // UI Polish: Глубокая внутренняя тень базового круга
                Circle()
                    .stroke(
                        Color.gray.opacity(0.15)
                            .shadow(.inner(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)),
                        lineWidth: 24
                    )
                
                // Сегмент 1: Углеводы + Неоновое свечение
                Circle()
                    .trim(from: 0, to: min(animC, 1.0))
                    .stroke(Color.drinkWater, style: StrokeStyle(lineWidth: 24, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.drinkWater.opacity(0.4), radius: 8, x: 0, y: 0)
                
                // Сегмент 2: Жиры
                Circle()
                    .trim(from: min(animC, 1.0), to: min(animC + animF, 1.0))
                    .stroke(Color.themeYellow, style: StrokeStyle(lineWidth: 24, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.themeYellow.opacity(0.4), radius: 8, x: 0, y: 0)
                
                // Сегмент 3: Белки
                Circle()
                    .trim(from: min(animC + animF, 1.0), to: min(animC + animF + animP, 1.0))
                    .stroke(Color.themePeach, style: StrokeStyle(lineWidth: 24, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.themePeach.opacity(0.4), radius: 8, x: 0, y: 0)
                
                // ✅ НОВОЕ: Сегмент 4: Быстрые калории (Без БЖУ)
                // Рисуется нейтральным серым цветом после всех макросов
                Circle()
                    .trim(from: min(animC + animF + animP, 1.0), to: min(animC + animF + animP + animOther, 1.0))
                    .stroke(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 24, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.gray.opacity(0.2), radius: 5, x: 0, y: 0)
                
                VStack(spacing: 6) {
                    Text(showRemaining ? "\(abs(remaining))" : "\(consumed)")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundColor(isOver && showRemaining ? .red : .primary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: consumed)
                    
                    Text(showRemaining ? (isOver ? "kcal over" : "kcal left") : "kcal eaten")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.textGray)
                    
                    Text(showRemaining && !isOver ? "Goal: \(target)" : "Goal: \(target)")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.textGray)
                }
            }
            .frame(width: 240, height: 240)
            .padding(.top, 10)
            .onTapGesture {
                HapticManager.shared.impact(style: .rigid)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showRemaining.toggle()
                }
            }
            
            if activeBurned > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").foregroundColor(.themeOrange)
                    Text("+\(activeBurned) kcal burned").font(.subheadline).bold().foregroundColor(.themeOrange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.themeOrange.opacity(0.1))
                .cornerRadius(20)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animC = cFrac
                animF = fFrac
                animP = pFrac
                animOther = otherFrac // ✅ Анимация при старте
            }
        }
        .onChange(of: cFrac) { _, nv in animC = nv }
        .onChange(of: fFrac) { _, nv in animF = nv }
        .onChange(of: pFrac) { _, nv in animP = nv }
        .onChange(of: otherFrac) { _, nv in animOther = nv } // ✅ Анимация при обновлении
    }
}

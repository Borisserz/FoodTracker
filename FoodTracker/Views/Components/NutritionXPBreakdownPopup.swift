import SwiftUI

struct NutritionXPBreakdown {
    var baseXP: Int
    var proteinGoalXP: Int
    var calorieGoalXP: Int
    
    var totalXP: Int {
        return baseXP + proteinGoalXP + calorieGoalXP
    }
}

struct NutritionXPBreakdownPopup: View {
    let breakdown: NutritionXPBreakdown
    let onDismiss: () -> Void
    
    @State private var showContent = false
    @State private var animatedBase = 0
    @State private var animatedProtein = 0
    @State private var animatedCalories = 0
    @State private var animatedTotal = 0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 24) {
                Text("DAY COMPLETE!")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: .themePink.opacity(0.8), radius: 10, y: 5)
                    .scaleEffect(showContent ? 1.0 : 0.5)
                    .opacity(showContent ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2), value: showContent)
                
                Text("Great job hitting your targets today!")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeIn.delay(0.4), value: showContent)
                
                VStack(spacing: 16) {
                    xpRow(title: "Base Logging XP", value: animatedBase)
                    
                    if breakdown.proteinGoalXP > 0 {
                        xpRow(title: "Protein Goal Bonus", value: animatedProtein, color: .themePink)
                    }
                    
                    if breakdown.calorieGoalXP > 0 {
                        xpRow(title: "Calorie Match Bonus", value: animatedCalories, color: .themeOrange)
                    }
                    
                    Divider().background(Color.white.opacity(0.3))
                    
                    HStack {
                        Text("Total XP Earned")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Text("+\(animatedTotal) XP")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
                .opacity(showContent ? 1 : 0)
                
                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.themePink)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
                .opacity(showContent ? 1 : 0)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.themeBg)
                    .shadow(color: Color.themePink.opacity(0.4), radius: 30)
            )
            .padding(.horizontal, 32)
            .rotation3DEffect(.degrees(showContent ? 0 : 20), axis: (x: 1, y: 0, z: 0))
            .scaleEffect(showContent ? 1 : 0.8)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showContent = true
            }
            animateNumbers()
        }
    }
    
    private func xpRow(title: String, value: Int, color: Color = .white) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
            Text("+\(value)")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundColor(color)
        }
    }
    
    private func animateNumbers() {
        let steps = 20
        let interval = 0.05
        
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                let fraction = Double(i) / Double(steps)
                animatedBase = Int(Double(breakdown.baseXP) * fraction)
            }
        }
        
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + interval * Double(i)) {
                let fraction = Double(i) / Double(steps)
                animatedProtein = Int(Double(breakdown.proteinGoalXP) * fraction)
                animatedCalories = Int(Double(breakdown.calorieGoalXP) * fraction)
            }
        }
        
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0 + interval * Double(i)) {
                let fraction = Double(i) / Double(steps)
                animatedTotal = Int(Double(breakdown.totalXP) * fraction)
            }
        }
    }
}

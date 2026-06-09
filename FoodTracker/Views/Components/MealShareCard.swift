import SwiftUI

struct MealShareCard: View {
    let summary: DailySummary
    
    var body: some View {
        ZStack {
            backgroundLayer
            
            VStack(spacing: 20) {
                headerSection
                titleSection
                statsGridSection
                Spacer()
                footerSection
            }
            .padding(.top, 40)
        }
        .frame(width: 440, height: 720)
        .background(Color.themeBg)
    }
    
    private var backgroundLayer: some View {
        ZStack {
            Color(red: 0.10, green: 0.11, blue: 0.20).ignoresSafeArea()
            
            Circle()
                .fill(Color.themePink)
                .frame(width: 350)
                .blur(radius: 80)
                .offset(x: -150, y: -250)
                .opacity(0.4)
            
            Circle()
                .fill(Color.themeOrange)
                .frame(width: 300)
                .blur(radius: 90)
                .offset(x: 180, y: 300)
                .opacity(0.35)
                
            Circle()
                .fill(Color.themeYellow)
                .frame(width: 200)
                .blur(radius: 60)
                .offset(x: -100, y: 150)
                .opacity(0.2)
        }
    }
    
    private var headerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
                .shadow(color: .orange.opacity(0.5), radius: 5, y: 2)
            
            Text("DAY LOGGED")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .tracking(3)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
    }
    
    private var titleSection: some View {
        VStack(spacing: 6) {
            Text("\(summary.totalCalories) kcal")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .themePink.opacity(0.5), radius: 20, y: 5)
            
            Text(summary.date.formatted(date: .long, time: .omitted).uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(1)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.top, 10)
    }
    
    private var statsGridSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                statGlassCard(title: "PROTEIN", value: "\(Int(summary.totalProtein))g", icon: "bolt.fill", color: .themePink)
                statGlassCard(title: "CARBS", value: "\(Int(summary.totalCarbs))g", icon: "leaf.fill", color: .themeOrange)
            }
            HStack(spacing: 16) {
                statGlassCard(title: "FATS", value: "\(Int(summary.totalFats))g", icon: "drop.fill", color: .themeYellow)
                statGlassCard(title: "MEALS", value: "\(summary.meals.count)", icon: "fork.knife", color: .green)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    private var footerSection: some View {
        VStack(spacing: 4) {
            Image(systemName: "applewatch")
                .font(.system(size: 24))
                .foregroundStyle(LinearGradient(colors: [.white, .gray], startPoint: .top, endPoint: .bottom))
            
            Text("TRACKED WITH FOODTRACKER")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.bottom, 30)
    }
    
    private func statGlassCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                }
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: color.opacity(0.5), radius: 8, y: 2)
                
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LinearGradient(colors: [Color.white.opacity(0.4), Color.white.opacity(0.0)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
    }
}

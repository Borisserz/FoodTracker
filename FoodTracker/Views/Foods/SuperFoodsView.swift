import SwiftUI
import SwiftData
struct DietsListView: View {
    @Environment(\.modelContext) private var context
    @Query private var users: [User]

    @State private var selectedIndex: Int = 0
    @Namespace private var animation

    var body: some View {
        ZStack {
            // Защита: если диеты еще не загрузились с сервера
            if DietDataLoader.shared.diets.isEmpty {
                VStack {
                    ProgressView()
                    Text("Loading Diet Plans...").foregroundColor(.gray).padding(.top)
                }
            } else {
                // Данные загружены, отображаем интерфейс
                let currentDietColor = DietDataLoader.shared.diets[selectedIndex].color
                currentDietColor.opacity(0.15)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.8), value: selectedIndex)

                VStack(spacing: 0) {

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Diet Plans")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                        Text("Choose your path to success")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    TabView(selection: $selectedIndex) {
                        ForEach(DietDataLoader.shared.diets.indices, id: \.self) { index in
                            let diet = DietDataLoader.shared.diets[index]
                            let isUserActiveDiet = users.first?.activeDietPlan?.key == diet.key

                            NavigationLink(destination: PremiumDietDetailView(diet: diet)) {
                                DietHeroCard(diet: diet, isActive: isUserActiveDiet)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .padding(.vertical, 20)

                    HStack(spacing: 8) {
                        ForEach(DietDataLoader.shared.diets.indices, id: \.self) { index in
                            Circle()
                                .fill(selectedIndex == index ? DietDataLoader.shared.diets[index].color : Color.gray.opacity(0.3))
                                .frame(width: selectedIndex == index ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: selectedIndex)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

struct DietHeroCard: View {
    let diet: DietPlan
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [diet.color.opacity(0.8), diet.color],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "leaf.fill")
                    .font(.system(size: 150))
                    .foregroundStyle(.white.opacity(0.2))
                    .offset(x: 180, y: 50)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    if isActive {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                            Text("ACTIVE PLAN")
                        }
                        .font(.system(.caption, design: .rounded, weight: .black))
                        .foregroundStyle(diet.color)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
                    }

                    Spacer(minLength: 80)

                    Text(diet.name)
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 2)

                    Text(diet.tagline)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(24)
            }

            VStack(spacing: 20) {
                HStack(spacing: 24) {
                    MacroMiniStat(title: "Fat", value: diet.macroBreakdown.fat, color: .themeYellow)
                    MacroMiniStat(title: "Protein", value: diet.macroBreakdown.protein, color: .themePeach)
                    MacroMiniStat(title: "Carbs", value: diet.macroBreakdown.carbs, color: .drinkWater)
                }

                HStack {
                    Text("Learn more")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title)
                }
                .foregroundStyle(diet.color)
            }
            .padding(24)
            .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: diet.color.opacity(0.3), radius: 20, y: 10)
        .padding(.horizontal, 24)
    }
}

struct MacroMiniStat: View {
    let title: String; let value: Int; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Color.gray.opacity(0.15), lineWidth: 4)
                Circle().trim(from: 0, to: CGFloat(value) / 100.0)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(value)%").font(.system(.caption, design: .rounded, weight: .bold))
            }.frame(width: 44, height: 44)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .bold()
        }
        .frame(maxWidth: .infinity)
    }
}

struct PremiumDietDetailView: View {
    let diet: DietPlan
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Query private var users: [User]

    var body: some View {
        let isCurrentDiet = users.first?.activeDietPlan?.key == diet.key

        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    GeometryReader { geo in
                        let minY = geo.frame(in: .global).minY
                        let isScrollingDown = minY > 0

                        ZStack(alignment: .bottomLeading) {

                            LinearGradient(
                                colors: [diet.color.opacity(0.7), diet.color],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(height: isScrollingDown ? 350 + minY : 350)
                            .offset(y: isScrollingDown ? -minY : 0)

                            Image(systemName: "sparkles")
                                .font(.system(size: 150))
                                .foregroundColor(.white.opacity(0.15))
                                .offset(x: 150, y: -40)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(diet.name)
                                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)

                                Text(diet.tagline)
                                    .font(.title3.bold())
                                    .foregroundColor(.white.opacity(0.95))
                                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                            }
                            .padding(24)
                            .padding(.bottom, 40)
                            .offset(y: isScrollingDown ? -minY * 0.5 : 0)
                        }
                    }
                    .frame(height: 350)

                    VStack(spacing: 24) {

                        HStack(spacing: 0) {
                            MacroDonutStat(title: "Fat", percent: diet.macroBreakdown.fat, color: .themeYellow)
                            Divider().frame(height: 50)
                            MacroDonutStat(title: "Protein", percent: diet.macroBreakdown.protein, color: .themePeach)
                            Divider().frame(height: 50)
                            MacroDonutStat(title: "Carbs", percent: diet.macroBreakdown.carbs, color: .drinkWater)
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.05), radius: 15, y: 5)
                        .offset(y: -40)
                        .padding(.bottom, -40)

                        Text(diet.description)
                            .font(.body)
                            .lineSpacing(6)
                            .foregroundColor(.primary.opacity(0.8))
                            .padding(.horizontal, 24)

                        VStack(alignment: .leading, spacing: 16) {
                            Text("What happens when you activate?")
                                .font(.title3.bold())
                                .padding(.horizontal, 24)

                            VStack(spacing: 12) {
                                DietFeatureRow(icon: "chart.pie.fill", color: .themePink, text: "Auto-adjusts your daily Protein, Fat, and Carbs targets.")
                                DietFeatureRow(icon: "magnifyingglass", color: .green, text: "Highlights compatible & forbidden foods while searching.")
                                DietFeatureRow(icon: "sparkles", color: .blue, text: "AI Coach adapts its advice strictly to the \(diet.name) rules.")
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 16) {
                            Text("Approved Foods").font(.title2).bold().padding(.horizontal, 24)
                            ForEach(diet.categories) { category in
                                PremiumFoodCategorySection(category: category, dietColor: diet.color)
                                    .padding(.horizontal, 24)
                            }
                        }

                        Spacer().frame(height: 120)
                    }
                    .background(Color.themeBg)
                }
            }
            .ignoresSafeArea(edges: .top)

            if let user = users.first {
                VStack {
                    Spacer()
                    ZStack {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .frame(height: 110)
                            .mask(LinearGradient(colors: [.white, .white, .clear], startPoint: .bottom, endPoint: .top))

                        Button(action: {
                            HapticManager.shared.impact(style: .heavy)
                            withAnimation(.spring()) {

                                if isCurrentDiet {
                                    user.applyDietBreakdown(
                                        fatPercent: 30,
                                        proteinPercent: 30,
                                        carbsPercent: 40,
                                        dietKey: "balanced"
                                    )
                                } else {
                                    user.applyDietBreakdown(
                                        fatPercent: diet.macroBreakdown.fat,
                                        proteinPercent: diet.macroBreakdown.protein,
                                        carbsPercent: diet.macroBreakdown.carbs,
                                        dietKey: diet.key
                                    )
                                }
                                try? context.save()
                            }
                        }) {
                            HStack {
                                if isCurrentDiet {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Deactivate Plan")
                                } else {
                                    Text("Set as My Diet Plan")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(isCurrentDiet ? .red : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(isCurrentDiet ? Color.red.opacity(0.15) : diet.color)
                            .cornerRadius(24)
                            .shadow(color: isCurrentDiet ? .clear : diet.color.opacity(0.4), radius: 10, y: 5)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 30)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationBarHidden(true)
        .overlay(
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
            }
            .padding(.leading, 20)
            .padding(.top, 50),
            alignment: .topLeading
        )
    }
}

struct DietFeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundColor(color)
            }

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
    }
}

struct MacroDonutStat: View {
    let title: String; let percent: Int; let color: Color
    @State private var anim: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(Color.gray.opacity(0.15), lineWidth: 6)
                Circle().trim(from: 0, to: anim).stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                Text("\(percent)%").font(.system(size: 14, weight: .bold, design: .rounded))
            }.frame(width: 50, height: 50)
            Text(title).font(.caption).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .onAppear { withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) { anim = Double(percent) / 100.0 } }
    }
}

struct PremiumFoodCategorySection: View {
    let category: FoodCategory
    let dietColor: Color
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                HStack {
                    Text(category.title).font(.headline).foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundColor(.gray)
                }
                .padding(20)
                .background(Color.white)
            }

            if isExpanded {
                VStack(spacing: 0) {
                    Divider().padding(.leading, 20)
                    ForEach(category.items) { item in
                        HStack(spacing: 16) {
                            Text(item.icon).font(.title2).frame(width: 40, height: 40).background(dietColor.opacity(0.1)).clipShape(Circle())
                            Text(item.name).font(.system(size: 16, weight: .medium, design: .rounded))
                            Spacer()
                            Text("\(item.calories) kcal").font(.subheadline.bold()).foregroundColor(dietColor)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                    }
                }
                .background(Color.white)
            }
        }
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
    }
}

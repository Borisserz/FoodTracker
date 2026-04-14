import SwiftUI

// MARK: - 📅 Интерактивный Календарь с эффектом фокуса
struct CalendarCarouselView: View {
    @Binding var selectedDate: Date
    
    private var days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (-30...30).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }
    
    var body: some View {
        GeometryReader { scrollGeo in
            let centerPoint = scrollGeo.size.width / 2
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(days, id: \.self) { date in
                            let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                            let isToday = Calendar.current.isDateInToday(date)
                            
                            GeometryReader { itemGeo in
                                // Вычисляем расстояние от центра экрана
                                let midX = itemGeo.frame(in: .global).midX - scrollGeo.frame(in: .global).minX
                                let distance = abs(centerPoint - midX)
                                
                                // Динамическое масштабирование и прозрачность (Cover Flow effect)
                                let scale = isSelected ? 1.05 : max(0.85, 1.0 - (distance / scrollGeo.size.width) * 0.5)
                                let opacity = isSelected ? 1.0 : max(0.5, 1.0 - (distance / scrollGeo.size.width) * 0.8)
                                
                                Button {
                                    HapticManager.shared.impact(style: .light)
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        selectedDate = date
                                        proxy.scrollTo(date, anchor: .center)
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        Text(dayOfWeekString(date))
                                            .font(.caption2)
                                            .fontWeight(isSelected ? .bold : .medium)
                                            .foregroundColor(isSelected ? .white.opacity(0.9) : .gray)
                                        
                                        Text("\(Calendar.current.component(.day, from: date))")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                    }
                                    .frame(width: 56, height: 72)
                                    .background(isSelected ? Color.themePink : (isToday ? Color.themeYellow.opacity(0.2) : Color.white))
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(isSelected ? Color.clear : Color.gray.opacity(0.1), lineWidth: 1)
                                    )
                                    .shadow(color: isSelected ? .themePink.opacity(0.4) : .black.opacity(0.02), radius: 8, y: 4)
                                }
                                .buttonStyle(PlainButtonStyle()) // Избегаем конфликта масштабов
                                .scaleEffect(scale)
                                .opacity(opacity)
                                .id(date)
                            }
                            .frame(width: 56, height: 72)
                        }
                    }
                    // Добавляем отступы по краям, чтобы первый/последний день мог встать по центру
                    .padding(.horizontal, centerPoint - 28)
                    .padding(.vertical, 10)
                }
                .onAppear {
                    DispatchQueue.main.async { proxy.scrollTo(Calendar.current.startOfDay(for: selectedDate), anchor: .center) }
                }
                .onChange(of: selectedDate) { _, newValue in
                    withAnimation { proxy.scrollTo(Calendar.current.startOfDay(for: newValue), anchor: .center) }
                }
            }
        }
        .frame(height: 95) // Явно задаем высоту, так как GeometryReader схлопывается
    }
    
    private func dayOfWeekString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).prefix(3).capitalized
    }
}

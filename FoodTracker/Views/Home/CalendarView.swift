import SwiftUI

// MARK: - 3. КАЛЕНДАРЬ ТЕКУЩЕГО МЕСЯЦА
struct CalendarCarouselView: View {
    @State private var selectedDay: Int?
    
    private var currentMonthDays: [Date] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: Date()) else { return [] }
        
        var days: [Date] = []
        var currentDate = monthInterval.start
        
        while currentDate < monthInterval.end {
            days.append(currentDate)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDay
        }
        return days
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(currentMonthDays, id: \.self) { date in
                        let dayComponent = Calendar.current.component(.day, from: date)
                        let isSelected = (dayComponent == selectedDay)
                        let isToday = Calendar.current.isDateInToday(date)
                        
                        VStack(spacing: 4) {
                            Text(dayOfWeekString(date))
                                .font(.caption2)
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .gray)
                            
                            Text("\(dayComponent)")
                                .font(.headline)
                        }
                        .frame(minWidth: 50)
                        .padding(10)
                        .background(isSelected ? Color.themePink : (isToday ? Color.themeYellow.opacity(0.3) : Color.white))
                        .foregroundColor(isSelected ? .white : .primary)
                        .cornerRadius(12)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedDay = dayComponent
                                proxy.scrollTo(dayComponent, anchor: .center)
                            }
                        }
                        .id(dayComponent)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 16)
            }
            .onAppear {
                let todayDay = Calendar.current.component(.day, from: Date())
                selectedDay = todayDay
                
                DispatchQueue.main.async {
                    proxy.scrollTo(todayDay, anchor: .center)
                }
            }
        }
    }
    
    private func dayOfWeekString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).prefix(1).uppercased()
    }
}

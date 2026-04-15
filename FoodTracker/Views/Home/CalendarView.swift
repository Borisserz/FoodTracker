//
//  CalendarView.swift
//  FoodTracker
//

import SwiftUI

// MARK: - 📅 Интерактивный Календарь с эффектом фокуса
struct CalendarCarouselView: View {
    @Binding var selectedDate: Date
    @State private var showingFullCalendar = false
    
    // Генерируем дни (например, 30 дней в прошлое и 7 в будущее от СЕГОДНЯ)
    private var days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (-30...7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }
    
    var body: some View {
        GeometryReader { scrollGeo in
            let centerPoint = scrollGeo.size.width / 2
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        
                        // 1. Дни карусели
                        ForEach(days, id: \.self) { date in
                            let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                            let isToday = Calendar.current.isDateInToday(date)
                            
                            GeometryReader { itemGeo in
                                // Вычисляем расстояние от центра экрана для 3D эффекта
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
                                .buttonStyle(PlainButtonStyle())
                                .scaleEffect(scale)
                                .opacity(opacity)
                                .id(date)
                            }
                            .frame(width: 56, height: 72)
                        }
                        
                        // 2. КНОПКА "ВЕСЬ КАЛЕНДАРЬ" (В конце списка)
                        Button(action: {
                            HapticManager.shared.impact(style: .medium)
                            showingFullCalendar = true
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.themePink)
                                
                                Text("All")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 56, height: 72)
                            .background(Color.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.themePink.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: Color.themePink.opacity(0.1), radius: 8, y: 4)
                        }
                        .buttonStyle(BounceButtonStyle())
                        .padding(.leading, 4) // Небольшой отступ от дней
                    }
                    .padding(.horizontal, centerPoint - 28) // Чтобы первый день был по центру
                    .padding(.vertical, 10)
                }
                // При загрузке центрируем на выбранной дате (или сегодня)
                .onAppear {
                    DispatchQueue.main.async {
                        // Если дата находится в пределах карусели, скроллим к ней
                        if days.contains(where: { Calendar.current.isDate($0, inSameDayAs: selectedDate) }) {
                            proxy.scrollTo(Calendar.current.startOfDay(for: selectedDate), anchor: .center)
                        } else {
                            // Иначе скроллим к кнопке "All"
                            proxy.scrollTo(days.last, anchor: .center)
                        }
                    }
                }
                .onChange(of: selectedDate) { _, newValue in
                    let startOfNewValue = Calendar.current.startOfDay(for: newValue)
                    if days.contains(startOfNewValue) {
                        withAnimation { proxy.scrollTo(startOfNewValue, anchor: .center) }
                    }
                }
            }
        }
        .frame(height: 95)
        .sheet(isPresented: $showingFullCalendar) {
            FullCalendarSheet(selectedDate: $selectedDate)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(32)
                .presentationDragIndicator(.visible)
        }
    }
    
    private func dayOfWeekString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).prefix(3).capitalized
    }
}

// MARK: - 📅 Полноэкранная Шторка Календаря
struct FullCalendarSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date
    
    // Локальный стейт, чтобы шторка закрывалась только после выбора
    @State private var internalDate: Date
    
    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        self._internalDate = State(initialValue: selectedDate.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ШАПКА
            HStack {
                Text("Select Date")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color.gray.opacity(0.3))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            // НАТИВНЫЙ КАЛЕНДАРЬ APPLE
            DatePicker(
                "Select Date",
                selection: $internalDate,
                in: ...Date(), // Разрешаем выбирать только даты до сегодня (включительно)
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .tint(.themePink)
            .padding(.horizontal, 16)
            .background(Color.white)
            .cornerRadius(24)
            .padding(.horizontal, 16)
            // Логика: при изменении даты закрываем шторку и передаем дату на главный экран
            .onChange(of: internalDate) { _, newValue in
                HapticManager.shared.impact(style: .medium)
                selectedDate = newValue
                
                // Небольшая задержка, чтобы пользователь увидел, что дата выбралась
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                }
            }
            
            Spacer()
            
            // КНОПКА "СЕГОДНЯ"
            Button(action: {
                HapticManager.shared.impact(style: .rigid)
                internalDate = Date() // Триггерит onChange и закрывает шторку
            }) {
                HStack {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                    Text("Jump to Today")
                }
                .font(.headline)
                .foregroundColor(.themePink)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.themePink.opacity(0.1))
                .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .background(Color.themeBg.ignoresSafeArea())
    }
}

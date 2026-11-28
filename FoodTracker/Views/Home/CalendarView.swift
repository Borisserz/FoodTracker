import SwiftUI
import SwiftData

struct CalendarCarouselView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Binding var selectedDate: Date
    @State private var showingFullCalendar = false
    @State private var currentDayStart = Calendar.current.startOfDay(for: Date())
    @Query(sort: \DailySummary.date, order: .reverse) private var summaries: [DailySummary]

    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
    }

    private var days: [Date] {
        let calendar = Calendar.current
        return (-30...0).compactMap { calendar.date(byAdding: .day, value: $0, to: currentDayStart) }
    }

    enum DayStatus {
        case empty
        case logged
        case completed
    }

    private func buildStatusMap() -> [Date: DayStatus] {
        let calendar = Calendar.current
        var map: [Date: DayStatus] = [:]
        map.reserveCapacity(summaries.count)
        for summary in summaries {
            let day = calendar.startOfDay(for: summary.date)
            let status: DayStatus
            if summary.totalCalories > 0 {
                status = .completed
            } else if !(summary.beverages ?? []).isEmpty || !(summary.activities ?? []).isEmpty || summary.weight != nil {
                status = .logged
            } else {
                status = .empty
            }
            if status == .completed || map[day] == nil {
                map[day] = status
            }
        }
        return map
    }

    var body: some View {
        let statusMap = buildStatusMap()

        GeometryReader { scrollGeo in
            let centerPoint = scrollGeo.size.width / 2

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {

                        ForEach(days, id: \.self) { date in
                            let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                            let isToday = Calendar.current.isDateInToday(date)
                            let status = statusMap[date] ?? .empty

                            Button {
                                HapticManager.shared.impact(style: .light)
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    selectedDate = date
                                    proxy.scrollTo(date, anchor: .center)
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Text(dayOfWeekString(date))
                                        .font(.caption2)
                                        .fontWeight(isSelected ? .bold : .medium)
                                        .foregroundColor(isSelected ? .white.opacity(0.9) : .gray)

                                    Text("\(Calendar.current.component(.day, from: date))")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))

                                    if status == .completed {
                                        Circle()
                                            .fill(isSelected ? Color.white : Color.green)
                                            .frame(width: 5, height: 5)
                                    } else if status == .logged {
                                        Circle()
                                            .fill(isSelected ? Color.white.opacity(0.6) : Color.orange.opacity(0.8))
                                            .frame(width: 5, height: 5)
                                    } else {
                                        Circle()
                                            .fill(Color.clear)
                                            .frame(width: 5, height: 5)
                                    }
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
                            .scaleEffect(isSelected ? 1.05 : 0.95)
                            .opacity(isSelected ? 1.0 : 0.85)
                            .id(date)
                        }

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
                        .padding(.leading, 4)
                    }
                    .padding(.horizontal, max(0, centerPoint - 28))
                    .padding(.vertical, 10)
                }

                .onAppear {
                    DispatchQueue.main.async {

                        if days.contains(where: { Calendar.current.isDate($0, inSameDayAs: selectedDate) }) {
                            proxy.scrollTo(Calendar.current.startOfDay(for: selectedDate), anchor: .center)
                        } else {

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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                let freshStart = Calendar.current.startOfDay(for: Date())
                if freshStart != currentDayStart {
                    selectedDate = MidnightRolloverHelper.resolvedSelection(
                        selectedDate: selectedDate,
                        previousDayStart: currentDayStart,
                        newDayStart: freshStart
                    )
                    currentDayStart = freshStart
                }
            }
        }
        .task(id: currentDayStart) {
            let delay = MidnightRolloverHelper.secondsUntilNextMidnight()
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            let freshStart = Calendar.current.startOfDay(for: Date())
            if freshStart != currentDayStart {
                selectedDate = MidnightRolloverHelper.resolvedSelection(
                    selectedDate: selectedDate,
                    previousDayStart: currentDayStart,
                    newDayStart: freshStart
                )
                currentDayStart = freshStart
            }
        }
    }

    private static let dayOfWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private func dayOfWeekString(_ date: Date) -> String {
        Self.dayOfWeekFormatter.string(from: date).prefix(3).capitalized
    }
}

struct FullCalendarSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date

    @State private var internalDate: Date

    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        self._internalDate = State(initialValue: selectedDate.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {

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

            DatePicker(
                "Select Date",
                selection: $internalDate,
                in: ...Date(),
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .tint(.themePink)
            .padding(.horizontal, 16)
            .background(Color.white)
            .cornerRadius(24)
            .padding(.horizontal, 16)

            .onChange(of: internalDate) { _, newValue in
                HapticManager.shared.impact(style: .medium)
                selectedDate = newValue

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                }
            }

            Spacer()

            Button(action: {
                HapticManager.shared.impact(style: .rigid)
                internalDate = Date()
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

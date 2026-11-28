import WidgetKit
import SwiftUI
import ActivityKit

struct FastingActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FastingAttributes.self) { context in
            // Lock Screen & Notification View
            LockScreenFastingView(context: context)
                .widgetURL(URL(string: "foodtracker://fasting"))
        } dynamicIsland: { context in
            // Dynamic Island View
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.planName, systemImage: "flame.fill")
                        .font(.headline)
                        .foregroundColor(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    FastingCountdownText(
                        targetEndDate: context.attributes.targetEndDate,
                        isCompleted: context.state.isCompleted,
                        isStale: context.isStale
                    )
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 50)
                        .lineLimit(1)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading) {
                        Text(LocalizedStringKey(context.state.currentStage))
                            .font(.caption.bold())
                        if !context.state.isCompleted && !context.isStale,
                           let startDate = context.attributes.startDate,
                           startDate < context.attributes.targetEndDate,
                           Date() < context.attributes.targetEndDate {
                            ProgressView(
                                timerInterval: startDate...context.attributes.targetEndDate,
                                countsDown: false
                            ) {
                                EmptyView()
                            } currentValueLabel: {
                                EmptyView()
                            }
                            .tint(.orange)
                        } else {
                            ProgressView(value: context.state.progressPct)
                                .tint(.orange)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
            } compactTrailing: {
                FastingCountdownText(
                    targetEndDate: context.attributes.targetEndDate,
                    isCompleted: context.state.isCompleted,
                    isStale: context.isStale
                )
                    .monospacedDigit()
                    .frame(minWidth: 52, maxWidth: 72, alignment: .trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .font(.caption2)
            } minimal: {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
            }
            .widgetURL(URL(string: "foodtracker://fasting"))
        }
    }
}

struct LockScreenFastingView: View {
    let context: ActivityViewContext<FastingAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Fasting Tracker", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundColor(.orange)
                Spacer()
                Text(context.attributes.planName)
                    .font(.subheadline.bold())
                    .foregroundColor(.gray)
            }
            
            HStack(alignment: .center, spacing: 20) {
                // Circular Progress
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    
                    Circle()
                        .trim(from: 0, to: context.state.progressPct)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: "timer")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
                .frame(width: 60, height: 60)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Stage")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(LocalizedStringKey(context.state.currentStage))
                        .font(.body.bold())
                        .foregroundColor(.white)
                    
                    let isOvertime = !context.state.isCompleted && FastingActivityTiming.overtimeInterval(targetEndDate: context.attributes.targetEndDate) != nil
                    HStack {
                        Text(context.state.isCompleted ? "Status:" : (isOvertime ? "Overtime:" : "Ends in:"))
                            .font(.caption)
                            .foregroundColor(.gray)
                        FastingCountdownText(
                            targetEndDate: context.attributes.targetEndDate,
                            isCompleted: context.state.isCompleted,
                            isStale: context.isStale
                        )
                            .font(.caption.bold())
                            .monospacedDigit()
                            .foregroundColor((context.state.isCompleted || isOvertime) ? .green : .orange)
                    }
                    .padding(.top, 2)
                    if !context.state.isCompleted && !context.isStale,
                       let startDate = context.attributes.startDate,
                       startDate < context.attributes.targetEndDate,
                       Date() < context.attributes.targetEndDate {
                        ProgressView(
                            timerInterval: startDate...context.attributes.targetEndDate,
                            countsDown: false
                        ) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .tint(.orange)
                        .padding(.top, 4)
                    }
                }
                Spacer()
            }
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.85))
        .activitySystemActionForegroundColor(.white)
    }
}

private struct FastingCountdownText: View {
    let targetEndDate: Date
    let isCompleted: Bool
    let isStale: Bool

    var body: some View {
        if !isCompleted && !isStale,
           let interval = FastingActivityTiming.remainingInterval(targetEndDate: targetEndDate) {
            Text(timerInterval: interval, countsDown: true)
        } else if !isCompleted && FastingActivityTiming.overtimeInterval(targetEndDate: targetEndDate) != nil {
            HStack(spacing: 0) {
                Text(verbatim: "+")
                Text(targetEndDate, style: .timer)
            }
            .minimumScaleFactor(0.75)
        } else {
            Text("Done")
        }
    }
}

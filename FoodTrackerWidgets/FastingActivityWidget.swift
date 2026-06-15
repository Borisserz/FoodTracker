import WidgetKit
import SwiftUI
import ActivityKit

// Import the module where FastingAttributes is located.
// Assuming it's in the same target or shared.

@main
struct FoodTrackerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        FastingActivityWidget()
    }
}

struct FastingActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FastingAttributes.self) { context in
            // Lock Screen & Notification View
            LockScreenFastingView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island View
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.planName, systemImage: "flame.fill")
                        .font(.headline)
                        .foregroundColor(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.attributes.targetEndDate, countsDown: true)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 50)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading) {
                        Text(context.state.currentStage)
                            .font(.caption.bold())
                        ProgressView(value: context.state.progressPct)
                            .tint(.orange)
                    }
                }
            } compactLeading: {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
            } compactTrailing: {
                Text(timerInterval: Date()...context.attributes.targetEndDate, countsDown: true)
                    .monospacedDigit()
                    .frame(width: 45)
                    .font(.caption2)
            } minimal: {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
            }
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
                        .animation(.linear, value: context.state.progressPct)
                    
                    Image(systemName: "timer")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
                .frame(width: 60, height: 60)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Stage")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(context.state.currentStage)
                        .font(.body.bold())
                    
                    HStack {
                        Text("Ends in:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(timerInterval: Date()...context.attributes.targetEndDate, countsDown: true)
                            .font(.caption.bold())
                            .monospacedDigit()
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 2)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }
}

import ActivityKit
import WidgetKit
import SwiftUI

struct MeetingNotesLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeetingActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.title)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "waveform")
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StatusText(phase: context.state.phase, startDate: context.state.startDate)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if case .recording(let isPaused) = context.state.phase, !isPaused {
                        Button(intent: StopRecordingIntent()) {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .tint(.red)
                    }
                }
            } compactLeading: {
                Image(systemName: "waveform")
                    .font(.caption2)
            } compactTrailing: {
                StatusText(phase: context.state.phase, startDate: context.state.startDate)
                    .font(.caption2)
                    .monospacedDigit()
                    .frame(maxWidth: 50)
            } minimal: {
                Image(systemName: "waveform")
                    .font(.caption2)
            }
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<MeetingActivityAttributes>

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.title)
                    .font(.headline)
                    .lineLimit(1)
                StatusText(phase: context.state.phase, startDate: context.state.startDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if case .recording(let isPaused) = context.state.phase, !isPaused {
                Button(intent: StopRecordingIntent()) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .padding(12)
                        .background(Color.red, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

private struct StatusText: View {
    let phase: MeetingActivityAttributes.ContentState.Phase
    let startDate: Date

    var body: some View {
        switch phase {
        case .recording(let isPaused):
            if isPaused {
                Text("Paused")
            } else {
                Text(startDate, style: .timer)
                    .monospacedDigit()
            }
        case .transcribing(let progress):
            Text("Transcribing \(Int(progress * 100))%")
        case .finished:
            Text("Done")
        }
    }
}

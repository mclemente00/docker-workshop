import SwiftUI

struct RecordButton: View {
    var isRecording: Bool
    var isPaused: Bool
    var onToggleRecording: () -> Void
    var onTogglePause: () -> Void

    var body: some View {
        HStack(spacing: 32) {
            if isRecording {
                Button(action: onTogglePause) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.title2)
                        .frame(width: 56, height: 56)
                        .background(.thinMaterial, in: Circle())
                }
                .accessibilityLabel(isPaused ? "Resume Recording" : "Pause Recording")
            }

            Button(action: onToggleRecording) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 72, height: 72)
                    .overlay {
                        RoundedRectangle(cornerRadius: isRecording ? 6 : 36)
                            .fill(.white)
                            .frame(
                                width: isRecording ? 28 : 64,
                                height: isRecording ? 28 : 64
                            )
                            .opacity(isRecording ? 1 : 0)
                    }
            }
            .accessibilityLabel(isRecording ? "Stop Recording" : "Start Recording")
        }
        .animation(.easeInOut(duration: 0.2), value: isRecording)
    }
}

#Preview {
    RecordButton(isRecording: false, isPaused: false, onToggleRecording: {}, onTogglePause: {})
}

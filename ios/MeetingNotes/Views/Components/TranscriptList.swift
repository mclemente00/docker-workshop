import SwiftUI

struct TranscriptList: View {
    var segments: [TranscriptSegment]
    var currentTime: TimeInterval
    var onSelect: (TranscriptSegment) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(segments) { segment in
                        let isActive = currentTime >= segment.startTime && currentTime < segment.endTime
                        Text(segment.text)
                            .font(.body)
                            .foregroundStyle(isActive ? Color.primary : Color.secondary)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                isActive ? Color.accentColor.opacity(0.15) : .clear,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .id(segment.persistentModelID)
                            .onTapGesture { onSelect(segment) }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .onChange(of: currentTime) { _, newValue in
                if let active = segments.first(where: { newValue >= $0.startTime && newValue < $0.endTime }) {
                    withAnimation {
                        proxy.scrollTo(active.persistentModelID, anchor: .center)
                    }
                }
            }
        }
    }
}

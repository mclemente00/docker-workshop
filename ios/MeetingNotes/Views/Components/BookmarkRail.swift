import SwiftUI

struct BookmarkRail: View {
    var bookmarks: [Bookmark]
    var currentTime: TimeInterval
    var onSelect: (Bookmark) -> Void

    private var sortedBookmarks: [Bookmark] {
        bookmarks.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(sortedBookmarks) { bookmark in
                    let isActive = abs(currentTime - bookmark.timestamp) < 1
                    Button {
                        onSelect(bookmark)
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "bookmark.fill")
                                .font(.caption)
                            Text(timeString(bookmark.timestamp))
                                .font(.caption2)
                                .monospacedDigit()
                        }
                        .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(width: 48)
    }

    private func timeString(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

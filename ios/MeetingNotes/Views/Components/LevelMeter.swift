import SwiftUI

struct LevelMeter: View {
    var level: Float

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                RoundedRectangle(cornerRadius: 6)
                    .fill(.tint)
                    .frame(width: proxy.size.width * CGFloat(min(max(level, 0), 1)))
                    .animation(.linear(duration: 0.1), value: level)
            }
        }
    }
}

#Preview {
    LevelMeter(level: 0.4)
        .frame(height: 12)
        .padding()
}

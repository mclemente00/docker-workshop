import SwiftUI

/// One-time notice shown before the first recording. Recording other people carries real legal
/// exposure — several US states require all-party consent, and much of Europe is stricter —
/// so this makes sure the responsibility is surfaced once, clearly, rather than buried in a
/// terms-of-service nobody reads.
struct ConsentNoticeView: View {
    var onAcknowledge: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "person.2.wave.2")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)

                    Text("Before You Record")
                        .font(.title2.bold())

                    Text("""
                    Recording other people carries real legal responsibility. Many US states \
                    require every participant's consent before you record a conversation, and \
                    many countries — especially in Europe — are stricter still.

                    Before you record a meeting, make sure everyone present knows and agrees to \
                    it. Meeting Notes shows a recording indicator on the Lock Screen and Dynamic \
                    Island for the whole recording, but getting consent is your responsibility, \
                    not the app's.
                    """)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Recording Consent")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button("I Understand", action: onAcknowledge)
                    .buttonStyle(.borderedProminent)
                    .padding()
            }
        }
        .interactiveDismissDisabled()
    }
}

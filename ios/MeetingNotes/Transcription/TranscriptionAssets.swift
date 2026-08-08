import Foundation
import Speech
import Observation

enum TranscriptionAssetsError: Error {
    case localeUnsupported
}

/// Wraps `AssetInventory` so a locale's on-device language model is confirmed installed —
/// with visible download progress — before the first transcription attempt.
@Observable
final class TranscriptionAssets: @unchecked Sendable {
    private(set) var downloadProgress: Double = 0
    private(set) var isDownloading = false

    func status(for locale: Locale) async -> AssetInventory.Status {
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        return await AssetInventory.status(forModules: [transcriber])
    }

    /// Reserves the locale and downloads its assets if they aren't already installed.
    func ensureInstalled(locale: Locale) async throws {
        guard await SpeechTranscriber.supportedLocale(equivalentTo: locale) != nil else {
            throw TranscriptionAssetsError.localeUnsupported
        }

        try await AssetInventory.reserve(locale: locale)

        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
            return
        }

        isDownloading = true
        downloadProgress = 0

        let progress = request.progress
        let observation = progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
            DispatchQueue.main.async {
                self?.downloadProgress = progress.fractionCompleted
            }
        }
        defer {
            observation.invalidate()
            isDownloading = false
        }

        try await request.downloadAndInstall()
        downloadProgress = 1
    }
}

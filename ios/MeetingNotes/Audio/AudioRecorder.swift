import Foundation
import AVFoundation
import Observation

/// Records the microphone input to an AAC `.m4a` file via an `AVAudioEngine` tap.
/// Pause/resume detaches and reattaches the tap while holding the file handle open.
@Observable
final class AudioRecorder: @unchecked Sendable {
    enum RecorderError: Error {
        case alreadyRecording
        case fileCreationFailed
    }

    private(set) var isRecording = false
    private(set) var isPaused = false
    private(set) var elapsedTime: TimeInterval = 0
    /// Normalized 0...1 peak level of the most recent buffer, for level-meter UI.
    private(set) var currentLevel: Float = 0

    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var segmentStartTime: Date?
    private var accumulatedTime: TimeInterval = 0
    private var elapsedTimer: Timer?
    private var liveBufferContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation?

    var inputFormat: AVAudioFormat {
        engine.inputNode.outputFormat(forBus: 0)
    }

    /// Fans out live buffers alongside the file write, for the mic check or the opt-in
    /// live-transcription toggle — those consume this instead of opening a second `AVAudioEngine`,
    /// since two engines can't reliably share the mic input at once. Only one subscriber at a time.
    func liveBufferStream() -> AsyncStream<AVAudioPCMBuffer> {
        liveBufferContinuation?.finish()
        let (stream, continuation) = AsyncStream.makeStream(of: AVAudioPCMBuffer.self)
        liveBufferContinuation = continuation
        return stream
    }

    func endLiveBufferStream() {
        liveBufferContinuation?.finish()
        liveBufferContinuation = nil
    }

    func startRecording(to url: URL) throws {
        guard !isRecording else { throw RecorderError.alreadyRecording }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: inputFormat.sampleRate,
            AVNumberOfChannelsKey: inputFormat.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        guard let file = try? AVAudioFile(forWriting: url, settings: settings) else {
            throw RecorderError.fileCreationFailed
        }
        audioFile = file

        installTap(on: inputNode, format: inputFormat)

        engine.prepare()
        try engine.start()

        isRecording = true
        isPaused = false
        accumulatedTime = 0
        segmentStartTime = .now
        startElapsedTimer()
    }

    func pause() {
        guard isRecording, !isPaused else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.pause()
        captureElapsedSegment()
        isPaused = true
        currentLevel = 0
        stopElapsedTimer()
        endLiveBufferStream()
    }

    func resume() throws {
        guard isRecording, isPaused else { return }
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        installTap(on: inputNode, format: inputFormat)
        try engine.start()
        segmentStartTime = .now
        isPaused = false
        startElapsedTimer()
    }

    @discardableResult
    func stopRecording() -> URL? {
        guard isRecording else { return nil }
        if !isPaused {
            engine.inputNode.removeTap(onBus: 0)
        }
        engine.stop()
        captureElapsedSegment()
        isRecording = false
        isPaused = false
        currentLevel = 0
        stopElapsedTimer()
        endLiveBufferStream()
        let url = audioFile?.url
        audioFile = nil
        return url
    }

    private func captureElapsedSegment() {
        if let segmentStartTime {
            accumulatedTime += Date.now.timeIntervalSince(segmentStartTime)
        }
        segmentStartTime = nil
        elapsedTime = accumulatedTime
    }

    private func installTap(on node: AVAudioNode, format: AVAudioFormat) {
        node.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            try? self.audioFile?.write(from: buffer)
            self.liveBufferContinuation?.yield(buffer)
            let level = Self.normalizedPeakLevel(from: buffer)
            DispatchQueue.main.async {
                self.currentLevel = level
            }
        }
    }

    private static func normalizedPeakLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        var peak: Float = 0
        let channelCount = Int(buffer.format.channelCount)
        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameLength {
                peak = max(peak, abs(samples[frame]))
            }
        }
        return min(peak, 1)
    }

    private func startElapsedTimer() {
        stopElapsedTimer()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let segmentStartTime = self.segmentStartTime else { return }
            self.elapsedTime = self.accumulatedTime + Date.now.timeIntervalSince(segmentStartTime)
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    deinit {
        elapsedTimer?.invalidate()
    }
}

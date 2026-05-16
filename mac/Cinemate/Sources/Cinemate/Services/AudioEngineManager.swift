import AVFoundation
import Foundation

// MARK: - EQ Preset

struct EQPreset: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let gains: [Float] // 10 bands

    static let flat = EQPreset(id: "flat", name: "Flat", gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    static let bassBoost = EQPreset(id: "bass_boost", name: "Bass Boost", gains: [8, 6, 4, 2, 0, 0, 0, 0, 0, 0])
    static let trebleBoost = EQPreset(id: "treble_boost", name: "Treble Boost", gains: [0, 0, 0, 0, 0, 1, 3, 5, 7, 9])
    static let vocal = EQPreset(id: "vocal", name: "Vocal", gains: [-2, -1, 0, 3, 6, 6, 3, 0, -1, -2])
    static let rock = EQPreset(id: "rock", name: "Rock", gains: [5, 4, 2, 0, -1, -1, 0, 2, 4, 5])
    static let electronic = EQPreset(id: "electronic", name: "Electronic", gains: [6, 5, 2, 0, -2, 0, 2, 4, 5, 6])
    static let classical = EQPreset(id: "classical", name: "Classical", gains: [0, 0, 0, 0, 0, 0, -2, -3, -3, -4])
    static let hipHop = EQPreset(id: "hip_hop", name: "Hip-Hop", gains: [7, 6, 3, 0, -1, -1, 1, 0, 2, 3])
    static let jazz = EQPreset(id: "jazz", name: "Jazz", gains: [4, 3, 1, 2, -1, -1, 0, 1, 3, 4])
    static let acoustic = EQPreset(id: "acoustic", name: "Acoustic", gains: [4, 3, 1, 0, 1, 1, 2, 3, 3, 2])

    static let allPresets: [EQPreset] = [
        .flat, .bassBoost, .trebleBoost, .vocal, .rock,
        .electronic, .classical, .hipHop, .jazz, .acoustic
    ]
}

// MARK: - EQ Settings (Persistence)

struct EQSettings: Codable {
    var isEnabled: Bool
    var gains: [Float] // 10 bands, -12 to +12
    var selectedPresetId: String?

    static let `default` = EQSettings(
        isEnabled: false,
        gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        selectedPresetId: "flat"
    )
}

// MARK: - Audio Engine Manager

/// Manages AVAudioEngine-based playback with a 10-band parametric EQ.
/// Replaces AVAudioPlayer to enable real-time audio processing.
@MainActor
final class AudioEngineManager: ObservableObject {

    // Standard 10-band frequencies
    static let frequencies: [Float] = [32, 64, 128, 256, 512, 1000, 2000, 4000, 8000, 16000]
    static let frequencyLabels: [String] = ["32", "64", "128", "256", "512", "1k", "2k", "4k", "8k", "16k"]
    static let bandCount = 10
    static let minGain: Float = -12
    static let maxGain: Float = 12

    // Published state
    @Published var isEQEnabled: Bool = false {
        didSet { applyEQState(); saveSettings() }
    }
    @Published var bandGains: [Float] = Array(repeating: 0, count: 10) {
        didSet { applyGains(); saveSettings() }
    }
    @Published var selectedPreset: EQPreset? = .flat {
        didSet { saveSettings() }
    }

    // Engine components
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var eqNode: AVAudioUnitEQ?
    private var audioFile: AVAudioFile?

    // Playback state tracking
    private(set) var isPlaying: Bool = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    // Scheduling state
    private var sampleRate: Double = 44100
    private var scheduledStartFrame: AVAudioFramePosition = 0
    private var pausedHostTime: AVAudioFramePosition = 0
    private var accumulatedFrames: AVAudioFramePosition = 0

    // Completion tracking
    var onTrackFinished: (() -> Void)?

    // Persistence
    private static let settingsFileURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cinemate")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("eq_settings.json")
    }()

    init() {
        loadSettings()
        setupEngine()
    }

    // MARK: - Engine Setup

    private func setupEngine() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let eq = AVAudioUnitEQ(numberOfBands: Self.bandCount)

        // Configure EQ bands
        for i in 0..<Self.bandCount {
            let band = eq.bands[i]
            band.filterType = .parametric
            band.frequency = Self.frequencies[i]
            band.bandwidth = 1.0 // octave
            band.gain = isEQEnabled ? bandGains[i] : 0
            band.bypass = false
        }

        engine.attach(player)
        engine.attach(eq)

        // Chain: playerNode -> EQ -> mainMixerNode -> output
        let mainMixer = engine.mainMixerNode
        let format = mainMixer.outputFormat(forBus: 0)

        engine.connect(player, to: eq, format: format)
        engine.connect(eq, to: mainMixer, format: format)

        self.audioEngine = engine
        self.playerNode = player
        self.eqNode = eq
    }

    // MARK: - Playback

    func loadAndPlay(url: URL, volume: Float) throws {
        stop()

        let file = try AVAudioFile(forReading: url)
        self.audioFile = file
        self.sampleRate = file.processingFormat.sampleRate
        self.duration = Double(file.length) / sampleRate
        self.scheduledStartFrame = 0
        self.accumulatedFrames = 0

        guard let engine = audioEngine, let player = playerNode, let eq = eqNode else {
            throw NSError(domain: "AudioEngineManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Engine not initialized"])
        }

        // Reconnect with the file's format
        let format = file.processingFormat
        engine.disconnectNodeOutput(player)
        engine.disconnectNodeOutput(eq)
        engine.connect(player, to: eq, format: format)
        engine.connect(eq, to: engine.mainMixerNode, format: format)

        if !engine.isRunning {
            try engine.start()
        }

        player.volume = volume
        scheduleFile(file, at: 0)
        player.play()
        isPlaying = true
    }

    private func scheduleFile(_ file: AVAudioFile, at startFrame: AVAudioFramePosition) {
        guard let player = playerNode else { return }

        file.framePosition = startFrame
        let remainingFrames = AVAudioFrameCount(file.length - startFrame)
        guard remainingFrames > 0 else { return }

        self.scheduledStartFrame = startFrame
        self.accumulatedFrames = 0

        player.scheduleSegment(file, startingFrame: startFrame, frameCount: remainingFrames, at: nil) { [weak self] in
            Task { @MainActor in
                guard let self = self, self.isPlaying else { return }
                self.isPlaying = false
                self.onTrackFinished?()
            }
        }
    }

    func pause() {
        guard let player = playerNode, isPlaying else { return }
        // Capture current position before pausing
        if let nodeTime = player.lastRenderTime,
           let playerTime = player.playerTime(forNodeTime: nodeTime) {
            accumulatedFrames = playerTime.sampleTime
        }
        player.pause()
        isPlaying = false
    }

    func resume() {
        guard let player = playerNode, let engine = audioEngine, !isPlaying else { return }
        if !engine.isRunning {
            try? engine.start()
        }
        player.play()
        isPlaying = true
    }

    func stop() {
        playerNode?.stop()
        audioEngine?.stop()
        isPlaying = false
        currentTime = 0
        accumulatedFrames = 0
        audioFile = nil

        // Re-setup engine for next track (engine.stop() invalidates connections)
        setupEngine()
    }

    func seek(to time: TimeInterval) {
        guard let file = audioFile, let player = playerNode, let engine = audioEngine else { return }

        let wasPlaying = isPlaying
        player.stop()

        let targetFrame = AVAudioFramePosition(time * sampleRate)
        let clampedFrame = max(0, min(targetFrame, file.length - 1))

        scheduleFile(file, at: clampedFrame)

        if wasPlaying {
            if !engine.isRunning {
                try? engine.start()
            }
            player.play()
            isPlaying = true
        }
    }

    func setVolume(_ volume: Float) {
        playerNode?.volume = volume
    }

    /// Returns the current playback position in seconds
    func getCurrentTime() -> TimeInterval {
        guard let player = playerNode else { return 0 }

        if isPlaying {
            if let nodeTime = player.lastRenderTime,
               let playerTime = player.playerTime(forNodeTime: nodeTime) {
                let frames = playerTime.sampleTime
                return Double(scheduledStartFrame + frames) / sampleRate
            }
        }
        // When paused, use accumulated frames
        return Double(scheduledStartFrame + accumulatedFrames) / sampleRate
    }

    // MARK: - EQ Controls

    func setGain(band: Int, gain: Float) {
        guard band >= 0, band < Self.bandCount else { return }
        bandGains[band] = max(Self.minGain, min(Self.maxGain, gain))
        selectedPreset = matchingPreset()
    }

    func applyPreset(_ preset: EQPreset) {
        guard preset.gains.count == Self.bandCount else { return }
        bandGains = preset.gains
        selectedPreset = preset
    }

    func resetBands() {
        applyPreset(.flat)
    }

    private func applyGains() {
        guard let eq = eqNode else { return }
        for i in 0..<Self.bandCount {
            eq.bands[i].gain = isEQEnabled ? bandGains[i] : 0
        }
    }

    private func applyEQState() {
        guard let eq = eqNode else { return }
        for i in 0..<Self.bandCount {
            eq.bands[i].gain = isEQEnabled ? bandGains[i] : 0
        }
    }

    /// Check if current gains match any preset
    private func matchingPreset() -> EQPreset? {
        for preset in EQPreset.allPresets {
            if preset.gains.count == bandGains.count {
                var matches = true
                for i in 0..<bandGains.count {
                    if abs(preset.gains[i] - bandGains[i]) > 0.1 {
                        matches = false
                        break
                    }
                }
                if matches { return preset }
            }
        }
        return nil
    }

    // MARK: - Persistence

    private func saveSettings() {
        let settings = EQSettings(
            isEnabled: isEQEnabled,
            gains: bandGains,
            selectedPresetId: selectedPreset?.id
        )
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: Self.settingsFileURL, options: .atomic)
        } catch {
            print("Failed to save EQ settings: \(error)")
        }
    }

    private func loadSettings() {
        let url = Self.settingsFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let settings = try JSONDecoder().decode(EQSettings.self, from: data)
            isEQEnabled = settings.isEnabled
            if settings.gains.count == Self.bandCount {
                bandGains = settings.gains
            }
            if let presetId = settings.selectedPresetId {
                selectedPreset = EQPreset.allPresets.first { $0.id == presetId }
            }
        } catch {
            print("Failed to load EQ settings: \(error)")
        }
    }
}

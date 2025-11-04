import Foundation
import AVFoundation
import SwiftUI

@MainActor
final class SoundscapeAudioEngine {
    static let shared = SoundscapeAudioEngine()

    private let engine = AVAudioEngine()
    private let ambientNode = AVAudioPlayerNode()
    private let harmonicNode = AVAudioPlayerNode()
    private let shimmerNode = AVAudioPlayerNode()
    private let reverb = AVAudioUnitReverb()

    private var ambientBuffer: AVAudioPCMBuffer?
    private var harmonicBuffer: AVAudioPCMBuffer?
    private var shimmerBuffer: AVAudioPCMBuffer?

    private var segmentTimers: [Timer] = []
    private var smoothingTimer: Timer?
    private var fadeOutTimer: Timer?

    private var ambientTargetVolume: Float = 0
    private var harmonicTargetVolume: Float = 0
    private var shimmerTargetVolume: Float = 0

    private var isPreviewMode = false
    private var lastPlanID: UUID?
    private var needsGraphRebuild = false

    private init() {
        setupEngine()
    }

    func configurePlayback(for plan: SoundscapePlan, napDuration: TimeInterval, remainingNapTime: TimeInterval, preview: Bool) {
        guard plan.id != lastPlanID || preview != isPreviewMode else {
            return
        }

        lastPlanID = plan.id
        isPreviewMode = preview

        cancelScheduledSegments()
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil
        configureAudioSession()
        guard ensureEngineReady() else { return }
        startBaseLayersIfNeeded()

        ambientTargetVolume = preview ? 0.16 : 0.12
        harmonicTargetVolume = preview ? 0.05 : 0.0
        shimmerTargetVolume = 0.0

        scheduleVolumeSmoothing()

        if preview {
            schedulePreviewSegments(for: plan)
        } else {
            scheduleRuntimeSegments(for: plan, napDuration: napDuration, remainingNapTime: remainingNapTime)
        }
    }

    func stopPlayback() {
        lastPlanID = nil
        cancelScheduledSegments()
        stopVolumeSmoothing()
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil
        needsGraphRebuild = true

        let steps = 20
        var currentStep = 0
        fadeOutTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            currentStep += 1
            let attenuation = Float(max(0, steps - currentStep)) / Float(steps)
            ambientNode.volume = ambientNode.volume * attenuation
            harmonicNode.volume = harmonicNode.volume * attenuation
            shimmerNode.volume = shimmerNode.volume * attenuation

            if currentStep >= steps {
                timer.invalidate()
                ambientNode.stop()
                harmonicNode.stop()
                shimmerNode.stop()
                if engine.isRunning {
                    engine.stop()
                }
                engine.reset()
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
        if let fadeOutTimer {
            RunLoop.main.add(fadeOutTimer, forMode: .common)
        }
    }

    // MARK: - Engine configuration

    private func setupEngine() {
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 22

        rebuildGraphConnections()
    }

    private func rebuildGraphConnections() {
        if ambientNode.engine == nil {
            engine.attach(ambientNode)
        }
        if harmonicNode.engine == nil {
            engine.attach(harmonicNode)
        }
        if shimmerNode.engine == nil {
            engine.attach(shimmerNode)
        }
        if reverb.engine == nil {
            engine.attach(reverb)
        }

        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        let connectionFormat: AVAudioFormat
        if outputFormat.channelCount == 0 {
            connectionFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2) ?? outputFormat
        } else {
            connectionFormat = outputFormat
        }

        if ambientNode.isPlaying {
            ambientNode.stop()
        }
        if harmonicNode.isPlaying {
            harmonicNode.stop()
        }
        if shimmerNode.isPlaying {
            shimmerNode.stop()
        }

        engine.disconnectNodeOutput(ambientNode)
        engine.disconnectNodeOutput(harmonicNode)
        engine.disconnectNodeOutput(shimmerNode)
        engine.disconnectNodeOutput(reverb)

        engine.connect(ambientNode, to: reverb, format: connectionFormat)
        engine.connect(harmonicNode, to: reverb, format: connectionFormat)
        engine.connect(shimmerNode, to: reverb, format: connectionFormat)
        engine.connect(reverb, to: engine.mainMixerNode, format: connectionFormat)

        engine.prepare()
        needsGraphRebuild = false
    }

    private func ensureEngineReady() -> Bool {
        let ambientConnected = !engine.outputConnectionPoints(for: ambientNode, outputBus: 0).isEmpty
        let harmonicConnected = !engine.outputConnectionPoints(for: harmonicNode, outputBus: 0).isEmpty
        let shimmerConnected = !engine.outputConnectionPoints(for: shimmerNode, outputBus: 0).isEmpty
        let reverbConnected = engine.outputConnectionPoints(for: reverb, outputBus: 0).contains { $0.node == engine.mainMixerNode }

        if needsGraphRebuild || !ambientConnected || !harmonicConnected || !shimmerConnected || !reverbConnected {
            rebuildGraphConnections()
        }

        return startEngineIfNeeded()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true, options: [.notifyOthersOnDeactivation])
        } catch {
            print("SoundscapeAudioEngine failed to configure audio session: \(error)")
        }
    }

    @discardableResult
    private func startEngineIfNeeded() -> Bool {
        if engine.isRunning { return true }
        do {
            try engine.start()
            return true
        } catch {
            print("Failed to start AVAudioEngine: \(error)")
            engine.stop()
            engine.reset()
            needsGraphRebuild = true
            rebuildGraphConnections()
            do {
                try engine.start()
                return true
            } catch {
                print("Retry to start AVAudioEngine failed: \(error)")
                return false
            }
        }
    }

    private func startBaseLayersIfNeeded() {
        guard engine.isRunning else { return }

        if ambientBuffer == nil {
            ambientBuffer = Self.makeBrownNoiseBuffer(duration: 2.5, amplitude: 0.35)
        }

        if harmonicBuffer == nil {
            harmonicBuffer = Self.makeHarmonicBuffer(frequencies: [392, 494, 587], duration: 4.0, amplitude: 0.18)
        }

        if shimmerBuffer == nil {
            shimmerBuffer = Self.makeHarmonicBuffer(frequencies: [880, 1175], duration: 6.0, amplitude: 0.12)
        }

        if let buffer = ambientBuffer, !ambientNode.isPlaying {
            ambientNode.volume = 0
            ambientNode.scheduleBuffer(buffer, at: nil, options: [.loops])
            ambientNode.play()
        }

        if let buffer = harmonicBuffer, !harmonicNode.isPlaying {
            harmonicNode.volume = 0
            harmonicNode.scheduleBuffer(buffer, at: nil, options: [.loops])
            harmonicNode.play()
        }

        if let buffer = shimmerBuffer, !shimmerNode.isPlaying {
            shimmerNode.volume = 0
            shimmerNode.scheduleBuffer(buffer, at: nil, options: [.loops])
            shimmerNode.play()
        }
    }

    // MARK: - Segment scheduling

    private func schedulePreviewSegments(for plan: SoundscapePlan) {
        let segments = plan.segments.sorted { $0.startOffset < $1.startOffset }
        guard !segments.isEmpty else { return }

        var accumulatedDelay: TimeInterval = 0
        for segment in segments {
            let effectiveDuration = max(16, segment.duration * 0.35)
            scheduleSegment(segment, delay: accumulatedDelay, duration: effectiveDuration)
            accumulatedDelay += effectiveDuration
        }

        scheduleReset(after: accumulatedDelay + 6)
    }

    private func scheduleRuntimeSegments(for plan: SoundscapePlan, napDuration: TimeInterval, remainingNapTime: TimeInterval) {
        let segments = plan.segments.sorted { $0.startOffset < $1.startOffset }
        guard !segments.isEmpty else { return }

        let elapsed = napDuration - remainingNapTime
        var lastTrigger: TimeInterval = 0

        for segment in segments {
            let delay = max(segment.startOffset - elapsed, 0)
            let duration = max(segment.duration, 30)
            lastTrigger = max(lastTrigger, delay + duration)
            scheduleSegment(segment, delay: delay, duration: duration)
        }

        // Ensure there is a gentle ramp reset after the final segment if the nap ends without manual stop.
        scheduleReset(after: lastTrigger + 60)
    }

    private func scheduleSegment(_ segment: SoundscapeSegment, delay: TimeInterval, duration: TimeInterval) {
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.applySegment(segment, duration: duration)
        }
        RunLoop.main.add(timer, forMode: .common)
        segmentTimers.append(timer)
    }

    private func scheduleReset(after delay: TimeInterval) {
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            ambientTargetVolume = isPreviewMode ? 0.12 : 0.08
            harmonicTargetVolume = isPreviewMode ? 0.02 : 0.0
            shimmerTargetVolume = 0.0
        }
        RunLoop.main.add(timer, forMode: .common)
        segmentTimers.append(timer)
    }

    private func applySegment(_ segment: SoundscapeSegment, duration: TimeInterval) {
        let intensity = segment.intensity.lowercased()

        switch intensity {
        case "low":
            ambientTargetVolume = isPreviewMode ? 0.18 : 0.14
            harmonicTargetVolume = isPreviewMode ? 0.05 : 0.02
            shimmerTargetVolume = isPreviewMode ? 0.02 : 0.0
        case "medium":
            ambientTargetVolume = isPreviewMode ? 0.24 : 0.18
            harmonicTargetVolume = isPreviewMode ? 0.08 : 0.05
            shimmerTargetVolume = isPreviewMode ? 0.04 : 0.02
        case "high":
            ambientTargetVolume = isPreviewMode ? 0.3 : 0.24
            harmonicTargetVolume = isPreviewMode ? 0.12 : 0.08
            shimmerTargetVolume = isPreviewMode ? 0.07 : 0.04
        default:
            ambientTargetVolume = isPreviewMode ? 0.2 : 0.14
            harmonicTargetVolume = isPreviewMode ? 0.06 : 0.03
            shimmerTargetVolume = isPreviewMode ? 0.03 : 0.01
        }

        // Gradually add more shimmer near the end of the segment for gentle brightness.
        let shimmerTimer = Timer.scheduledTimer(withTimeInterval: max(duration - 8, 4), repeats: false) { [weak self] _ in
            guard let self else { return }
            shimmerTargetVolume = min(shimmerTargetVolume + 0.02, 0.12)
        }
        RunLoop.main.add(shimmerTimer, forMode: .common)
        segmentTimers.append(shimmerTimer)
    }

    private func cancelScheduledSegments() {
        segmentTimers.forEach { $0.invalidate() }
        segmentTimers.removeAll()
    }

    // MARK: - Volume smoothing

    private func scheduleVolumeSmoothing() {
        guard smoothingTimer == nil else { return }
        smoothingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.stepVolumesTowardTargets()
        }
        if let smoothingTimer {
            RunLoop.main.add(smoothingTimer, forMode: .common)
        }
    }

    private func stopVolumeSmoothing() {
        smoothingTimer?.invalidate()
        smoothingTimer = nil
    }

    private func stepVolumesTowardTargets() {
        ambientNode.volume = smooth(current: ambientNode.volume, target: ambientTargetVolume)
        harmonicNode.volume = smooth(current: harmonicNode.volume, target: harmonicTargetVolume)
        shimmerNode.volume = smooth(current: shimmerNode.volume, target: shimmerTargetVolume)
    }

    private func smooth(current: Float, target: Float) -> Float {
        let delta = target - current
        let step = delta * 0.25
        if abs(step) < 0.0005 { return target }
        return current + step
    }

    // MARK: - Buffer helpers

    private static func makeBrownNoiseBuffer(duration: TimeInterval, amplitude: Float) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2) else { return nil }
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        for channel in 0..<Int(format.channelCount) {
            let channelData = buffer.floatChannelData![channel]
            var lastValue: Float = 0
            for frame in 0..<Int(frameCount) {
                let white = Float.random(in: -1...1)
                let brown = (lastValue + (0.02 * white)) / 1.02
                channelData[frame] = max(-1, min(1, brown * amplitude))
                lastValue = channelData[frame]
            }
        }

        return buffer
    }

    private static func makeHarmonicBuffer(frequencies: [Double], duration: TimeInterval, amplitude: Float) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2) else { return nil }
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        let rampFrames = Int(min(4_410, frameCount / 6))

        for channel in 0..<Int(format.channelCount) {
            let channelData = buffer.floatChannelData![channel]
            for frame in 0..<Int(frameCount) {
                let time = Double(frame) / format.sampleRate
                var value: Double = 0
                for (index, frequency) in frequencies.enumerated() {
                    let phaseOffset = Double(index) * .pi / 6
                    value += sin((2 * .pi * frequency * time) + phaseOffset)
                }
                let normalized = Float(value / Double(frequencies.count))
                channelData[frame] = normalized * amplitude
            }

            // Apply gentle fade in/out to avoid pops.
            for frame in 0..<rampFrames {
                let scale = Float(frame) / Float(rampFrames)
                channelData[frame] *= scale
                channelData[Int(frameCount) - frame - 1] *= scale
            }
        }

        return buffer
    }
}

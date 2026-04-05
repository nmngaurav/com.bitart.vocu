import AVFoundation
import Foundation
import Observation

extension Notification.Name {
    /// Posted when streaming failed, URL was invalid/blocked, and speech fallback is used.
    static let vocuAudioDidUseSpeechFallback = Notification.Name("vocuAudioDidUseSpeechFallback")
}

/// Remote pronunciation + speech fallback. Configures `AVAudioSession` so playback is audible.
@Observable
@MainActor
final class AudioPlaybackService: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = AudioPlaybackService()

    enum Phase: Equatable {
        case idle
        case loading
        case playingStream
        case speaking
    }

    private(set) var phase: Phase = .idle

    private var player: AVPlayer?
    private var statusObservation: NSKeyValueObservation?
    private var failedEndObserver: NSObjectProtocol?
    private var didPlayToEndObserver: NSObjectProtocol?
    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Resolves API strings (https, scheme-less host paths, `//host/...`).
    func normalizedAudioURL(from string: String) -> URL? {
        let t = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if let u = URL(string: t), let scheme = u.scheme, !scheme.isEmpty {
            return u
        }
        if t.hasPrefix("//"), let u = URL(string: "https:" + t) {
            return u
        }
        if !t.contains("://"), let u = URL(string: "https://" + t) {
            return u
        }
        return URL(string: t.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? t)
    }

    /// Placeholder / docs hosts that never resolve in production — skip network, use speech.
    func shouldSkipStreaming(for url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return true }
        let blockedSuffixes = ["example.com", "example.org", "example.net"]
        for s in blockedSuffixes {
            if host == s || host.hasSuffix(".\(s)") { return true }
        }
        return false
    }

    func prepareSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("[Lexis Audio] AVAudioSession error: \(error.localizedDescription)")
            #endif
        }
    }

    /// Plays remote audio; on failure (or invalid / blocked URL), speaks `fallbackText` if provided.
    func play(urlString: String, fallbackText: String?) {
        stop(clearPhase: true)
        prepareSession()
        phase = .loading

        guard let url = normalizedAudioURL(from: urlString) else {
            useSpeechFallback(fallbackText, notify: false, reason: "invalid_or_empty_url")
            return
        }

        if shouldSkipStreaming(for: url) {
            #if DEBUG
            print("[Lexis Audio] skipping stream for placeholder host: \(url.host ?? "?")")
            #endif
            useSpeechFallback(fallbackText, notify: true, reason: "skipped_host")
            return
        }

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] observed, _ in
            guard let self else { return }
            Task { @MainActor in
                switch observed.status {
                case .failed:
                    #if DEBUG
                    print("[Lexis Audio] item failed: \(String(describing: observed.error)) url=\(url.absoluteString)")
                    #endif
                    self.handleStreamFailure(fallbackText: fallbackText)
                case .readyToPlay:
                    self.phase = .playingStream
                default:
                    break
                }
            }
        }

        failedEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleStreamFailure(fallbackText: fallbackText)
            }
        }

        didPlayToEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.phase = .idle
            }
        }

        newPlayer.play()
    }

    func stop(clearPhase: Bool = true) {
        synthesizer.stopSpeaking(at: .immediate)
        statusObservation?.invalidate()
        statusObservation = nil
        removeItemObservers()
        player?.pause()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if clearPhase { phase = .idle }
    }

    private func removeItemObservers() {
        if let o = failedEndObserver {
            NotificationCenter.default.removeObserver(o)
            failedEndObserver = nil
        }
        if let o = didPlayToEndObserver {
            NotificationCenter.default.removeObserver(o)
            didPlayToEndObserver = nil
        }
    }

    private func handleStreamFailure(fallbackText: String?) {
        guard player != nil else { return }
        statusObservation?.invalidate()
        statusObservation = nil
        removeItemObservers()
        player?.pause()
        player = nil
        useSpeechFallback(fallbackText, notify: true, reason: "stream_failed")
    }

    private func useSpeechFallback(_ text: String?, notify: Bool, reason: String) {
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else {
            phase = .idle
            return
        }
        phase = .speaking
        prepareSession()
        let utterance = AVSpeechUtterance(string: t)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
        if notify {
            NotificationCenter.default.post(
                name: .vocuAudioDidUseSpeechFallback,
                object: nil,
                userInfo: ["reason": reason]
            )
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if self.phase == .speaking {
                self.phase = .idle
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.phase = .idle
        }
    }
}

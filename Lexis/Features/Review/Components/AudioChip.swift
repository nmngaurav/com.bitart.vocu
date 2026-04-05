import SwiftUI

struct AudioChip: View {
    let audioURLString: String
    /// Spoken if URL is invalid or streaming fails.
    var fallbackWord: String? = nil

    @State private var audio = AudioPlaybackService.shared

    private var trimmedURL: String {
        audioURLString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasStreamingURL: Bool { !trimmedURL.isEmpty }

    private var hasFallback: Bool {
        !(fallbackWord?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    private var isEnabled: Bool { hasStreamingURL || hasFallback }

    var body: some View {
        Group {
            if isEnabled {
                Button {
                    Haptics.impact(.light)
                    AudioPlaybackService.shared.play(
                        urlString: hasStreamingURL ? trimmedURL : "",
                        fallbackText: fallbackWord
                    )
                } label: {
                    HStack(spacing: 6) {
                        if audio.phase == .loading {
                            ProgressView()
                                .scaleEffect(0.72)
                                .tint(.textSecondary)
                        } else {
                            Image(systemName: audio.phase == .speaking ? "waveform" : "speaker.wave.2.fill")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text(labelText)
                            .font(.lexisCaptionM)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.glassBorder)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.glassBorderActive, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel)
            }
        }
    }

    private var labelText: String {
        switch audio.phase {
        case .loading: return "Loading…"
        case .speaking: return "Speaking"
        case .playingStream: return "Playing"
        default: return "Listen"
        }
    }

    private var accessibilityLabel: String {
        switch audio.phase {
        case .loading: return "Loading pronunciation"
        case .speaking: return "Speaking word with system voice"
        case .playingStream: return "Playing pronunciation audio"
        default: return hasStreamingURL ? "Play pronunciation" : "Speak word with system voice"
        }
    }
}

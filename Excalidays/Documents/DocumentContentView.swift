import SwiftUI

struct DocumentContentView: View {
    let session: CanvasSession

    var body: some View {
        ZStack {
            CanvasView(session: session)
                .accessibilityLabel("Excalidraw drawing canvas")
                .id(session.webViewID)

            if session.runtimeState != .ready {
                statusOverlay
            }
        }
        .frame(minWidth: 680, minHeight: 480)
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch session.runtimeState {
        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.0)

                Text("Preparing canvas…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        case let .failed(message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)

                Text("Canvas Unavailable")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                Text(message)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)

                Button("Try Again") {
                    session.retryLoad()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Try Again loading the canvas")
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 24, x: 0, y: 10)
        case .destroyed, .ready:
            EmptyView()
        }
    }
}

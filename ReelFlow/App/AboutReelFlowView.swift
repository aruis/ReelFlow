import AppKit
import SwiftUI

struct AboutReelFlowView: View {
    static let windowID = "about-reelflow"

    @Environment(\.openURL) private var openURL
    private let websiteURL = URL(string: "https://ximatai.net/apps/reelflow")!
    private let repositoryURL = URL(string: "https://github.com/aruis/ReelFlow")!
    private let contactURL = URL(string: "mailto:dev@ximatai.net")!
    let hasProAccess: Bool

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Text("ReelFlow")
                            .font(.system(size: 28, weight: .bold, design: .rounded))

                        if hasProAccess {
                            Text("PRO")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.16), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                        }
                    }

                    Text(versionLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                    HStack(spacing: 10) {
                        actionButton(title: websiteButtonTitle, systemImage: "globe", url: websiteURL)
                        actionButton(title: String(localized: "GitHub"), systemImage: "chevron.left.forwardslash.chevron.right", url: repositoryURL)
                        actionButton(title: String(localized: "联系我"), systemImage: "envelope", url: contactURL)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(32)
            .background(.thinMaterial)
        }
        .frame(width: 420, height: 320)
    }

    private var versionLine: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        return String.localizedStringWithFormat(String(localized: "版本 %@"), version)
    }

    private var websiteButtonTitle: String {
        String(localized: "戏码台")
    }

    @ViewBuilder
    private func actionButton(title: String, systemImage: String, url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

#Preview {
    AboutReelFlowView(hasProAccess: true)
}

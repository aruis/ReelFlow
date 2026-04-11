import AppKit
import SwiftUI

struct FocuslessOptionCardButton: NSViewRepresentable {
    @Environment(\.isEnabled) private var environmentEnabled

    let title: String
    let subtitle: String?
    let isSelected: Bool
    let isEnabled: Bool
    let cornerRadius: CGFloat
    let minHeight: CGFloat
    let multilineSubtitle: Bool
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> OptionCardButton {
        let button = OptionCardButton()
        button.target = context.coordinator
        button.action = #selector(Coordinator.trigger)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    func updateNSView(_ nsView: OptionCardButton, context: Context) {
        context.coordinator.action = action
        let effectiveIsEnabled = isEnabled && environmentEnabled
        nsView.isEnabled = effectiveIsEnabled
        nsView.configure(
            title: title,
            subtitle: subtitle,
            isSelected: isSelected,
            isEnabled: effectiveIsEnabled,
            cornerRadius: cornerRadius,
            minHeight: minHeight,
            multilineSubtitle: multilineSubtitle
        )
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func trigger() {
            action()
        }
    }
}

final class OptionCardButton: NSButton {
    private struct Configuration {
        let title: String
        let subtitle: String?
        let isSelected: Bool
        let isEnabled: Bool
        let cornerRadius: CGFloat
        let minHeight: CGFloat
        let multilineSubtitle: Bool
    }

    private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private var trackingArea: NSTrackingArea?
    private var configuration: Configuration?
    private var isHovering = false
    private var isPressing = false
    private var isFocusVisible = false
    private var suppressFocusOnNextFirstResponder = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        title = ""
        isBordered = false
        bezelStyle = .regularSquare
        focusRingType = .none
        setButtonType(.momentaryChange)
        allowsMixedState = false
        setAccessibilityRole(.button)

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.setAccessibilityElement(false)
        addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        render()
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        render()
        super.mouseExited(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        suppressFocusOnNextFirstResponder = true
        window?.makeFirstResponder(nil)
        isPressing = true
        render()
        super.mouseDown(with: event)
        isPressing = false
        render()
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            let triggeredByKeyboard = NSApp.currentEvent?.type == .keyDown
            isFocusVisible = !suppressFocusOnNextFirstResponder && triggeredByKeyboard
            suppressFocusOnNextFirstResponder = false
            render()
        }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            isFocusVisible = false
            render()
        }
        return resigned
    }

    func configure(
        title: String,
        subtitle: String?,
        isSelected: Bool,
        isEnabled: Bool,
        cornerRadius: CGFloat,
        minHeight: CGFloat,
        multilineSubtitle: Bool
    ) {
        configuration = Configuration(
            title: title,
            subtitle: subtitle,
            isSelected: isSelected,
            isEnabled: isEnabled,
            cornerRadius: cornerRadius,
            minHeight: minHeight,
            multilineSubtitle: multilineSubtitle
        )
        render()
    }

    private func render() {
        guard let configuration else { return }

        let isEnabled = configuration.isEnabled
        let isFocused = isEnabled && isFocusVisible
        let isHovered = isEnabled && isHovering
        let isPressed = isEnabled && isPressing

        let backgroundFill: Color
        if configuration.isSelected {
            if isPressed {
                backgroundFill = Color.accentColor.opacity(0.24)
            } else if isHovered {
                backgroundFill = Color.accentColor.opacity(0.20)
            } else {
                backgroundFill = Color.accentColor.opacity(0.16)
            }
        } else {
            if !isEnabled {
                backgroundFill = Color.secondary.opacity(0.05)
            } else if isPressed {
                backgroundFill = Color.secondary.opacity(0.13)
            } else if isHovered {
                backgroundFill = Color.secondary.opacity(0.11)
            } else {
                backgroundFill = Color.secondary.opacity(0.08)
            }
        }

        let borderColor: Color
        let borderWidth: CGFloat
        if isFocused {
            borderColor = Color.white.opacity(0.32)
            borderWidth = 1.2
        } else if configuration.isSelected {
            borderColor = Color.accentColor
            borderWidth = 1.4
        } else {
            borderColor = Color.secondary.opacity(isEnabled ? 0.22 : 0.12)
            borderWidth = 1
        }

        let titleColor: Color = isEnabled ? .primary : .secondary.opacity(0.65)
        let subtitleColor: Color = isEnabled ? .secondary : .secondary.opacity(0.55)

        hostingView.rootView = AnyView(
            VStack(spacing: 4) {
                Text(configuration.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)

                if let subtitle = configuration.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(subtitleColor)
                        .lineLimit(configuration.multilineSubtitle ? 2 : 1)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, minHeight: configuration.minHeight)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .opacity(isEnabled ? 1 : 0.72)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .animation(.easeOut(duration: 0.08), value: isPressed)
            .animation(.easeOut(duration: 0.10), value: isFocused)
        )
    }
}

import SwiftUI

struct SimpleSettingsPanel: View {
    @ObservedObject var viewModel: ExportViewModel
    @Binding var isAudioDropTarget: Bool
    let onAudioDrop: ([NSItemProvider]) -> Bool
    @State private var plateSimplePrefixDrafts: [PlateSimpleElementKey: String] = [:]

    private let optionCardCornerRadius: CGFloat = 10
    private let optionCardMinHeight: CGFloat = 48
    private let plateRowHeight: CGFloat = 42

    private enum ResolutionChoice: Int, CaseIterable, Identifiable {
        case hd720
        case fullHD1080
        case qhd1440
        case uhd4K

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .hd720: return "720p"
            case .fullHD1080: return "1080p"
            case .qhd1440: return "1440p"
            case .uhd4K: return "4K"
            }
        }

        var size: (width: Int, height: Int) {
            switch self {
            case .hd720: return (1280, 720)
            case .fullHD1080: return (1920, 1080)
            case .qhd1440: return (2560, 1440)
            case .uhd4K: return (3840, 2160)
            }
        }
    }

    private enum DurationChoice: String, CaseIterable, Identifiable {
        case quick
        case standard
        case relaxed

        var id: String { rawValue }

        var title: String {
            switch self {
            case .quick: return String(localized: "快节奏")
            case .standard: return String(localized: "标准")
            case .relaxed: return String(localized: "舒缓")
            }
        }

        var subtitle: String? {
            switch self {
            case .quick: return String(localized: "约 1.5 秒/张")
            case .standard: return String(localized: "约 2.5 秒/张")
            case .relaxed: return String(localized: "约 4 秒/张")
            }
        }

        var seconds: Double {
            switch self {
            case .quick: return 1.5
            case .standard: return 2.5
            case .relaxed: return 4.0
            }
        }
    }

    private enum TransitionChoice: String, CaseIterable, Identifiable {
        case off
        case soft
        case standard

        var id: String { rawValue }

        var title: String {
            switch self {
            case .off: return String(localized: "关闭")
            case .soft: return String(localized: "柔和")
            case .standard: return String(localized: "标准")
            }
        }

        var subtitle: String? {
            switch self {
            case .off: return String(localized: "不使用转场")
            case .soft: return String(localized: "0.4 秒")
            case .standard: return String(localized: "0.8 秒")
            }
        }

        var transitionDuration: Double {
            switch self {
            case .off: return 0
            case .soft: return 0.4
            case .standard: return 0.8
            }
        }
    }

    private enum TransitionGapChoice: String, CaseIterable, Identifiable {
        case none
        case short
        case medium

        var id: String { rawValue }

        var title: String {
            switch self {
            case .none: return String(localized: "无")
            case .short: return String(localized: "短")
            case .medium: return String(localized: "中")
            }
        }

        var subtitle: String? {
            switch self {
            case .none: return String(localized: "无空窗")
            case .short: return String(localized: "0.18 秒")
            case .medium: return String(localized: "0.36 秒")
            }
        }

        var duration: Double {
            switch self {
            case .none: return 0
            case .short: return 0.18
            case .medium: return 0.36
            }
        }
    }

    private enum KenBurnsChoice: String, CaseIterable, Identifiable {
        case off
        case subtle
        case standard

        var id: String { rawValue }

        var title: String {
            switch self {
            case .off: return String(localized: "关闭")
            case .subtle: return String(localized: "轻微")
            case .standard: return String(localized: "标准")
            }
        }

        var subtitle: String? {
            switch self {
            case .off: return String(localized: "无动效")
            case .subtle: return String(localized: "更克制")
            case .standard: return String(localized: "标准幅度")
            }
        }
    }

    private enum PlateFontSizeChoice: Int, CaseIterable, Identifiable {
        case small = 22
        case medium = 26
        case large = 32

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .small: return String(localized: "小")
            case .medium: return String(localized: "中")
            case .large: return String(localized: "大")
            }
        }
    }

    private enum FrameWidthChoice: Int, CaseIterable, Identifiable {
        case none = 0
        case thin = 16
        case medium = 24
        case wide = 36

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .none: return String(localized: "无")
            case .thin: return String(localized: "细")
            case .medium: return String(localized: "中")
            case .wide: return String(localized: "宽")
            }
        }
    }

    private enum PlatePlacementChoice: String, CaseIterable, Identifiable {
        case none
        case frame
        case canvasBottom

        var id: String { rawValue }

        var title: String {
            switch self {
            case .none:
                return String(localized: "无")
            case .frame:
                return String(localized: "相框内")
            case .canvasBottom:
                return String(localized: "相框外")
            }
        }
    }

    var body: some View {
        Form {
            Section(String(localized: "输出")) {
                if let settingsValidationMessage {
                    settingsValidationView(settingsValidationMessage)
                }

                settingsGroup(title: String(localized: "分辨率")) {
                    choiceGrid(
                        ResolutionChoice.allCases,
                        selection: resolutionBinding,
                        title: \ResolutionChoice.title,
                        subtitle: { choice in
                            "\(choice.size.width) × \(choice.size.height)"
                        }
                    )
                }
                .disabled(viewModel.isBusy)

                settingsGroup(title: String(localized: "帧率（FPS）")) {
                    choiceGrid(
                        [24, 30, 60],
                        selection: fpsBinding,
                        title: { "\($0)" },
                        subtitle: { _ in nil }
                    )
                }
                .disabled(viewModel.isBusy)
            }

            Section(String(localized: "播放节奏")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "展示节奏"))
                        .font(.subheadline.weight(.medium))
                    choiceGrid(
                        DurationChoice.allCases,
                        selection: imageDurationBinding,
                        title: \DurationChoice.title,
                        subtitle: \DurationChoice.subtitle
                    )
                }
                .disabled(viewModel.isBusy)

                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "动效"))
                        .font(.subheadline.weight(.medium))
                    Text(String(localized: "控制画面切换、空窗节奏与推拉动效。"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 8) {
                        settingsSubgroup(title: String(localized: "转场")) {
                            choiceGrid(
                                TransitionChoice.allCases,
                                selection: transitionBinding,
                                title: \TransitionChoice.title,
                                subtitle: \TransitionChoice.subtitle
                            )
                        }

                        settingsSubgroup(title: String(localized: "背景空窗")) {
                            choiceGrid(
                                TransitionGapChoice.allCases,
                                selection: transitionGapBinding,
                                title: \TransitionGapChoice.title,
                                subtitle: \TransitionGapChoice.subtitle
                            )
                        }

                        settingsSubgroup(title: String(localized: "推拉动效（Ken Burns）")) {
                            choiceGrid(
                                KenBurnsChoice.allCases,
                                selection: kenBurnsBinding,
                                title: \KenBurnsChoice.title,
                                subtitle: \KenBurnsChoice.subtitle
                            )
                        }
                    }
                    .padding(12)
                    .background(optionContainerBackground)
                    .overlay(optionContainerBorder)
                }
                .disabled(viewModel.isBusy)
            }

            Section(String(localized: "画面风格")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "横竖图策略"))
                        .font(.subheadline.weight(.medium))
                    choiceGrid(
                        orientationChoices,
                        selection: orientationBinding,
                        title: \PhotoOrientationStrategy.displayName,
                        subtitle: { _ in nil }
                    )
                }
                .disabled(viewModel.isBusy)

                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "相框风格"))
                        .font(.subheadline.weight(.medium))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                        ForEach(FrameStylePreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                            optionCardButton(
                                title: preset.displayName,
                                subtitle: nil,
                                isSelected: viewModel.config.frameStylePreset == preset
                            ) {
                                viewModel.config.frameStylePreset = preset
                            }
                        }
                    }
                }
                .disabled(viewModel.isBusy)

                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "相框宽度"))
                        .font(.subheadline.weight(.medium))
                    choiceGrid(
                        FrameWidthChoice.allCases,
                        selection: frameWidthChoiceBinding,
                        title: \FrameWidthChoice.title,
                        subtitle: { _ in nil }
                    )
                }
                .disabled(viewModel.isBusy)
            }

            Section(String(localized: "铭牌信息")) {
                settingsGroup(title: String(localized: "位置")) {
                    choiceGrid(
                        PlatePlacementChoice.allCases,
                        selection: platePlacementChoiceBinding,
                        title: \PlatePlacementChoice.title,
                        subtitle: { _ in nil }
                    )
                }
                .disabled(viewModel.isBusy)

                if viewModel.config.plateEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "字段与标签"))
                            .font(.subheadline.weight(.medium))
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.config.plateSimpleElements.indices, id: \.self) { index in
                                simplePlateFieldRow(index: index)
                            }
                        }
                    }
                    .disabled(viewModel.isBusy)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "文字样式"))
                            .font(.subheadline.weight(.medium))
                        settingsSubgroup(title: String(localized: "字体风格")) {
                            choiceGrid(
                                PlateFontStyle.allCases,
                                selection: plateFontStyleBinding,
                                title: \PlateFontStyle.displayName,
                                subtitle: { _ in nil }
                            )
                        }

                        settingsSubgroup(title: String(localized: "字号")) {
                            choiceGrid(
                                PlateFontSizeChoice.allCases,
                                selection: plateFontSizeChoiceBinding,
                                title: \PlateFontSizeChoice.title,
                                subtitle: { _ in nil }
                            )
                        }
                    }
                    .disabled(viewModel.isBusy)
                }
            }

            AudioSettingsSection(
                viewModel: viewModel,
                isAudioDropTarget: $isAudioDropTarget,
                onAudioDrop: onAudioDrop,
                showsBackgroundAudio: false
            )
        }
        .formStyle(.grouped)
    }

    private var settingsValidationMessage: String? {
        viewModel.validationMessage
    }

    private func settingsValidationView(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.red)
    }

    private func choiceGrid<T: Hashable & Identifiable & CaseIterable>(
        _ choices: T.AllCases,
        selection: Binding<T>,
        title: KeyPath<T, String>,
        subtitle: KeyPath<T, String?>
    ) -> some View where T.AllCases: RandomAccessCollection, T.AllCases.Element == T {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
            ForEach(Array(choices)) { choice in
                let isSelected = selection.wrappedValue == choice
                Button {
                    selection.wrappedValue = choice
                } label: {
                    VStack(spacing: 4) {
                        Text(choice[keyPath: title])
                            .font(.caption.weight(.semibold))
                        if let subtitle = choice[keyPath: subtitle] {
                            Text(subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: isSelected ? 1.4 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func choiceGrid<T: Hashable, S: Sequence>(
        _ choices: S,
        selection: Binding<T>,
        title: @escaping (T) -> String,
        subtitle: @escaping (T) -> String?
    ) -> some View where S.Element == T {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
            ForEach(Array(choices), id: \.self) { choice in
                optionCardButton(
                    title: title(choice),
                    subtitle: subtitle(choice),
                    isSelected: selection.wrappedValue == choice
                ) {
                    selection.wrappedValue = choice
                }
            }
        }
    }

    private var plateFontSizeChoiceBinding: Binding<PlateFontSizeChoice> {
        Binding(
            get: {
                currentPlateFontSizeChoice(for: viewModel.config.plateFontSize, outputHeight: viewModel.config.outputHeight)
            },
            set: { choice in
                markSimplePlateEditing()
                viewModel.config.plateFontSize = scaledPlateFontSize(for: choice, outputHeight: viewModel.config.outputHeight)
            }
        )
    }

    private var frameWidthChoiceBinding: Binding<FrameWidthChoice> {
        Binding(
            get: {
                currentFrameWidthChoice(for: viewModel.config.innerPadding, outputHeight: viewModel.config.outputHeight)
            },
            set: { choice in
                viewModel.config.innerPadding = scaledFrameWidth(for: choice, outputHeight: viewModel.config.outputHeight)
            }
        )
    }

    private var plateFontStyleBinding: Binding<PlateFontStyle> {
        Binding(
            get: { viewModel.config.plateFontStyle },
            set: { style in
                markSimplePlateEditing()
                viewModel.config.plateFontStyle = style
            }
        )
    }

    private var plateEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.config.plateEnabled },
            set: { isEnabled in
                viewModel.config.plateEnabled = isEnabled
                viewModel.config.plateEditorMode = isEnabled ? .simple : .none
            }
        )
    }

    private var platePlacementChoiceBinding: Binding<PlatePlacementChoice> {
        Binding(
            get: {
                guard viewModel.config.plateEnabled else { return .none }
                switch viewModel.config.platePlacement {
                case .frame:
                    return .frame
                case .canvasBottom:
                    return .canvasBottom
                }
            },
            set: { choice in
                switch choice {
                case .none:
                    viewModel.config.plateEnabled = false
                    viewModel.config.plateEditorMode = .none
                case .frame:
                    viewModel.config.beginSimplePlateEditing(enableIfNeeded: true)
                    viewModel.config.platePlacement = .frame
                case .canvasBottom:
                    viewModel.config.beginSimplePlateEditing(enableIfNeeded: true)
                    viewModel.config.platePlacement = .canvasBottom
                }
            }
        )
    }

    private var fpsBinding: Binding<Int> {
        Binding(
            get: { viewModel.config.fps },
            set: { viewModel.config.fps = $0 }
        )
    }

    private var resolutionBinding: Binding<ResolutionChoice> {
        Binding(
            get: {
                switch (viewModel.config.outputWidth, viewModel.config.outputHeight) {
                case (1280, 720): return .hd720
                case (1920, 1080): return .fullHD1080
                case (2560, 1440): return .qhd1440
                case (3840, 2160): return .uhd4K
                default: return .fullHD1080
                }
            },
            set: { choice in
                let previousHeight = viewModel.config.outputHeight
                let previousChoice = currentPlateFontSizeChoice(for: viewModel.config.plateFontSize, outputHeight: previousHeight)
                let previousFrameWidthChoice = currentFrameWidthChoice(for: viewModel.config.innerPadding, outputHeight: previousHeight)
                let size = choice.size
                viewModel.config.outputWidth = size.width
                viewModel.config.outputHeight = size.height
                if isUsingSimplePlateFontSizePreset(previousChoice, outputHeight: previousHeight) {
                    viewModel.config.plateFontSize = scaledPlateFontSize(for: previousChoice, outputHeight: size.height)
                }
                if isUsingSimpleFrameWidthPreset(previousFrameWidthChoice, outputHeight: previousHeight) {
                    viewModel.config.innerPadding = scaledFrameWidth(for: previousFrameWidthChoice, outputHeight: size.height)
                }
            }
        )
    }

    private var imageDurationBinding: Binding<DurationChoice> {
        Binding(
            get: {
                let value = viewModel.config.imageDuration
                return DurationChoice.allCases.min(by: { abs($0.seconds - value) < abs($1.seconds - value) }) ?? .standard
            },
            set: { choice in
                viewModel.config.setImageDurationSafely(choice.seconds)
            }
        )
    }

    private func currentPlateFontSizeChoice(for fontSize: Double, outputHeight: Int) -> PlateFontSizeChoice {
        PlateFontSizeChoice.allCases.min(by: {
            abs(scaledPlateFontSize(for: $0, outputHeight: outputHeight) - fontSize)
                < abs(scaledPlateFontSize(for: $1, outputHeight: outputHeight) - fontSize)
        }) ?? .medium
    }

    private func isUsingSimplePlateFontSizePreset(_ choice: PlateFontSizeChoice, outputHeight: Int) -> Bool {
        abs(viewModel.config.plateFontSize - scaledPlateFontSize(for: choice, outputHeight: outputHeight)) <= 0.5
    }

    private func scaledPlateFontSize(for choice: PlateFontSizeChoice, outputHeight: Int) -> Double {
        let scale = max(Double(outputHeight) / 1080.0, 0.75)
        let rawSize = Double(choice.rawValue) * scale
        return min(
            max(rawSize, RenderEditorConfig.plateFontSizeRange.lowerBound),
            RenderEditorConfig.plateFontSizeRange.upperBound
        )
    }

    private func currentFrameWidthChoice(for innerPadding: Double, outputHeight: Int) -> FrameWidthChoice {
        FrameWidthChoice.allCases.min(by: {
            abs(scaledFrameWidth(for: $0, outputHeight: outputHeight) - innerPadding)
                < abs(scaledFrameWidth(for: $1, outputHeight: outputHeight) - innerPadding)
        }) ?? .medium
    }

    private func isUsingSimpleFrameWidthPreset(_ choice: FrameWidthChoice, outputHeight: Int) -> Bool {
        abs(viewModel.config.innerPadding - scaledFrameWidth(for: choice, outputHeight: outputHeight)) <= 0.5
    }

    private func scaledFrameWidth(for choice: FrameWidthChoice, outputHeight: Int) -> Double {
        let scale = max(Double(outputHeight) / 1080.0, 0.75)
        let rawSize = Double(choice.rawValue) * scale
        return min(
            max(rawSize, RenderEditorConfig.innerPaddingRange.lowerBound),
            RenderEditorConfig.innerPaddingRange.upperBound
        )
    }

    private var transitionBinding: Binding<TransitionChoice> {
        Binding(
            get: {
                if !viewModel.config.enableCrossfade || viewModel.config.transitionDuration <= 0.001 {
                    return .off
                }
                let duration = viewModel.config.transitionDuration
                let candidates: [TransitionChoice] = [.soft, .standard]
                return candidates.min(by: { abs($0.transitionDuration - duration) < abs($1.transitionDuration - duration) }) ?? .standard
            },
            set: { choice in
                if choice == .off {
                    viewModel.config.enableCrossfade = false
                    viewModel.config.setTransitionDurationSafely(0)
                    return
                }
                viewModel.config.enableCrossfade = true
                viewModel.config.setTransitionDurationSafely(choice.transitionDuration)
            }
        )
    }

    private var transitionGapBinding: Binding<TransitionGapChoice> {
        Binding(
            get: {
                let value = viewModel.config.transitionDipDuration
                return TransitionGapChoice.allCases.min(by: {
                    abs($0.duration - value) < abs($1.duration - value)
                }) ?? .short
            },
            set: { choice in
                viewModel.config.transitionDipDuration = choice.duration
            }
        )
    }

    private var kenBurnsBinding: Binding<KenBurnsChoice> {
        Binding(
            get: {
                guard viewModel.config.enableKenBurns else { return .off }
                switch viewModel.config.kenBurnsIntensity {
                case .small: return .subtle
                case .medium, .large: return .standard
                }
            },
            set: { choice in
                switch choice {
                case .off:
                    viewModel.config.enableKenBurns = false
                case .subtle:
                    viewModel.config.enableKenBurns = true
                    viewModel.config.kenBurnsIntensity = .small
                case .standard:
                    viewModel.config.enableKenBurns = true
                    viewModel.config.kenBurnsIntensity = .medium
                }
            }
        )
    }

    private var orientationBinding: Binding<PhotoOrientationStrategy> {
        Binding(
            get: { viewModel.config.orientationStrategy },
            set: { viewModel.config.orientationStrategy = $0 }
        )
    }

    private var orientationChoices: [PhotoOrientationStrategy] {
        [.followAsset, .forceLandscape, .forcePortrait]
    }

    private func plateSimpleEnabledBinding(index: Int) -> Binding<Bool> {
        Binding(
            get: { viewModel.config.plateSimpleElements[index].enabled },
            set: { isEnabled in
                markSimplePlateEditing()
                viewModel.config.plateSimpleElements[index].enabled = isEnabled
                if !isEnabled {
                    commitPrefixDraft(for: viewModel.config.plateSimpleElements[index].key)
                }
            }
        )
    }

    private func simplePlateFieldRow(index: Int) -> some View {
        let key = viewModel.config.plateSimpleElements[index].key
        let isEnabled = viewModel.config.plateSimpleElements[index].enabled

        return HStack(spacing: 10) {
            Text(key.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isEnabled ? .primary : .secondary)
                .frame(width: 42, alignment: .leading)

            prefixInput(text: prefixDraftBinding(index: index), key: key, isEnabled: isEnabled)

            Toggle("", isOn: plateSimpleEnabledBinding(index: index))
                .labelsHidden()
        }
        .padding(.horizontal, 10)
        .frame(minHeight: plateRowHeight)
        .background(rowBackground(isEnabled: isEnabled))
        .overlay(rowBorder(isEnabled: isEnabled))
    }

    private func prefixDraftBinding(index: Int) -> Binding<String> {
        let key = viewModel.config.plateSimpleElements[index].key
        return Binding(
            get: { plateSimplePrefixDrafts[key] ?? viewModel.config.plateSimpleElements[index].prefix },
            set: {
                markSimplePlateEditing()
                plateSimplePrefixDrafts[key] = $0
            }
        )
    }

    private func commitPrefixDraft(for key: PlateSimpleElementKey) {
        guard let draft = plateSimplePrefixDrafts[key] else { return }
        guard let index = viewModel.config.plateSimpleElements.firstIndex(where: { $0.key == key }) else {
            plateSimplePrefixDrafts.removeValue(forKey: key)
            return
        }
        viewModel.config.plateSimpleElements[index].prefix = draft
        plateSimplePrefixDrafts.removeValue(forKey: key)
    }

    private func commitAllPlateSimpleDrafts() {
        for key in Array(plateSimplePrefixDrafts.keys) {
            commitPrefixDraft(for: key)
        }
    }

    private func markSimplePlateEditing() {
        viewModel.config.beginSimplePlateEditing(enableIfNeeded: viewModel.config.plateEnabled)
    }

    private func orientationChoiceButton(title: String, strategy: PhotoOrientationStrategy) -> some View {
        optionCardButton(
            title: title,
            subtitle: nil,
            isSelected: viewModel.config.orientationStrategy == strategy
        ) {
            viewModel.config.orientationStrategy = strategy
        }
    }

    private func frameStyleChoiceButton(title: String, preset: FrameStylePreset) -> some View {
        optionCardButton(
            title: title,
            subtitle: nil,
            isSelected: viewModel.config.frameStylePreset == preset
        ) {
            viewModel.config.frameStylePreset = preset
        }
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
            content()
        }
    }

    private func settingsSubgroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var optionContainerBackground: some View {
        RoundedRectangle(cornerRadius: optionCardCornerRadius, style: .continuous)
            .fill(Color.secondary.opacity(0.08))
    }

    private var optionContainerBorder: some View {
        RoundedRectangle(cornerRadius: optionCardCornerRadius, style: .continuous)
            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
    }

    private func optionCardButton(
        title: String,
        subtitle: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: optionCardMinHeight)
            .padding(.horizontal, 8)
            .background(optionCardBackground(isSelected: isSelected))
            .overlay(optionCardBorder(isSelected: isSelected))
        }
        .buttonStyle(.plain)
    }

    private func optionCardBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: optionCardCornerRadius, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08))
    }

    private func optionCardBorder(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: optionCardCornerRadius, style: .continuous)
            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.22), lineWidth: isSelected ? 1.4 : 1)
    }

    private func prefixInput(text: Binding<String>, key: PlateSimpleElementKey, isEnabled: Bool) -> some View {
        ZStack(alignment: .leading) {
            if text.wrappedValue.isEmpty {
                Text(isEnabled ? String(localized: "留空") : String(localized: "未启用"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 10)
            }

            TextField(
                "",
                text: text,
                onEditingChanged: { editing in
                    if !editing {
                        commitPrefixDraft(for: key)
                    }
                },
                onCommit: {
                    commitPrefixDraft(for: key)
                }
            )
            .textFieldStyle(.plain)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(isEnabled ? .primary : .secondary)
            .padding(.horizontal, 10)
            .disabled(!isEnabled)
        }
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(isEnabled ? 0.10 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(isEnabled ? 0.18 : 0.10), lineWidth: 1)
        )
    }

    private func rowBackground(isEnabled: Bool) -> some View {
        RoundedRectangle(cornerRadius: optionCardCornerRadius, style: .continuous)
            .fill(Color.secondary.opacity(isEnabled ? 0.08 : 0.05))
    }

    private func rowBorder(isEnabled: Bool) -> some View {
        RoundedRectangle(cornerRadius: optionCardCornerRadius, style: .continuous)
            .stroke(Color.secondary.opacity(isEnabled ? 0.18 : 0.10), lineWidth: 1)
    }
}

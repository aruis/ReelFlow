import Foundation
import SwiftUI
import CoreText

private struct InlineHelpButton: View {
    let text: String
    @State private var showsPopover = false

    var body: some View {
        Button {
            showsPopover.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(text)
        .popover(isPresented: $showsPopover, arrowEdge: .bottom) {
            Text(text)
                .font(.caption)
                .frame(width: 220, alignment: .leading)
                .padding(12)
        }
    }
}

struct AdvancedSettingsPanel: View {
    @ObservedObject var viewModel: ExportViewModel
    @Binding var isAudioDropTarget: Bool
    let onAudioDrop: ([NSItemProvider]) -> Bool
    var isLocked: Bool = false
    @State private var prefersCustomResolution = false
    @State private var prefersCustomDuration = false
    @State private var prefersCustomLayout = false
    @State private var prefersCustomTemplate = false


    private let optionCardCornerRadius: CGFloat = 10
    private let optionCardMinHeight: CGFloat = 48
    private let numericRowLabelWidth: CGFloat = 86
    private let numericFieldWidth: CGFloat = 78
    private let numericFieldWideWidth: CGFloat = 96
    private let numericControlHeight: CGFloat = 30
    private let numericStepperWidth: CGFloat = 26

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

    private enum DurationChoice: String, CaseIterable, Identifiable {
        case quick
        case standard
        case relaxed
        case custom

        var id: String { rawValue }

        var title: String {
            switch self {
            case .quick: return String(localized: "快节奏")
            case .standard: return String(localized: "标准")
            case .relaxed: return String(localized: "舒缓")
            case .custom: return String(localized: "自定义")
            }
        }

        var subtitle: String? {
            switch self {
            case .quick: return String(localized: "1.5 秒/张")
            case .standard: return String(localized: "2.5 秒/张")
            case .relaxed: return String(localized: "4.0 秒/张")
            case .custom: return String(localized: "手动微调")
            }
        }

        var seconds: Double? {
            switch self {
            case .quick: return 1.5
            case .standard: return 2.5
            case .relaxed: return 4.0
            case .custom: return nil
            }
        }
    }

    private enum ResolutionPreset: Int, CaseIterable, Identifiable {
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

        var subtitle: String {
            "\(size.width) × \(size.height)"
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

    private enum ResolutionChoice: String, CaseIterable, Identifiable {
        case hd720
        case fullHD1080
        case qhd1440
        case uhd4K
        case custom

        var id: String { rawValue }

        var title: String {
            switch self {
            case .hd720: return "720p"
            case .fullHD1080: return "1080p"
            case .qhd1440: return "1440p"
            case .uhd4K: return "4K"
            case .custom: return String(localized: "自定义")
            }
        }

        var subtitle: String? {
            switch self {
            case .hd720: return "1280 × 720"
            case .fullHD1080: return "1920 × 1080"
            case .qhd1440: return "2560 × 1440"
            case .uhd4K: return "3840 × 2160"
            case .custom: return String(localized: "手动宽高")
            }
        }

        var preset: ResolutionPreset? {
            switch self {
            case .hd720: return .hd720
            case .fullHD1080: return .fullHD1080
            case .qhd1440: return .qhd1440
            case .uhd4K: return .uhd4K
            case .custom: return nil
            }
        }
    }

    private enum LayoutDensityChoice: String, CaseIterable, Identifiable {
        case compact
        case balanced
        case spacious
        case custom

        var id: String { rawValue }

        var title: String {
            switch self {
            case .compact: return String(localized: "紧凑")
            case .balanced: return String(localized: "平衡")
            case .spacious: return String(localized: "宽松")
            case .custom: return String(localized: "自定义")
            }
        }

        var subtitle: String? {
            switch self {
            case .compact: return String(localized: "更满版")
            case .balanced: return String(localized: "推荐")
            case .spacious: return String(localized: "更有留白")
            case .custom: return String(localized: "手动微调")
            }
        }
    }

    private enum PlateTemplatePreset: String, CaseIterable, Identifiable {
        case defaultClassic
        case exposure
        case dateFirst
        case minimal
        case custom

        var id: String { rawValue }

        var title: String {
            switch self {
            case .defaultClassic: return String(localized: "经典")
            case .exposure: return String(localized: "曝光优先")
            case .dateFirst: return String(localized: "日期优先")
            case .minimal: return String(localized: "极简")
            case .custom: return String(localized: "自定义")
            }
        }

        var subtitle: String? {
            switch self {
            case .defaultClassic: return String(localized: "默认模板")
            case .exposure: return String(localized: "参数更完整")
            case .dateFirst: return String(localized: "突出拍摄日期")
            case .minimal: return String(localized: "只保留设备")
            case .custom: return nil
            }
        }

        var templateText: String? {
            switch self {
            case .defaultClassic:
                return PlateSettings.defaultTemplateText
            case .exposure:
                return "{camera}   ISO {iso}   {lens}   S {shutter}   A {aperture}"
            case .dateFirst:
                return "{date}   {camera}   {lens}"
            case .minimal:
                return "{camera}   {lens}"
            case .custom:
                return nil
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
            case .none: return String(localized: "无")
            case .frame: return String(localized: "相框内")
            case .canvasBottom: return String(localized: "相框外")
            }
        }

        var subtitle: String? {
            switch self {
            case .none: return String(localized: "不显示铭牌")
            case .frame: return String(localized: "更靠近画面")
            case .canvasBottom: return String(localized: "更像胶片铭牌")
            }
        }
    }

    var body: some View {
        Form {
            Section(String(localized: "导出设置")) {
                if let settingsValidationMessage {
                    settingsValidationView(settingsValidationMessage)
                }

                summaryCard(
                    title: String(localized: "当前输出"),
                    summary: exportSummaryText
                )

                settingsGroup(
                    title: String(localized: "帧率"),
                    description: String(localized: "控制播放流畅度")
                ) {
                    choiceGrid(
                        [24, 30, 60],
                        selection: fpsBinding,
                        title: { "\($0) FPS" },
                        subtitle: { _ in nil }
                    )
                }

                settingsGroup(
                    title: String(localized: "画面尺寸"),
                    description: String(localized: "控制输出尺寸")
                ) {
                    choiceGrid(
                        ResolutionChoice.allCases,
                        selection: resolutionChoiceBinding,
                        title: \ResolutionChoice.title,
                        subtitle: \ResolutionChoice.subtitle
                    )
                    .disabled(isControlDisabled)

                    settingsSubgroup(title: String(localized: "尺寸细调")) {
                        VStack(alignment: .leading, spacing: 10) {
                            dimensionEditorRow(
                                title: String(localized: "宽度"),
                                unit: "px",
                                value: outputWidthBinding,
                                range: RenderEditorConfig.outputWidthRange
                            )
                            dimensionEditorRow(
                                title: String(localized: "高度"),
                                unit: "px",
                                value: outputHeightBinding,
                                range: RenderEditorConfig.outputHeightRange
                            )
                        }
                        .padding(12)
                        .background(optionContainerBackground)
                        .overlay(optionContainerBorder)
                    }
                }

                settingsGroup(
                    title: String(localized: "时间与节奏"),
                    description: String(localized: "控制时长、转场与动效")
                ) {
                    settingsSubgroup(title: String(localized: "展示节奏")) {
                        choiceGrid(
                            DurationChoice.allCases,
                            selection: durationChoiceBinding,
                            title: \DurationChoice.title,
                            subtitle: \DurationChoice.subtitle
                        )
                    }

                    settingsSubgroup(title: String(localized: "时长细调")) {
                        VStack(alignment: .leading, spacing: 10) {
                            doubleInputRow(
                                title: String(localized: "单图时长"),
                                unit: "s",
                                value: imageDurationBinding,
                                range: RenderEditorConfig.imageDurationRange,
                                step: 0.5
                            )
                        }
                        .padding(12)
                        .background(optionContainerBackground)
                        .overlay(optionContainerBorder)
                    }

                    settingsSubgroup(title: String(localized: "推拉动效（Ken Burns）")) {
                        choiceGrid(
                            KenBurnsChoice.allCases,
                            selection: kenBurnsChoiceBinding,
                            title: \KenBurnsChoice.title,
                            subtitle: \KenBurnsChoice.subtitle
                        )
                    }

                    settingsSubgroup(title: String(localized: "转场与空窗细调")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Toggle(String(localized: "启用淡入淡出转场"), isOn: $viewModel.config.enableCrossfade)
                                Spacer(minLength: 0)
                                Text(viewModel.config.enableCrossfade ? String(localized: "已开启") : String(localized: "已关闭"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            settingsSubgroup(title: String(localized: "转场时长")) {
                                sliderSettingRow(
                                    title: String(localized: "交接长度"),
                                    value: transitionDurationBinding,
                                    range: RenderEditorConfig.transitionDurationRange,
                                    step: 0.05,
                                    format: { String(format: "%.2f s", $0) },
                                    isDisabled: isControlDisabled || !viewModel.config.enableCrossfade
                                )

                                if let transitionValidationMessage {
                                    Text(transitionValidationMessage)
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                            }

                            settingsSubgroup(title: String(localized: "背景空窗")) {
                                sliderSettingRow(
                                    title: String(localized: "空窗长度"),
                                    value: transitionDipDurationBinding,
                                    range: RenderEditorConfig.transitionDipDurationRange,
                                    step: 0.01,
                                    format: { String(format: "%.2f s", $0) },
                                    isDisabled: isControlDisabled
                                )
                            }
                        }
                        .padding(12)
                        .background(optionContainerBackground)
                        .overlay(optionContainerBorder)
                    }
                }

                settingsGroup(
                    title: String(localized: "画面策略"),
                    description: String(localized: "控制取向与相框风格")
                ) {
                    settingsSubgroup(title: String(localized: "横竖图策略")) {
                        choiceGrid(
                            orientationChoices,
                            selection: orientationBinding,
                            title: \PhotoOrientationStrategy.displayName,
                            subtitle: { _ in nil }
                        )
                    }

                    settingsSubgroup(title: String(localized: "相框风格")) {
                        choiceGrid(
                            FrameStylePreset.allCases,
                            selection: frameStyleBinding,
                            title: \FrameStylePreset.displayName,
                            subtitle: { preset in
                                preset == .custom ? String(localized: "可调灰度") : nil
                            }
                        )
                    }

                    settingsSubgroup(title: String(localized: "色调细调")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(localized: "自定义色调"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            sliderSettingRow(
                                title: String(localized: "背景灰度"),
                                value: canvasBackgroundGrayBinding,
                                range: RenderEditorConfig.grayRange,
                                step: 0.01,
                                format: { "\(Int(($0 * 100).rounded()))%" },
                                isDisabled: isControlDisabled
                            )
                            sliderSettingRow(
                                title: String(localized: "相纸亮度"),
                                value: canvasPaperWhiteBinding,
                                range: RenderEditorConfig.grayRange,
                                step: 0.01,
                                format: { "\(Int(($0 * 100).rounded()))%" },
                                isDisabled: isControlDisabled
                            )
                            sliderSettingRow(
                                title: String(localized: "边框灰度"),
                                value: canvasStrokeGrayBinding,
                                range: RenderEditorConfig.grayRange,
                                step: 0.01,
                                format: { "\(Int(($0 * 100).rounded()))%" },
                                isDisabled: isControlDisabled
                            )
                            sliderSettingRow(
                                title: String(localized: "文字灰度"),
                                value: canvasTextGrayBinding,
                                range: RenderEditorConfig.grayRange,
                                step: 0.01,
                                format: { "\(Int(($0 * 100).rounded()))%" },
                                isDisabled: isControlDisabled
                            )
                        }
                        .padding(12)
                        .background(optionContainerBackground)
                        .overlay(optionContainerBorder)
                    }
                }
            }

            Section(String(localized: "高级布局")) {
                settingsGroup(
                    title: String(localized: "版式密度"),
                    description: String(localized: "控制留白与边距")
                ) {
                    choiceGrid(
                        LayoutDensityChoice.allCases,
                        selection: layoutDensityBinding,
                        title: \LayoutDensityChoice.title,
                        subtitle: \LayoutDensityChoice.subtitle
                    )
                    .disabled(isControlDisabled)

                    settingsSubgroup(title: String(localized: "精细调整")) {
                        VStack(alignment: .leading, spacing: 10) {
                            doubleInputRow(
                                title: String(localized: "左右留白"),
                                unit: "px",
                                value: horizontalMarginBinding,
                                range: RenderEditorConfig.horizontalMarginRange,
                                step: 1
                            )
                            doubleInputRow(
                                title: String(localized: "上留白"),
                                unit: "px",
                                value: topMarginBinding,
                                range: RenderEditorConfig.topMarginRange,
                                step: 1
                            )
                            doubleInputRow(
                                title: String(localized: "下留白"),
                                unit: "px",
                                value: bottomMarginBinding,
                                range: RenderEditorConfig.bottomMarginRange,
                                step: 1
                            )
                            doubleInputRow(
                                title: String(localized: "相框宽度"),
                                unit: "px",
                                value: innerPaddingBinding,
                                range: RenderEditorConfig.innerPaddingRange,
                                step: 1
                            )
                        }
                        .padding(12)
                        .background(optionContainerBackground)
                        .overlay(optionContainerBorder)
                    }
                }

                settingsGroup(
                    title: String(localized: "铭牌信息"),
                    description: String(localized: "控制位置、模板与字体")
                ) {
                    settingsSubgroup(title: String(localized: "位置")) {
                        choiceGrid(
                            PlatePlacementChoice.allCases,
                            selection: platePlacementChoiceBinding,
                            title: \PlatePlacementChoice.title,
                            subtitle: \PlatePlacementChoice.subtitle
                        )
                    }
                    .disabled(isControlDisabled)

                    plateContentEditor
                }
            }

            Section(String(localized: "预览与缓存")) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "性能说明"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(String(localized: "仅影响预览，不影响导出"))
                            .font(.subheadline)
                    }

                    integerInputRow(
                        title: String(localized: "预取半径"),
                        help: String(localized: "控制预览时会提前载入当前片段前后的素材范围。值越大，切换更顺滑，但会占用更多内存。"),
                        value: $viewModel.config.prefetchRadius,
                        range: RenderEditorConfig.prefetchRadiusRange
                    )
                    integerInputRow(
                        title: String(localized: "预取并发"),
                        help: String(localized: "控制同时预加载多少个素材任务。值越高，预取速度更快，但可能增加系统负担。"),
                        value: $viewModel.config.prefetchMaxConcurrent,
                        range: RenderEditorConfig.prefetchMaxConcurrentRange
                    )
                }
                .padding(12)
                .background(optionContainerBackground)
                .overlay(optionContainerBorder)
                .disabled(isControlDisabled)
            }

            AudioSettingsSection(
                viewModel: viewModel,
                isAudioDropTarget: $isAudioDropTarget,
                onAudioDrop: onAudioDrop
            )
            .disabled(isControlDisabled)
        }
        .formStyle(.grouped)
    }

    private var isControlDisabled: Bool {
        viewModel.isBusy || isLocked
    }

    private var settingsValidationMessage: String? {
        viewModel.validationMessage
    }

    private var transitionValidationMessage: String? {
        guard viewModel.config.enableCrossfade else { return nil }
        guard viewModel.config.transitionDuration >= viewModel.config.imageDuration else { return nil }
        return String(localized: "转场时长必须小于单图时长，请缩短转场或延长单图时长。")
    }

    private var exportSummaryText: String {
        String(
            localized: "\(viewModel.config.outputWidth) × \(viewModel.config.outputHeight) · \(viewModel.config.fps) FPS · 单图 \(String(format: "%.1f", viewModel.config.imageDuration))s · \(viewModel.config.frameStylePreset.displayName)"
        )
    }

    private var motionSummaryText: String {
        let transitionState = viewModel.config.enableCrossfade
            ? String(localized: "转场 \(String(format: "%.2f", viewModel.config.transitionDuration))s")
            : String(localized: "无转场")
        let dipState = String(localized: "空窗 \(String(format: "%.2f", viewModel.config.transitionDipDuration))s")
        return [transitionState, dipState].joined(separator: " · ")
    }

    private var frameStyleSummaryText: String {
        String(
            localized: "背景 \(Int((viewModel.config.canvasBackgroundGray * 100).rounded()))% · 相纸 \(Int((viewModel.config.canvasPaperWhite * 100).rounded()))% · 边框 \(Int((viewModel.config.canvasStrokeGray * 100).rounded()))%"
        )
    }

    private var layoutSummaryText: String {
        String(
            localized: "左右 \(String(format: "%.0f", viewModel.config.horizontalMargin)) · 上 \(String(format: "%.0f", viewModel.config.topMargin)) · 下 \(String(format: "%.0f", viewModel.config.bottomMargin)) · 内边距 \(String(format: "%.0f", viewModel.config.innerPadding))"
        )
    }

    private var plateSummaryText: String {
        let location = viewModel.config.platePlacement == .frame
            ? String(localized: "相框内")
            : String(localized: "相框外")
        return String(localized: "\(location) · \(viewModel.config.plateFontStyle.displayName) · \(String(format: "%.1f", viewModel.config.plateFontSize)) pt")
    }

    private var orientationChoices: [PhotoOrientationStrategy] {
        [.followAsset, .forceLandscape, .forcePortrait]
    }

    private var fpsBinding: Binding<Int> {
        Binding(
            get: { viewModel.config.fps },
            set: { viewModel.config.fps = $0 }
        )
    }

    private var resolutionChoiceBinding: Binding<ResolutionChoice> {
        Binding(
            get: {
                if prefersCustomResolution {
                    return .custom
                }
                switch resolutionPreset(for: viewModel.config.outputWidth, height: viewModel.config.outputHeight) {
                case .hd720: return .hd720
                case .fullHD1080: return .fullHD1080
                case .qhd1440: return .qhd1440
                case .uhd4K: return .uhd4K
                case nil: return .custom
                }
            },
            set: { choice in
                if let preset = choice.preset {
                    prefersCustomResolution = false
                    viewModel.config.outputWidth = preset.size.width
                    viewModel.config.outputHeight = preset.size.height
                } else {
                    prefersCustomResolution = true
                }
            }
        )
    }

    private var frameStyleBinding: Binding<FrameStylePreset> {
        Binding(
            get: { viewModel.config.frameStylePreset },
            set: { preset in
                viewModel.config.frameStylePreset = preset
                guard preset != .custom else { return }
                let canvas = preset.canvas
                viewModel.config.canvasBackgroundGray = canvas.backgroundGray
                viewModel.config.canvasPaperWhite = canvas.paperWhite
                viewModel.config.canvasStrokeGray = canvas.strokeGray
                viewModel.config.canvasTextGray = canvas.textGray
            }
        )
    }

    private var durationChoiceBinding: Binding<DurationChoice> {
        Binding(
            get: {
                if prefersCustomDuration {
                    return .custom
                }
                let duration = viewModel.config.imageDuration
                for choice in DurationChoice.allCases where choice != .custom {
                    if let seconds = choice.seconds, abs(seconds - duration) < 0.11 {
                        return choice
                    }
                }
                return .custom
            },
            set: { choice in
                if let seconds = choice.seconds {
                    prefersCustomDuration = false
                    viewModel.config.setImageDurationSafely(seconds)
                } else {
                    prefersCustomDuration = true
                }
            }
        )
    }

    private var imageDurationBinding: Binding<Double> {
        Binding(
            get: { viewModel.config.imageDuration },
            set: {
                prefersCustomDuration = true
                viewModel.config.setImageDurationSafely($0)
            }
        )
    }

    private var outputWidthBinding: Binding<Int> {
        Binding(
            get: { viewModel.config.outputWidth },
            set: {
                prefersCustomResolution = true
                viewModel.config.outputWidth = $0
            }
        )
    }

    private var outputHeightBinding: Binding<Int> {
        Binding(
            get: { viewModel.config.outputHeight },
            set: {
                prefersCustomResolution = true
                viewModel.config.outputHeight = $0
            }
        )
    }

    private var transitionDurationBinding: Binding<Double> {
        Binding(
            get: { viewModel.config.transitionDuration },
            set: { viewModel.config.setTransitionDurationSafely($0) }
        )
    }

    private var transitionDipDurationBinding: Binding<Double> {
        Binding(
            get: { viewModel.config.transitionDipDuration },
            set: { value in
                viewModel.config.transitionDipDuration = min(
                    max(value, RenderEditorConfig.transitionDipDurationRange.lowerBound),
                    RenderEditorConfig.transitionDipDurationRange.upperBound
                )
            }
        )
    }

    private var kenBurnsChoiceBinding: Binding<KenBurnsChoice> {
        Binding(
            get: {
                guard viewModel.config.enableKenBurns else { return .off }
                switch viewModel.config.kenBurnsIntensity {
                case .small:
                    return .subtle
                case .medium, .large:
                    return .standard
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

    private var canvasBackgroundGrayBinding: Binding<Double> {
        Binding(
            get: { viewModel.config.canvasBackgroundGray },
            set: {
                viewModel.config.frameStylePreset = .custom
                viewModel.config.canvasBackgroundGray = $0
            }
        )
    }

    private var canvasPaperWhiteBinding: Binding<Double> {
        Binding(
            get: { viewModel.config.canvasPaperWhite },
            set: {
                viewModel.config.frameStylePreset = .custom
                viewModel.config.canvasPaperWhite = $0
            }
        )
    }

    private var canvasStrokeGrayBinding: Binding<Double> {
        Binding(
            get: { viewModel.config.canvasStrokeGray },
            set: {
                viewModel.config.frameStylePreset = .custom
                viewModel.config.canvasStrokeGray = $0
            }
        )
    }

    private var canvasTextGrayBinding: Binding<Double> {
        Binding(
            get: { viewModel.config.canvasTextGray },
            set: {
                viewModel.config.frameStylePreset = .custom
                viewModel.config.canvasTextGray = $0
            }
        )
    }

    private var horizontalMarginBinding: Binding<Double> {
        Binding(
            get: { viewModel.config.horizontalMargin },
            set: {
                prefersCustomLayout = true
                viewModel.config.horizontalMargin = $0
            }
        )
    }

    private var topMarginBinding: Binding<Double> {
        Binding(
            get: { viewModel.config.topMargin },
            set: {
                prefersCustomLayout = true
                viewModel.config.topMargin = $0
            }
        )
    }

    private var bottomMarginBinding: Binding<Double> {
        Binding(
            get: { viewModel.config.bottomMargin },
            set: {
                prefersCustomLayout = true
                viewModel.config.bottomMargin = $0
            }
        )
    }

    private var innerPaddingBinding: Binding<Double> {
        Binding(
            get: { viewModel.config.innerPadding },
            set: {
                prefersCustomLayout = true
                viewModel.config.innerPadding = $0
            }
        )
    }

    private var layoutDensityBinding: Binding<LayoutDensityChoice> {
        Binding(
            get: {
                if prefersCustomLayout {
                    return .custom
                }
                let layout = (
                    horizontal: viewModel.config.horizontalMargin,
                    top: viewModel.config.topMargin,
                    bottom: viewModel.config.bottomMargin,
                    inner: viewModel.config.innerPadding
                )

                for choice in LayoutDensityChoice.allCases where choice != .custom {
                    let preset = layoutPresetValues(for: choice, outputHeight: viewModel.config.outputHeight)
                    let isMatching =
                        abs(layout.horizontal - preset.horizontal) <= 2 &&
                        abs(layout.top - preset.top) <= 2 &&
                        abs(layout.bottom - preset.bottom) <= 2 &&
                        abs(layout.inner - preset.inner) <= 2
                    if isMatching {
                        return choice
                    }
                }

                return .custom
            },
            set: { choice in
                guard choice != .custom else {
                    prefersCustomLayout = true
                    return
                }
                prefersCustomLayout = false
                let preset = layoutPresetValues(for: choice, outputHeight: viewModel.config.outputHeight)
                viewModel.config.horizontalMargin = preset.horizontal
                viewModel.config.topMargin = preset.top
                viewModel.config.bottomMargin = preset.bottom
                viewModel.config.innerPadding = preset.inner
            }
        )
    }

    private var plateTemplatePresetBinding: Binding<PlateTemplatePreset> {
        Binding(
            get: {
                if prefersCustomTemplate {
                    return .custom
                }
                let current = currentPlatePresetSource.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !current.isEmpty else { return .custom }

                for preset in PlateTemplatePreset.allCases where preset != .custom {
                    if preset.templateText == current {
                        return preset
                    }
                }

                return .custom
            },
            set: { preset in
                activateCustomPlateEditorIfNeeded()
                if let template = preset.templateText {
                    prefersCustomTemplate = false
                    viewModel.config.plateTemplateText = template
                } else {
                    prefersCustomTemplate = true
                }
            }
        )
    }

    private var plateContentEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.config.plateEnabled {
                settingsSubgroup(title: String(localized: "模板预设")) {
                    choiceGrid(
                        PlateTemplatePreset.allCases,
                        selection: plateTemplatePresetBinding,
                        title: \PlateTemplatePreset.title,
                        subtitle: \PlateTemplatePreset.subtitle
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(String(localized: "文字样式"))
                            .font(.subheadline.weight(.medium))
                        Spacer(minLength: 0)
                        Text("\(viewModel.config.plateFontStyle.displayName) · \(String(format: "%.1f", viewModel.config.plateFontSize)) pt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Picker(String(localized: "字体风格"), selection: $viewModel.config.plateFontStyle) {
                        ForEach(PlateFontStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)

                    doubleInputRow(
                        title: String(localized: "字号"),
                        unit: "pt",
                        value: $viewModel.config.plateFontSize,
                        range: RenderEditorConfig.plateFontSizeRange,
                        step: 0.5
                    )
                }
                .padding(12)
                .background(optionContainerBackground)
                .overlay(optionContainerBorder)
                .disabled(isControlDisabled)

                plateTemplatePreview

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(String(localized: "模板编辑"))
                            .font(.subheadline.weight(.medium))
                        Spacer(minLength: 0)
                        Button(String(localized: "恢复默认")) {
                            viewModel.config.resetPlateTemplateToDefault()
                        }
                        .buttonStyle(.borderless)
                        .disabled(isControlDisabled)

                        Button(String(localized: "清空")) {
                            viewModel.config.plateTemplateText = ""
                        }
                        .buttonStyle(.borderless)
                            .disabled(isControlDisabled)
                    }

                    customPlateTemplateEditor
                        .disabled(isControlDisabled)

                    settingsSubgroup(title: String(localized: "占位符")) {
                        VStack(alignment: .leading, spacing: 10) {
                            tokenGrid
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(12)
                .background(optionContainerBackground)
                .overlay(optionContainerBorder)
            }
        }
    }

    private var tokenGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
            plateTokenButton(title: String(localized: "快门"), token: "{shutter}")
            plateTokenButton(title: String(localized: "光圈"), token: "{aperture}")
            plateTokenButton(title: "ISO", token: "{iso}")
            plateTokenButton(title: String(localized: "焦距"), token: "{focal}")
            plateTokenButton(title: String(localized: "日期"), token: "{date}")
            plateTokenButton(title: String(localized: "机型"), token: "{camera}")
            plateTokenButton(title: String(localized: "镜头"), token: "{lens}")
        }
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
                    activateCustomPlateEditorIfNeeded()
                    viewModel.config.plateEnabled = true
                    viewModel.config.platePlacement = .frame
                case .canvasBottom:
                    activateCustomPlateEditorIfNeeded()
                    viewModel.config.plateEnabled = true
                    viewModel.config.platePlacement = .canvasBottom
                }
            }
        )
    }

    private func resolutionPreset(for width: Int, height: Int) -> ResolutionPreset? {
        ResolutionPreset.allCases.first { preset in
            preset.size.width == width && preset.size.height == height
        }
    }

    private func layoutPresetValues(
        for choice: LayoutDensityChoice,
        outputHeight: Int
    ) -> (horizontal: Double, top: Double, bottom: Double, inner: Double) {
        let scale = max(Double(outputHeight) / 1080.0, 0.75)

        let rawValues: (Double, Double, Double, Double) = switch choice {
        case .compact:
            (120, 42, 76, 16)
        case .balanced:
            (180, 72, 96, 24)
        case .spacious:
            (190, 70, 118, 28)
        case .custom:
            (viewModel.config.horizontalMargin, viewModel.config.topMargin, viewModel.config.bottomMargin, viewModel.config.innerPadding)
        }

        return (
            horizontal: min(max(rawValues.0 * scale, RenderEditorConfig.horizontalMarginRange.lowerBound), RenderEditorConfig.horizontalMarginRange.upperBound),
            top: min(max(rawValues.1 * scale, RenderEditorConfig.topMarginRange.lowerBound), RenderEditorConfig.topMarginRange.upperBound),
            bottom: min(max(rawValues.2 * scale, RenderEditorConfig.bottomMarginRange.lowerBound), RenderEditorConfig.bottomMarginRange.upperBound),
            inner: min(max(rawValues.3 * scale, RenderEditorConfig.innerPaddingRange.lowerBound), RenderEditorConfig.innerPaddingRange.upperBound)
        )
    }

    private func plateTokenButton(title: String, token: String) -> some View {
        Button(title) {
            viewModel.config.insertPlateToken(token)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .focusable(false)
        .disabled(isControlDisabled)
    }

    private func settingsValidationView(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.red)
    }

    private var customPlateTemplateEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: plateTemplateTextBinding)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 96)
                .padding(8)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

            if viewModel.config.plateTemplateText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(String(localized: "输入铭牌模板，或从下方插入占位符"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .allowsHitTesting(false)
            }
        }
    }

    private var plateTemplateTextBinding: Binding<String> {
        Binding(
            get: {
                if viewModel.config.plateEditorMode == .simple {
                    return viewModel.config.simplePlateTemplateText
                }
                return viewModel.config.plateTemplateText
            },
            set: {
                prefersCustomTemplate = true
                if viewModel.config.plateEditorMode == .simple {
                    viewModel.config.beginCustomPlateEditing(seedFromSimpleIfNeeded: true)
                }
                viewModel.config.plateTemplateText = $0
            }
        )
    }

    private var plateTemplatePreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(localized: "示例预览"))
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 0)
                Text(String(localized: "当前铭牌效果"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(samplePlatePreviewText)
                .font(platePreviewFont)
                .tracking(0.2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.14))
                )
        }
        .padding(12)
        .background(optionContainerBackground)
        .overlay(optionContainerBorder)
    }

    private var samplePlatePreviewText: String {
        sampleExif.resolvedPlateText(template: currentPlatePreviewTemplate)
    }

    private var platePreviewFont: Font {
        let size = max(viewModel.config.plateFontSize * 0.6, 12)
        let plateFont = PlatformDrawing.plateFont(
            style: viewModel.config.plateFontStyle,
            ofSize: size
        )
        let fontName = CTFontCopyPostScriptName(plateFont) as String
        return .custom(fontName, size: size)
    }

    private var currentPlatePreviewTemplate: String {
        if viewModel.config.plateEditorMode == .simple {
            return viewModel.config.simplePlateTemplateText
        }
        return viewModel.config.plateTemplateText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentPlatePresetSource: String {
        if viewModel.config.plateEditorMode == .simple {
            return viewModel.config.simplePlateTemplateText
        }
        return viewModel.config.plateTemplateText
    }

    private var sampleExif: ExifInfo {
        ExifInfo(
            shutter: "1/125",
            aperture: "2.8",
            iso: "400",
            focalLength: "35",
            date: "2026-02-06",
            camera: "Leica Q3",
            lens: "Summilux 28"
        )
    }

    private func activateCustomPlateEditorIfNeeded() {
        guard viewModel.config.plateEnabled else { return }
        viewModel.config.beginCustomPlateEditing(seedFromSimpleIfNeeded: true)
    }

    private func summaryCard(title: String, summary: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(summary)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(optionContainerBackground)
        .overlay(optionContainerBorder)
    }

    private func settingsGroup<Content: View>(
        title: String,
        description: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
            if let description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content()
        }
    }

    private func settingsSubgroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
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
                optionCardButton(
                    title: choice[keyPath: title],
                    subtitle: choice[keyPath: subtitle],
                    isSelected: isSelected
                ) {
                    selection.wrappedValue = choice
                }
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

    private func optionCardButton(
        title: String,
        subtitle: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        FocuslessOptionCardButton(
            title: title,
            subtitle: subtitle,
            isSelected: isSelected,
            isEnabled: !isControlDisabled,
            cornerRadius: optionCardCornerRadius,
            minHeight: optionCardMinHeight,
            multilineSubtitle: true,
            action: action
        )
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? String(localized: "已选中") : String(localized: "未选中"))
        .disabled(isControlDisabled)
    }

    private var optionContainerBackground: some View {
        RoundedRectangle(cornerRadius: optionCardCornerRadius, style: .continuous)
            .fill(Color.secondary.opacity(0.08))
    }

    private var optionContainerBorder: some View {
        RoundedRectangle(cornerRadius: optionCardCornerRadius, style: .continuous)
            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
    }

    private func optionCardBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: optionCardCornerRadius, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08))
    }

    private func optionCardBorder(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: optionCardCornerRadius, style: .continuous)
            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.22), lineWidth: isSelected ? 1.4 : 1)
    }

    private func sliderSettingRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: @escaping (Double) -> String,
        isDisabled: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.medium))
                Spacer(minLength: 8)
                Text(format(value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: range, step: step)
                .disabled(isDisabled)
        }
    }

    private func dimensionEditorRow(
        title: String,
        unit: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .frame(width: numericRowLabelWidth, alignment: .leading)

            Spacer(minLength: 8)

            numericValueField(
                value: value,
                prompt: nil,
                unit: unit,
                fieldWidth: numericFieldWideWidth
            )

            Stepper("", value: value, in: range, step: 2)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: numericStepperWidth)
        }
    }

    private func doubleInputRow(
        title: String,
        unit: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .frame(width: numericRowLabelWidth, alignment: .leading)

            Spacer(minLength: 8)

            numericValueField(
                value: value,
                prompt: nil,
                unit: unit,
                fieldWidth: unit == "pt" ? numericFieldWideWidth : numericFieldWidth,
                fractionLength: unit == "pt" || unit == "s" ? 1 : 0
            )

            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: numericStepperWidth)
        }
        .disabled(isControlDisabled)
    }

    private func integerInputRow(
        title: String,
        help: String? = nil,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                if let help {
                    InlineHelpButton(text: help)
                }
            }
            .frame(width: numericRowLabelWidth, alignment: .leading)

            Spacer(minLength: 8)

            numericValueField(
                value: value,
                prompt: nil,
                unit: nil,
                fieldWidth: numericFieldWidth
            )

            Stepper("", value: value, in: range)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: numericStepperWidth)
        }
    }

    private func numericValueField(
        value: Binding<Int>,
        prompt: String?,
        unit: String?,
        fieldWidth: CGFloat
    ) -> some View {
        HStack(spacing: 0) {
            TextField(
                "",
                value: value,
                format: .number,
                prompt: prompt.map { Text($0).foregroundStyle(.tertiary) }
            )
            .textFieldStyle(.plain)
            .font(.system(.caption, design: .rounded).monospacedDigit())
            .multilineTextAlignment(.trailing)
            .frame(width: fieldWidth)

            if let unit {
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: numericControlHeight)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private func numericValueField(
        value: Binding<Double>,
        prompt: String?,
        unit: String?,
        fieldWidth: CGFloat,
        fractionLength: Int
    ) -> some View {
        HStack(spacing: 0) {
            TextField(
                "",
                value: value,
                format: .number.precision(.fractionLength(fractionLength)),
                prompt: prompt.map { Text($0).foregroundStyle(.tertiary) }
            )
            .textFieldStyle(.plain)
            .font(.system(.caption, design: .rounded).monospacedDigit())
            .multilineTextAlignment(.trailing)
            .frame(width: fieldWidth)

            if let unit {
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: numericControlHeight)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}

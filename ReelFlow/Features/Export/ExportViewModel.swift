import AVFoundation
import Combine
import CoreGraphics
import SwiftUI
import UniformTypeIdentifiers

extension PhotoOrientationStrategy {
    var displayName: String {
        switch self {
        case .followAsset:
            return "按素材方向"
        case .forceLandscape:
            return "强制横图"
        case .forcePortrait:
            return "强制竖图"
        }
    }
}

extension PreflightIssue {
    var ignoreKey: String {
        "\(index)|\(severity.rawValue)|\(fileName)|\(message)"
    }
}

@MainActor
final class ExportViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    struct EntitlementAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    enum EntitlementState: String, Equatable {
        case loading
        case free
        case pro
    }

    static let freePhotoLimit = 20

    enum FileListFilter: String, CaseIterable, Identifiable {
        case all
        case problematic
        case mustFix
        case normal

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return "全部"
            case .problematic:
                return "仅问题"
            case .mustFix:
                return "仅必须修复"
            case .normal:
                return "仅正常"
            }
        }
    }

    enum PreflightIssueFilter: String, CaseIterable, Identifiable {
        case all
        case mustFix
        case review

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return "全部问题"
            case .mustFix:
                return "仅必须修复"
            case .review:
                return "仅建议关注"
            }
        }
    }

    struct FlowStep: Identifiable {
        let id: String
        let title: String
        let done: Bool
    }

    @Published var imageURLs: [URL] = []
    @Published var outputURL: URL?
    @Published var previewImage: CGImage?
    @Published var previewSecond: Double = 0
    @Published var previewStatusMessage: String = "未生成预览"
    @Published var previewErrorMessage: String?
    @Published var failedAssetNames: [String] = []
    @Published var preflightReport: PreflightReport?
    @Published var ignoredPreflightIssueKeys: Set<String> = []
    @Published var skippedAssetNamesFromPreflight: [String] = []
    @Published var fileListFilter: FileListFilter = .all
    @Published var preflightIssueFilter: PreflightIssueFilter = .all
    @Published var config = RenderEditorConfig()
    @Published var audioStatusMessage: String?
    @Published var shutterSoundStatusMessage: String?
    @Published var selectedAudioDuration: TimeInterval?
    @Published var isAudioPreviewPlaying = false
    @Published var isShutterSoundPreviewPlaying = false
    @Published var entitlementAlert: EntitlementAlert?
    @Published var recoveryAdvice: RecoveryAdvice?
    @Published var failureCardCopy: FailureCardCopy?
    @Published var workflow = ExportWorkflowModel()

    let entitlementStateProvider: @MainActor () -> EntitlementState
    let makeEngine: (RenderSettings) -> any RenderingEngineClient
    var exportTask: Task<Void, Never>?
    var previewTask: Task<Void, Never>?
    var lastFailedRequest: ExportRequest?
    var pendingRequestFromPreflight: ExportRequest?
    var pendingPreviewRequest: (urls: [URL], second: Double, useProxySettings: Bool)?
    var lastLogURL: URL?
    var lastSuccessfulOutputURL: URL?
    var autoPreviewRefreshEnabled = true
    var timelinePreviewEnabled = true
    var previewAudioPlayer: AVAudioPlayer?
    var shutterSoundPreviewPlayer: AVAudioPlayer?
    var audioDurationTask: Task<Void, Never>?
    var lastAudioDurationLookupKey = ""
    var hasUserSelectedOutputURL = false

    init(
        entitlementState: @escaping @MainActor () -> EntitlementState = { .free },
        makeEngine: @escaping (RenderSettings) -> any RenderingEngineClient = { settings in
        RenderEngine(settings: settings)
    }
    ) {
        self.entitlementStateProvider = entitlementState
        self.makeEngine = makeEngine
        super.init()
        outputURL = Self.defaultOutputURL()
        hasUserSelectedOutputURL = false
        if let outputURL {
            workflow.setIdleMessage("默认导出路径已设置：\(outputURL.lastPathComponent)（可修改）")
        }
        applyUITestScenarioIfNeeded()
        refreshSelectedAudioDuration(force: true)
    }

    convenience init(
        hasProAccess: @escaping @MainActor () -> Bool,
        makeEngine: @escaping (RenderSettings) -> any RenderingEngineClient = { settings in
            RenderEngine(settings: settings)
        }
    ) {
        self.init(
            entitlementState: { hasProAccess() ? .pro : .free },
            makeEngine: makeEngine
        )
    }

    var isBusy: Bool {
        workflow.isBusy
    }

    var isExporting: Bool {
        workflow.isExporting
    }

    var isPreviewGenerating: Bool {
        workflow.state == .previewing
    }

    var progress: Double {
        workflow.progress
    }

    var statusMessage: String {
        workflow.statusMessage
    }

    var validationMessage: String? {
        invalidSettingsMessage
    }

    var hasFailureCard: Bool {
        workflow.state == .failed && recoveryAdvice != nil && failureCardCopy != nil
    }

    var hasSuccessCard: Bool {
        workflow.state == .succeeded && lastSuccessfulOutputURL != nil
    }

    var latestLogPath: String? {
        lastLogURL?.path
    }

    var latestOutputFilename: String? {
        lastSuccessfulOutputURL?.lastPathComponent
    }

    var latestOutputURL: URL? {
        lastSuccessfulOutputURL
    }

    var canRetryLastExport: Bool {
        !isBusy && lastFailedRequest != nil
    }

    var hasBlockingPreflightIssues: Bool {
        preflightReport?.hasBlockingIssues == true
    }

    var filteredPreflightIssues: [PreflightIssue] {
        guard let report = preflightReport else { return [] }
        let visibleIssues = report.issues.filter { !ignoredPreflightIssueKeys.contains($0.ignoreKey) }
        switch preflightIssueFilter {
        case .all:
            return visibleIssues
        case .mustFix:
            return visibleIssues.filter { $0.severity == .mustFix }
        case .review:
            return visibleIssues.filter { $0.severity == .shouldReview }
        }
    }

    var ignoredIssueCount: Int {
        ignoredPreflightIssueKeys.count
    }

    var ignoredPreflightIssues: [PreflightIssue] {
        guard let report = preflightReport else { return [] }
        return report.issues.filter { ignoredPreflightIssueKeys.contains($0.ignoreKey) }
    }

    var actionAvailability: ExportActionAvailability {
        ExportActionAvailability(
            workflowState: workflow.state,
            hasRetryTask: lastFailedRequest != nil
        )
    }

    var hasSelectedImages: Bool {
        !imageURLs.isEmpty
    }

    var hasOutputPath: Bool {
        outputURL != nil
    }

    var hasPreviewFrame: Bool {
        previewImage != nil
    }

    var canRunPreview: Bool {
        actionAvailability.canGeneratePreview && hasSelectedImages && validationMessage == nil
    }

    var canRunExport: Bool {
        actionAvailability.canStartExport && hasSelectedImages && validationMessage == nil
    }

    var entitlementState: EntitlementState {
        entitlementStateProvider()
    }

    var isEntitlementResolved: Bool {
        entitlementState != .loading
    }

    var hasProAccess: Bool {
        entitlementState == .pro
    }

    var activeWatermark: WatermarkSettings? {
        entitlementState == .free ? .reelFlowFreeTier : nil
    }

    var currentRenderSettings: RenderSettings {
        config.renderSettings.applying(watermark: activeWatermark)
    }

    var photoImportLimit: Int? {
        entitlementState == .free ? Self.freePhotoLimit : nil
    }

    var photoImportSummary: String {
        if let photoImportLimit {
            return "\(imageURLs.count)/\(photoImportLimit) 张"
        }
        return "\(imageURLs.count) 张"
    }

    var remainingPhotoImportSlots: Int? {
        guard let photoImportLimit else { return nil }
        return max(photoImportLimit - imageURLs.count, 0)
    }

    var isNearPhotoImportLimit: Bool {
        guard let photoImportLimit else { return false }
        return imageURLs.count >= max(photoImportLimit - 4, 1) && imageURLs.count < photoImportLimit
    }

    var isAtPhotoImportLimit: Bool {
        guard let photoImportLimit else { return false }
        return imageURLs.count >= photoImportLimit
    }

    var photoImportStatusMessage: String {
        if entitlementState == .loading {
            return "正在检查购买状态…"
        }
        guard let remainingPhotoImportSlots else {
            return "Pro 已解锁：可继续导入更多照片。"
        }
        if isAtPhotoImportLimit {
            return "已到免费版 20 张上限，升级 Pro 可继续添加。"
        }
        if isNearPhotoImportLimit {
            return "还可再导入 \(remainingPhotoImportSlots) 张，升级 Pro 可解锁无限图片导入。"
        }
        return "免费版当前最多支持 20 张照片。"
    }

    var planStatusMessage: String {
        switch entitlementState {
        case .loading:
            return "正在检查购买状态…"
        case .pro:
            return "ReelFlow Pro 已解锁：无限图片导入，导出无水印。"
        case .free:
            return "免费版支持最多 20 张照片，导出会带 Made with ReelFlow 水印。"
        }
    }

    var flowSteps: [FlowStep] {
        [
            FlowStep(id: "select-images", title: "选择图片", done: hasSelectedImages),
            FlowStep(id: "preview", title: "（可选）生成预览", done: hasPreviewFrame || hasSelectedImages),
            FlowStep(id: "export", title: "导出 MP4（必要时选择路径）", done: hasSuccessCard)
        ]
    }

    var selectedAudioFilename: String? {
        let path = config.audioFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    var selectedShutterSoundFilename: String? {
        switch config.shutterSoundSource {
        case .preset:
            return config.shutterSoundPreset.displayName
        case .custom:
            let path = config.shutterSoundCustomFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { return nil }
            return URL(fileURLWithPath: path).lastPathComponent
        }
    }

    var canPreviewAudio: Bool {
        config.audioEnabled && selectedAudioFilename != nil && !isBusy
    }

    var nextActionHint: String {
        if !hasSelectedImages {
            return "下一步：点击左侧“导入图片”或直接拖入素材。"
        }
        if validationMessage != nil {
            return "下一步：先修正参数校验错误，再继续。"
        }
        if !hasPreviewFrame {
            return "可选：点击“生成预览”确认画面；也可直接导出 MP4。"
        }
        if isExporting {
            return "正在导出，请等待完成。"
        }
        return "已就绪：点击顶部“导出 MP4”即可完成首次导出。"
    }

    var orderedImageURLsForDisplay: [URL] {
        let problematic = problematicAssetNameSet
        return imageURLs.sorted { lhs, rhs in
            let lhsProblematic = problematic.contains(lhs.lastPathComponent)
            let rhsProblematic = problematic.contains(rhs.lastPathComponent)
            if lhsProblematic != rhsProblematic {
                return lhsProblematic && !rhsProblematic
            }
            return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }
    }

    var filteredImageURLsForDisplay: [URL] {
        let problematic = problematicAssetNameSet
        let mustFix = mustFixAssetNameSet
        switch fileListFilter {
        case .all:
            return orderedImageURLsForDisplay
        case .problematic:
            return orderedImageURLsForDisplay.filter { problematic.contains($0.lastPathComponent) }
        case .mustFix:
            return orderedImageURLsForDisplay.filter { mustFix.contains($0.lastPathComponent) }
        case .normal:
            return orderedImageURLsForDisplay.filter { !problematic.contains($0.lastPathComponent) }
        }
    }

    var problematicAssetNameSet: Set<String> {
        var names = Set(failedAssetNames)
        if let report = preflightReport {
            for issue in report.issues where !ignoredPreflightIssueKeys.contains(issue.ignoreKey) {
                names.insert(issue.fileName)
            }
        }
        for skipped in skippedAssetNamesFromPreflight {
            names.insert(skipped)
        }
        return names
    }

    var mustFixAssetNameSet: Set<String> {
        guard let report = preflightReport else { return [] }
        return Set(
            report.issues
                .filter { $0.severity == .mustFix && !ignoredPreflightIssueKeys.contains($0.ignoreKey) }
                .map(\.fileName)
        )
    }

    func preflightIssueTags(for fileName: String) -> [String] {
        guard let report = preflightReport else { return [] }
        let issues = report.issues.filter {
            $0.fileName == fileName && !ignoredPreflightIssueKeys.contains($0.ignoreKey)
        }
        guard !issues.isEmpty else { return [] }

        var tags: [String] = []
        if issues.contains(where: { $0.severity == .mustFix }) {
            tags.append("必须修复")
        }
        if issues.contains(where: { $0.severity == .shouldReview }) {
            tags.append("建议关注")
        }
        return tags
    }

    var configSignature: String {
        [
            "\(config.outputWidth)",
            "\(config.outputHeight)",
            "\(config.fps)",
            String(format: "%.3f", config.imageDuration),
            String(format: "%.3f", config.transitionDuration),
            config.orientationStrategy.rawValue,
            config.frameStylePreset.rawValue,
            String(format: "%.3f", config.canvasBackgroundGray),
            String(format: "%.3f", config.canvasPaperWhite),
            String(format: "%.3f", config.canvasStrokeGray),
            String(format: "%.3f", config.canvasTextGray),
            String(format: "%.2f", config.horizontalMargin),
            String(format: "%.2f", config.topMargin),
            String(format: "%.2f", config.bottomMargin),
            String(format: "%.2f", config.innerPadding),
            config.plateEnabled ? "1" : "0",
            String(format: "%.2f", config.plateHeight),
            String(format: "%.2f", config.plateBaselineOffset),
            String(format: "%.2f", config.plateFontSize),
            config.platePlacement.rawValue,
            config.plateEditorMode.rawValue,
            config.plateSimpleElements.map {
                "\($0.key.rawValue):\($0.enabled ? 1 : 0):\($0.prefix)"
            }.joined(separator: ","),
            config.plateTemplateText,
            config.enableCrossfade ? "1" : "0",
            String(format: "%.3f", config.transitionDipDuration),
            config.enableKenBurns ? "1" : "0",
            config.kenBurnsIntensity.rawValue,
            "\(config.prefetchRadius)",
            "\(config.prefetchMaxConcurrent)",
            config.audioEnabled ? "1" : "0",
            config.audioFilePath,
            String(format: "%.3f", config.audioVolume),
            config.audioLoopEnabled ? "1" : "0",
            entitlementState.rawValue
        ].joined(separator: "|")
    }

    func presentFreeTierImportLimitAlert(incomingCount: Int, resultingCount: Int, replacingExisting: Bool) {
        let actionText = replacingExisting ? "导入这批素材" : "继续添加这些素材"
        let title = "免费版最多支持 20 张照片"
        let message = "\(actionText)后会达到 \(resultingCount) 张，因此本次不会导入任何新素材。升级 ReelFlow Pro 可解锁无限图片导入，并移除导出水印。"
        entitlementAlert = EntitlementAlert(title: title, message: message)
        workflow.setIdleMessage("免费版最多支持 20 张照片；本次有 \(incomingCount) 张未导入。")
    }

}

struct ExportRequest {
    let imageURLs: [URL]
    let outputURL: URL
    let settings: RenderSettings
}

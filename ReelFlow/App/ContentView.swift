import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    private struct SuccessSheetContext: Identifiable {
        let id = UUID()
        let outputURL: URL
        let logURL: URL?
    }

    enum LayoutMode {
        case app
        case workspaceOnly
        case sidebarOnly
        case centerOnly
        case settingsOnly
    }

    private enum CenterPreviewTab: String, CaseIterable, Identifiable {
        case singleFrame
        case videoTimeline

        var id: String { rawValue }

        var title: String {
            switch self {
            case .singleFrame: return String(localized: "单帧预览")
            case .videoTimeline: return String(localized: "时间轴预览")
            }
        }
    }

    private enum SettingsTab: String, CaseIterable, Identifiable {
        case simple
        case advanced

        var id: String { rawValue }

        var title: String {
            switch self {
            case .simple: return String(localized: "简单")
            case .advanced: return String(localized: "高级")
            }
        }
    }

    @StateObject private var viewModel: ExportViewModel
    @ObservedObject private var purchaseStore: PurchaseStore
    private let layoutMode: LayoutMode
    @State private var centerPreviewTab: CenterPreviewTab = .singleFrame
    @State private var settingsTab: SettingsTab = .simple
    @State private var selectedAssetURL: URL?
    @State private var selectedAssetURLs: Set<URL> = []
    @State private var singlePreviewDebounceTask: Task<Void, Never>?
    @State private var isAssetDropTarget = false
    @State private var isAudioDropTarget = false
    @State private var draggingAssetURL: URL?
    @State private var expandedPreflightIssueKeys: Set<String> = []
    @State private var ignoredIssuesExpanded = false
    @State private var ignoredIssueSearchText = ""
    @State private var preflightOnlyPending = true
    @State private var preflightPrioritizeMustFix = true
    @State private var preflightSecondaryActionsExpanded = false
    @State private var splitColumnVisibility: NavigationSplitViewVisibility = .all
    @State private var successSheetContext: SuccessSheetContext?
    @State private var feedbackDismissTask: Task<Void, Never>?

    @MainActor
    init() {
        let purchaseStore = PurchaseStore()
        _purchaseStore = ObservedObject(wrappedValue: purchaseStore)
        _viewModel = StateObject(
            wrappedValue: ExportViewModel(
                entitlementState: { Self.mapEntitlementState(purchaseStore.entitlementState) }
            )
        )
        self.layoutMode = .app
    }

    @MainActor
    init(purchaseStore: PurchaseStore) {
        _purchaseStore = ObservedObject(wrappedValue: purchaseStore)
        _viewModel = StateObject(
            wrappedValue: ExportViewModel(
                entitlementState: { Self.mapEntitlementState(purchaseStore.entitlementState) }
            )
        )
        self.layoutMode = .app
    }

    @MainActor
    fileprivate init(viewModel: ExportViewModel, layoutMode: LayoutMode, purchaseStore: PurchaseStore) {
        _purchaseStore = ObservedObject(wrappedValue: purchaseStore)
        _viewModel = StateObject(wrappedValue: viewModel)
        self.layoutMode = layoutMode
    }

    var body: some View {
        rootContent
            .sheet(item: $successSheetContext) { context in
                ExportSuccessSheet(
                    filename: context.outputURL.lastPathComponent,
                    directoryPath: (context.outputURL.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath,
                    hasLog: context.logURL != nil,
                    onOpenOutputFile: { viewModel.openLatestOutputFile() },
                    onOpenOutputDirectory: { viewModel.openLatestOutputDirectory() },
                    onOpenLog: { viewModel.openLatestLog() }
                )
            }
            .onAppear {
                applyUITestOverridesIfNeeded()
                applyPreviewModePolicy(for: centerPreviewTab)
                presentSuccessSheetIfNeeded()
                if centerPreviewTab == .singleFrame {
                    scheduleSingleFramePreview()
                }
            }
            .alert(item: $viewModel.entitlementAlert) { alert in
                switch purchaseStore.entitlementState {
                case .pro:
                    Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        dismissButton: .default(Text("知道了"))
                    )
                case .free:
                    Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        primaryButton: .default(Text("升级 Pro")) {
                            purchaseStore.purchasePro()
                        },
                        secondaryButton: .cancel(Text("稍后"))
                    )
                case .loading:
                    Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        dismissButton: .default(Text("知道了"))
                    )
                }
            }
            .onChange(of: viewModel.configSignature) { _, _ in
                viewModel.handleConfigChanged()
                if centerPreviewTab == .singleFrame {
                    scheduleSingleFramePreview()
                }
            }
            .onChange(of: purchaseStore.entitlementState) { _, _ in
                if centerPreviewTab == .singleFrame {
                    scheduleSingleFramePreview()
                } else if viewModel.hasSelectedImages {
                    viewModel.generatePreview()
                }
            }
            .onChange(of: purchaseStore.feedback) { _, feedback in
                schedulePurchaseFeedbackDismiss(for: feedback)
            }
            .onChange(of: viewModel.imageURLs) { _, urls in
                guard !urls.isEmpty else {
                    selectedAssetURL = nil
                    selectedAssetURLs = []
                    if centerPreviewTab == .singleFrame {
                        scheduleSingleFramePreview()
                    }
                    return
                }
                selectedAssetURLs = selectedAssetURLs.intersection(Set(urls))
                if let selectedAssetURL, urls.contains(selectedAssetURL) {
                    if centerPreviewTab == .singleFrame {
                        scheduleSingleFramePreview()
                    }
                    return
                }
                selectedAssetURL = urls.first
                if let first = urls.first {
                    selectedAssetURLs = [first]
                }
            }
            .onChange(of: selectedAssetURL) { _, _ in
                if centerPreviewTab == .singleFrame {
                    scheduleSingleFramePreview()
                }
            }
            .onChange(of: selectedAssetURLs) { _, urls in
                guard !urls.isEmpty else { return }
                if let selectedAssetURL, urls.contains(selectedAssetURL) {
                    return
                }
                selectedAssetURL = viewModel.imageURLs.first(where: { urls.contains($0) })
            }
            .onChange(of: centerPreviewTab) { _, tab in
                applyPreviewModePolicy(for: tab)
                if tab == .singleFrame {
                    scheduleSingleFramePreview()
                } else {
                    viewModel.generatePreview()
                }
            }
            .onChange(of: viewModel.statusMessage) { _, _ in
                presentSuccessSheetIfNeeded()
            }
            .onDisappear {
                feedbackDismissTask?.cancel()
                viewModel.stopAudioPreview()
                viewModel.stopShutterSoundPreview()
            }
    }

    @ViewBuilder
    private var rootContent: some View {
        switch layoutMode {
        case .app:
            NavigationSplitView(columnVisibility: $splitColumnVisibility) {
                sidebarAssetColumn
                    .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 360)
            } detail: {
                workspaceDetailSplit
                    .navigationSplitViewColumnWidth(min: 860, ideal: 1040)
            }
            .navigationSplitViewStyle(.balanced)
            .navigationTitle("ReelFlow")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if let primary = firstRunPrimaryAction {
                        Button(primary.title) { primary.handler() }
                            .accessibilityIdentifier("toolbar_primary_action")
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .disabled(isToolbarPrimaryActionDisabled(for: primary.kind))
                    }
                    if viewModel.isExporting {
                        Button("取消导出") { viewModel.cancelExport() }
                            .accessibilityIdentifier("primary_cancel")
                            .disabled(!viewModel.actionAvailability.canCancelExport)
                    }
                }

                ToolbarItem(placement: .automatic) {
                    Menu("更多") {
                        Button("导入模板") { viewModel.importTemplate() }
                            .accessibilityIdentifier("secondary_import_template")
                            .disabled(!viewModel.actionAvailability.canImportTemplate)
                        Button("保存模板") { viewModel.exportTemplate() }
                            .accessibilityIdentifier("secondary_export_template")
                            .disabled(!viewModel.hasSelectedImages || !viewModel.actionAvailability.canSaveTemplate)
                        Divider()
                        Button("重试上次导出") { viewModel.retryLastExport() }
                            .accessibilityIdentifier("secondary_retry_export")
                            .disabled(!viewModel.hasSelectedImages || !viewModel.actionAvailability.canRetryExport)
                        Button("导出排障包") { viewModel.exportDiagnosticsBundle() }
                            .accessibilityIdentifier("secondary_export_diagnostics")
                            .disabled(!viewModel.hasSelectedImages || viewModel.isBusy)
                        #if DEBUG
                        Divider()
                        Button("模拟导出失败") { viewModel.simulateExportFailure() }
                            .disabled(viewModel.isBusy)
                        #endif
                    }
                    .accessibilityIdentifier("toolbar_more_menu")
                }
            }
        case .workspaceOnly:
            workspaceDetailSplit
                .frame(minWidth: 980, minHeight: 720)
        case .sidebarOnly:
            sidebarAssetColumn
                .frame(minWidth: 300, minHeight: 720)
        case .centerOnly:
            centerPreviewColumn
                .frame(minWidth: 760, minHeight: 720)
        case .settingsOnly:
            rightSettingsColumn
                .frame(minWidth: 380, minHeight: 720)
        }
    }

    private var sidebarAssetColumn: some View {
        AssetSidebarPanel(
            viewModel: viewModel,
            selectedAssetURL: $selectedAssetURL,
            selectedAssetURLs: $selectedAssetURLs,
            isAssetDropTarget: $isAssetDropTarget,
            draggingAssetURL: $draggingAssetURL,
            planPresentationState: sidebarPlanPresentationState
        )
    }

    private var sidebarPlanPresentationState: AssetSidebarPanel.PlanPresentationState {
        switch purchaseStore.entitlementState {
        case .loading:
            return .loading
        case .free:
            return .free
        case .pro:
            return .pro
        }
    }

    private static func mapEntitlementState(_ state: PurchaseStore.EntitlementState) -> ExportViewModel.EntitlementState {
        switch state {
        case .loading:
            return .loading
        case .free:
            return .free
        case .pro:
            return .pro
        }
    }

    private var workspaceDetailSplit: some View {
        HSplitView {
            centerPreviewColumn
                .frame(minWidth: 520, idealWidth: 680, maxWidth: .infinity)
            rightSettingsColumn
                .frame(minWidth: 300, idealWidth: 360, maxWidth: 460)
        }
    }

    private var centerPreviewColumn: some View {
        Group {
            if shouldUseFullHeightEmptyState {
                VStack(alignment: .leading, spacing: 14) {
                    if let validationMessage = viewModel.validationMessage {
                        Text("参数校验: \(validationMessage)")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("settings_validation_message")
                    }

                    emptyPreviewPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let validationMessage = viewModel.validationMessage {
                            Text("参数校验: \(validationMessage)")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .accessibilityIdentifier("settings_validation_message")
                        }

                        if viewModel.hasSelectedImages {
                            HStack(alignment: .top, spacing: 16) {
                                contentSummaryHeader
                                Spacer(minLength: 0)
                                Picker("", selection: $centerPreviewTab) {
                                    ForEach(CenterPreviewTab.allCases) { tab in
                                        Text(tab.title).tag(tab)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 220)
                            }

                            if centerPreviewTab == .singleFrame {
                                previewPanel
                            } else {
                                videoPreviewPanel
                            }

                            previewOutputBar
                        } else {
                            emptyPreviewPanel
                        }

                        workflowPanel
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var rightSettingsColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            planStatusBanner
            if let feedback = purchaseStore.feedback {
                purchaseFeedbackBanner(feedback)
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer(minLength: 0)
                    Picker("模式", selection: $settingsTab) {
                        ForEach(SettingsTab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 140)
                    .disabled(viewModel.isBusy)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
            settingsPanel
        }
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor),
                    Color(nsColor: .windowBackgroundColor)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var planStatusBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(planTitle)
                        .font(.callout.weight(.semibold))
                    Text(planBenefitSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if purchaseStore.entitlementState == .free {
                    HStack(spacing: 8) {
                        Button(purchaseStore.purchaseButtonTitle) {
                            purchaseStore.purchasePro()
                        }
                        .accessibilityIdentifier("plan_upgrade_button")
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(purchaseStore.isBusy)

                        Button("恢复购买") {
                            purchaseStore.restorePurchases()
                        }
                        .accessibilityIdentifier("plan_restore_button")
                        .controlSize(.small)
                        .disabled(purchaseStore.isBusy)
                    }
                }
            }

            Divider()

            if purchaseStore.entitlementState == .loading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在同步购买状态")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if purchaseStore.entitlementState == .pro {
                Label("已解锁无限图片导入与无水印导出", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Label(quotaSummaryText, systemImage: "photo.on.rectangle.angled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            planStatusBackground
        )
        .accessibilityIdentifier("plan_status_banner")
    }

    private var planTitle: String {
        switch purchaseStore.entitlementState {
        case .loading:
            return String(localized: "正在检查购买状态")
        case .free:
            return String(localized: "免费版")
        case .pro:
            return String(localized: "ReelFlow Pro")
        }
    }

    private var planBenefitSummary: String {
        switch purchaseStore.entitlementState {
        case .loading:
            return String(localized: "稍后会根据你的购买记录自动更新。")
        case .pro:
            return String(localized: "无限图片导入 · 无水印导出")
        case .free:
            return String(localized: "最多 20 张照片 · 导出带水印")
        }
    }

    private var planStatusBackground: Color {
        switch purchaseStore.entitlementState {
        case .loading:
            return Color.secondary.opacity(0.04)
        case .free:
            return Color.secondary.opacity(0.05)
        case .pro:
            return Color.green.opacity(0.06)
        }
    }

    private var quotaSummaryText: String {
        if viewModel.isAtPhotoImportLimit {
            return String(localized: "当前素材 \(viewModel.photoImportSummary)，已到上限")
        }
        if viewModel.isNearPhotoImportLimit, let remaining = viewModel.remainingPhotoImportSlots {
            return String(localized: "当前素材 \(viewModel.photoImportSummary)，还可导入 \(remaining) 张")
        }
        return String(localized: "当前素材 \(viewModel.photoImportSummary)")
    }

    private func purchaseFeedbackBanner(_ feedback: PurchaseStore.Feedback) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName(for: feedback.tone))
                .font(.subheadline)
                .foregroundStyle(color(for: feedback.tone))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(feedback.title)
                    .font(.callout.weight(.semibold))
                Text(feedback.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                purchaseStore.clearFeedback()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(color(for: feedback.tone).opacity(0.10))
        .accessibilityIdentifier("purchase_feedback_banner")
    }

    @ViewBuilder
    private var contentSummaryHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Text(previewSummaryTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                previewSummaryStatus
            }

            Text(settingsSummaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var previewSummaryStatus: some View {
        if let errorMessage = viewModel.previewErrorMessage {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
                .help("预览错误: \(errorMessage)")
        } else if viewModel.isPreviewGenerating {
            ProgressView()
                .controlSize(.small)
                .help("正在生成预览…")
        } else {
            Image(systemName: "checkmark.circle")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .help(viewModel.previewStatusMessage)
        }
    }

    private var settingsSummaryText: String {
        let durationText = String(format: "%.2f", viewModel.previewMaxSecond)
        return String(
            localized: "预计 \(durationText)s · \(viewModel.config.outputWidth)×\(viewModel.config.outputHeight) · \(viewModel.config.fps) FPS"
        )
    }

    private var previewSummaryTitle: String {
        String(localized: "\(viewModel.imageURLs.count) 张图片已就绪")
    }


    private var settingsAudioSummaryMessage: String? {
        guard viewModel.config.audioEnabled else { return nil }
        guard let audioDuration = viewModel.selectedAudioDuration else {
            return String(localized: "音频时长尚未读取，导出前会再次校验。")
        }
        let videoDuration = viewModel.previewMaxSecond
        let audioText = String(format: "%.2f", audioDuration)
        let videoText = String(format: "%.2f", videoDuration)
        if viewModel.config.audioLoopEnabled {
            return String(localized: "音频 \(audioText)s，将循环覆盖约 \(videoText)s 视频。")
        }
        if audioDuration >= videoDuration {
            return String(localized: "音频 \(audioText)s，导出时会截断到视频时长 \(videoText)s。")
        }
        return String(localized: "音频 \(audioText)s，结束后视频仍会继续到 \(videoText)s。")
    }

    private var workflowPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.hasSelectedImages || viewModel.hasFailureCard || viewModel.hasSuccessCard {
                exportStatusPanel
            }

            if purchaseStore.entitlementState == .free, viewModel.hasSelectedImages {
                freeTierExportNoticePanel
            }

            if viewModel.hasSelectedImages, viewModel.outputURL == nil {
                outputPathHintPanel
            }

            if let report = viewModel.preflightReport, !report.issues.isEmpty {
                PreflightPanel(
                    viewModel: viewModel,
                    compactIssues: preflightDisplayIssues(report: report),
                    allDisplayIssues: preflightIssuesForDisplay(report: report),
                    filteredIgnoredIssues: filteredIgnoredIssues,
                    selectedAssetURL: selectedAssetURL,
                    onSelectAsset: { url in
                        if viewModel.fileListFilter != .all {
                            viewModel.fileListFilter = .all
                        }
                        selectedAssetURL = url
                        selectedAssetURLs = [url]
                    },
                    expansionBindingForKey: { key in preflightIssueExpandedBinding(for: key) },
                    preflightSecondaryActionsExpanded: $preflightSecondaryActionsExpanded,
                    preflightOnlyPending: $preflightOnlyPending,
                    preflightPrioritizeMustFix: $preflightPrioritizeMustFix,
                    expandedPreflightIssueKeys: $expandedPreflightIssueKeys,
                    ignoredIssuesExpanded: $ignoredIssuesExpanded,
                    ignoredIssueSearchText: $ignoredIssueSearchText
                )
            }
        }
        .textSelection(.enabled)
    }

    private var freeTierExportNoticePanel: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "watermark")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text("免费版导出将带水印")
                    .font(.callout.weight(.semibold))
                Text("当前预览与导出都会显示较轻的 Made with ReelFlow 标记。升级 Pro 后会自动移除。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("free_tier_export_notice")
    }

    private func schedulePurchaseFeedbackDismiss(for feedback: PurchaseStore.Feedback?) {
        feedbackDismissTask?.cancel()
        guard feedback != nil else { return }

        feedbackDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled {
                purchaseStore.clearFeedback()
            }
        }
    }

    private func color(for tone: PurchaseStore.Feedback.Tone) -> Color {
        switch tone {
        case .success:
            return .green
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    private func iconName(for tone: PurchaseStore.Feedback.Tone) -> String {
        switch tone {
        case .success:
            return "checkmark.circle.fill"
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    private var outputPathHintPanel: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.badge.questionmark")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("未设置导出位置")
                    .font(.callout.weight(.semibold))
                Text("导出前请先选择保存位置。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
            Button("设置位置") { viewModel.chooseOutput() }
                .controlSize(.small)
                .disabled(!viewModel.actionAvailability.canSelectOutput)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var emptyPreviewPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("从左侧开始，先导入图片")
                    .font(.headline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.08), in: Capsule())

            Text("导入后，这里会显示预览与导出状态。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(minHeight: 320)
    }

    private var exportStatusPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.hasFailureCard, let copy = viewModel.failureCardCopy {
                FailureStatusCard(
                    copy: copy,
                    isBusy: viewModel.isBusy,
                    onPrimaryAction: { viewModel.performRecoveryAction() },
                    onOpenLog: { viewModel.openLatestLog() }
                )

                if !viewModel.failedAssetNames.isEmpty {
                    FailedAssetsPanel(
                        names: failedAssetNamesPreview,
                        hiddenCount: failedAssetHiddenCount
                    )
                }
            } else if viewModel.validationMessage != nil {
                WorkflowOverviewPanel(
                    statusMessage: viewModel.statusMessage,
                    nextActionHint: viewModel.nextActionHint,
                    firstRunPrimaryActionKind: firstRunPrimaryAction?.kind,
                    firstRunPrimaryActionTitle: firstRunPrimaryAction?.title,
                    firstRunPrimaryActionSubtitle: firstRunPrimaryActionSubtitle,
                    isBusy: viewModel.isBusy,
                    onFirstRunPrimaryAction: { firstRunPrimaryAction?.handler() }
                )
            } else {
                HStack(spacing: 10) {
                    Spacer(minLength: 0)

                    if let primary = firstRunPrimaryAction, !showsIntegratedPreviewPrimaryAction {
                        WorkflowPrimaryActionButton(
                            kind: primary.kind,
                            title: primary.title,
                            subtitle: firstRunPrimaryActionSubtitle,
                            isBusy: viewModel.isBusy,
                            accessibilityIdentifier: "workflow_primary_action",
                            action: primary.handler
                        )
                            .disabled(viewModel.isBusy)
                    }
                }
            }
        }
    }

    private var firstRunPrimaryAction: (kind: WorkflowPrimaryActionKind, title: String, handler: () -> Void)? {
        if !viewModel.hasSelectedImages {
            return (.importImages, String(localized: "导入图片"), { viewModel.chooseImages() })
        }
        if viewModel.validationMessage != nil {
            return nil
        }
        if viewModel.hasSuccessCard {
            return (.exportAgain, String(localized: "再次导出"), { viewModel.export() })
        }
        if !viewModel.hasPreviewFrame {
            return (.generatePreview, String(localized: "生成预览"), {
                if centerPreviewTab == .singleFrame, let selected = selectedAssetForPreview {
                    viewModel.generatePreviewForSelectedAsset(selected)
                } else {
                    viewModel.generatePreview()
                }
            })
        }
        return (.exportMP4, String(localized: "导出 MP4"), { viewModel.export() })
    }

    private var firstRunPrimaryActionSubtitle: String? {
        guard let primary = firstRunPrimaryAction else { return nil }
        switch primary.kind {
        case .exportMP4:
            return viewModel.outputURL == nil ? String(localized: "请先选择导出路径") : nil
        case .exportAgain:
            return viewModel.outputURL == nil ? String(localized: "请先选择导出路径") : nil
        case .importImages:
            return String(localized: "从本地选择素材，开始生成视频")
        case .generatePreview:
            return String(localized: "先确认画面效果，再决定是否导出")
        default:
            return nil
        }
    }

    private func isToolbarPrimaryActionDisabled(for kind: WorkflowPrimaryActionKind) -> Bool {
        switch kind {
        case .exportMP4, .exportAgain:
            return !viewModel.canRunExport
        case .generatePreview:
            return !viewModel.canRunPreview
        case .importImages:
            return viewModel.isBusy
        default:
            return viewModel.isBusy
        }
    }

    private var showsIntegratedPreviewPrimaryAction: Bool {
        guard viewModel.outputURL != nil else { return false }
        guard viewModel.validationMessage == nil else { return false }
        return !viewModel.hasFailureCard
    }

    private func isIntegratedPreviewPrimaryActionDisabled(for kind: WorkflowPrimaryActionKind) -> Bool {
        isToolbarPrimaryActionDisabled(for: kind)
    }

    private func previewActionSummaryTitle(for kind: WorkflowPrimaryActionKind) -> String? {
        if viewModel.isExporting {
            return String(localized: "正在导出")
        }
        switch kind {
        case .generatePreview:
            return String(localized: "当前设置已更新，可先生成预览。")
        case .exportAgain:
            return String(localized: "可以沿用当前设置再次导出。")
        default:
            return nil
        }
    }

    @ViewBuilder
    private var previewOutputBar: some View {
        if viewModel.hasSelectedImages, previewOutputDirectoryURL != nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "folder.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("导出目录")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .center, spacing: 6) {
                            Text(previewOutputDirectoryText)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)

                            Button {
                                viewModel.openLatestOutputDirectory()
                            } label: {
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .help("打开导出文件夹")
                            .accessibilityLabel("打开导出文件夹")
                        }
                    }

                    Spacer(minLength: 0)

                    Button("设置位置") { viewModel.chooseOutput() }
                        .controlSize(.small)
                        .disabled(!viewModel.actionAvailability.canSelectOutput)
                }

                if let primary = firstRunPrimaryAction, showsIntegratedPreviewPrimaryAction {
                    HStack(alignment: .center, spacing: 12) {
                        if let title = previewActionSummaryTitle(for: primary.kind) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(.primary)
                                if let subtitle = previewActionSubtitle(for: primary.kind) {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer(minLength: 0)

                        if viewModel.isExporting {
                            Button("取消导出") { viewModel.cancelExport() }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                                .accessibilityIdentifier("preview_output_cancel_action")
                                .disabled(!viewModel.actionAvailability.canCancelExport)
                        } else {
                            WorkflowPrimaryActionButton(
                                kind: primary.kind,
                                title: primary.title,
                                subtitle: nil,
                                isBusy: viewModel.isBusy,
                                accessibilityIdentifier: "preview_output_primary_action",
                                action: primary.handler
                            )
                            .disabled(isIntegratedPreviewPrimaryActionDisabled(for: primary.kind))
                        }
                    }
                }

                if viewModel.isExporting {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 8) {
                            Text("导出进度")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)

                            Spacer(minLength: 0)

                            Text(exportProgressText)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        ProgressView(value: viewModel.progress)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var previewOutputDirectoryURL: URL? {
        viewModel.outputURL?.deletingLastPathComponent()
    }

    private var previewOutputDirectoryText: String {
        guard let directoryURL = previewOutputDirectoryURL else { return "" }
        return (directoryURL.path as NSString).abbreviatingWithTildeInPath
    }

    private var exportProgressText: String {
        let progress = min(max(viewModel.progress, 0), 1)
        return "\(Int((progress * 100).rounded()))%"
    }

    private func previewActionSubtitle(for kind: WorkflowPrimaryActionKind) -> String? {
        if viewModel.isExporting {
            return String(localized: "导出期间预览与输出设置暂时锁定。")
        }
        return nil
    }

    private func presentSuccessSheetIfNeeded() {
        guard viewModel.hasSuccessCard else { return }
        guard let outputURL = viewModel.latestOutputURL ?? viewModel.outputURL else { return }
        if successSheetContext?.outputURL == outputURL {
            return
        }
        successSheetContext = SuccessSheetContext(
            outputURL: outputURL,
            logURL: viewModel.lastLogURL
        )
    }

    private func preflightIssueExpandedBinding(for key: String) -> Binding<Bool> {
        Binding(
            get: { expandedPreflightIssueKeys.contains(key) },
            set: { newValue in
                if newValue {
                    expandedPreflightIssueKeys.insert(key)
                } else {
                    expandedPreflightIssueKeys.remove(key)
                }
            }
        )
    }

    private var failedAssetNamesPreview: [String] {
        Array(viewModel.failedAssetNames.prefix(3))
    }

    private var failedAssetHiddenCount: Int {
        max(0, viewModel.failedAssetNames.count - failedAssetNamesPreview.count)
    }

    private func preflightIssuesForDisplay(report: PreflightReport) -> [PreflightIssue] {
        var issues = report.issues
        if preflightOnlyPending {
            issues = issues.filter { !viewModel.isIssueIgnored($0) }
        }
        if viewModel.preflightIssueFilter == .mustFix {
            issues = issues.filter { $0.severity == .mustFix }
        } else if viewModel.preflightIssueFilter == .review {
            issues = issues.filter { $0.severity == .shouldReview }
        }
        if preflightPrioritizeMustFix {
            issues.sort { lhs, rhs in
                if lhs.severity != rhs.severity {
                    return lhs.severity == .mustFix
                }
                return lhs.index < rhs.index
            }
        }
        return issues
    }

    private func preflightDisplayIssues(report: PreflightReport) -> [PreflightIssue] {
        Array(preflightIssuesForDisplay(report: report).prefix(6))
    }

    private var filteredIgnoredIssues: [PreflightIssue] {
        viewModel.ignoredPreflightIssues.filter { issue in
            ignoredIssueSearchText.isEmpty || issue.fileName.localizedCaseInsensitiveContains(ignoredIssueSearchText)
        }
    }

    private var selectedAssetForPreview: URL? {
        if let selectedAssetURL, viewModel.imageURLs.contains(selectedAssetURL) {
            return selectedAssetURL
        }
        return viewModel.imageURLs.first
    }

    private var shouldUseFullHeightEmptyState: Bool {
        !viewModel.hasSelectedImages
            && !viewModel.hasFailureCard
            && !viewModel.hasSuccessCard
            && (viewModel.preflightReport?.issues.isEmpty ?? true)
    }

    private func scheduleSingleFramePreview() {
        guard !viewModel.isBusy else { return }
        guard viewModel.validationMessage == nil else { return }
        guard let selected = selectedAssetForPreview else { return }

        singlePreviewDebounceTask?.cancel()
        singlePreviewDebounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: 120_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                viewModel.generatePreviewForSelectedAsset(selected)
            }
        }
    }

    private func applyPreviewModePolicy(for tab: CenterPreviewTab) {
        switch tab {
        case .singleFrame:
            viewModel.setTimelinePreviewEnabled(false)
            viewModel.setAutoPreviewRefreshEnabled(false)
        case .videoTimeline:
            viewModel.setTimelinePreviewEnabled(true)
            viewModel.setAutoPreviewRefreshEnabled(true)
        }
    }

    private func applyUITestOverridesIfNeeded() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-ui-test-scenario"), arguments.indices.contains(flagIndex + 1) else {
            return
        }
        if arguments[flagIndex + 1] == "preflight_navigation" {
            preflightSecondaryActionsExpanded = true
        }
        #endif
    }

    private var previewPanel: some View {
        SingleFramePreviewPanel(viewModel: viewModel)
    }

    private var videoPreviewPanel: some View {
        let videoDuration = max(viewModel.previewMaxSecond, 0)
        let settings = viewModel.currentRenderSettings
        let timeline = TimelineEngine(
            itemCount: max(viewModel.imageURLs.count, 1),
            imageDuration: settings.imageDuration,
            transitionDuration: settings.effectiveTransitionDuration,
            transitionDipDuration: settings.transitionDipDuration
        )
        let audioSegments = audioTimelineSegments(
            videoDuration: videoDuration,
            audioDuration: viewModel.selectedAudioDuration,
            loopEnabled: viewModel.config.audioLoopEnabled
        )
        return VideoTimelinePreviewPanel(
            viewModel: viewModel,
            audioSegments: audioSegments,
            imageSegmentStarts: timeline.clips.map(\.start)
        )
    }

    private var settingsPanel: some View {
        Group {
            if settingsTab == .simple {
                SimpleSettingsPanel(
                    viewModel: viewModel,
                    isAudioDropTarget: $isAudioDropTarget,
                    onAudioDrop: { providers in
                        handleAudioDrop(providers: providers)
                    }
                )
            } else {
                AdvancedSettingsPanel(
                    viewModel: viewModel,
                    isAudioDropTarget: $isAudioDropTarget,
                    onAudioDrop: { providers in
                        handleAudioDrop(providers: providers)
                    }
                )
            }
        }
    }

    private func handleAudioDrop(providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else { return false }

        let lock = NSLock()
        let group = DispatchGroup()
        var dropped: [URL] = []

        for provider in fileProviders {
            group.enter()
            provider.loadObject(ofClass: NSURL.self) { item, _ in
                defer { group.leave() }
                guard let item = item as? URL else { return }
                lock.lock()
                dropped.append(item)
                lock.unlock()
            }
        }

        group.notify(queue: .main) {
            _ = viewModel.importDroppedAudioTrack(dropped)
        }

        return true
    }

    private func audioTimelineSegments(
        videoDuration: Double,
        audioDuration: Double?,
        loopEnabled: Bool
    ) -> [(start: Double, end: Double)] {
        guard videoDuration > 0, let audioDuration, audioDuration > 0 else { return [] }
        if !loopEnabled {
            return [(0, min(videoDuration, audioDuration))]
        }

        var segments: [(start: Double, end: Double)] = []
        var cursor: Double = 0
        while cursor < videoDuration {
            let end = min(videoDuration, cursor + audioDuration)
            segments.append((cursor, end))
            if end <= cursor { break }
            cursor = end
        }
        return segments
    }
}

#Preview("App") {
    ContentView(purchaseStore: PurchaseStore(mode: .preview(hasProAccess: false)))
}

#Preview("Workspace") {
    ContentView(
        viewModel: ContentView.makeWorkspacePreviewViewModel(),
        layoutMode: .workspaceOnly,
        purchaseStore: PurchaseStore(mode: .preview(hasProAccess: false))
    )
}

#Preview("Sidebar") {
    ContentView(
        viewModel: ContentView.makeWorkspacePreviewViewModel(),
        layoutMode: .sidebarOnly,
        purchaseStore: PurchaseStore(mode: .preview(hasProAccess: false))
    )
}

#Preview("Center") {
    ContentView(
        viewModel: ContentView.makeWorkspacePreviewViewModel(),
        layoutMode: .centerOnly,
        purchaseStore: PurchaseStore(mode: .preview(hasProAccess: false))
    )
}

#Preview("Settings") {
    ContentView(
        viewModel: ContentView.makeWorkspacePreviewViewModel(),
        layoutMode: .settingsOnly,
        purchaseStore: PurchaseStore(mode: .preview(hasProAccess: false))
    )
}

private extension ContentView {
    static func makeWorkspacePreviewViewModel() -> ExportViewModel {
        let viewModel = ExportViewModel(hasProAccess: { false })
        viewModel.imageURLs = [
            URL(fileURLWithPath: "/tmp/preview-a.jpg"),
            URL(fileURLWithPath: "/tmp/preview-b.jpg"),
            URL(fileURLWithPath: "/tmp/preview-c.jpg")
        ]
        viewModel.outputURL = URL(fileURLWithPath: "/tmp/ReelFlow-Preview.mp4")
        viewModel.selectedAudioDuration = 18.4
        viewModel.config.audioEnabled = true
        viewModel.config.audioLoopEnabled = true
        viewModel.config.audioFilePath = "/tmp/preview-bgm.m4a"
        viewModel.previewImage = PlaceholderImageFactory.makeSolidImage(size: CGSize(width: 1440, height: 900))
        viewModel.previewStatusMessage = "预览已更新 (0.00s)"
        viewModel.workflow.setIdleMessage("已就绪，可直接导出 MP4。")
        return viewModel
    }
}

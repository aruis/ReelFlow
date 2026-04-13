import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension ContentView {
    enum PreviewRefreshMode {
        case debounced
        case immediate
    }

    enum PreviewRefreshReason: String {
        case onAppear
        case configChanged
        case entitlementChanged
        case imageURLsChanged
        case selectedAssetChanged
        case centerPreviewTabChanged
        case manualPrimaryAction
    }

    var sidebarAssetColumn: some View {
        AssetSidebarPanel(
            viewModel: viewModel,
            selectedAssetURL: $selectedAssetURL,
            selectedAssetURLs: $selectedAssetURLs,
            isAssetDropTarget: $isAssetDropTarget,
            draggingAssetURL: $draggingAssetURL,
            planPresentationState: sidebarPlanPresentationState
        )
    }

    var sidebarPlanPresentationState: AssetSidebarPanel.PlanPresentationState {
        switch purchaseStore.entitlementState {
        case .loading:
            return .loading
        case .free:
            return .free
        case .pro:
            return .pro
        }
    }

    static func mapEntitlementState(_ state: PurchaseStore.EntitlementState) -> ExportViewModel.EntitlementState {
        switch state {
        case .loading:
            return .loading
        case .free:
            return .free
        case .pro:
            return .pro
        }
    }

    var workspaceDetailSplit: some View {
        HSplitView {
            centerPreviewColumn
                .frame(minWidth: 520, idealWidth: 680, maxWidth: .infinity)
            rightSettingsColumn
                .frame(minWidth: 300, idealWidth: 360, maxWidth: 460)
        }
    }

    var centerPreviewColumn: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let validationMessage = viewModel.validationMessage {
                        Text(String(localized: "参数校验: \(validationMessage)"))
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
                            .frame(
                                minHeight: shouldUseFullHeightEmptyState
                                    ? max(geometry.size.height - 32, 320)
                                    : 320
                            )
                    }

                    if !shouldUseFullHeightEmptyState {
                        workflowPanel
                    }
                }
                .padding(16)
                .frame(
                    maxWidth: .infinity,
                    minHeight: shouldUseFullHeightEmptyState ? geometry.size.height : nil,
                    alignment: .topLeading
                )
            }
            .scrollIndicators(.automatic)
        }
    }

    var rightSettingsColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            planStatusBanner
            if let feedback = purchaseStore.feedback {
                purchaseFeedbackBanner(feedback)
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer(minLength: 0)
                    settingsModeControl
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

    var settingsModeControl: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases) { tab in
                let isSelected = settingsTab == tab
                let isHovered = hoveredSettingsTab == tab
                Button {
                    guard !viewModel.isBusy else { return }
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                        settingsTab = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(
                            ZStack {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.white.opacity(0.14))
                                        .matchedGeometryEffect(id: "settings-mode-pill", in: settingsModeAnimation)
                                } else if isHovered {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                }
                            }
                        )
                }
                .buttonStyle(SettingsModeSegmentButtonStyle())
                .focusable(false)
                .disabled(viewModel.isBusy)
                .onHover { isInside in
                    hoveredSettingsTab = isInside ? tab : nil
                }
                .accessibilityElement()
                .accessibilityIdentifier("settings_tab_\(tab.rawValue)")
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .animation(.easeOut(duration: 0.12), value: isHovered)
            }
        }
        .padding(3)
        .frame(width: 142)
        .opacity(viewModel.isBusy ? 0.6 : 1)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private struct SettingsModeSegmentButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.985 : 1)
                .opacity(configuration.isPressed ? 0.9 : 1)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
        }
    }

    var planStatusBanner: some View {
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
                Label("已解锁高级设置、无限图片导入与无水印导出", systemImage: "checkmark.circle.fill")
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
        .background(planStatusBackground)
        .accessibilityIdentifier("plan_status_banner")
    }

    var planTitle: String {
        switch purchaseStore.entitlementState {
        case .loading:
            return String(localized: "正在检查购买状态")
        case .free:
            return String(localized: "免费版")
        case .pro:
            return String(localized: "ReelFlow Pro")
        }
    }

    var planBenefitSummary: String {
        switch purchaseStore.entitlementState {
        case .loading:
            return String(localized: "稍后会根据你的购买记录自动更新。")
        case .pro:
            return String(localized: "无限图片导入 · 无水印导出")
        case .free:
            return String(localized: "最多 \(PlanLimits.freePhotoLimit) 张照片 · 导出带水印")
        }
    }

    var planStatusBackground: Color {
        switch purchaseStore.entitlementState {
        case .loading:
            return Color.secondary.opacity(0.04)
        case .free:
            return Color.secondary.opacity(0.05)
        case .pro:
            return Color.green.opacity(0.06)
        }
    }

    var quotaSummaryText: String {
        if viewModel.isAtPhotoImportLimit {
            return String(localized: "当前素材 \(viewModel.photoImportSummary)，已到上限")
        }
        if viewModel.isNearPhotoImportLimit, let remaining = viewModel.remainingPhotoImportSlots {
            return String(localized: "当前素材 \(viewModel.photoImportSummary)，还可导入 \(remaining) 张")
        }
        return String(localized: "当前素材 \(viewModel.photoImportSummary)")
    }

    func purchaseFeedbackBanner(_ feedback: PurchaseStore.Feedback) -> some View {
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
    var contentSummaryHeader: some View {
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
    var previewSummaryStatus: some View {
        if let errorMessage = viewModel.previewErrorMessage {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
                .help(String(localized: "预览错误: \(errorMessage)"))
        } else if viewModel.isPreviewGenerating {
            ProgressView()
                .controlSize(.small)
                .help(String(localized: "正在生成预览…"))
        } else {
            Image(systemName: "checkmark.circle")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .help(viewModel.previewStatusMessage)
        }
    }

    var settingsSummaryText: String {
        let durationText = String(format: "%.2f", viewModel.previewMaxSecond)
        return String(
            localized: "预计 \(durationText)s · \(viewModel.config.outputWidth)×\(viewModel.config.outputHeight) · \(viewModel.config.fps) FPS"
        )
    }

    var previewSummaryTitle: String {
        String(localized: "\(viewModel.imageURLs.count) 张图片已就绪")
    }

    var settingsAudioSummaryMessage: String? {
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

    var workflowPanel: some View {
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

    var freeTierExportNoticePanel: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "watermark")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text("免费版导出将带水印")
                    .font(.callout.weight(.semibold))
                Text("当前预览与导出会在角落显示较轻的 ReelFlow 标记。升级 Pro 后会自动移除。")
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

    func schedulePurchaseFeedbackDismiss(for feedback: PurchaseStore.Feedback?) {
        feedbackDismissTask?.cancel()
        guard feedback != nil else { return }

        feedbackDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled {
                purchaseStore.clearFeedback()
            }
        }
    }

    func color(for tone: PurchaseStore.Feedback.Tone) -> Color {
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

    func iconName(for tone: PurchaseStore.Feedback.Tone) -> String {
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

    var outputPathHintPanel: some View {
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

    var emptyPreviewPanel: some View {
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

    var exportStatusPanel: some View {
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
                    nextActionHint: viewModel.nextActionHint
                )
            }
        }
    }

    func workflowPrimaryActionKind(for id: ExportViewModel.PrimaryActionID) -> WorkflowPrimaryActionKind {
        switch id {
        case .importImages:
            return .importImages
        case .generatePreview:
            return .generatePreview
        case .chooseOutput:
            return .chooseOutput
        case .exportMP4:
            return .exportMP4
        case .exportAgain:
            return .exportAgain
        }
    }

    func performPrimaryAction(_ action: ExportViewModel.PrimaryAction) {
        switch action.id {
        case .importImages:
            viewModel.chooseImages()
        case .generatePreview:
            requestPreviewRefresh(reason: .manualPrimaryAction, mode: .immediate)
        case .chooseOutput:
            viewModel.chooseOutput()
        case .exportMP4, .exportAgain:
            viewModel.export()
        }
    }

    @ViewBuilder
    var previewOutputBar: some View {
        if viewModel.hasSelectedImages {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: previewOutputDirectoryURL == nil ? "folder.badge.questionmark" : "folder.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("导出目录")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .center, spacing: 6) {
                            Text(previewOutputDirectoryText)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(previewOutputDirectoryURL == nil ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)

                            if previewOutputDirectoryURL != nil {
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
                    }

                    Spacer(minLength: 0)

                    Button("设置位置") { viewModel.chooseOutput() }
                        .controlSize(.small)
                        .disabled(!viewModel.actionAvailability.canSelectOutput)
                }

                if let primaryAction = viewModel.primaryAction {
                    HStack(alignment: .center, spacing: 12) {
                        if let title = viewModel.isExporting
                            ? String(localized: "正在导出")
                            : nil {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(.primary)
                                if let subtitle = viewModel.isExporting
                                    ? String(localized: "导出期间预览与输出设置暂时锁定。")
                                    : nil {
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
                                kind: workflowPrimaryActionKind(for: primaryAction.id),
                                title: primaryAction.title,
                                subtitle: primaryAction.buttonSubtitle,
                                isBusy: viewModel.isBusy,
                                accessibilityIdentifier: "preview_output_primary_action",
                                action: { performPrimaryAction(primaryAction) }
                            )
                            .disabled(primaryAction.isDisabled)
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
            #if DEBUG
            .overlay(alignment: .bottomTrailing) {
                Text(previewRefreshDebugSignal)
                    .font(.caption2)
                    .foregroundStyle(.clear)
                    .accessibilityIdentifier("preview_refresh_debug_signal")
                    .accessibilityLabel("preview refresh debug signal")
                    .accessibilityValue(previewRefreshDebugSignal)
                    .allowsHitTesting(false)
                    .frame(width: 1, height: 1)
                    .clipped()
            }
            #endif
        }
    }

    var previewOutputDirectoryURL: URL? {
        viewModel.outputURL?.deletingLastPathComponent()
    }

    var previewOutputDirectoryText: String {
        guard let directoryURL = previewOutputDirectoryURL else {
            return String(localized: "尚未设置")
        }
        return (directoryURL.path as NSString).abbreviatingWithTildeInPath
    }

    var exportProgressText: String {
        let progress = min(max(viewModel.progress, 0), 1)
        return LocalizedFormatting.percent(progress)
    }

    var previewRefreshDebugSignal: String {
        [
            lastPreviewRefreshReason ?? "none",
            lastPreviewRefreshTab ?? "none",
            lastPreviewRefreshMode ?? "none"
        ].joined(separator: "|")
    }

    func presentSuccessSheetIfNeeded() {
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

    func preflightIssueExpandedBinding(for key: String) -> Binding<Bool> {
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

    var failedAssetNamesPreview: [String] {
        Array(viewModel.failedAssetNames.prefix(3))
    }

    var failedAssetHiddenCount: Int {
        max(0, viewModel.failedAssetNames.count - failedAssetNamesPreview.count)
    }

    func preflightIssuesForDisplay(report: PreflightReport) -> [PreflightIssue] {
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

    func preflightDisplayIssues(report: PreflightReport) -> [PreflightIssue] {
        Array(preflightIssuesForDisplay(report: report).prefix(6))
    }

    var filteredIgnoredIssues: [PreflightIssue] {
        viewModel.ignoredPreflightIssues.filter { issue in
            ignoredIssueSearchText.isEmpty || issue.fileName.localizedCaseInsensitiveContains(ignoredIssueSearchText)
        }
    }

    var selectedAssetForPreview: URL? {
        if let selectedAssetURL, viewModel.imageURLs.contains(selectedAssetURL) {
            return selectedAssetURL
        }
        return viewModel.imageURLs.first
    }

    var shouldUseFullHeightEmptyState: Bool {
        !viewModel.hasSelectedImages
            && !viewModel.hasFailureCard
            && !viewModel.hasSuccessCard
            && (viewModel.preflightReport?.issues.isEmpty ?? true)
    }

    func cancelPendingPreviewRefresh() {
        singlePreviewDebounceTask?.cancel()
        singlePreviewDebounceTask = nil
    }

    func requestPreviewRefresh(
        reason: PreviewRefreshReason,
        mode: PreviewRefreshMode = .debounced,
        tab: CenterPreviewTab? = nil
    ) {
        let effectiveTab = tab ?? centerPreviewTab
        cancelPendingPreviewRefresh()
        lastPreviewRefreshReason = reason.rawValue
        lastPreviewRefreshTab = effectiveTab.rawValue
        lastPreviewRefreshMode = mode == .debounced ? "debounced" : "immediate"

        #if DEBUG
        debugPrint("Preview refresh requested:", reason.rawValue, "tab:", String(describing: effectiveTab), "mode:", String(describing: mode))
        #endif

        guard viewModel.hasSelectedImages else { return }
        guard !viewModel.isBusy else { return }
        guard viewModel.validationMessage == nil else { return }

        switch effectiveTab {
        case .singleFrame:
            guard let selected = selectedAssetForPreview else { return }
            guard mode == .debounced else {
                viewModel.generatePreviewForSelectedAsset(selected)
                return
            }

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
        case .videoTimeline:
            viewModel.generatePreview()
        }
    }

    func requestPreviewRefreshAfterConfigChange() {
        viewModel.handleConfigChanged()
        requestPreviewRefresh(reason: .configChanged)
    }

    func syncSelectionAfterImageURLsChanged(_ urls: [URL]) {
        guard !urls.isEmpty else {
            cancelPendingPreviewRefresh()
            selectedAssetURL = nil
            selectedAssetURLs = []
            return
        }

        selectedAssetURLs = selectedAssetURLs.intersection(Set(urls))
        if let selectedAssetURL, urls.contains(selectedAssetURL) {
            requestPreviewRefresh(reason: .imageURLsChanged)
            return
        }

        selectedAssetURL = urls.first
        if let first = urls.first {
            selectedAssetURLs = [first]
        }
    }

    func syncPrimarySelection(from urls: Set<URL>) {
        guard !urls.isEmpty else { return }
        if let selectedAssetURL, urls.contains(selectedAssetURL) {
            return
        }
        selectedAssetURL = viewModel.imageURLs.first(where: { urls.contains($0) })
    }

    func applyPreviewModePolicy(for tab: CenterPreviewTab) {
        switch tab {
        case .singleFrame:
            viewModel.setTimelinePreviewEnabled(false)
            viewModel.setAutoPreviewRefreshEnabled(false)
        case .videoTimeline:
            viewModel.setTimelinePreviewEnabled(true)
            viewModel.setAutoPreviewRefreshEnabled(true)
        }
    }

    func applyUITestOverridesIfNeeded() {
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

    var previewPanel: some View {
        SingleFramePreviewPanel(viewModel: viewModel)
    }

    var videoPreviewPanel: some View {
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

    var settingsPanel: some View {
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
                ZStack {
                    AdvancedSettingsPanel(
                        viewModel: viewModel,
                        isAudioDropTarget: $isAudioDropTarget,
                        onAudioDrop: { providers in
                            handleAudioDrop(providers: providers)
                        },
                        isLocked: isAdvancedSettingsLocked
                    )

                    if isAdvancedSettingsLocked {
                        advancedSettingsLockOverlay
                    }
                }
            }
        }
    }

    var isAdvancedSettingsLocked: Bool {
        purchaseStore.entitlementState != .pro
    }

    var advancedSettingsLockOverlay: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.72))
                .allowsHitTesting(false)

            VStack(alignment: .center, spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    Text(advancedSettingsLockTitle)
                        .font(.headline)
                    Text(advancedSettingsLockMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }

                if purchaseStore.entitlementState == .free {
                    HStack(spacing: 10) {
                        Button(purchaseStore.purchaseButtonTitle) {
                            purchaseStore.purchasePro()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(purchaseStore.isBusy)

                        Button("恢复购买") {
                            purchaseStore.restorePurchases()
                        }
                        .disabled(purchaseStore.isBusy)
                    }
                } else {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在同步购买状态")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
            .padding(.horizontal, 24)
        }
    }

    var advancedSettingsLockTitle: String {
        switch purchaseStore.entitlementState {
        case .loading:
            return String(localized: "正在检查 Pro 状态")
        case .free:
            return String(localized: "解锁 Pro 后可使用高级设置")
        case .pro:
            return ""
        }
    }

    var advancedSettingsLockMessage: String {
        switch purchaseStore.entitlementState {
        case .loading:
            return String(localized: "购买状态确认后，这里会自动更新。")
        case .free:
            return String(localized: "高级设置包含更细的布局、模板、背景音频和性能控制。升级后即可编辑。")
        case .pro:
            return ""
        }
    }

    func handleAudioDrop(providers: [NSItemProvider]) -> Bool {
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

    func audioTimelineSegments(
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

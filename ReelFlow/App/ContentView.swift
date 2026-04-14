import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    struct SuccessSheetContext: Identifiable {
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

    enum CenterPreviewTab: String, CaseIterable, Identifiable {
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

    enum SettingsTab: String, CaseIterable, Identifiable {
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

    @StateObject var viewModel: ExportViewModel
    @ObservedObject var purchaseStore: PurchaseStore
    let layoutMode: LayoutMode
    @State var centerPreviewTab: CenterPreviewTab = .singleFrame
    @State var settingsTab: SettingsTab = .simple
    @State var selectedAssetURL: URL?
    @State var selectedAssetURLs: Set<URL> = []
    @State var singlePreviewDebounceTask: Task<Void, Never>?
    @State var isAssetDropTarget = false
    @State var isAudioDropTarget = false
    @State var draggingAssetURL: URL?
    @State var expandedPreflightIssueKeys: Set<String> = []
    @State var ignoredIssuesExpanded = false
    @State var ignoredIssueSearchText = ""
    @State var preflightOnlyPending = true
    @State var preflightPrioritizeMustFix = true
    @State var preflightSecondaryActionsExpanded = false
    @State var splitColumnVisibility: NavigationSplitViewVisibility = .all
    @State var successSheetContext: SuccessSheetContext?
    @State var feedbackDismissTask: Task<Void, Never>?
    @State var lastPreviewRefreshReason: String?
    @State var lastPreviewRefreshTab: String?
    @State var lastPreviewRefreshMode: String?

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
                requestPreviewRefresh(reason: .onAppear)
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
                requestPreviewRefreshAfterConfigChange()
            }
            .onChange(of: purchaseStore.entitlementState) { _, _ in
                requestPreviewRefresh(reason: .entitlementChanged)
            }
            .onChange(of: purchaseStore.feedback) { _, feedback in
                schedulePurchaseFeedbackDismiss(for: feedback)
            }
            .onChange(of: viewModel.imageURLs) { _, urls in
                syncSelectionAfterImageURLsChanged(urls)
            }
            .onChange(of: selectedAssetURL) { _, _ in
                requestPreviewRefresh(reason: .selectedAssetChanged)
            }
            .onChange(of: selectedAssetURLs) { _, urls in
                syncPrimarySelection(from: urls)
            }
            .onChange(of: centerPreviewTab) { _, tab in
                applyPreviewModePolicy(for: tab)
                requestPreviewRefresh(reason: .centerPreviewTabChanged, tab: tab)
            }
            .onChange(of: viewModel.statusMessage) { _, _ in
                presentSuccessSheetIfNeeded()
            }
            .onDisappear {
                cancelPendingPreviewRefresh()
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
            .navigationTitle(Text(verbatim: "ReelFlow"))
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button(String(localized: "导入模板")) { viewModel.importTemplate() }
                            .accessibilityIdentifier("secondary_import_template")
                            .disabled(!viewModel.actionAvailability.canImportTemplate)
                        Button(String(localized: "保存模板")) { viewModel.exportTemplate() }
                            .accessibilityIdentifier("secondary_export_template")
                            .disabled(!viewModel.actionAvailability.canSaveTemplate)
                        Button(String(localized: "恢复设置")) { viewModel.resetSettingsToDefaults() }
                            .accessibilityIdentifier("secondary_reset_settings")
                            .disabled(viewModel.isBusy)
                        Divider()
                        Button(String(localized: "重试上次导出")) { viewModel.retryLastExport() }
                            .accessibilityIdentifier("secondary_retry_export")
                            .disabled(!viewModel.hasSelectedImages || !viewModel.actionAvailability.canRetryExport)
                        Button(String(localized: "导出排障包")) { viewModel.exportDiagnosticsBundle() }
                            .accessibilityIdentifier("secondary_export_diagnostics")
                            .disabled(!viewModel.hasSelectedImages || viewModel.isBusy)
                        #if DEBUG
                        Divider()
                        Button(String(localized: "模拟导出失败")) { viewModel.simulateExportFailure() }
                            .disabled(viewModel.isBusy)
                        #endif
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .menuIndicator(.hidden)
                    .help(String(localized: "更多"))
                    .accessibilityLabel(String(localized: "更多"))
                    .accessibilityHint(String(localized: "打开更多操作"))
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
        viewModel.previewStatusMessage = String(localized: "预览已更新 (0.00s)")
        viewModel.workflow.setIdleMessage(String(localized: "已就绪，可直接导出 MP4。"))
        return viewModel
    }
}

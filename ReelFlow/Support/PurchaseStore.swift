import Combine
import Foundation
import StoreKit

@MainActor
final class PurchaseStore: ObservableObject {
    enum Mode {
        case live
        case preview(hasProAccess: Bool)
    }

    struct Feedback: Identifiable, Equatable {
        enum Tone: Equatable {
            case success
            case info
            case warning
            case error
        }

        let id = UUID()
        let tone: Tone
        let title: String
        let message: String
    }

    static let proProductID = "net.ximatai.reelflow.pro"

    @Published private(set) var hasProAccess = false
    @Published private(set) var proProduct: Product?
    @Published private(set) var isBusy = false
    @Published private(set) var statusMessage: String?
    @Published var feedback: Feedback?

    private let mode: Mode
    private var updatesTask: Task<Void, Never>?

    init(mode: Mode = .live) {
        #if DEBUG
        if let previewMode = Self.uiTestPreviewMode() {
            self.mode = previewMode
        } else {
            self.mode = mode
        }
        #else
        self.mode = mode
        #endif

        switch self.mode {
        case .live:
            updatesTask = observeTransactionUpdates()
            Task {
                await refreshStore()
            }
        case .preview(let hasProAccess):
            self.hasProAccess = hasProAccess
            self.statusMessage = hasProAccess ? "测试场景：ReelFlow Pro 已解锁" : "测试场景：免费版"
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var purchaseButtonTitle: String {
        if hasProAccess {
            return "ReelFlow Pro 已解锁"
        }
        if let proProduct {
            return "升级 Pro · \(proProduct.displayPrice)"
        }
        return "升级到 Pro"
    }

    var planDescription: String {
        if hasProAccess {
            return "ReelFlow Pro 已解锁：无限导入，导出无水印。"
        }
        return "免费版最多导入 20 张照片，导出会带 Made with ReelFlow 水印。"
    }

    func purchasePro() {
        guard case .live = mode else { return }
        guard !isBusy else { return }
        guard let proProduct else {
            statusMessage = "暂时无法连接 App Store，请稍后重试。"
            feedback = Feedback(
                tone: .error,
                title: "无法开始购买",
                message: "当前未读取到 ReelFlow Pro 商品，请稍后重试。"
            )
            Task {
                await refreshProducts()
            }
            return
        }

        isBusy = true
        Task {
            defer { isBusy = false }

            do {
                let result = try await proProduct.purchase()
                switch result {
                case .success(let verification):
                    guard case .verified(let transaction) = verification else {
                        statusMessage = "购买未通过验证，请稍后重试。"
                        feedback = Feedback(
                            tone: .error,
                            title: "购买未完成",
                            message: "App Store 返回了未验证交易，当前不会解锁 Pro。"
                        )
                        return
                    }

                    hasProAccess = true
                    statusMessage = "ReelFlow Pro 已解锁。"
                    feedback = Feedback(
                        tone: .success,
                        title: "ReelFlow Pro 已解锁",
                        message: "无限导入与无水印导出已立即生效。"
                    )
                    await transaction.finish()
                    await refreshEntitlements()
                case .userCancelled:
                    statusMessage = "已取消购买。"
                    feedback = Feedback(
                        tone: .info,
                        title: "已取消购买",
                        message: "当前仍处于免费版，你可以稍后再升级。"
                    )
                case .pending:
                    statusMessage = "购买正在等待确认。"
                    feedback = Feedback(
                        tone: .warning,
                        title: "购买等待确认",
                        message: "交易仍在处理中，确认完成后会自动解锁 Pro。"
                    )
                @unknown default:
                    statusMessage = "购买结果暂不可用，请稍后查看。"
                    feedback = Feedback(
                        tone: .warning,
                        title: "购买状态未知",
                        message: "当前无法确认购买结果，请稍后再看。"
                    )
                }
            } catch {
                statusMessage = "购买失败：\(error.localizedDescription)"
                feedback = Feedback(
                    tone: .error,
                    title: "购买失败",
                    message: error.localizedDescription
                )
            }
        }
    }

    func restorePurchases() {
        guard case .live = mode else { return }
        guard !isBusy else { return }

        isBusy = true
        Task {
            defer { isBusy = false }

            do {
                try await AppStore.sync()
                await refreshEntitlements()
                statusMessage = hasProAccess ? "已恢复 ReelFlow Pro。" : "未找到可恢复的 ReelFlow Pro 购买。"
                feedback = hasProAccess
                    ? Feedback(
                        tone: .success,
                        title: "已恢复购买",
                        message: "ReelFlow Pro 已恢复，无限导入与无水印导出已生效。"
                    )
                    : Feedback(
                        tone: .info,
                        title: "未找到可恢复购买",
                        message: "当前 Apple 账号下没有 ReelFlow Pro 的可恢复记录。"
                    )
            } catch {
                statusMessage = "恢复购买失败：\(error.localizedDescription)"
                feedback = Feedback(
                    tone: .error,
                    title: "恢复购买失败",
                    message: error.localizedDescription
                )
            }
        }
    }

    func refreshStore() async {
        guard case .live = mode else { return }
        await refreshProducts()
        await refreshEntitlements()
    }

    private func refreshProducts() async {
        do {
            let products = try await Product.products(for: [Self.proProductID])
            proProduct = products.first
            if proProduct == nil {
                statusMessage = "未找到 ReelFlow Pro 商品，请检查 App Store Connect 配置。"
            }
        } catch {
            statusMessage = "无法读取购买信息：\(error.localizedDescription)"
        }
    }

    private func refreshEntitlements() async {
        var unlocked = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.proProductID else { continue }
            guard transaction.revocationDate == nil else { continue }

            if let expirationDate = transaction.expirationDate, expirationDate < Date() {
                continue
            }

            unlocked = true
            break
        }

        hasProAccess = unlocked
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            guard let self else { return }

            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result else { continue }
                guard transaction.productID == Self.proProductID else {
                    await transaction.finish()
                    continue
                }

                await refreshEntitlements()
                await transaction.finish()
            }
        }
    }

    private static func uiTestPreviewMode() -> Mode? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-ui-test-pro-access"), arguments.indices.contains(flagIndex + 1) else {
            return nil
        }
        return arguments[flagIndex + 1] == "enabled" ? .preview(hasProAccess: true) : .preview(hasProAccess: false)
    }

    func clearFeedback() {
        feedback = nil
    }
}

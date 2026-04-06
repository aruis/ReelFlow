import Testing
@testable import ReelFlow

@MainActor
struct PurchaseStoreTests {
    @Test
    func previewModeCanExposeUnlockedState() async throws {
        let store = PurchaseStore(mode: .preview(hasProAccess: true))

        #expect(store.hasProAccess == true)
        #expect(store.entitlementState == .pro)
        #expect(store.statusMessage?.contains("已解锁") == true)
    }

    @Test
    func previewModeResolvesFreeStateImmediately() async throws {
        let store = PurchaseStore(mode: .preview(hasProAccess: false))

        #expect(store.entitlementState == .free)
        #expect(store.isEntitlementResolved == true)
    }

    @Test
    func clearFeedbackRemovesVisibleFeedback() async throws {
        let store = PurchaseStore(mode: .preview(hasProAccess: false))
        store.feedback = .init(tone: .info, title: "提示", message: "测试消息")

        #expect(store.feedback != nil)
        store.clearFeedback()
        #expect(store.feedback == nil)
    }
}

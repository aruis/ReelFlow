import Foundation
import Testing
@testable import ReelFlow

struct ExportStatusMessageBuilderTests {
    @Test
    func successMessageIncludesAudioLineWhenAttached() {
        let text = ExportStatusMessageBuilder.success(
            outputFilename: "ReelFlow-Output.mp4",
            logPath: "/tmp/render.log",
            audioAttached: true
        )

        #expect(text == "导出完成: ReelFlow-Output.mp4\n音频: 已附加单轨背景音频\n日志: /tmp/render.log")
    }

    @Test
    func successMessageOmitsAudioLineWhenNotAttached() {
        let text = ExportStatusMessageBuilder.success(
            outputFilename: "ReelFlow-Output.mp4",
            logPath: "/tmp/render.log",
            audioAttached: false
        )

        #expect(text == "导出完成: ReelFlow-Output.mp4\n日志: /tmp/render.log")
    }

    @Test
    func failureMessageWithAssetsIncludesRemediation() {
        let text = ExportStatusMessageBuilder.failure(
            head: "[E_EXPORT_PIPELINE] 导出失败",
            stage: .export,
            logPath: "/tmp/render.log",
            adviceActionTitle: "重试上次导出",
            adviceMessage: "请先处理素材后重试。",
            failedAssetNames: ["a.jpg", "b.jpg"]
        )

        #expect(
            text == "[E_EXPORT_PIPELINE] 导出失败\n失败阶段: 导出\n问题素材: a.jpg、b.jpg\n处理建议: 在素材列表中定位该文件，替换或移除后重试导出\n建议动作: 重试上次导出\n详细建议: 请先处理素材后重试。\n日志: /tmp/render.log"
        )
    }

    @Test
    func failureMessageWithoutAssetsUsesCompactForm() {
        let text = ExportStatusMessageBuilder.failure(
            head: "[E_EXPORT_PIPELINE] 导出失败",
            stage: .export,
            logPath: "/tmp/render.log",
            adviceActionTitle: "重试上次导出",
            adviceMessage: "可先重试导出。",
            failedAssetNames: []
        )

        #expect(
            text == "[E_EXPORT_PIPELINE] 导出失败\n失败阶段: 导出\n建议动作: 重试上次导出\n建议: 可先重试导出。\n日志: /tmp/render.log"
        )
    }

    @Test
    func failureCardCopyWithAssetsUsesAssetFocusedGuidance() {
        let copy = ExportStatusMessageBuilder.failureCardCopy(
            stage: .export,
            adviceActionTitle: "重试上次导出",
            adviceMessage: "请先处理素材后重试。",
            failedAssetNames: ["a.jpg", "b.jpg"]
        )

        #expect(copy.problemSummary == "问题素材：a.jpg、b.jpg。")
        #expect(copy.nextStep == "请在素材列表定位并替换或移除问题素材后重试。")
        #expect(copy.actionTitle == "重试上次导出")
    }

    @Test
    func failureCardCopyWithoutAssetsUsesStageAndAdvice() {
        let copy = ExportStatusMessageBuilder.failureCardCopy(
            stage: .preview,
            adviceActionTitle: "调整参数后重试",
            adviceMessage: "可先调整参数或重新选择素材后再试。",
            failedAssetNames: []
        )

        #expect(copy.problemSummary == "失败阶段：预览。")
        #expect(copy.nextStep == "可先调整参数或重新选择素材后再试。")
        #expect(copy.actionTitle == "调整参数后重试")
    }
}

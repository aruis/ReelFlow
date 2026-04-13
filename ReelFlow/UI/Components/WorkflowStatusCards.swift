import SwiftUI

enum WorkflowPrimaryActionKind {
    case importImages
    case generatePreview
    case chooseOutput
    case exportMP4
    case exportAgain
    case custom(systemImage: String)

    var systemImage: String {
        switch self {
        case .importImages:
            return "photo.badge.plus"
        case .generatePreview:
            return "play.rectangle.fill"
        case .chooseOutput:
            return "folder.badge.plus"
        case .exportMP4:
            return "square.and.arrow.up.fill"
        case .exportAgain:
            return "arrow.clockwise.circle.fill"
        case .custom(let systemImage):
            return systemImage
        }
    }
}

struct ExportSuccessSheet: View {
    @Environment(\.dismiss) private var dismiss

    let filename: String
    let directoryPath: String
    let hasLog: Bool
    let onOpenOutputFile: () -> Void
    let onOpenOutputDirectory: () -> Void
    let onOpenLog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("导出完成")
                        .font(.title3.weight(.semibold))
                    Text("视频已经生成，可以直接打开或继续处理。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                successInfoRow(
                    systemImage: "doc.fill",
                    title: String(localized: "导出文件"),
                    value: filename,
                    emphasized: true
                )
                successInfoRow(
                    systemImage: "folder.fill",
                    title: String(localized: "导出目录"),
                    value: directoryPath
                )
            }
            .padding(14)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 10) {
                Button {
                    onOpenOutputFile()
                    dismiss()
                } label: {
                    Label("打开文件", systemImage: "play.rectangle.fill")
                }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("success_sheet_open_file")
                Button {
                    onOpenOutputDirectory()
                } label: {
                    Label("打开文件夹", systemImage: "folder")
                }
                .accessibilityIdentifier("success_sheet_open_directory")
                if hasLog {
                    Button {
                        onOpenLog()
                    } label: {
                        Label("查看日志", systemImage: "doc.text")
                    }
                    .accessibilityIdentifier("success_sheet_open_log")
                }
                Spacer(minLength: 0)
                Button("完成") { dismiss() }
                    .accessibilityIdentifier("success_sheet_done")
            }
            .controlSize(.regular)
        }
        .padding(20)
        .frame(minWidth: 420)
        .accessibilityIdentifier("success_sheet")
    }

    private func successInfoRow(
        systemImage: String,
        title: String,
        value: String,
        emphasized: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(emphasized ? Color.accentColor : Color.secondary)
                .frame(width: 18, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(emphasized ? .headline : .callout)
                    .foregroundStyle(emphasized ? .primary : .secondary)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WorkflowOverviewPanel: View {
    let statusMessage: String
    let nextActionHint: String

    var body: some View {
        GroupBox("流程状态") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("下一步")
                            .font(.headline)
                        Text(nextActionHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("flow_next_hint")
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                workflowInfoRow(
                    systemImage: "text.alignleft",
                    title: String(localized: "当前情况"),
                    value: statusMessage,
                    emphasized: true
                )
                .padding(14)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func workflowInfoRow(
        systemImage: String,
        title: String,
        value: String,
        emphasized: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(emphasized ? Color.accentColor : Color.secondary)
                .frame(width: 18, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(emphasized ? .callout.weight(.semibold) : .callout)
                    .foregroundStyle(emphasized ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("workflow_status_message")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WorkflowPrimaryActionButton: View {
    let kind: WorkflowPrimaryActionKind
    let title: String
    let subtitle: String?
    let isBusy: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: action) {
                if isBusy {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text(title)
                    }
                } else {
                    Label(title, systemImage: kind.systemImage)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
        }
        .fixedSize(horizontal: false, vertical: false)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct FailureStatusCard: View {
    let copy: FailureCardCopy
    let isBusy: Bool
    let onPrimaryAction: () -> Void
    let onOpenLog: () -> Void

    var body: some View {
        GroupBox("导出失败") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("导出没有完成")
                            .font(.headline)
                        Text(String(localized: "建议先做：\(copy.actionTitle)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    failureInfoRow(
                        systemImage: "exclamationmark.bubble.fill",
                        title: String(localized: "问题是什么"),
                        value: copy.problemSummary,
                        emphasized: true
                    )
                    failureInfoRow(
                        systemImage: "arrow.trianglehead.turn.up.right.circle.fill",
                        title: String(localized: "建议操作"),
                        value: copy.nextStep
                    )
                }
                .padding(14)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack(spacing: 10) {
                    Spacer(minLength: 0)

                    Button {
                        onOpenLog()
                    } label: {
                        Label("查看日志", systemImage: "doc.text")
                    }
                        .accessibilityIdentifier("failure_open_log")

                    Button {
                        onPrimaryAction()
                    } label: {
                        Label(copy.actionTitle, systemImage: "arrow.clockwise")
                    }
                        .accessibilityIdentifier("failure_primary_action")
                        .buttonStyle(.borderedProminent)
                        .disabled(isBusy)
                }
                .controlSize(.small)
                .padding(.top, 4)
                .padding(.bottom, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("failure_card")
    }

    private func failureInfoRow(
        systemImage: String,
        title: String,
        value: String,
        emphasized: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(emphasized ? Color.orange : Color.secondary)
                .frame(width: 18, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(emphasized ? .callout.weight(.semibold) : .callout)
                    .foregroundStyle(emphasized ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FailedAssetsPanel: View {
    let names: [String]
    let hiddenCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("失败素材")
                .font(.subheadline.weight(.semibold))
            ForEach(names, id: \.self) { name in
                Text(name)
                    .font(.callout)
            }
            if hiddenCount > 0 {
                Text(String(localized: "另有 \(hiddenCount) 项失败素材，可在“素材列表”查看全部。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SuccessStatusCard: View {
    let filename: String?
    let logPath: String?
    let isBusy: Bool
    let onExportAgain: () -> Void
    let onOpenOutputFile: () -> Void
    let onOpenOutputDirectory: () -> Void
    let onOpenLog: () -> Void

    var body: some View {
        GroupBox("导出完成") {
            VStack(alignment: .leading, spacing: 8) {
                Text(filename ?? String(localized: "已生成可播放的 MP4 文件"))
                    .font(.callout.weight(.semibold))

                HStack(spacing: 10) {
                    Button("打开文件") { onOpenOutputFile() }
                        .accessibilityIdentifier("success_open_file")
                        .buttonStyle(.borderedProminent)
                    Button("打开文件夹") { onOpenOutputDirectory() }
                        .accessibilityIdentifier("success_open_output")
                    Button("再次导出") { onExportAgain() }
                        .accessibilityIdentifier("success_export_again")
                        .disabled(isBusy)
                    if logPath != nil {
                        Button("查看日志") { onOpenLog() }
                            .accessibilityIdentifier("success_open_log")
                    }
                }
                .controlSize(.small)

                if let logPath {
                    Text(logPath)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("success_card")
    }
}

import SwiftUI
import UniformTypeIdentifiers

struct AudioSettingsSection: View {
    @ObservedObject var viewModel: ExportViewModel
    @Binding var isAudioDropTarget: Bool
    let onAudioDrop: ([NSItemProvider]) -> Bool
    var showsBackgroundAudio: Bool = true

    private var shutterPreviewButton: some View {
        Button {
            _ = viewModel.startShutterSoundPreview()
        } label: {
            Image(systemName: viewModel.isShutterSoundPreviewPlaying ? "speaker.wave.2.fill" : "play.fill")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .background(
            Circle()
                .fill(Color.accentColor.opacity(viewModel.isBusy || viewModel.isShutterSoundPreviewPlaying ? 0.18 : 0.9))
        )
        .foregroundStyle(.white.opacity(viewModel.isBusy || viewModel.isShutterSoundPreviewPlaying ? 0.7 : 1))
        .disabled(viewModel.isBusy || viewModel.isShutterSoundPreviewPlaying)
        .help(viewModel.isShutterSoundPreviewPlaying ? "试听中…" : "试听快门声")
        .accessibilityLabel(viewModel.isShutterSoundPreviewPlaying ? "试听中…" : "试听快门声")
    }

    var body: some View {
        Section("音频") {
            if showsBackgroundAudio {
                Toggle("启用背景音频", isOn: $viewModel.config.audioEnabled)
                    .disabled(viewModel.isBusy)

                if viewModel.config.audioEnabled {
                    if viewModel.selectedAudioFilename == nil {
                        Text("已启用背景音频，但还没有选择音频文件。")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    HStack(spacing: 10) {
                        Button("选择音频") {
                            viewModel.chooseAudioTrack()
                        }
                        .disabled(viewModel.isBusy)

                        Button("清除音频") {
                            viewModel.clearAudioTrack()
                        }
                        .disabled(viewModel.isBusy || viewModel.selectedAudioFilename == nil)
                    }

                    if let name = viewModel.selectedAudioFilename {
                        Text(String(localized: "已选: \(name)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("尚未选择音频文件")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "音量: \(Int((viewModel.config.audioVolume * 100).rounded()))%"))
                        Slider(value: $viewModel.config.audioVolume, in: RenderEditorConfig.audioVolumeRange, step: 0.01)
                            .disabled(viewModel.isBusy)
                    }

                    Toggle("自动循环至视频结束", isOn: $viewModel.config.audioLoopEnabled)
                        .disabled(viewModel.isBusy)

                    if let message = viewModel.audioStatusMessage {
                        Text(message)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("导出时会把这条音频加入视频。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 6) {
                        Label("拖拽音频到此处", systemImage: "waveform")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("支持拖入 1 条音频文件。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isAudioDropTarget ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isAudioDropTarget ? Color.accentColor : Color.secondary.opacity(0.25),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                            )
                    )
                    .onDrop(of: [UTType.fileURL], isTargeted: $isAudioDropTarget, perform: onAudioDrop)
                }

                Divider()
            }

            Toggle("切换新照片时播放快门声", isOn: $viewModel.config.shutterSoundEnabled)
                .disabled(viewModel.isBusy)

            if viewModel.config.shutterSoundEnabled {
                Picker("声音来源", selection: $viewModel.config.shutterSoundSource) {
                    Text("内置型号").tag(ShutterSoundSource.preset)
                    Text("自定义文件").tag(ShutterSoundSource.custom)
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isBusy)

                switch viewModel.config.shutterSoundSource {
                case .preset:
                    HStack(spacing: 8) {
                        Picker("相机型号", selection: $viewModel.config.shutterSoundPreset) {
                            ForEach(ShutterSoundPreset.allCases, id: \.self) { preset in
                                Text(preset.displayName).tag(preset)
                            }
                        }
                        .disabled(viewModel.isBusy)

                        shutterPreviewButton
                    }

                    if ShutterSoundCatalog.bundledURL(for: viewModel.config.shutterSoundPreset) == nil {
                        Text("当前构建未包含该型号快门声资源，请改用“自定义文件”或补充资源。")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }

                case .custom:
                    HStack(spacing: 10) {
                        Button("选择快门声") {
                            viewModel.chooseShutterSoundTrack()
                        }
                        .disabled(viewModel.isBusy)

                        Button("清除快门声") {
                            viewModel.clearShutterSoundTrack()
                        }
                        .disabled(viewModel.isBusy || viewModel.selectedShutterSoundFilename == nil)

                        shutterPreviewButton
                    }

                    if let name = viewModel.selectedShutterSoundFilename {
                        Text(String(localized: "已选: \(name)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("尚未选择快门声音效")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let message = viewModel.shutterSoundStatusMessage {
                        Text(message)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("支持选择一条短音效，导出时会在每张新照片开始时触发。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "快门声音量: \(Int((viewModel.config.shutterSoundVolume * 100).rounded()))%"))
                    Slider(value: $viewModel.config.shutterSoundVolume, in: RenderEditorConfig.audioVolumeRange, step: 0.01)
                        .disabled(viewModel.isBusy)
                }
            }
        }
    }
}

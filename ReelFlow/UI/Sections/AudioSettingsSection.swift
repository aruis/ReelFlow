import SwiftUI

private enum ShutterSoundPickerOption: Hashable {
    case none
    case preset(ShutterSoundPreset)
    case custom
}

struct AudioSettingsSection: View {
    @ObservedObject var viewModel: ExportViewModel
    @Binding var isAudioDropTarget: Bool
    let onAudioDrop: ([NSItemProvider]) -> Bool
    var showsBackgroundAudio: Bool = true

    private var shutterPreviewButton: some View {
        Button {
            if viewModel.isShutterSoundPreviewPlaying {
                viewModel.stopShutterSoundPreview()
            } else {
                _ = viewModel.startShutterSoundPreview()
            }
        } label: {
            Image(systemName: viewModel.isShutterSoundPreviewPlaying ? "stop.fill" : "play.fill")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .background(
            Circle()
                .fill(Color.accentColor.opacity(viewModel.isBusy ? 0.18 : (viewModel.isShutterSoundPreviewPlaying ? 0.35 : 0.9)))
        )
        .foregroundStyle(.white.opacity(viewModel.isBusy ? 0.7 : 1))
        .disabled(viewModel.isBusy || !isShutterSoundActive)
        .help(viewModel.isShutterSoundPreviewPlaying ? "停止试听" : "试听快门声")
        .accessibilityLabel(viewModel.isShutterSoundPreviewPlaying ? "停止试听" : "试听快门声")
    }

    private var selectedAudioSummary: String {
        viewModel.selectedAudioFilename ?? String(localized: "尚未选择音频")
    }

    private var hasSelectedAudio: Bool {
        viewModel.selectedAudioFilename != nil
    }

    private var shutterSoundPickerSelection: Binding<ShutterSoundPickerOption> {
        Binding(
            get: {
                guard viewModel.config.shutterSoundEnabled else { return .none }
                switch viewModel.config.shutterSoundSource {
                case .preset:
                    return .preset(viewModel.config.shutterSoundPreset)
                case .custom:
                    return .custom
                }
            },
            set: { newValue in
                viewModel.stopShutterSoundPreview()
                switch newValue {
                case .none:
                    viewModel.config.shutterSoundEnabled = false
                case .preset(let preset):
                    viewModel.config.shutterSoundEnabled = true
                    viewModel.config.shutterSoundSource = .preset
                    viewModel.config.shutterSoundPreset = preset
                case .custom:
                    let previousSelection: ShutterSoundPickerOption = if !viewModel.config.shutterSoundEnabled {
                        .none
                    } else {
                        switch viewModel.config.shutterSoundSource {
                        case .preset:
                            .preset(viewModel.config.shutterSoundPreset)
                        case .custom:
                            .custom
                        }
                    }
                    let previousSource = viewModel.config.shutterSoundSource
                    let previousPreset = viewModel.config.shutterSoundPreset
                    let previousPath = viewModel.config.shutterSoundCustomFilePath
                    viewModel.config.shutterSoundEnabled = true
                    viewModel.config.shutterSoundSource = .custom
                    if viewModel.config.shutterSoundCustomFilePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        viewModel.chooseShutterSoundTrack()
                        if viewModel.config.shutterSoundCustomFilePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            switch previousSelection {
                            case .none:
                                viewModel.config.shutterSoundEnabled = false
                            case .preset:
                                viewModel.config.shutterSoundEnabled = true
                                viewModel.config.shutterSoundSource = previousSource
                                viewModel.config.shutterSoundPreset = previousPreset
                            case .custom:
                                viewModel.config.shutterSoundEnabled = true
                                viewModel.config.shutterSoundSource = previousSource
                                viewModel.config.shutterSoundPreset = previousPreset
                                viewModel.config.shutterSoundCustomFilePath = previousPath
                            }
                        }
                    }
                }
            }
        )
    }

    private var selectedShutterSoundPickerTitle: String {
        guard viewModel.config.shutterSoundEnabled else {
            return String(localized: "无")
        }
        switch viewModel.config.shutterSoundSource {
        case .preset:
            return viewModel.config.shutterSoundPreset.displayName
        case .custom:
            return customShutterSoundOptionTitle
        }
    }

    private var customShutterSoundOptionTitle: String {
        let path = viewModel.config.shutterSoundCustomFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !path.isEmpty {
            let name = URL(fileURLWithPath: path).lastPathComponent
            return String(localized: "自定义：\(name)")
        }
        return String(localized: "自定义文件")
    }

    private var isShutterSoundActive: Bool {
        viewModel.config.shutterSoundEnabled && viewModel.config.resolvedShutterSoundTrack != nil
    }

    private var groupCardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.04))
    }

    var body: some View {
        Section("音频") {
            if showsBackgroundAudio {
                VStack(alignment: .leading, spacing: 12) {
                    Label("背景音乐", systemImage: "music.note")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("背景声音")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(selectedAudioSummary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer(minLength: 8)

                        Button(hasSelectedAudio ? "更换" : "选择") {
                            viewModel.chooseAudioTrack()
                        }
                        .focusable(false)
                        .disabled(viewModel.isBusy)

                        if hasSelectedAudio {
                            Button {
                                viewModel.clearAudioTrack()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .disabled(viewModel.isBusy)
                            .help("清除音频")
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("音量")
                            Spacer()
                            Text("\(Int((viewModel.config.audioVolume * 100).rounded()))%")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .font(.body)

                        Slider(value: $viewModel.config.audioVolume, in: RenderEditorConfig.audioVolumeRange, step: 0.01)
                            .disabled(viewModel.isBusy || !hasSelectedAudio)
                    }

                    Toggle("自动循环至视频结束", isOn: $viewModel.config.audioLoopEnabled)
                        .disabled(viewModel.isBusy || !hasSelectedAudio)
                }
                .padding(14)
                .background(groupCardBackground)
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("快门声", systemImage: "camera.shutter.button")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("照片切换时播放的快门声")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Menu {
                        Button(String(localized: "无")) {
                            shutterSoundPickerSelection.wrappedValue = .none
                        }
                        Divider()
                        ForEach(ShutterSoundPreset.allCases, id: \.self) { preset in
                            Button(preset.displayName) {
                                shutterSoundPickerSelection.wrappedValue = .preset(preset)
                            }
                        }
                        Divider()
                        Button(customShutterSoundOptionTitle) {
                            shutterSoundPickerSelection.wrappedValue = .custom
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(selectedShutterSoundPickerTitle)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .frame(minHeight: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .disabled(viewModel.isBusy)

                    if viewModel.config.shutterSoundSource == .custom, viewModel.selectedShutterSoundFilename != nil, viewModel.config.shutterSoundEnabled {
                        Button {
                            viewModel.clearShutterSoundTrack()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .disabled(viewModel.isBusy)
                        .help("关闭快门声")
                    }

                    shutterPreviewButton
                }

                if viewModel.config.shutterSoundEnabled, viewModel.config.shutterSoundSource == .preset,
                   ShutterSoundCatalog.bundledURL(for: viewModel.config.shutterSoundPreset) == nil {
                    Text("当前构建未包含该型号快门声资源，请改用自定义文件或补充资源。")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                if viewModel.config.shutterSoundEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "快门声音量: \(Int((viewModel.config.shutterSoundVolume * 100).rounded()))%"))
                        Slider(value: $viewModel.config.shutterSoundVolume, in: RenderEditorConfig.audioVolumeRange, step: 0.01)
                            .disabled(viewModel.isBusy)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "延迟播放: \(viewModel.config.shutterSoundDelay, specifier: "%.2f")s"))
                        Slider(value: $viewModel.config.shutterSoundDelay, in: RenderEditorConfig.shutterSoundDelayRange, step: 0.01)
                            .disabled(viewModel.isBusy)
                    }
                }
            }
            .padding(14)
            .background(groupCardBackground)
        }
    }
}

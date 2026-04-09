import SwiftUI

struct SingleFramePreviewPanel: View {
    @ObservedObject var viewModel: ExportViewModel

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                previewSurface(
                    image: viewModel.previewImage,
                    placeholderSystemImage: "photo",
                    placeholderText: String(localized: "尚未生成单帧预览"),
                    accessibilityIdentifier: "single_frame_preview_surface"
                )
            }
        }
    }
}

struct VideoTimelinePreviewPanel: View {
    @ObservedObject var viewModel: ExportViewModel
    let audioSegments: [(start: Double, end: Double)]
    let imageSegmentStarts: [Double]

    private var previewBlockedMessage: String? {
        guard !viewModel.imageURLs.isEmpty else { return nil }
        if let validationMessage = viewModel.validationMessage {
            return String(localized: "当前参数下无法刷新预览：\(validationMessage)")
        }
        if viewModel.isBusy && !viewModel.isPreviewGenerating {
            return String(localized: "导出进行中，时间轴预览暂不刷新。")
        }
        return nil
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.config.audioEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        let videoDuration = max(viewModel.previewMaxSecond, 0)
                        let audioDuration = viewModel.selectedAudioDuration
                        let audioName = viewModel.selectedAudioFilename ?? String(localized: "未选择音频")

                        Text(String(localized: "音轨: \(audioName)"))
                            .font(.caption)
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.12))
                            GeometryReader { proxy in
                                let width = proxy.size.width
                                ForEach(Array(audioSegments.enumerated()), id: \.offset) { _, segment in
                                    let start = segment.start
                                    let end = segment.end
                                    let x = videoDuration > 0 ? CGFloat(start / videoDuration) * width : 0
                                    let segmentWidth = videoDuration > 0 ? max(2, CGFloat((end - start) / videoDuration) * width) : 0
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.accentColor.opacity(0.75))
                                        .frame(width: segmentWidth, height: 10)
                                        .offset(x: x, y: 4)
                                }
                            }
                        }
                        .frame(height: 18)

                        if let audioDuration {
                            let loopState = viewModel.config.audioLoopEnabled ? String(localized: "自动循环开启") : String(localized: "自动循环关闭")
                            Text(String(localized: "视频 \(videoDuration, specifier: "%.2f")s · 音频 \(audioDuration, specifier: "%.2f")s · \(loopState)"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        } else {
                            Text("未读取到音频时长，导出前会再次校验。")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            Button(viewModel.isAudioPreviewPlaying ? String(localized: "暂停试听") : String(localized: "试听当前时间点")) {
                                viewModel.toggleAudioPreview()
                            }
                            .disabled(!viewModel.canPreviewAudio)

                            Button("停止") {
                                viewModel.stopAudioPreview()
                            }
                            .disabled(!viewModel.isAudioPreviewPlaying)
                        }
                        .controlSize(.small)
                    }
                }

                previewSurface(
                    image: viewModel.previewImage,
                    placeholderSystemImage: "film",
                    placeholderText: String(localized: "尚未生成时间轴预览"),
                    accessibilityIdentifier: "timeline_preview_surface"
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(viewModel.previewSecond, specifier: "%.2f")s / \(viewModel.previewMaxSecond, specifier: "%.2f")s")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                            .accessibilityIdentifier("timeline_preview_duration")
                    }

                    TimelineScrubber(
                        value: $viewModel.previewSecond,
                        range: 0...max(viewModel.previewMaxSecond, 0.001),
                        audioSegments: audioSegments,
                        audioWaveformSamples: viewModel.audioWaveformSamples,
                        markers: imageSegmentStarts,
                        isEnabled: !(viewModel.isBusy || viewModel.imageURLs.isEmpty)
                    )
                    .onChange(of: viewModel.previewSecond) { _, _ in
                        viewModel.schedulePreviewRegeneration()
                        viewModel.syncAudioPreviewPosition()
                    }
                    .accessibilityIdentifier("timeline_preview_slider")

                    if let previewBlockedMessage {
                        Text(previewBlockedMessage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct TimelineScrubber: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let audioSegments: [(start: Double, end: Double)]
    let audioWaveformSamples: [CGFloat]
    let markers: [Double]
    let isEnabled: Bool

    private enum Metrics {
        static let knobSize: CGFloat = 14
        static let trackHeight: CGFloat = 3
        static let labelBandHeight: CGFloat = 10
        static let topPadding: CGFloat = 4
        static let labelToTrackGap: CGFloat = 0
        static let waveformHeight: CGFloat = 18
        static let waveformTopInset: CGFloat = 4
        static let railHeight: CGFloat = 28
        static let bottomPadding: CGFloat = 6
        static let labelWidth: CGFloat = 18

        static let totalHeight: CGFloat =
            topPadding + labelBandHeight + labelToTrackGap + railHeight + bottomPadding

        static let trackCenterY: CGFloat =
            topPadding + labelBandHeight + labelToTrackGap + railHeight / 2

        static let labelCenterY: CGFloat =
            topPadding + labelBandHeight / 2
    }

    private var progress: Double {
        let span = max(range.upperBound - range.lowerBound, 0.001)
        return min(max((value - range.lowerBound) / span, 0), 1)
    }

    private var normalizedMarkers: [Double] {
        let span = max(range.upperBound - range.lowerBound, 0.001)
        return markers
            .map { min(max(($0 - range.lowerBound) / span, 0), 1) }
            .sorted()
    }

    private var currentSectionIndex: Int? {
        guard !normalizedMarkers.isEmpty else { return nil }
        return normalizedMarkers.lastIndex(where: { progress >= $0 }) ?? 0
    }

    private var hasAudioWaveform: Bool {
        !audioSegments.isEmpty && !audioWaveformSamples.isEmpty
    }

    private func markerX(for marker: Double, availableWidth: CGFloat) -> CGFloat {
        let rawX = CGFloat(marker) * availableWidth + Metrics.knobSize / 2
        return min(
            max(rawX, Metrics.labelWidth / 2),
            max(availableWidth + Metrics.knobSize - Metrics.labelWidth / 2, Metrics.labelWidth / 2)
        )
    }

    private func isActiveMarker(_ index: Int) -> Bool {
        currentSectionIndex == index
    }

    private func markerLabelColor(for index: Int) -> Color {
        isActiveMarker(index) ? Color.accentColor.opacity(0.95) : .secondary.opacity(0.78)
    }

    private func markerTickColor(for index: Int) -> Color {
        isActiveMarker(index) ? Color.accentColor.opacity(0.72) : Color.white.opacity(0.14)
    }

    private func markerTickHeight(for index: Int) -> CGFloat {
        isActiveMarker(index) ? 16 : 11
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let availableWidth = max(width - Metrics.knobSize, 1)
            let knobOffset = CGFloat(progress) * availableWidth
            let labelIndices = visibleLabelIndices(for: width)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    }
                    .frame(height: Metrics.totalHeight)

                if hasAudioWaveform {
                    GeometryReader { waveformProxy in
                        let waveformWidth = max(waveformProxy.size.width - Metrics.knobSize, 1)

                        ForEach(Array(audioSegments.enumerated()), id: \.offset) { index, segment in
                            AudioWaveformOverlay(
                                samples: audioWaveformSamples,
                                range: range,
                                segment: segment,
                                availableWidth: waveformWidth,
                                height: Metrics.waveformHeight,
                                tint: index.isMultiple(of: 2)
                                    ? Color.accentColor.opacity(isEnabled ? 0.30 : 0.18)
                                    : Color.accentColor.opacity(isEnabled ? 0.22 : 0.14)
                            )
                            .offset(
                                x: Metrics.knobSize / 2,
                                y: Metrics.topPadding + Metrics.labelBandHeight + Metrics.waveformTopInset
                            )
                        }
                    }
                    .frame(height: Metrics.totalHeight)
                }

                ForEach(Array(normalizedMarkers.enumerated()), id: \.offset) { index, marker in
                    if labelIndices.contains(index) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(isActiveMarker(index) ? .semibold : .regular))
                            .foregroundStyle(markerLabelColor(for: index))
                            .monospacedDigit()
                            .frame(width: Metrics.labelWidth, alignment: .center)
                            .position(
                                x: markerX(for: marker, availableWidth: availableWidth),
                                y: Metrics.labelCenterY
                            )
                    }
                }

                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: Metrics.trackHeight)
                    .offset(y: Metrics.trackCenterY - Metrics.trackHeight / 2)

                Capsule()
                    .fill(Color.accentColor.opacity(isEnabled ? 0.95 : 0.45))
                    .frame(width: knobOffset + Metrics.knobSize / 2, height: Metrics.trackHeight)
                    .offset(y: Metrics.trackCenterY - Metrics.trackHeight / 2)

                ForEach(Array(normalizedMarkers.enumerated()), id: \.offset) { index, marker in
                    Capsule()
                        .fill(markerTickColor(for: index))
                        .frame(width: 1, height: markerTickHeight(for: index))
                        .offset(
                            x: CGFloat(marker) * availableWidth + Metrics.knobSize / 2,
                            y: Metrics.trackCenterY - markerTickHeight(for: index) / 2
                        )
                }

                Capsule()
                    .fill(Color.accentColor.opacity(isEnabled ? 1 : 0.55))
                    .frame(width: 2, height: 20)
                    .offset(
                        x: knobOffset + Metrics.knobSize / 2 - 1,
                        y: Metrics.trackCenterY - 10
                    )

                Circle()
                    .fill(isEnabled ? Color.white.opacity(0.96) : Color.white.opacity(0.55))
                    .frame(width: Metrics.knobSize, height: Metrics.knobSize)
                    .shadow(color: .black.opacity(0.28), radius: 4, y: 1)
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.22), lineWidth: 0.6)
                    }
                    .offset(
                        x: knobOffset,
                        y: Metrics.trackCenterY - Metrics.knobSize / 2
                    )
            }
            .frame(height: Metrics.totalHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard isEnabled else { return }
                        let clampedX = min(max(gesture.location.x - Metrics.knobSize / 2, 0), availableWidth)
                        let ratio = Double(clampedX / availableWidth)
                        value = range.lowerBound + ratio * (range.upperBound - range.lowerBound)
                    }
            )
            .opacity(isEnabled ? 1 : 0.65)
        }
        .frame(height: Metrics.totalHeight)
    }

    private func visibleLabelIndices(for width: CGFloat) -> Set<Int> {
        guard !normalizedMarkers.isEmpty else { return [] }

        let maxVisibleLabels = max(Int(width / 24), 2)
        let markerCount = normalizedMarkers.count
        let rawStep = max(Int(ceil(Double(markerCount) / Double(maxVisibleLabels))), 1)
        let preferredSteps = [1, 2, 5, 10, 15, 20, 25, 30]
        let step = preferredSteps.first(where: { $0 >= rawStep }) ?? rawStep

        var indices = Set(stride(from: 0, to: markerCount, by: step))
        indices.insert(0)
        indices.insert(markerCount - 1)
        if let currentSectionIndex {
            indices.insert(currentSectionIndex)
        }
        return indices
    }
}

private struct AudioWaveformOverlay: View {
    let samples: [CGFloat]
    let range: ClosedRange<Double>
    let segment: (start: Double, end: Double)
    let availableWidth: CGFloat
    let height: CGFloat
    let tint: Color

    private var span: Double {
        max(range.upperBound - range.lowerBound, 0.001)
    }

    private var segmentWidth: CGFloat {
        max(CGFloat((segment.end - segment.start) / span) * availableWidth, 1)
    }

    private var offsetX: CGFloat {
        CGFloat((segment.start - range.lowerBound) / span) * availableWidth
    }

    var body: some View {
        HStack(alignment: .center, spacing: 1) {
            ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                Capsule(style: .continuous)
                    .fill(tint)
                    .frame(maxWidth: .infinity)
                    .frame(height: max(2, sample * height))
            }
        }
        .frame(width: segmentWidth, height: height, alignment: .center)
        .offset(x: offsetX)
        .clipped()
    }
}

private extension View {
    func previewSurface(
        image: CGImage?,
        placeholderSystemImage: String,
        placeholderText: String,
        accessibilityIdentifier: String
    ) -> some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 420)
                    .padding(.vertical, 4)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 420)
                    .overlay {
                        VStack(spacing: 6) {
                            Image(systemName: placeholderSystemImage)
                            Text(placeholderText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

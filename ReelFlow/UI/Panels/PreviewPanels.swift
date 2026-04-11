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
        static let waveformHeight: CGFloat = 16
        static let baselineGapToLabels: CGFloat = 12
        static let bottomPadding: CGFloat = 12
        static let labelWidth: CGFloat = 18

        static let totalHeight: CGFloat =
            topPadding + labelBandHeight + labelToTrackGap + waveformHeight + baselineGapToLabels + bottomPadding

        static let baselineY: CGFloat =
            topPadding + labelBandHeight + labelToTrackGap + waveformHeight + baselineGapToLabels

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
        isActiveMarker(index) ? Color.accentColor.opacity(0.96) : Color.white.opacity(0.60)
    }

    private func markerTickColor(for index: Int) -> Color {
        isActiveMarker(index) ? Color.accentColor.opacity(0.78) : Color.white.opacity(0.22)
    }

    private func markerTickHeight(for index: Int) -> CGFloat {
        markerTickTopExtension(for: index) + markerTickBottomExtension(for: index)
    }

    private func markerTickTopExtension(for index: Int) -> CGFloat {
        isActiveMarker(index) ? 16 : 12
    }

    private func markerTickBottomExtension(for index: Int) -> CGFloat {
        isActiveMarker(index) ? 3 : 2
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let availableWidth = max(width - Metrics.knobSize, 1)
            let knobOffset = CGFloat(progress) * availableWidth
            let labelIndices = visibleLabelIndices(for: width)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    }
                    .frame(width: width, height: Metrics.totalHeight)

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
                                playedProgress: progress,
                                activeTint: index.isMultiple(of: 2)
                                    ? Color(red: 0.50, green: 0.64, blue: 0.78).opacity(isEnabled ? 0.44 : 0.24)
                                    : Color(red: 0.46, green: 0.60, blue: 0.74).opacity(isEnabled ? 0.40 : 0.22),
                                inactiveTint: index.isMultiple(of: 2)
                                    ? Color(red: 0.53, green: 0.57, blue: 0.63).opacity(isEnabled ? 0.16 : 0.10)
                                    : Color(red: 0.48, green: 0.53, blue: 0.60).opacity(isEnabled ? 0.14 : 0.09)
                            )
                            .offset(
                                x: Metrics.knobSize / 2,
                                y: Metrics.baselineY - Metrics.waveformHeight
                            )
                        }
                    }
                    .frame(width: width, height: Metrics.totalHeight)
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
                    .fill(Color.white.opacity(0.10))
                    .frame(height: Metrics.trackHeight)
                    .offset(x: 0, y: Metrics.baselineY - Metrics.trackHeight / 2)

                Capsule()
                    .fill(Color.accentColor.opacity(isEnabled ? 0.9 : 0.42))
                    .frame(width: knobOffset + Metrics.knobSize / 2, height: Metrics.trackHeight)
                    .offset(x: 0, y: Metrics.baselineY - Metrics.trackHeight / 2)

                ForEach(Array(normalizedMarkers.enumerated()), id: \.offset) { index, marker in
                    Capsule()
                        .fill(markerTickColor(for: index))
                        .frame(width: 1, height: markerTickHeight(for: index))
                        .offset(
                            x: CGFloat(marker) * availableWidth + Metrics.knobSize / 2,
                            y: Metrics.baselineY - markerTickTopExtension(for: index)
                        )
                }

                Capsule()
                    .fill(Color.accentColor.opacity(isEnabled ? 1 : 0.55))
                    .frame(width: 2, height: 20)
                    .offset(
                        x: knobOffset + Metrics.knobSize / 2 - 1,
                        y: Metrics.baselineY - 10
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
                        y: Metrics.baselineY - Metrics.knobSize / 2
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
    let playedProgress: Double
    let activeTint: Color
    let inactiveTint: Color

    private var span: Double {
        max(range.upperBound - range.lowerBound, 0.001)
    }

    private var segmentWidth: CGFloat {
        max(CGFloat((segment.end - segment.start) / span) * availableWidth, 1)
    }

    private var offsetX: CGFloat {
        CGFloat((segment.start - range.lowerBound) / span) * availableWidth
    }

    private var playedFraction: CGFloat {
        let segmentStart = CGFloat((segment.start - range.lowerBound) / span)
        let segmentEnd = CGFloat((segment.end - range.lowerBound) / span)
        let played = CGFloat(playedProgress)
        guard segmentEnd > segmentStart else { return 0 }
        let clamped = min(max((played - segmentStart) / (segmentEnd - segmentStart), 0), 1)
        return clamped
    }

    var body: some View {
        ZStack(alignment: .leading) {
            waveformBars(tint: inactiveTint)

            waveformBars(tint: activeTint)
                .mask(alignment: .leading) {
                    Rectangle()
                        .frame(width: max(0, segmentWidth * playedFraction))
                }
        }
        .frame(width: segmentWidth, height: height, alignment: .bottom)
        .offset(x: offsetX)
        .clipped()
    }

    @ViewBuilder
    private func waveformBars(tint: Color) -> some View {
        HStack(alignment: .bottom, spacing: 1) {
            ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                let emphasizedSample = max(sample - 0.06, 0)
                let peakHeight = max(2, pow(emphasizedSample, 1.35) * height * 1.28)
                UnevenRoundedRectangle(
                    topLeadingRadius: 2,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 2,
                    style: .continuous
                )
                    .fill(tint)
                    .frame(maxWidth: .infinity)
                    .frame(height: peakHeight)
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
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

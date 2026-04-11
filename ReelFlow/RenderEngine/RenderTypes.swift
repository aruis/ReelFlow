import CoreGraphics
import CoreImage
import Foundation

enum TransitionStyle: String, Codable, Sendable {
    case crossfade
}

enum PhotoOrientationStrategy: String, Codable, Sendable {
    case followAsset
    case forceLandscape
    case forcePortrait
}

enum PlatePlacement: String, Codable, Sendable {
    case frame
    case canvasBottom
}

enum PlateFontStyle: String, Codable, CaseIterable, Sendable {
    case classicMono
    case modernSans
    case editorial

    var displayName: String {
        switch self {
        case .classicMono:
            return String(localized: "经典等宽")
        case .modernSans:
            return String(localized: "现代无衬线")
        case .editorial:
            return String(localized: "编辑衬线")
        }
    }
}

enum ShutterSoundSource: String, Codable, CaseIterable, Sendable {
    case preset
    case custom
}

enum ShutterSoundPreset: String, Codable, CaseIterable, Sendable {
    case canonEOS
    case nikonDSLR
    case sonyAlpha
    case panasonicLumix
    case fujifilmX
    case hasselblad500CM
    case leicaM

    nonisolated var displayName: String {
        switch self {
        case .canonEOS:
            return "Canon EOS"
        case .nikonDSLR:
            return "Nikon D850"
        case .sonyAlpha:
            return "Sony Alpha"
        case .panasonicLumix:
            return "Panasonic Lumix"
        case .fujifilmX:
            return "Fujifilm X"
        case .hasselblad500CM:
            return "Hasselblad 500C/M"
        case .leicaM:
            return "Leica M"
        }
    }

    nonisolated var resourceName: String {
        switch self {
        case .canonEOS:
            return "canon-eos-style"
        case .nikonDSLR:
            return "nikon-dslr-style"
        case .sonyAlpha:
            return "sony-alpha-style"
        case .panasonicLumix:
            return "panasonic-lumix-style"
        case .fujifilmX:
            return "fujifilm-x-style"
        case .hasselblad500CM:
            return "hasselblad-500cm-style"
        case .leicaM:
            return "leica-m-style"
        }
    }
}

enum KenBurnsIntensity: String, Codable, CaseIterable, Sendable {
    case small
    case medium
    case large

    var displayName: String {
        switch self {
        case .small:
            return String(localized: "小")
        case .medium:
            return String(localized: "中")
        case .large:
            return String(localized: "大")
        }
    }

    nonisolated var motionScale: CGFloat {
        switch self {
        case .small:
            return 0.7
        case .medium:
            return 1.0
        case .large:
            return 1.3
        }
    }
}

struct LayoutSettings: Codable, Sendable {
    let horizontalMargin: Double
    let topMargin: Double
    let bottomMargin: Double
    let innerPadding: Double

    nonisolated static let `default` = LayoutSettings(
        horizontalMargin: 180,
        topMargin: 72,
        bottomMargin: 96,
        innerPadding: 24
    )
}

struct PlateSettings: Codable, Sendable {
    nonisolated static let defaultTemplateText = "S {shutter}   A {aperture}   ISO {iso}   F {focal}"

    let enabled: Bool
    let height: Double
    let baselineOffset: Double
    let fontSize: Double
    let fontStyle: PlateFontStyle
    let placement: PlatePlacement
    let templateText: String

    nonisolated static let `default` = PlateSettings(
        enabled: true,
        height: 96,
        baselineOffset: 18,
        fontSize: 26,
        fontStyle: .classicMono,
        placement: .frame,
        templateText: Self.defaultTemplateText
    )

    nonisolated init(
        enabled: Bool,
        height: Double,
        baselineOffset: Double,
        fontSize: Double,
        fontStyle: PlateFontStyle = .classicMono,
        placement: PlatePlacement = .frame,
        templateText: String = PlateSettings.defaultTemplateText
    ) {
        self.enabled = enabled
        self.height = height
        self.baselineOffset = baselineOffset
        self.fontSize = fontSize
        self.fontStyle = fontStyle
        self.placement = placement
        self.templateText = templateText
    }
}

struct CanvasSettings: Codable, Sendable {
    let backgroundGray: Double
    let paperWhite: Double
    let strokeGray: Double
    let textGray: Double

    nonisolated static let `default` = CanvasSettings(
        backgroundGray: 0.09,
        paperWhite: 0.98,
        strokeGray: 0.82,
        textGray: 0.15
    )
}

struct AudioTrackSettings: Sendable {
    let sourceURL: URL
    let volume: Double
    let loopEnabled: Bool

    nonisolated init(sourceURL: URL, volume: Double = 1, loopEnabled: Bool = false) {
        self.sourceURL = sourceURL
        self.volume = max(0, min(volume, 1))
        self.loopEnabled = loopEnabled
    }
}

struct ShutterSoundTrackSettings: Sendable {
    let sourceURL: URL
    let volume: Double
    let delay: TimeInterval

    nonisolated init(sourceURL: URL, volume: Double = 1, delay: TimeInterval = 0) {
        self.sourceURL = sourceURL
        self.volume = max(0, min(volume, 1))
        self.delay = max(0, delay)
    }
}

struct WatermarkSettings: Sendable, Equatable {
    let text: String
    let textOpacity: Double
    let backgroundOpacity: Double
    let fontSize: Double
    let cornerRadius: Double
    let horizontalPadding: Double
    let verticalPadding: Double
    let inset: Double

    nonisolated static let reelFlowFreeTier = WatermarkSettings(
        text: "Made with ReelFlow",
        textOpacity: 0.68,
        backgroundOpacity: 0.18,
        fontSize: 22,
        cornerRadius: 12,
        horizontalPadding: 12,
        verticalPadding: 7,
        inset: 28
    )
}

struct RenderSettings {
    let outputSize: CGSize
    let fps: Int32
    let imageDuration: TimeInterval
    let transitionDuration: TimeInterval
    let transitionEnabled: Bool
    let transitionStyle: TransitionStyle
    let transitionDipDuration: TimeInterval
    let orientationStrategy: PhotoOrientationStrategy
    let enableKenBurns: Bool
    let kenBurnsIntensity: KenBurnsIntensity
    let prefetchRadius: Int
    let prefetchMaxConcurrent: Int
    let layout: LayoutSettings
    let plate: PlateSettings
    let canvas: CanvasSettings
    let audioTrack: AudioTrackSettings?
    let shutterSoundTrack: ShutterSoundTrackSettings?
    let watermark: WatermarkSettings?

    nonisolated init(
        outputSize: CGSize,
        fps: Int32,
        imageDuration: TimeInterval,
        transitionDuration: TimeInterval,
        transitionEnabled: Bool = true,
        transitionStyle: TransitionStyle = .crossfade,
        transitionDipDuration: TimeInterval = 0.18,
        orientationStrategy: PhotoOrientationStrategy = .followAsset,
        enableKenBurns: Bool,
        kenBurnsIntensity: KenBurnsIntensity = .medium,
        prefetchRadius: Int = 1,
        prefetchMaxConcurrent: Int = 2,
        layout: LayoutSettings = .default,
        plate: PlateSettings = .default,
        canvas: CanvasSettings = .default,
        audioTrack: AudioTrackSettings? = nil,
        shutterSoundTrack: ShutterSoundTrackSettings? = nil,
        watermark: WatermarkSettings? = nil
    ) {
        self.outputSize = outputSize
        self.fps = fps
        self.imageDuration = imageDuration
        self.transitionDuration = transitionDuration
        self.transitionEnabled = transitionEnabled
        self.transitionStyle = transitionStyle
        self.transitionDipDuration = max(0, transitionDipDuration)
        self.orientationStrategy = orientationStrategy
        self.enableKenBurns = enableKenBurns
        self.kenBurnsIntensity = kenBurnsIntensity
        self.prefetchRadius = max(0, prefetchRadius)
        self.prefetchMaxConcurrent = max(1, prefetchMaxConcurrent)
        self.layout = layout
        self.plate = plate
        self.canvas = canvas
        self.audioTrack = audioTrack
        self.shutterSoundTrack = shutterSoundTrack
        self.watermark = watermark
    }

    nonisolated static let mvp = RenderSettings(
        outputSize: CGSize(width: 1920, height: 1080),
        fps: 30,
        imageDuration: 3.0,
        transitionDuration: 0.6,
        transitionEnabled: true,
        transitionStyle: .crossfade,
        transitionDipDuration: 0.18,
        orientationStrategy: .followAsset,
        enableKenBurns: true,
        kenBurnsIntensity: .medium,
        prefetchRadius: 1,
        prefetchMaxConcurrent: 2,
        layout: .default,
        plate: .default,
        canvas: .default
    )

    nonisolated init(template: RenderTemplate) {
        self.init(
            outputSize: CGSize(width: template.output.width, height: template.output.height),
            fps: template.output.fps,
            imageDuration: template.timeline.imageDuration,
            transitionDuration: template.timeline.transitionDuration,
            transitionEnabled: template.transition.enabled,
            transitionStyle: template.transition.style,
            transitionDipDuration: template.transition.dipDuration,
            orientationStrategy: template.motion.orientationStrategy,
            enableKenBurns: template.motion.enableKenBurns,
            kenBurnsIntensity: template.motion.intensity,
            prefetchRadius: template.performance.prefetchRadius,
            prefetchMaxConcurrent: template.performance.prefetchMaxConcurrent,
            layout: .init(
                horizontalMargin: template.layout.horizontalMargin,
                topMargin: template.layout.topMargin,
                bottomMargin: template.layout.bottomMargin,
                innerPadding: template.layout.innerPadding
            ),
            plate: .init(
                enabled: template.plate.enabled,
                height: template.plate.height,
                baselineOffset: template.plate.baselineOffset,
                fontSize: template.plate.fontSize,
                fontStyle: template.plate.fontStyle,
                placement: template.plate.placement,
                templateText: template.plate.templateText
            ),
            canvas: .init(
                backgroundGray: template.canvas.backgroundGray,
                paperWhite: template.canvas.paperWhite,
                strokeGray: template.canvas.strokeGray,
                textGray: template.canvas.textGray
            ),
            audioTrack: template.audio.enabled ? .init(
                sourceURL: URL(fileURLWithPath: template.audio.filePath),
                volume: template.audio.volume,
                loopEnabled: template.audio.loopEnabled
            ) : nil,
            shutterSoundTrack: {
                guard template.shutterSound.enabled else { return nil }
                let resolvedURL: URL?
                switch template.shutterSound.source {
                case .preset:
                    resolvedURL = ShutterSoundCatalog.bundledURL(for: template.shutterSound.preset)
                case .custom:
                    let path = template.shutterSound.customFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
                    resolvedURL = path.isEmpty ? nil : URL(fileURLWithPath: path)
                }

                guard let resolvedURL else { return nil }
                return .init(
                    sourceURL: resolvedURL,
                    volume: template.shutterSound.volume,
                    delay: template.shutterSound.delay
                )
            }(),
            watermark: nil
        )
    }

    nonisolated func applying(watermark: WatermarkSettings?) -> RenderSettings {
        RenderSettings(
            outputSize: outputSize,
            fps: fps,
            imageDuration: imageDuration,
            transitionDuration: transitionDuration,
            transitionEnabled: transitionEnabled,
            transitionStyle: transitionStyle,
            transitionDipDuration: transitionDipDuration,
            orientationStrategy: orientationStrategy,
            enableKenBurns: enableKenBurns,
            kenBurnsIntensity: kenBurnsIntensity,
            prefetchRadius: prefetchRadius,
            prefetchMaxConcurrent: prefetchMaxConcurrent,
            layout: layout,
            plate: plate,
            canvas: canvas,
            audioTrack: audioTrack,
            shutterSoundTrack: shutterSoundTrack,
            watermark: watermark
        )
    }

    nonisolated var template: RenderTemplate {
        RenderTemplate(
            output: .init(
                width: Int(outputSize.width.rounded()),
                height: Int(outputSize.height.rounded()),
                fps: fps
            ),
            timeline: .init(
                imageDuration: imageDuration,
                transitionDuration: transitionDuration
            ),
            transition: .init(
                style: transitionStyle,
                enabled: transitionEnabled,
                dipDuration: transitionDipDuration
            ),
            motion: .init(
                enableKenBurns: enableKenBurns,
                intensity: kenBurnsIntensity,
                orientationStrategy: orientationStrategy
            ),
            performance: .init(
                prefetchRadius: prefetchRadius,
                prefetchMaxConcurrent: prefetchMaxConcurrent
            ),
            layout: .init(
                horizontalMargin: layout.horizontalMargin,
                topMargin: layout.topMargin,
                bottomMargin: layout.bottomMargin,
                innerPadding: layout.innerPadding
            ),
            plate: .init(
                enabled: plate.enabled,
                height: plate.height,
                baselineOffset: plate.baselineOffset,
                fontSize: plate.fontSize,
                fontStyle: plate.fontStyle,
                placement: plate.placement,
                templateText: plate.templateText
            ),
            canvas: .init(
                backgroundGray: canvas.backgroundGray,
                paperWhite: canvas.paperWhite,
                strokeGray: canvas.strokeGray,
                textGray: canvas.textGray
            ),
            audio: .init(
                enabled: audioTrack != nil,
                filePath: audioTrack?.sourceURL.path ?? "",
                volume: audioTrack?.volume ?? 1,
                loopEnabled: audioTrack?.loopEnabled ?? false
            ),
            shutterSound: .init(
                enabled: shutterSoundTrack != nil,
                source: .custom,
                preset: .canonEOS,
                customFilePath: shutterSoundTrack?.sourceURL.path ?? "",
                volume: shutterSoundTrack?.volume ?? 1,
                delay: shutterSoundTrack?.delay ?? 0
            ),
            plateEditorMode: nil,
            plateSimpleElements: nil
        )
    }

    nonisolated var effectiveTransitionDuration: TimeInterval {
        transitionEnabled ? transitionDuration : 0
    }
}

struct RenderTemplate: Codable, Sendable {
    nonisolated static let currentSchemaVersion = 7

    let schemaVersion: Int
    let output: Output
    let timeline: Timeline
    let transition: Transition
    let motion: Motion
    let performance: Performance
    let layout: Layout
    let plate: Plate
    let canvas: Canvas
    let audio: Audio
    let shutterSound: ShutterSound
    let plateEditorMode: PlateEditorMode?
    let plateSimpleElements: [PlateSimpleElement]?

    nonisolated init(
        schemaVersion: Int = RenderTemplate.currentSchemaVersion,
        output: Output,
        timeline: Timeline,
        transition: Transition,
        motion: Motion,
        performance: Performance,
        layout: Layout,
        plate: Plate,
        canvas: Canvas,
        audio: Audio = .default,
        shutterSound: ShutterSound = .default,
        plateEditorMode: PlateEditorMode? = nil,
        plateSimpleElements: [PlateSimpleElement]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.output = output
        self.timeline = timeline
        self.transition = transition
        self.motion = motion
        self.performance = performance
        self.layout = layout
        self.plate = plate
        self.canvas = canvas
        self.audio = audio
        self.shutterSound = shutterSound
        self.plateEditorMode = plateEditorMode
        self.plateSimpleElements = plateSimpleElements
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case output
        case timeline
        case transition
        case motion
        case performance
        case layout
        case plate
        case canvas
        case audio
        case shutterSound
        case plateEditorMode
        case plateSimpleElements
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        output = try container.decode(Output.self, forKey: .output)
        timeline = try container.decode(Timeline.self, forKey: .timeline)
        transition = try container.decodeIfPresent(Transition.self, forKey: .transition) ?? .default
        motion = try container.decode(Motion.self, forKey: .motion)
        performance = try container.decode(Performance.self, forKey: .performance)
        layout = try container.decodeIfPresent(Layout.self, forKey: .layout) ?? .default
        plate = try container.decodeIfPresent(Plate.self, forKey: .plate) ?? .default
        canvas = try container.decodeIfPresent(Canvas.self, forKey: .canvas) ?? .default
        audio = try container.decodeIfPresent(Audio.self, forKey: .audio) ?? .default
        shutterSound = try container.decodeIfPresent(ShutterSound.self, forKey: .shutterSound) ?? .default
        plateEditorMode = try container.decodeIfPresent(PlateEditorMode.self, forKey: .plateEditorMode)
        plateSimpleElements = try container.decodeIfPresent([PlateSimpleElement].self, forKey: .plateSimpleElements)
    }

    struct Output: Codable, Sendable {
        let width: Int
        let height: Int
        let fps: Int32
    }

    struct Timeline: Codable, Sendable {
        let imageDuration: TimeInterval
        let transitionDuration: TimeInterval
    }

    struct Transition: Codable, Sendable {
        let style: TransitionStyle
        let enabled: Bool
        let dipDuration: TimeInterval

        nonisolated static let `default` = Transition(style: .crossfade, enabled: true, dipDuration: 0.18)

        private enum CodingKeys: String, CodingKey {
            case style
            case enabled
            case dipDuration
        }

        nonisolated init(
            style: TransitionStyle,
            enabled: Bool = true,
            dipDuration: TimeInterval = 0.18
        ) {
            self.style = style
            self.enabled = enabled
            self.dipDuration = max(0, dipDuration)
        }

        nonisolated init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            style = try container.decodeIfPresent(TransitionStyle.self, forKey: .style) ?? .crossfade
            enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
            dipDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .dipDuration) ?? 0.18
        }
    }

    struct Motion: Codable, Sendable {
        let enableKenBurns: Bool
        let intensity: KenBurnsIntensity
        let orientationStrategy: PhotoOrientationStrategy

        private enum CodingKeys: String, CodingKey {
            case enableKenBurns
            case intensity
            case orientationStrategy
        }

        nonisolated init(
            enableKenBurns: Bool,
            intensity: KenBurnsIntensity = .medium,
            orientationStrategy: PhotoOrientationStrategy = .followAsset
        ) {
            self.enableKenBurns = enableKenBurns
            self.intensity = intensity
            self.orientationStrategy = orientationStrategy
        }

        nonisolated init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            enableKenBurns = try container.decode(Bool.self, forKey: .enableKenBurns)
            intensity = try container.decodeIfPresent(KenBurnsIntensity.self, forKey: .intensity) ?? .medium
            orientationStrategy = try container.decodeIfPresent(PhotoOrientationStrategy.self, forKey: .orientationStrategy) ?? .followAsset
        }
    }

    struct Performance: Codable, Sendable {
        let prefetchRadius: Int
        let prefetchMaxConcurrent: Int
    }

    struct Layout: Codable, Sendable {
        let horizontalMargin: Double
        let topMargin: Double
        let bottomMargin: Double
        let innerPadding: Double

        nonisolated static let `default` = Layout(
            horizontalMargin: 180,
            topMargin: 72,
            bottomMargin: 96,
            innerPadding: 24
        )
    }

    struct Plate: Codable, Sendable {
        let enabled: Bool
        let height: Double
        let baselineOffset: Double
        let fontSize: Double
        let fontStyle: PlateFontStyle
        let placement: PlatePlacement
        let templateText: String

        nonisolated static let `default` = Plate(
            enabled: true,
            height: 96,
            baselineOffset: 18,
            fontSize: 26,
            fontStyle: .classicMono,
            placement: .frame,
            templateText: PlateSettings.defaultTemplateText
        )

        private enum CodingKeys: String, CodingKey {
            case enabled
            case height
            case baselineOffset
            case fontSize
            case fontStyle
            case placement
            case templateText
        }

        nonisolated init(
            enabled: Bool,
            height: Double,
            baselineOffset: Double,
            fontSize: Double,
            fontStyle: PlateFontStyle = .classicMono,
            placement: PlatePlacement = .frame,
            templateText: String = PlateSettings.defaultTemplateText
        ) {
            self.enabled = enabled
            self.height = height
            self.baselineOffset = baselineOffset
            self.fontSize = fontSize
            self.fontStyle = fontStyle
            self.placement = placement
            self.templateText = templateText
        }

        nonisolated init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
            height = try container.decodeIfPresent(Double.self, forKey: .height) ?? 96
            baselineOffset = try container.decodeIfPresent(Double.self, forKey: .baselineOffset) ?? 18
            fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 26
            fontStyle = try container.decodeIfPresent(PlateFontStyle.self, forKey: .fontStyle) ?? .classicMono
            placement = try container.decodeIfPresent(PlatePlacement.self, forKey: .placement) ?? .frame
            templateText = try container.decodeIfPresent(String.self, forKey: .templateText) ?? PlateSettings.defaultTemplateText
        }
    }

    struct Canvas: Codable, Sendable {
        let backgroundGray: Double
        let paperWhite: Double
        let strokeGray: Double
        let textGray: Double

        nonisolated static let `default` = Canvas(
            backgroundGray: 0.09,
            paperWhite: 0.98,
            strokeGray: 0.82,
            textGray: 0.15
        )
    }

    struct Audio: Codable, Sendable {
        let enabled: Bool
        let filePath: String
        let volume: Double
        let loopEnabled: Bool

        nonisolated static let `default` = Audio(enabled: false, filePath: "", volume: 1, loopEnabled: false)

        private enum CodingKeys: String, CodingKey {
            case enabled
            case filePath
            case volume
            case loopEnabled
        }

        nonisolated init(enabled: Bool, filePath: String, volume: Double = 1, loopEnabled: Bool = false) {
            self.enabled = enabled && !filePath.isEmpty
            self.filePath = filePath
            self.volume = max(0, min(volume, 1))
            self.loopEnabled = loopEnabled
        }

        nonisolated init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
            let filePath = try container.decodeIfPresent(String.self, forKey: .filePath) ?? ""
            let volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? 1
            let loopEnabled = try container.decodeIfPresent(Bool.self, forKey: .loopEnabled) ?? false
            self.init(enabled: enabled, filePath: filePath, volume: volume, loopEnabled: loopEnabled)
        }
    }

    struct ShutterSound: Codable, Sendable {
        let enabled: Bool
        let source: ShutterSoundSource
        let preset: ShutterSoundPreset
        let customFilePath: String
        let volume: Double
        let delay: Double

        nonisolated static let `default` = ShutterSound(
            enabled: false,
            source: .preset,
            preset: .canonEOS,
            customFilePath: "",
            volume: 1,
            delay: 0
        )

        private enum CodingKeys: String, CodingKey {
            case enabled
            case source
            case preset
            case customFilePath
            case volume
            case delay
        }

        nonisolated init(
            enabled: Bool,
            source: ShutterSoundSource,
            preset: ShutterSoundPreset,
            customFilePath: String = "",
            volume: Double = 1,
            delay: Double = 0
        ) {
            self.enabled = enabled
            self.source = source
            self.preset = preset
            self.customFilePath = customFilePath
            self.volume = max(0, min(volume, 1))
            self.delay = max(0, delay)
        }

        nonisolated init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
            let source = try container.decodeIfPresent(ShutterSoundSource.self, forKey: .source) ?? .preset
            let preset = try container.decodeIfPresent(ShutterSoundPreset.self, forKey: .preset) ?? .canonEOS
            let customFilePath = try container.decodeIfPresent(String.self, forKey: .customFilePath) ?? ""
            let volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? 1
            let delay = try container.decodeIfPresent(Double.self, forKey: .delay) ?? 0
            self.init(
                enabled: enabled,
                source: source,
                preset: preset,
                customFilePath: customFilePath,
                volume: volume,
                delay: delay
            )
        }
    }
}

struct ExifInfo: Sendable {
    let shutter: String?
    let aperture: String?
    let iso: String?
    let focalLength: String?
    let date: String?
    let camera: String?
    let lens: String?

    nonisolated var plateText: String {
        resolvedPlateText(template: PlateSettings.defaultTemplateText)
    }

    nonisolated func resolvedPlateText(template: String) -> String {
        let normalized = template.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }
        let source = normalized
        return source
            .replacingOccurrences(of: "{shutter}", with: shutter ?? "--")
            .replacingOccurrences(of: "{aperture}", with: aperture ?? "--")
            .replacingOccurrences(of: "{iso}", with: iso ?? "--")
            .replacingOccurrences(of: "{focal}", with: focalLength ?? "--")
            .replacingOccurrences(of: "{date}", with: date ?? "--")
            .replacingOccurrences(of: "{camera}", with: camera ?? "--")
            .replacingOccurrences(of: "{lens}", with: lens ?? "--")
    }
}

struct RenderAsset {
    let url: URL
    let image: CIImage
    let exif: ExifInfo
}

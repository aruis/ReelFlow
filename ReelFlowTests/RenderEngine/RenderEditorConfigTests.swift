import Foundation
import Testing
@testable import ReelFlow

struct RenderEditorConfigTests {
    @Test
    func clampKeepsConfigInsideSafeRange() {
        var config = RenderEditorConfig()
        config.outputWidth = 100
        config.outputHeight = 100
        config.fps = 0
        config.imageDuration = 0
        config.transitionDuration = 10
        config.canvasBackgroundGray = -1
        config.canvasPaperWhite = 2
        config.canvasStrokeGray = -2
        config.canvasTextGray = 3
        config.horizontalMargin = -10
        config.topMargin = 1000
        config.bottomMargin = 1000
        config.innerPadding = -8
        config.plateHeight = 999
        config.plateBaselineOffset = -5
        config.plateFontSize = 100
        config.plateFontStyle = .editorial
        config.prefetchRadius = -3
        config.prefetchMaxConcurrent = 0
        config.audioEnabled = true
        config.audioFilePath = "/tmp/test.m4a"
        config.audioVolume = 2
        config.shutterSoundEnabled = true
        config.shutterSoundSource = .custom
        config.shutterSoundCustomFilePath = "/tmp/shutter.m4a"
        config.shutterSoundVolume = 2

        config.clampToSafeRange()

        #expect(config.outputWidth == RenderEditorConfig.outputWidthRange.lowerBound)
        #expect(config.outputHeight == RenderEditorConfig.outputHeightRange.lowerBound)
        #expect(config.fps == RenderEditorConfig.fpsRange.lowerBound)
        #expect(config.imageDuration == RenderEditorConfig.imageDurationRange.lowerBound)
        #expect(config.transitionDuration < config.imageDuration)
        #expect(config.canvasBackgroundGray == RenderEditorConfig.grayRange.lowerBound)
        #expect(config.canvasPaperWhite == RenderEditorConfig.grayRange.upperBound)
        #expect(config.canvasStrokeGray == RenderEditorConfig.grayRange.lowerBound)
        #expect(config.canvasTextGray == RenderEditorConfig.grayRange.upperBound)
        #expect(config.horizontalMargin == RenderEditorConfig.horizontalMarginRange.lowerBound)
        #expect(config.topMargin == RenderEditorConfig.topMarginRange.upperBound)
        #expect(config.bottomMargin == RenderEditorConfig.bottomMarginRange.upperBound)
        #expect(config.innerPadding == RenderEditorConfig.innerPaddingRange.lowerBound)
        #expect(config.plateHeight == RenderEditorConfig.plateHeightRange.upperBound)
        #expect(config.plateBaselineOffset == RenderEditorConfig.plateBaselineOffsetRange.lowerBound)
        #expect(config.plateFontSize == RenderEditorConfig.plateFontSizeRange.upperBound)
        #expect(config.prefetchRadius == RenderEditorConfig.prefetchRadiusRange.lowerBound)
        #expect(config.prefetchMaxConcurrent == RenderEditorConfig.prefetchMaxConcurrentRange.lowerBound)
        #expect(config.audioVolume == RenderEditorConfig.audioVolumeRange.upperBound)
        #expect(config.shutterSoundVolume == RenderEditorConfig.audioVolumeRange.upperBound)
    }

    @Test
    func templateRoundTripPreservesEditableFields() {
        var config = RenderEditorConfig()
        config.outputWidth = 2560
        config.outputHeight = 1440
        config.fps = 24
        config.imageDuration = 2.5
        config.transitionDuration = 0.5
        config.enableCrossfade = false
        config.transitionDipDuration = 0.23
        config.orientationStrategy = .forcePortrait
        config.frameStylePreset = .custom
        config.canvasBackgroundGray = 0.2
        config.canvasPaperWhite = 0.95
        config.canvasStrokeGray = 0.66
        config.canvasTextGray = 0.18
        config.horizontalMargin = 160
        config.topMargin = 66
        config.bottomMargin = 104
        config.innerPadding = 28
        config.plateEnabled = false
        config.plateHeight = 78
        config.plateBaselineOffset = 12
        config.plateFontSize = 22
        config.plateFontStyle = .modernSans
        config.platePlacement = .canvasBottom
        config.plateEditorMode = .custom
        config.plateTemplateText = "{date}   {camera}   ISO {iso}"
        config.enableKenBurns = false
        config.kenBurnsIntensity = .large
        config.prefetchRadius = 3
        config.prefetchMaxConcurrent = 4
        config.audioEnabled = true
        config.audioFilePath = "/tmp/bgm.m4a"
        config.audioVolume = 0.72
        config.audioLoopEnabled = true
        config.shutterSoundEnabled = true
        config.shutterSoundSource = .custom
        config.shutterSoundPreset = .sonyAlpha
        config.shutterSoundCustomFilePath = "/tmp/shutter.m4a"
        config.shutterSoundVolume = 0.64
        config.shutterSoundDelay = 0.35

        let rebuilt = RenderEditorConfig(template: config.template)

        #expect(rebuilt.outputWidth == config.outputWidth)
        #expect(rebuilt.outputHeight == config.outputHeight)
        #expect(rebuilt.fps == config.fps)
        #expect(rebuilt.imageDuration == config.imageDuration)
        #expect(rebuilt.transitionDuration == config.transitionDuration)
        #expect(rebuilt.enableCrossfade == config.enableCrossfade)
        #expect(rebuilt.transitionDipDuration == config.transitionDipDuration)
        #expect(rebuilt.orientationStrategy == config.orientationStrategy)
        #expect(rebuilt.frameStylePreset == config.frameStylePreset)
        #expect(rebuilt.canvasBackgroundGray == config.canvasBackgroundGray)
        #expect(rebuilt.canvasPaperWhite == config.canvasPaperWhite)
        #expect(rebuilt.canvasStrokeGray == config.canvasStrokeGray)
        #expect(rebuilt.canvasTextGray == config.canvasTextGray)
        #expect(rebuilt.horizontalMargin == config.horizontalMargin)
        #expect(rebuilt.topMargin == config.topMargin)
        #expect(rebuilt.bottomMargin == config.bottomMargin)
        #expect(rebuilt.innerPadding == config.innerPadding)
        #expect(rebuilt.plateEnabled == config.plateEnabled)
        #expect(rebuilt.plateHeight == config.plateHeight)
        #expect(rebuilt.plateBaselineOffset == config.plateBaselineOffset)
        #expect(rebuilt.plateFontSize == config.plateFontSize)
        #expect(rebuilt.plateFontStyle == config.plateFontStyle)
        #expect(rebuilt.platePlacement == config.platePlacement)
        #expect(rebuilt.plateEditorMode == .none)
        #expect(rebuilt.plateTemplateText == config.plateTemplateText)
        #expect(rebuilt.enableKenBurns == config.enableKenBurns)
        #expect(rebuilt.kenBurnsIntensity == config.kenBurnsIntensity)
        #expect(rebuilt.prefetchRadius == config.prefetchRadius)
        #expect(rebuilt.prefetchMaxConcurrent == config.prefetchMaxConcurrent)
        #expect(rebuilt.audioEnabled == config.audioEnabled)
        #expect(rebuilt.audioFilePath == config.audioFilePath)
        #expect(rebuilt.audioVolume == config.audioVolume)
        #expect(rebuilt.audioLoopEnabled == config.audioLoopEnabled)
        #expect(rebuilt.shutterSoundEnabled == config.shutterSoundEnabled)
        #expect(rebuilt.shutterSoundSource == config.shutterSoundSource)
        #expect(rebuilt.shutterSoundPreset == config.shutterSoundPreset)
        #expect(rebuilt.shutterSoundCustomFilePath == config.shutterSoundCustomFilePath)
        #expect(rebuilt.shutterSoundVolume == config.shutterSoundVolume)
        #expect(rebuilt.shutterSoundDelay == config.shutterSoundDelay)
    }

    @Test
    func simplePlateEditorStateRoundTripsInTemplate() {
        var config = RenderEditorConfig()
        config.plateEnabled = true
        config.plateEditorMode = .simple
        config.plateSimpleElements = [
            .init(key: .date, enabled: true, prefix: "日期"),
            .init(key: .camera, enabled: true, prefix: ""),
            .init(key: .iso, enabled: false, prefix: "ISO ")
        ]

        let rebuilt = RenderEditorConfig(template: config.template)

        #expect(rebuilt.plateEditorMode == .simple)
        #expect(rebuilt.plateSimpleElements.map(\.key) == [.date, .camera, .iso, .lens, .shutter, .aperture, .focal])
        #expect(rebuilt.plateSimpleElements.map(\.enabled) == [true, true, false, true, true, true, false])
        #expect(rebuilt.plateSimpleElements.map(\.prefix) == ["日期", "", "ISO ", "", "S", "A", "F"])
        #expect(rebuilt.simplePlateTemplateText == "日期 {date}   {camera}   {lens}   S {shutter}   A {aperture}")
    }

    @Test
    func legacyTemplateImportPreservesPlateTemplateAsCustomEditing() {
        let legacyTemplate = RenderTemplate(
            schemaVersion: 6,
            output: .init(width: 1920, height: 1080, fps: 30),
            timeline: .init(imageDuration: 2.5, transitionDuration: 0.6),
            transition: .default,
            motion: .init(enableKenBurns: false, intensity: .medium, orientationStrategy: .followAsset),
            performance: .init(prefetchRadius: 1, prefetchMaxConcurrent: 2),
            layout: .default,
            plate: .init(
                enabled: true,
                height: 96,
                baselineOffset: 18,
                fontSize: 26,
                fontStyle: .classicMono,
                placement: .frame,
                templateText: "{camera}   {date}"
            ),
            canvas: .default
        )

        let rebuilt = RenderEditorConfig(template: legacyTemplate)

        #expect(rebuilt.plateEditorMode == .custom)
        #expect(rebuilt.plateTemplateText == "{camera}   {date}")
    }

    @Test
    func presetCanvasIsAppliedToRenderSettings() {
        var config = RenderEditorConfig()
        config.frameStylePreset = .contrast
        config.canvasBackgroundGray = 0.33
        config.canvasPaperWhite = 0.44
        config.canvasStrokeGray = 0.55
        config.canvasTextGray = 0.66

        let settings = config.renderSettings

        #expect(settings.canvas.backgroundGray == FrameStylePreset.contrast.canvas.backgroundGray)
        #expect(settings.canvas.paperWhite == FrameStylePreset.contrast.canvas.paperWhite)
        #expect(settings.canvas.strokeGray == FrameStylePreset.contrast.canvas.strokeGray)
        #expect(settings.canvas.textGray == FrameStylePreset.contrast.canvas.textGray)
    }

    @Test
    func layoutAndPlateSettingsAreAppliedToRenderSettings() {
        var config = RenderEditorConfig()
        config.horizontalMargin = 150
        config.topMargin = 55
        config.bottomMargin = 92
        config.innerPadding = 20
        config.plateEnabled = false
        config.plateHeight = 72
        config.plateBaselineOffset = 10
        config.plateFontSize = 21
        config.plateFontStyle = .editorial

        let settings = config.renderSettings

        #expect(settings.layout.horizontalMargin == 150)
        #expect(settings.layout.topMargin == 55)
        #expect(settings.layout.bottomMargin == 92)
        #expect(settings.layout.innerPadding == 20)
        #expect(settings.plate.enabled == false)
        #expect(settings.plate.height == 72)
        #expect(settings.plate.baselineOffset == 10)
        #expect(settings.plate.fontSize == 21)
        #expect(settings.plate.fontStyle == .editorial)
    }

    @Test
    func simplePlateDefaultsIncludeDateButKeepItDisabled() {
        let config = RenderEditorConfig()

        let keys = config.plateSimpleElements.map(\.key)

        #expect(keys.contains(.date))
        #expect(config.plateSimpleElements.first(where: { $0.key == .date })?.enabled == false)
        #expect(config.plateSimpleElements.first(where: { $0.key == .focal })?.enabled == false)
    }

    @Test
    func simplePlateTemplateReflectsFieldVisibility() {
        var config = RenderEditorConfig()
        config.plateSimpleElements = [
            .init(key: .camera, enabled: true, prefix: ""),
            .init(key: .iso, enabled: true, prefix: "ISO "),
            .init(key: .date, enabled: false, prefix: "")
        ]

        #expect(config.simplePlateTemplateText == "{camera}   ISO {iso}   {lens}   S {shutter}   A {aperture}")
    }

    @Test
    func beginSimplePlateEditingSetsInternalModeToSimple() {
        var config = RenderEditorConfig()
        config.plateEnabled = true
        config.plateEditorMode = .custom

        config.beginSimplePlateEditing()

        #expect(config.plateEditorMode == .simple)
    }

    @Test
    func beginCustomPlateEditingSeedsTemplateFromSimpleMode() {
        var config = RenderEditorConfig()
        config.plateEnabled = true
        config.plateEditorMode = .simple
        config.plateSimpleElements = [
            .init(key: .camera, enabled: true, prefix: ""),
            .init(key: .shutter, enabled: true, prefix: "S ")
        ]
        config.plateTemplateText = "legacy template"

        config.beginCustomPlateEditing()

        #expect(config.plateEditorMode == .custom)
        #expect(config.plateTemplateText == "{camera}   S {shutter}   {lens}   A {aperture}   ISO {iso}")
    }

    @Test
    func audioEnabledWithoutFilePathIsInvalid() {
        var config = RenderEditorConfig()
        config.audioEnabled = true
        config.audioFilePath = " "

        #expect(config.invalidMessage?.contains("音频") == true)
    }

    @Test
    func shutterSoundEnabledWithoutResolvedTrackIsInvalid() {
        var config = RenderEditorConfig()
        config.shutterSoundEnabled = true
        config.shutterSoundSource = .custom
        config.shutterSoundCustomFilePath = " "

        #expect(config.invalidMessage?.contains("快门声") == true)
    }

    @Test
    func customShutterSoundIsAppliedToRenderSettings() {
        var config = RenderEditorConfig()
        config.shutterSoundEnabled = true
        config.shutterSoundSource = .custom
        config.shutterSoundCustomFilePath = "/tmp/shutter.m4a"
        config.shutterSoundVolume = 0.58
        config.shutterSoundDelay = 0.27

        let settings = config.renderSettings

        #expect(settings.shutterSoundTrack?.sourceURL.path == "/tmp/shutter.m4a")
        #expect(settings.shutterSoundTrack?.volume == 0.58)
        #expect(settings.shutterSoundTrack?.delay == 0.27)
    }

    @Test
    func settingImageDurationSafelyAlsoKeepsTransitionValid() {
        var config = RenderEditorConfig()
        config.imageDuration = 3
        config.transitionDuration = 1.8

        config.setImageDurationSafely(1.2)

        #expect(config.imageDuration == 1.2)
        #expect(config.transitionDuration < config.imageDuration)
        #expect(abs(config.transitionDuration - 1.15) < 0.0001)
    }

    @Test
    func settingTransitionDurationSafelyClampsToImageDuration() {
        var config = RenderEditorConfig()
        config.imageDuration = 1.4

        config.setTransitionDurationSafely(2)

        #expect(config.transitionDuration < config.imageDuration)
        #expect(abs(config.transitionDuration - 1.35) < 0.0001)
    }
}

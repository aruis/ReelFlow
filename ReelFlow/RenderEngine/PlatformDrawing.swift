import CoreGraphics
import Foundation
import CoreText

enum PlatformDrawing {
    nonisolated static func textColor(gray: CGFloat, alpha: CGFloat = 1) -> CGColor {
        CGColor(gray: gray, alpha: alpha)
    }

    nonisolated static func systemFont(ofSize size: CGFloat) -> CTFont {
        CTFontCreateUIFontForLanguage(.system, size, nil) ?? CTFontCreateWithName("HelveticaNeue" as CFString, size, nil)
    }

    nonisolated static func monospacedFont(ofSize size: CGFloat) -> CTFont {
        let descriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontTraitsAttribute: [
                kCTFontSymbolicTrait: CTFontSymbolicTraits.traitMonoSpace.rawValue
            ],
            kCTFontSizeAttribute: size
        ] as CFDictionary)
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }

    nonisolated static func serifFont(ofSize size: CGFloat) -> CTFont {
        for fallbackName in ["NewYork-Regular", "TimesNewRomanPSMT", "Times New Roman", "Georgia"] {
            let font = CTFontCreateWithName(fallbackName as CFString, size, nil)
            if CTFontGetSize(font) > 0 {
                return font
            }
        }

        return systemFont(ofSize: size)
    }

    nonisolated static func plateFont(style: PlateFontStyle, ofSize size: CGFloat) -> CTFont {
        switch style {
        case .classicMono:
            return monospacedFont(ofSize: size)
        case .modernSans:
            return systemFont(ofSize: size)
        case .editorial:
            return serifFont(ofSize: size)
        }
    }
}

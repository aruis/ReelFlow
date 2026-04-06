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
}

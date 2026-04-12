import Foundation
import Testing

struct LocalizationCatalogTests {
    private var catalogURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("ReelFlow/Localizable.xcstrings")
    }

    private func loadCatalog() throws -> [String: Any] {
        let data = try Data(contentsOf: catalogURL)
        let object = try JSONSerialization.jsonObject(with: data)
        let root = try #require(object as? [String: Any])
        return try #require(root["strings"] as? [String: Any])
    }

    private func englishValue(for key: String, in strings: [String: Any]) throws -> String {
        let entry = try #require(strings[key] as? [String: Any])
        let localizations = try #require(entry["localizations"] as? [String: Any])
        let english = try #require(localizations["en"] as? [String: Any])
        let stringUnit = try #require(english["stringUnit"] as? [String: Any])
        return try #require(stringUnit["value"] as? String)
    }

    @Test
    func everyLiveStringHasEnglishLocalization() throws {
        let strings = try loadCatalog()

        let missingEnglish = strings.keys.sorted().filter { key in
            // Xcode string catalogs may include an empty reserved entry that is not a user-facing string.
            if key.isEmpty { return false }
            guard let entry = strings[key] as? [String: Any] else { return true }
            if entry["extractionState"] as? String == "stale" {
                return false
            }
            let localizations = entry["localizations"] as? [String: Any]
            return localizations?["en"] == nil
        }

        #expect(missingEnglish.isEmpty)
    }

    @Test
    func reviewedEnglishTermsRemainStableForKeySettingsStrings() throws {
        let strings = try loadCatalog()

        // Lock only domain terms that would be confusing if they drift again.
        let expectedEnglishTerms = [
            "背景声音": "Audio Track",
            "边框灰度": "Border Gray Level",
            "不显示铭牌": "Hide Caption"
        ]

        for (key, expectedValue) in expectedEnglishTerms {
            #expect(try englishValue(for: key, in: strings) == expectedValue)
        }
    }
}

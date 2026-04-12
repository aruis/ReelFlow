import Foundation

enum LocalizedFormatting {
    static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }
}

import Foundation

func shortText(_ value: String, limit: Int = 30) -> String {
    guard value.count > limit else {
        return value
    }

    let trimmedLimit = max(1, limit - 3)
    return String(value.prefix(trimmedLimit)) + "..."
}

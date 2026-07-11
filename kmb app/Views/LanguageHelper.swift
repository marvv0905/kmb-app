import SwiftUI

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case traditionalChinese = "zh"

    var label: String {
        switch self {
        case .english: return "English"
        case .traditionalChinese: return "繁體中文"
        }
    }
}

struct LanguageHelper {
    @AppStorage("app_language") private static var storedLanguage: String = AppLanguage.english.rawValue

    static var current: AppLanguage {
        AppLanguage(rawValue: storedLanguage) ?? .english
    }

    static func set(_ language: AppLanguage) {
        storedLanguage = language.rawValue
    }

    static func stopName(en: String, tc: String, sc: String) -> String {
        current == .english ? en : tc
    }

    static func routeDest(en: String, tc: String, sc: String) -> String {
        current == .english ? en : tc
    }

    static func remark(en: String, tc: String, sc: String) -> String? {
        let text = current == .english ? en : tc
        return text.isEmpty ? nil : text
    }
}

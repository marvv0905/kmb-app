import SwiftUI

enum BrutalTheme {
    static let bg = Color(white: 0.95)
    static let surface = Color(white: 0.90)
    static let text = Color.black
    static let textSecondary = Color(white: 0.40)
    static let accent = Color.kmbRed
    static let border = Color.black
    static let borderWidth: CGFloat = 1.5
    static let cardBorderWidth: CGFloat = 2
    static let radius: CGFloat = 0
    static let shadowOffset: CGFloat = 2
    static let shadowPressedOffset: CGFloat = 1
}

extension Font {
    static let brutalBody = Font.custom("ArchivoBlack-Regular", size: 15)
    static let brutalSmall = Font.custom("ArchivoBlack-Regular", size: 12)
    static let brutalTitle = Font.custom("ArchivoBlack-Regular", size: 20)
    static let brutalNumber = Font.custom("ArchivoBlack-Regular", size: 24)
    static let brutalTab = Font.custom("ArchivoBlack-Regular", size: 9)
}

extension Font {
    static let brutalChineseBody = Font.system(size: 15, weight: .heavy)
    static let brutalChineseSmall = Font.system(size: 12, weight: .heavy)
    static let brutalChineseTitle = Font.system(size: 20, weight: .heavy)
}

struct BrutalDivider: View {
    var body: some View {
        Rectangle()
            .fill(BrutalTheme.border)
            .frame(height: 1)
    }
}

struct NavigationBarBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(Color(uiColor: UIColor(bgHex: 0xF2F2F2)), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

extension View {
    func navigationBarBackground() -> some View {
        modifier(NavigationBarBackground())
    }
}

extension UIColor {
    convenience init(bgHex: Int) {
        self.init(
            red: CGFloat((bgHex >> 16) & 0xFF) / 255.0,
            green: CGFloat((bgHex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(bgHex & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}

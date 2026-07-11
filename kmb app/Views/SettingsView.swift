import SwiftUI

struct SettingsView: View {
    @AppStorage("app_language") private var language: String = AppLanguage.english.rawValue

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text("Language / 語言")
                    .font(.brutalChineseTitle)

                HStack(spacing: 0) {
                    ForEach(AppLanguage.allCases, id: \.rawValue) { lang in
                        Button {
                            language = lang.rawValue
                        } label: {
                            Text(lang.label)
                                .font(.brutalChineseBody)
                                .foregroundStyle(language == lang.rawValue ? .white : BrutalTheme.text)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(language == lang.rawValue ? BrutalTheme.accent : BrutalTheme.bg)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .overlay(
                    Rectangle()
                        .stroke(BrutalTheme.border, lineWidth: BrutalTheme.cardBorderWidth)
                )
                .shadow(color: .black.opacity(0.08), radius: 0, x: BrutalTheme.shadowOffset, y: BrutalTheme.shadowOffset)

                Spacer()
            }
            .padding()
            .background(BrutalTheme.bg)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackground()
        }
    }
}

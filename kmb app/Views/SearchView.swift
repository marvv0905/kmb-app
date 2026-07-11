import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                inputDisplay

                if !viewModel.inputText.isEmpty {
                    resultsArea
                } else {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxHeight: .infinity)
            .background(BrutalTheme.bg)
            .overlay(alignment: .bottom) {
                keypad
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackground()
            .onAppear { viewModel.loadRoutesFromDB() }
        }
    }

    private var inputDisplay: some View {
        HStack {
            Text(viewModel.inputText.isEmpty ? "Enter route number" : viewModel.inputText)
                .font(viewModel.inputText.isEmpty ? .brutalBody : .brutalNumber)
                .foregroundStyle(viewModel.inputText.isEmpty ? BrutalTheme.textSecondary : BrutalTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !viewModel.inputText.isEmpty {
                Button {
                    viewModel.backspace()
                } label: {
                    Image(systemName: "delete.backward.fill")
                        .font(.title3)
                        .foregroundStyle(BrutalTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(BrutalTheme.bg)
        .overlay(alignment: .bottom) {
            BrutalDivider()
        }
    }

    private var resultsArea: some View {
        Group {
            if viewModel.isLoadingRoutes {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text("Loading routes...")
                        .font(.brutalBody)
                        .foregroundStyle(BrutalTheme.textSecondary)
                }
                .padding()
            } else if viewModel.searchResults.isEmpty {
                Text("No routes found")
                    .font(.brutalBody)
                    .foregroundStyle(BrutalTheme.textSecondary)
                    .padding()
            } else {
                List {
                    ForEach(viewModel.searchResults) { route in
                        NavigationLink {
                            RouteDetailView(route: route)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(route.routeCode)
                                            .font(.brutalTitle)
                                            .foregroundStyle(BrutalTheme.accent)

                                        Text(route.bound == "O" ? "OUT" : "IN")
                                            .font(.brutalSmall)
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(route.bound == "O" ? BrutalTheme.accent : Color.blue)
                                    }
                                    Text(LanguageHelper.routeDest(en: route.originEn, tc: route.originTc, sc: route.originSc))
                                        .font(.brutalChineseSmall)
                                        .foregroundStyle(BrutalTheme.textSecondary)
                                }
                                Spacer()
                                Text(LanguageHelper.routeDest(en: route.destEn, tc: route.destTc, sc: route.destSc))
                                    .font(.brutalChineseSmall)
                                    .foregroundStyle(BrutalTheme.text)
                                    .multilineTextAlignment(.trailing)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(BrutalTheme.bg)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, 280, for: .scrollContent)
            }
        }
    }

    private var keypad: some View {
        HStack(spacing: 0) {
            numericKeypad
                .frame(maxWidth: .infinity)

            Rectangle()
                .fill(BrutalTheme.border)
                .frame(width: 1)

            letterKeypad
                .frame(width: 110)
        }
        .frame(height: 280)
        .background(BrutalTheme.bg)
        .overlay(alignment: .top) {
            BrutalDivider()
        }
    }

    private var numericKeypad: some View {
        VStack(spacing: 1) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { col in
                        BrutalKeyButton(label: viewModel.numericKeys[row][col], font: .brutalNumber) {
                            viewModel.appendDigit(viewModel.numericKeys[row][col])
                        }
                    }
                }
            }
            HStack(spacing: 1) {
                BrutalKeyButton(label: "C", font: .brutalTitle) {
                    viewModel.clearAll()
                }
                BrutalKeyButton(label: "0", font: .brutalNumber) {
                    viewModel.appendDigit("0")
                }
                BrutalKeyButton(label: "⌫", font: .brutalNumber) {
                    viewModel.backspace()
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var letterKeypad: some View {
        VStack(spacing: 1) {
            ForEach(viewModel.letterKeys.indices, id: \.self) { i in
                let pair = viewModel.letterKeys[i]
                HStack(spacing: 1) {
                    BrutalKeyButton(label: pair[0], font: .brutalTitle) {
                        viewModel.appendLetter(pair[0])
                    }
                    if pair.count > 1 {
                        BrutalKeyButton(label: pair[1], font: .brutalTitle) {
                            viewModel.appendLetter(pair[1])
                        }
                    } else {
                        Color.clear
                    }
                }
            }
        }
        .padding(1)
        .background(BrutalTheme.bg)
    }
}

struct BrutalKeyButton: View {
    let label: String
    var font: Font = .brutalTitle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(font)
                .foregroundStyle(BrutalTheme.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(BrutalTheme.bg)
                .overlay(
                    Rectangle()
                        .stroke(BrutalTheme.border.opacity(0.3), lineWidth: 0.5)
                )
        }
    }
}

import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.nearbyStops.isEmpty {
                    ProgressView("Loading nearby stops...")
                        .font(.brutalBody)
                } else if let error = viewModel.errorMessage, viewModel.nearbyStops.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 40, weight: .heavy))
                        Text("Unable to load stops")
                            .font(.brutalTitle)
                        Text(error)
                            .font(.brutalChineseSmall)
                            .foregroundStyle(BrutalTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.nearbyStops.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bus")
                            .font(.system(size: 40, weight: .heavy))
                        Text("No nearby stops")
                            .font(.brutalTitle)
                        Text("No bus stops found within 500m")
                            .font(.brutalChineseSmall)
                            .foregroundStyle(BrutalTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if viewModel.isSyncing {
                            HStack {
                                ProgressView().scaleEffect(0.8)
                                Text("Updating stop data...")
                                    .font(.brutalSmall)
                                    .foregroundStyle(BrutalTheme.textSecondary)
                            }
                            .listRowBackground(BrutalTheme.bg)
                        }

                        ForEach(viewModel.nearbyStops) { item in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.displayName)
                                        .font(.brutalChineseBody)

                                    Text("\(Int(item.distance))m")
                                        .font(.brutalSmall)
                                        .foregroundStyle(BrutalTheme.textSecondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    ForEach(item.etas.prefix(3)) { eta in
                                        HomeETALabel(eta: eta)
                                    }
                                    if item.etas.isEmpty && !viewModel.isLoading {
                                        Text("—")
                                            .font(.brutalSmall)
                                            .foregroundStyle(BrutalTheme.textSecondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(BrutalTheme.bg)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(BrutalTheme.bg)
            .navigationTitle("Nearby")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackground()
            .task {
                await viewModel.start()
                await viewModel.etaPollingLoop()
            }
            .refreshable {
                await viewModel.refreshStops()
            }
        }
    }
}

struct HomeETALabel: View {
    let eta: ArrivalETA

    var body: some View {
        HStack(spacing: 6) {
            Text(eta.routeCode)
                .font(.brutalSmall)
                .foregroundStyle(BrutalTheme.textSecondary)
            if let minutes = eta.minutesAway {
                Text(minutes < 0 ? "Due" : "\(minutes) min")
                    .font(.brutalSmall)
                    .foregroundStyle(minutes <= 3 ? BrutalTheme.accent : BrutalTheme.text)
            }
        }
    }
}

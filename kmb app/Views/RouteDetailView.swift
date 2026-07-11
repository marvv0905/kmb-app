import SwiftUI
import MapKit

struct RouteDetailView: View {
    let route: BusRoute
    @State private var viewModel: RouteDetailViewModel

    init(route: BusRoute) {
        self.route = route
        _viewModel = State(initialValue: RouteDetailViewModel(route: route))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading stops...")
                    .font(.brutalBody)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 40, weight: .heavy))
                    Text("Unable to load data")
                        .font(.brutalTitle)
                    Text(error)
                        .font(.brutalChineseSmall)
                        .foregroundStyle(BrutalTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        routeMap
                            .frame(height: geometry.size.height * 0.5)
                        BrutalDivider()
                        stopList
                    }
                }
            }
        }
        .background(BrutalTheme.bg)
        .navigationTitle("Route \(route.routeCode)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackground()
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("Route \(route.routeCode)")
                        .font(.brutalTitle)
                        .foregroundStyle(BrutalTheme.accent)
                    Text(LanguageHelper.routeDest(en: route.destEn, tc: route.destTc, sc: route.destSc))
                        .font(.brutalChineseSmall)
                        .foregroundStyle(BrutalTheme.textSecondary)
                }
            }
        }
        .task { await viewModel.load() }
    }

    private var routeMap: some View {
        Map(position: $viewModel.mapPosition) {
            ForEach(viewModel.stopDetails) { stop in
                Annotation(stop.displayName, coordinate: stop.coordinate) {
                    BrutalStopMarker(
                        seq: stop.seq,
                        isSelected: viewModel.expandedSeq == stop.seq
                    )
                    .onTapGesture {
                        viewModel.selectStop(stop.seq)
                    }
                }
            }

            if viewModel.polylineCoords.count > 1 {
                MapPolyline(coordinates: viewModel.polylineCoords)
                    .stroke(BrutalTheme.accent.opacity(0.6), lineWidth: 3)
            }
        }
        .mapControlVisibility(.hidden)
    }

    private var stopList: some View {
        List {
            ForEach(viewModel.stopDetails) { stop in
                BrutalStopRow(
                    stop: stop,
                    isExpanded: viewModel.expandedSeq == stop.seq
                ) {
                    Task {
                        await viewModel.toggleStop(stop.seq)
                    }
                }
                .listRowBackground(viewModel.expandedSeq == stop.seq ? BrutalTheme.surface : BrutalTheme.bg)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

struct BrutalStopMarker: View {
    let seq: Int
    let isSelected: Bool

    private static let markerGrey = Color(white: 0.35)

    var body: some View {
        Text("\(seq)")
            .font(.brutalSmall)
            .foregroundStyle(.white)
            .frame(width: isSelected ? 28 : 24, height: isSelected ? 28 : 24)
            .background(isSelected ? BrutalTheme.accent : BrutalStopMarker.markerGrey)
            .shadow(color: .black.opacity(0.15), radius: 0, x: 2, y: 2)
    }
}

struct BrutalStopRow: View {
    let stop: RouteDetailViewModel.StopDetail
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack {
                    Text("\(stop.seq)")
                        .font(.brutalSmall)
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(isExpanded ? BrutalTheme.accent : Color(white: 0.35))

                    Text(stop.displayName)
                        .font(.brutalChineseBody)
                        .foregroundStyle(BrutalTheme.text)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .fontWeight(.heavy)
                        .foregroundStyle(BrutalTheme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 10)

            if isExpanded {
                VStack(spacing: 0) {
                    if stop.etas.isEmpty {
                        ProgressView()
                            .scaleEffect(0.7)
                            .padding(.leading, 32)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(stop.etas) { eta in
                            HStack(spacing: 6) {
                                if let minutes = eta.minutesAway {
                                    Text(minutes < 0 ? "Due" : "\(minutes) min")
                                        .font(.brutalSmall)
                                        .foregroundStyle(minutes <= 3 ? BrutalTheme.accent : BrutalTheme.text)
                                        .frame(minWidth: 50, alignment: .leading)
                                } else {
                                    Text("--")
                                        .font(.brutalSmall)
                                        .foregroundStyle(BrutalTheme.textSecondary)
                                        .frame(minWidth: 50, alignment: .leading)
                                }
                                if let remark = LanguageHelper.remark(en: eta.remarkEn, tc: eta.remarkTc, sc: eta.remarkSc) {
                                    Text(remark)
                                        .font(.brutalChineseSmall)
                                        .foregroundStyle(BrutalTheme.textSecondary)
                                }
                                Spacer()
                                if let etaTime = eta.etaTime {
                                    Text(etaTime, style: .time)
                                        .font(.brutalSmall)
                                        .foregroundStyle(BrutalTheme.textSecondary)
                                }
                            }
                            .padding(.leading, 32)
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.bottom, 10)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(BrutalTheme.border)
                        .frame(width: 1)
                        .padding(.leading, 11)
                }
            }
        }
        .overlay(alignment: .bottom) {
            BrutalDivider()
        }
    }
}

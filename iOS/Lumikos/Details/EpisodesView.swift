import SwiftUI

/// Seasons as expandable groups. Episodes are loaded when a season is opened for the first time.
struct EpisodesView: View {
    let model: DetailsViewModel
    let seasons: [SeasonInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Episodes").font(.title3.bold())
            ForEach(seasons) { season in
                DisclosureGroup {
                    Button("Mark the whole season") { Task { await model.toggleSeason(season) } }
                        .font(.footnote)
                    ForEach(model.episodes[season.number] ?? []) { episode in
                        episodeRow(season: season.number, episode: episode)
                    }
                    if model.episodes[season.number] == nil {
                        ProgressView().task { await model.loadEpisodes(season: season.number) }
                    }
                } label: {
                    HStack {
                        Text(season.name)
                        Spacer()
                        Text("\(watchedCount(season)) / \(season.episodeCount)").foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func episodeRow(season: Int, episode: Episode) -> some View {
        Button { Task { await model.toggleEpisode(season: season, episode: episode.number) } } label: {
            HStack {
                Image(systemName: model.isWatched(season: season, episode: episode.number) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(.green)
                Text("\(episode.number). \(episode.name)")
                Spacer()
            }
        }
        .foregroundStyle(.primary)
    }

    private func watchedCount(_ season: SeasonInfo) -> Int {
        (1...max(season.episodeCount, 1)).filter { model.isWatched(season: season.number, episode: $0) }.count
    }
}

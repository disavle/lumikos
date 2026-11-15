import SwiftUI

struct DetailsView: View {
    let model: DetailsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                actions
                if model.ratingsEnabled, model.isInList {
                    EmojiRating(rating: model.item?.rating) { rating in
                        Task { await model.setRating(rating) }
                    }
                    .frame(maxWidth: .infinity)
                }
                if let error = model.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
                if let overview = model.details?.card.overview ?? model.card.overview, !overview.isEmpty {
                    Text(overview)
                }
                if model.episodesEnabled, let seasons = model.details?.seasons, !seasons.isEmpty {
                    EpisodesView(model: model, seasons: seasons)
                }
            }
            .padding()
        }
        .navigationTitle(model.card.title)
        .task { await model.load() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            PosterImage(path: model.card.posterPath)
                .frame(width: 120, height: 180)
                .clipShape(.rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 6) {
                Text(model.card.title).font(.title2.bold())
                Text(subtitle(year: model.card.year, type: model.card.type)).foregroundStyle(.secondary)
                if let details = model.details {
                    Text(details.genres.joined(separator: ", ")).font(.subheadline)
                    if let runtime = details.runtime, runtime > 0 {
                        Text("\(runtime) min").font(.subheadline)
                    }
                    if !details.seasons.isEmpty {
                        Text("Seasons: \(details.seasons.count)").font(.subheadline)
                    }
                } else if model.errorMessage == nil {
                    ProgressView()
                }
            }
        }
    }

    private var actions: some View {
        HStack {
            if model.isInList {
                Button(role: .destructive) { Task { await model.remove() } } label: {
                    Label("Remove", systemImage: "heart.slash")
                }
            } else {
                Button { Task { await model.addToList() } } label: {
                    Label("Add to list", systemImage: "heart")
                }
                .accessibilityIdentifier(AXID.detailsAdd)
            }
            Button { Task { await model.markWatched() } } label: {
                Label("Watched", systemImage: model.item?.status == .watched ? "checkmark.circle.fill" : "checkmark.circle")
            }
            .accessibilityIdentifier(AXID.detailsWatched)
            Button { Task { await model.togglePin() } } label: {
                Label("Pin", systemImage: model.item?.pinned == true ? "pin.fill" : "pin")
            }
            .accessibilityIdentifier(AXID.detailsPin)
        }
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .font(.title3)
    }
}

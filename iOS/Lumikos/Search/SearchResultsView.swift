import SwiftUI

/// Rows with search results. Shown inside ListView while the search field has text.
struct SearchResultsView: View {
    let model: SearchViewModel
    /// Keys of titles that are already in my list.
    let inList: Set<String>

    var body: some View {
        if let error = model.errorMessage {
            Text(error).foregroundStyle(.red)
        }
        if model.isSearching && model.results.isEmpty {
            ProgressView().frame(maxWidth: .infinity)
        }
        ForEach(model.results, id: \.key) { card in
            HStack(spacing: 12) {
                Button { model.onOpenDetails?(card) } label: {
                    HStack(spacing: 12) {
                        PosterImage(path: card.posterPath, width: 154)
                            .frame(width: 50, height: 75)
                            .clipShape(.rect(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.title).font(.headline)
                            Text(subtitle(year: card.year, type: card.type))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .foregroundStyle(.primary)

                if inList.contains(card.key) || model.addedKeys.contains(card.key) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    Button { Task { await model.add(card) } } label: {
                        Image(systemName: "plus.circle").font(.title2)
                    }
                    .buttonStyle(.borderless)  // inside a List row, so only the icon reacts to taps
                    .accessibilityIdentifier(AXID.searchAdd)
                }
            }
            .accessibilityIdentifier(AXID.searchRow)
        }
    }
}

import Shared
import SwiftUI

struct ListView: View {
    @Bindable var model: ListViewModel
    @Bindable var search: SearchViewModel

    var body: some View {
        List {
            if search.query.isEmpty {
                myList
            } else {
                // While the search field has text, the screen shows TMDB results instead of my list.
                SearchResultsView(model: search, inList: Set(model.items.map(\.key)))
            }
        }
        .searchable(text: $search.query, prompt: "Find a movie or series")
        .task(id: search.query) { await search.search() }
        .overlay {
            if search.query.isEmpty && model.items.isEmpty {
                ContentUnavailableView("Your list is empty", systemImage: "heart",
                                       description: Text("Swipe right on the For you tab or search above."))
            }
        }
        .toolbar { toolbar }
        .refreshable { await model.refresh() }
        .task { await model.refresh() }
    }

    @ViewBuilder
    private var myList: some View {
        let sections = model.sections
        if !model.isOnline {
            OfflineBanner().listRowInsets(EdgeInsets())
        }
        if let error = model.errorMessage {
            Text(error).foregroundStyle(.red)
        }

        Picker("Show", selection: $model.filter) {
            Text("All").tag(ListViewModel.Filter.all)
            Text("Movies").tag(ListViewModel.Filter.movies)
            Text("Series").tag(ListViewModel.Filter.series)
        }
        .pickerStyle(.segmented)
        .listRowBackground(Color.clear)

        if !sections.pinned.isEmpty {
            Section("Watching now") {
                ForEach(sections.pinned, id: \.key) { row($0) }
            }
        }
        Section(sections.pinned.isEmpty ? "" : String(localized: "Everything else")) {
            ForEach(sections.rest, id: \.key) { row($0) }
        }
    }

    private func row(_ item: ListItem) -> some View {
        Button { model.onOpenDetails?(item) } label: {
            HStack(spacing: 12) {
                PosterImage(path: item.posterPath, width: 154)
                    .frame(width: 50, height: 75)
                    .clipShape(.rect(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.headline)
                    Text(subtitle(year: item.year, type: item.type))
                        .font(.subheadline).foregroundStyle(.secondary)
                    if item.type == .tv, let total = item.totalEpisodes, total > 0 {
                        // "12 / 40" episodes watched
                        ProgressView(value: Double(item.watchedEpisodes.count), total: Double(total)) {
                            Text("\(item.watchedEpisodes.count) / \(total)").font(.caption)
                        }
                    }
                }
                Spacer()
                if item.status == .watched { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                if let rating = item.rating { Text(EmojiRating.emoji[rating - 1]) }
            }
        }
        .foregroundStyle(.primary)
        .accessibilityIdentifier(AXID.listRow)
        // Swipe a row: pin or delete. Disabled offline: the server would not get it.
        .swipeActions(edge: .leading) {
            Button { Task { await model.togglePin(item) } } label: {
                Label(item.pinned ? LocalizedStringKey("Unpin") : "Pin", systemImage: item.pinned ? "pin.slash" : "pin")
            }
            .tint(.orange)
            .disabled(!model.isOnline)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { Task { await model.delete(item) } } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(!model.isOnline)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu("Sort", systemImage: "arrow.up.arrow.down") {
                Picker("Sort", selection: $model.sort) {
                    Text("Date added").tag(ListViewModel.Sort.added)
                    Text("My rating").tag(ListViewModel.Sort.rating)
                    Text("Title").tag(ListViewModel.Sort.title)
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Text("@\(model.nickname)")
                Button("Log out") { model.logOut() }
                Button("Delete account", role: .destructive) { Task { await model.deleteAccount() } }
            } label: {
                Image(systemName: "person.crop.circle")
            }
            .accessibilityIdentifier(AXID.listAccount)
        }
    }
}

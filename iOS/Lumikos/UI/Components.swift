import Shared
import SwiftUI

/// A TMDB poster. AsyncImage downloads it and URLCache keeps it, so scrolling back is instant.
struct PosterImage: View {
    let path: String?
    var width = 342  // TMDB sizes: w92, w154, w342, w500, w780

    var body: some View {
        AsyncImage(url: path.flatMap { URL(string: "https://image.tmdb.org/t/p/w\(width)\($0)") }) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Rectangle()
                .fill(.quaternary)
                .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
        }
    }
}

/// Rating from 1 to 5 as emoji. Tap the selected one again to clear it.
struct EmojiRating: View {
    static let emoji = ["😣", "😕", "😐", "🙂", "🤩"]

    let rating: Int?
    let onChange: (Int?) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    onChange(rating == value ? nil : value)
                } label: {
                    Text(Self.emoji[value - 1])
                        .font(.largeTitle)
                        .opacity(rating == nil || rating == value ? 1 : 0.3)
                        .scaleEffect(rating == value ? 1.2 : 1)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.spring, value: rating)
    }
}

/// A yellow strip at the top when there is no internet.
struct OfflineBanner: View {
    var body: some View {
        Label("No internet. Showing the saved list.", systemImage: "wifi.slash")
            .font(.footnote)
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(.yellow.opacity(0.3))
    }
}

/// "2019 · Series"
func subtitle(year: Int?, type: MediaType) -> String {
    let kind = type == .movie ? String(localized: "Movie") : String(localized: "TV series")
    return [year.map { String($0) }, kind].compactMap { $0 }.joined(separator: " · ")
}

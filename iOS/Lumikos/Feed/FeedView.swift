import SwiftUI

struct FeedView: View {
    let model: FeedViewModel

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                if model.isLoading {
                    ProgressView()
                } else if let error = model.errorMessage, model.cards.isEmpty {
                    ContentUnavailableView {
                        Label("Could not load", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try again") { Task { await model.reload() } }
                    }
                } else if model.cards.isEmpty {
                    ContentUnavailableView("That's all for now", systemImage: "popcorn")
                }

                // Only the top 3 cards are drawn; the last one in ZStack is on top, hence reversed().
                // id: \.key, because a movie and a series can have the same TMDB id.
                ForEach(Array(model.cards.prefix(3).reversed()), id: \.key) { card in
                    SwipeCard(card: card) { liked in
                        model.swipe(card, liked: liked)
                    }
                    .onTapGesture { model.open(card) }
                    .accessibilityIdentifier(AXID.feedCard)
                }
            }
            .frame(maxHeight: .infinity)

            // Buttons do the same as swipes: easier for VoiceOver and for Maestro.
            if let top = model.cards.first {
                HStack(spacing: 48) {
                    roundButton("xmark", color: .red, id: AXID.feedSkip) { model.swipe(top, liked: false) }
                    roundButton("heart.fill", color: .green, id: AXID.feedLike) { model.swipe(top, liked: true) }
                }
            }
        }
        .padding()
        .task { await model.loadIfNeeded() }
    }

    private func roundButton(_ icon: String, color: Color, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
                .frame(width: 64, height: 64)
                .background(.thinMaterial, in: .circle)
        }
        .accessibilityIdentifier(id)
    }
}

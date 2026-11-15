import Shared
import SwiftUI

/// A Tinder-like card. Drag it left or right far enough and it flies away.
struct SwipeCard: View {
    let card: TitleCard
    let onSwipe: (_ liked: Bool) -> Void

    @State private var offset: CGSize = .zero
    private let threshold: CGFloat = 120  // how far to drag before it counts

    var body: some View {
        PosterImage(path: card.posterPath, width: 500)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(.rect(cornerRadius: 24))
            .overlay(alignment: .bottomLeading) { caption }
            .overlay(alignment: .top) { stamp }
            .shadow(radius: 8)
            .offset(offset)
            .rotationEffect(.degrees(offset.width / 20))
            .gesture(
                DragGesture()
                    .onChanged { offset = $0.translation }
                    .onEnded { value in
                        if abs(value.translation.width) > threshold {
                            let liked = value.translation.width > 0
                            withAnimation(.easeOut(duration: 0.2)) {
                                offset.width = liked ? 1000 : -1000
                            } completion: {
                                onSwipe(liked)
                            }
                        } else {
                            withAnimation(.spring) { offset = .zero }  // not far enough: back to the center
                        }
                    }
            )
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.title).font(.title2.bold())
            HStack {
                Text(subtitle(year: card.year, type: card.type))
                if let vote = card.voteAverage, vote > 0 {
                    Text("★ \(vote, specifier: "%.1f")")
                }
            }
            .font(.subheadline)
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.linearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom))
        .clipShape(.rect(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
    }

    /// "WANT" or "SKIP", more visible the further you drag.
    private var stamp: some View {
        let liked = offset.width > 0
        return Text(liked ? LocalizedStringKey("WANT") : "SKIP")
            .font(.largeTitle.bold())
            .foregroundStyle(liked ? .green : .red)
            .padding(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(liked ? .green : .red, lineWidth: 4))
            .rotationEffect(.degrees(liked ? -15 : 15))
            .padding(32)
            .opacity(min(abs(offset.width) / threshold, 1))
    }
}

import SwiftUI
import UIKit

/// Tab 2: my list.
@MainActor
final class ListCoordinator: Coordinator {
    let navigationController = UINavigationController()
    let dependencies: AppDependencies
    var onLogOut: (() -> Void)?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func start() -> UIViewController {
        let model = ListViewModel(
            api: dependencies.api,
            cache: ListCache(context: dependencies.modelContainer.mainContext),
            network: dependencies.network,
            nickname: dependencies.tokenStore.nickname ?? ""
        )
        model.onOpenDetails = { [weak self, weak model] item in
            // After a change on the details screen, reload the list so it shows the new state.
            self?.showDetails(of: item.card) { _ in
                guard let model else { return }
                Task { await model.refresh() }
            }
        }
        model.onLogOut = { [weak self] in self?.onLogOut?() }

        let controller = UIHostingController(rootView: ListView(model: model))
        controller.title = String(localized: "My list")
        controller.navigationItem.largeTitleDisplayMode = .always
        navigationController.navigationBar.prefersLargeTitles = true
        controller.tabBarItem = UITabBarItem(title: controller.title, image: UIImage(systemName: "list.bullet"), tag: 1)
        controller.tabBarItem.accessibilityIdentifier = AXID.tabList
        navigationController.viewControllers = [controller]
        return navigationController
    }
}

private extension ListItem {
    /// The details screen takes a card, so we make one from the list item.
    var card: TitleCard {
        TitleCard(id: id, type: type, title: title, year: year, posterPath: posterPath, overview: nil, voteAverage: nil)
    }
}

import SwiftUI
import UIKit

/// Tab 1: the swipe feed.
@MainActor
final class FeedCoordinator: Coordinator {
    let navigationController = UINavigationController()
    let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func start() -> UIViewController {
        let model = FeedViewModel(api: dependencies.api)
        model.onOpenDetails = { [weak self] card in self?.showDetails(of: card) }

        let controller = UIHostingController(rootView: FeedView(model: model))
        controller.title = String(localized: "For you")
        controller.tabBarItem = UITabBarItem(title: controller.title, image: UIImage(systemName: "rectangle.stack"), tag: 0)
        controller.tabBarItem.accessibilityIdentifier = AXID.tabFeed
        navigationController.viewControllers = [controller]
        return navigationController
    }
}

import Shared
import SwiftUI
import UIKit

/// Navigation is UIKit, screens are SwiftUI.
/// A coordinator creates screens, wraps them in UIHostingController and decides where to go next.
/// ViewModels know nothing about navigation: they only call closures like `onOpenDetails`.
@MainActor
protocol Coordinator: AnyObject {
    var navigationController: UINavigationController { get }
    var dependencies: AppDependencies { get }
}

extension Coordinator {
    /// Both tabs open the same details screen, so it lives here.
    /// `onChange` lets the tab refresh itself after I tap a button on the details screen.
    func showDetails(of card: TitleCard, onChange: @escaping (ListItem?) -> Void = { _ in }) {
        let model = DetailsViewModel(card: card, api: dependencies.api)
        model.onChange = onChange
        let controller = UIHostingController(rootView: DetailsView(model: model))
        controller.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(controller, animated: true)
    }
}

/// The root: shows the login screen or the tab bar.
@MainActor
final class AppCoordinator {
    private let window: UIWindow
    private let dependencies: AppDependencies
    private var children: [any Coordinator] = []  // keeps tab coordinators alive

    init(window: UIWindow, dependencies: AppDependencies) {
        self.window = window
        self.dependencies = dependencies
    }

    func start() {
        // Any request that gets 401 sends us back to the login screen.
        dependencies.api.onUnauthorized = { [weak self] in self?.logOut() }

        if dependencies.tokenStore.token == nil { showAuth() } else { showTabs() }
        window.makeKeyAndVisible()
    }

    private func showAuth() {
        children = []
        let model = AuthViewModel(api: dependencies.api, tokenStore: dependencies.tokenStore)
        model.onLoggedIn = { [weak self] in self?.showTabs() }
        setRoot(UIHostingController(rootView: AuthView(model: model)))
    }

    private func showTabs() {
        let feed = FeedCoordinator(dependencies: dependencies)
        let list = ListCoordinator(dependencies: dependencies)
        list.onLogOut = { [weak self] in self?.logOut() }
        children = [feed, list]

        let tabs = UITabBarController()
        tabs.viewControllers = [feed.start(), list.start()]
        setRoot(tabs)
    }

    private func logOut() {
        // Tell the server to forget the token. The token is passed explicitly,
        // because the Task starts later, when the Keychain is already empty.
        if let token = dependencies.tokenStore.token {
            let api = dependencies.api
            Task { try? await api.send(.logout(token: token)) }
        }
        dependencies.tokenStore.clear()
        showAuth()
    }

    private func setRoot(_ controller: UIViewController) {
        window.rootViewController = controller
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
    }
}

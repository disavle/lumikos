import Combine
import Network

/// Tells whether the phone is online. This is the one place where we use Combine.
///
/// NWPathMonitor calls us on a background queue every time the network changes.
/// We push the value into a CurrentValueSubject (a Combine "box" that always has the latest value),
/// and screens subscribe with `sink` (see ListViewModel.observeNetwork).
final class NetworkMonitor: @unchecked Sendable {
    // @unchecked Sendable: CurrentValueSubject is thread-safe, the compiler just cannot prove it.
    private let subject = CurrentValueSubject<Bool, Never>(true)
    private let monitor = NWPathMonitor()

    /// Emits only when the value changes: online → offline → online.
    var isOnline: AnyPublisher<Bool, Never> {
        subject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var isOnlineNow: Bool { subject.value }

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.subject.send(path.status == .satisfied)
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }

    deinit {
        monitor.cancel()
    }
}

/// Accessibility identifiers. Maestro (.maestro/*.yaml) finds views by these ids,
/// so UI tests do not break when a text or a language changes.
enum AXID {
    static let authEmail = "auth.email"
    static let authNickname = "auth.nickname"
    static let authLogin = "auth.login"
    static let authPassword = "auth.password"
    static let authSubmit = "auth.submit"
    static let authSwitchMode = "auth.switchMode"

    static let tabFeed = "tab.feed"
    static let tabList = "tab.list"

    static let feedCard = "feed.card"
    static let feedLike = "feed.like"
    static let feedSkip = "feed.skip"

    static let listRow = "list.row"
    static let listAccount = "list.account"

    static let searchRow = "search.row"
    static let searchAdd = "search.add"

    static let detailsAdd = "details.add"
    static let detailsWatched = "details.watched"
    static let detailsPin = "details.pin"
}

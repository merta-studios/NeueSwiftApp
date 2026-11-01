import UIKit

/// Zwischenziel für den `CADisplayLink`.
///
/// Der Display Link hält sein Ziel fest. Zeigt er direkt auf die View, kann die
/// View nie freigegeben werden. Der Proxy hält nur eine Closure, die die View
/// schwach referenziert – damit bleibt die App sauber, auch wenn Ansichten
/// ausgetauscht werden.
final class DisplayLinkProxy: NSObject {
    var handler: (() -> Void)?

    @objc func step() {
        handler?()
    }
}

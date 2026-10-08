import Foundation
import UIKit

enum SupportChat {
    static let url = URL(string: "https://t.me/Maer_VPN_bot")!

    @discardableResult
    static func open() -> Bool {
        UIApplication.shared.open(url)
        return true
    }
}

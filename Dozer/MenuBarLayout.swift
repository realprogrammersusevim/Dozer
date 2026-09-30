/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import Cocoa
import ApplicationServices

/// Reads the real menu bar layout from MenuBarAgent.
///
/// Since macOS 27 status items are drawn out of process by MenuBarAgent. A status item's own window
/// is only a placeholder (it reports `length + 16` wide while the real slot is `length + 2`), and an
/// item too wide to fit is moved behind the "«" overflow button or dropped instead of pushing its
/// neighbours off screen. MenuBarAgent's accessibility tree has the real positions.
enum MenuBarLayout {
    private static let agentBundleIdentifier = "com.apple.MenuBarAgent"
    private static let overflowButtonDescription = "Show Hidden Menu Bar Items"

    /// Room the overflow button needs between the notch and the first status item: it sits 21.5pt
    /// after the notch, is 17.5pt wide, and the next item starts 14.5pt after it.
    static let overflowReserve: CGFloat = 53.5

    struct Snapshot {
        fileprivate(set) var items: [String: CGRect] = [:]
        fileprivate(set) var overflowButton: CGRect?

        func frame(of identifier: String) -> CGRect? {
            items[identifier]
        }

        /// Whether the item is drawn in the menu bar, rather than moved behind the overflow button or dropped
        func isOnBar(_ identifier: String) -> Bool {
            guard let frame = items[identifier] else {
                return false
            }
            guard let overflowButton = overflowButton else {
                return true
            }
            return frame.minX >= overflowButton.maxX
        }
    }

    /// Whether status items are drawn by MenuBarAgent (macOS 27 and later)
    static var isAvailable: Bool {
        agent != nil
    }

    /// Whether MenuBarAgent can be read, which needs the Accessibility permission
    static var isReadable: Bool {
        isAvailable && AXIsProcessTrusted()
    }

    /// Ask for the Accessibility permission, which hiding icons needs from macOS 27
    static func requestAccessIfNeeded() {
        guard isAvailable else {
            return
        }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Positions of the status items whose accessibility identifier starts with `prefix`, and of the overflow button
    static func snapshot(identifierPrefix prefix: String) -> Snapshot {
        var snapshot = Snapshot()
        guard isReadable, let agent = agent else {
            return snapshot
        }

        let application = AXUIElementCreateApplication(agent.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.25)

        func walk(_ element: AXUIElement, depth: Int) {
            guard depth < 6 else {
                return
            }
            for child in children(of: element) {
                if let identifier = attribute(child, "AXIdentifier") as? String, identifier.hasPrefix(prefix) {
                    snapshot.items[identifier] = frame(of: child)
                } else if attribute(child, kAXDescriptionAttribute) as? String == overflowButtonDescription {
                    snapshot.overflowButton = frame(of: child)
                }
                walk(child, depth: depth + 1)
            }
        }
        walk(application, depth: 0)

        return snapshot
    }

    /// Left edge of the part of the menu bar status items can use: the notch, or the end of the frontmost app's menus
    static func leadingEdge(of screen: NSScreen) -> CGFloat? {
        if let area = screen.auxiliaryTopRightArea {
            return area.minX
        }

        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.25)
        guard let menuBar = attribute(application, kAXMenuBarAttribute) else {
            return nil
        }
        // swiftlint:disable:next force_cast
        return children(of: menuBar as! AXUIElement).map { frame(of: $0).maxX }.max()
    }

    // MARK: Private helpers
    private static var agent: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: agentBundleIdentifier).first
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    private static func frame(of element: AXUIElement) -> CGRect {
        var origin = CGPoint.zero
        var size = CGSize.zero
        if let value = attribute(element, kAXPositionAttribute) {
            // swiftlint:disable:next force_cast
            AXValueGetValue(value as! AXValue, .cgPoint, &origin)
        }
        if let value = attribute(element, kAXSizeAttribute) {
            // swiftlint:disable:next force_cast
            AXValueGetValue(value as! AXValue, .cgSize, &size)
        }
        return CGRect(origin: origin, size: size)
    }
}

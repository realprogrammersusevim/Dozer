/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import Cocoa
import Defaults

private struct StatusIconLength {
    static var show: CGFloat {
        Defaults[.buttonPadding]
    }
    static let hide: CGFloat = 10_000
}

class HelperstatusIcon {
    static let identifierPrefix = "com.mortennn.Dozer.statusIcon."
    private static var iconCount = 0

    var type: StatusIconType

    /// Accessibility identifier used to find this icon in MenuBarAgent
    let identifier: String

    private(set) var isShown = true

    /// Bumped whenever the icon is shown or hidden, so a fill still settling from an earlier hide stops
    private var fillGeneration = 0

    let statusIcon: NSStatusItem = NSStatusBar.system.statusItem(withLength: StatusIconLength.show)

    init() {
        type = .normal
        HelperstatusIcon.iconCount += 1
        identifier = HelperstatusIcon.identifierPrefix + String(HelperstatusIcon.iconCount)
        statusIcon.length = StatusIconLength.show

        guard let statusIconButton = statusIcon.button else {
            fatalError("helper status item button failed")
        }

        statusIconButton.setAccessibilityIdentifier(identifier)

        // These items act as spacers, so don't draw a pressed-state highlight
        (statusIconButton.cell as? NSButtonCell)?.highlightsBy = []

        statusIconButton.target = self
        statusIconButton.action = #selector(statusIconClicked(_:))
        setIcon()
        statusIconButton.sendAction(on: [.leftMouseDown, .rightMouseDown])
    }

    deinit {
        print("status item has been deallocated")
    }

    func show() {
        fillGeneration += 1
        isShown = true
        statusIcon.length = StatusIconLength.show
        setIcon()
    }

    func hide() {
        fillGeneration += 1
        isShown = false
        if MenuBarLayout.isReadable {
            fillToLeadingEdge(generation: fillGeneration, attempt: 0)
        } else {
            // Before macOS 27 a very long status item pushes every item to its left off screen
            statusIcon.length = StatusIconLength.hide
        }
    }

    func toggle() {
        if isShown {
            hide()
        } else {
            show()
        }
    }

    func setIcon() {
        guard let statusIconButton = statusIcon.button else {
            fatalError("helper status item button failed")
        }
        statusIconButton.image = Icons().helperstatusIcon
        statusIconButton.image!.isTemplate = true
    }

    func setSize() {
        if isShown {
            statusIcon.length = StatusIconLength.show
        }
        guard let statusIconButton = statusIcon.button else {
            fatalError("helper status item button failed")
        }
        let image = statusIconButton.image
        var size = DozerIcons.shared.iconFontSize
        if self.type == .remove {
            size /= 2
        }
        image?.size = NSSize(width: size, height: size)
        statusIconButton.image = image
    }

    func showRemoveIcons() {}

    @objc
    func statusIconClicked(_ sender: AnyObject?) {}

    var isHidden: Bool {
        !isShown
    }

    /// Prefers MenuBarAgent's position, as from macOS 27 the status item window is only a placeholder
    func xPositionOnScreen(in layout: MenuBarLayout.Snapshot) -> CGFloat {
        if let frame = layout.frame(of: identifier) {
            return frame.minX
        }
        guard let dozerIconFrame = statusIcon.button?.window?.frame else {
            return 0
        }
        return dozerIconFrame.origin.x
    }

    // MARK: Hiding on macOS 27
    // MenuBarAgent moves an item that doesn't fit behind the overflow button instead of letting it push
    // its neighbours off screen. So grow the icon just enough to take up all the room left of it: the
    // items to its left no longer fit and go behind the overflow button, while the icon stays in place
    // as an empty spacer.

    private static let settleDelay: TimeInterval = 0.25
    private static let maxLayoutAttempts = 4
    private static let maxShrinkAttempts = 6
    private static let shrinkStep: CGFloat = 4

    private func fillToLeadingEdge(generation: Int, attempt: Int) {
        guard generation == fillGeneration, !isShown else {
            return
        }

        let layout = MenuBarLayout.snapshot(identifierPrefix: HelperstatusIcon.identifierPrefix)
        guard let frame = layout.frame(of: identifier),
              layout.isOnBar(identifier),
              let screen = NSScreen.screens.first,
              let leadingEdge = MenuBarLayout.leadingEdge(of: screen) else {
            // Not laid out yet (e.g. right after launch), or already behind the overflow button because
            // the menu bar is full, in which case everything to its left is hidden already
            if attempt < HelperstatusIcon.maxLayoutAttempts {
                DispatchQueue.main.asyncAfter(deadline: .now() + HelperstatusIcon.settleDelay) {
                    self.fillToLeadingEdge(generation: generation, attempt: attempt + 1)
                }
            }
            return
        }

        // The right edge stays put as the length changes, and the slot is `length + padding` wide
        let padding = frame.width - statusIcon.length
        let length = floor(frame.maxX - (leadingEdge + MenuBarLayout.overflowReserve) - padding)
        guard length > StatusIconLength.show else {
            return
        }

        statusIcon.button?.image = nil
        statusIcon.length = length
        keepOnBar(generation: generation, attempt: 0)
    }

    /// Shrink the icon if it ended up behind the overflow button itself
    private func keepOnBar(generation: Int, attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + HelperstatusIcon.settleDelay) {
            guard generation == self.fillGeneration, !self.isShown else {
                return
            }
            let layout = MenuBarLayout.snapshot(identifierPrefix: HelperstatusIcon.identifierPrefix)
            guard !layout.isOnBar(self.identifier) else {
                return
            }
            let length = self.statusIcon.length - HelperstatusIcon.shrinkStep
            guard attempt < HelperstatusIcon.maxShrinkAttempts, length > StatusIconLength.show else {
                self.statusIcon.length = StatusIconLength.show
                self.setIcon()
                return
            }
            self.statusIcon.length = length
            self.keepOnBar(generation: generation, attempt: attempt + 1)
        }
    }
}

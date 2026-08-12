/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/. */

import Cocoa
import Defaults
import KeyboardShortcuts
import Settings

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        KeyboardShortcuts.onKeyUp(for: .toggleMenuItems) {
            DozerIcons.shared.toggle()
        }

        // Keep the "a shortcut exists" flag in sync even if Settings is never opened
        Defaults[.isShortcutSet] = KeyboardShortcuts.getShortcut(for: .toggleMenuItems) != nil

        // Initalize Dozer Icons
        _ = DozerIcons.shared

        // If enabled hide menu bar icons at launch
        DozerIcons.shared.hideAtLaunch()

        _ = DozerIcons.toggleDockIcon(showIcon: false)
    }

    // Show all Dozer icons when opening Dozer from Finder etc.
    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        DozerIcons.shared.showAll()
        return true
    }

    lazy var settingsPanes: [SettingsPane] = [
        Dozer(),
        General()
    ]

    lazy var settingsWindowController = SettingsWindowController(
        panes: settingsPanes,
        style: .toolbarItems,
        animated: true,
        hidesToolbarForSingleItem: true
    )
}

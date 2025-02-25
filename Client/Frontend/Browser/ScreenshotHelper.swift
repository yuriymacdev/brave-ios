/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import WebKit
import Shared

private let log = Logger.browserLogger

/**
 * Handles screenshots for a given tab, including pages with non-webview content.
 */
class ScreenshotHelper {
    var viewIsVisible = false

    fileprivate weak var tabManager: TabManager?

    init(tabManager: TabManager) {
        self.tabManager = tabManager
    }

    func takeScreenshot(_ tab: Tab) {
        guard let webView = tab.webView, let url = tab.url else {
            log.error("Tab webView or url is nil")
            tab.setScreenshot(nil)
            return
        }

        if InternalURL(url)?.isAboutHomeURL == true {
            if let homePanel = tabManager?.selectedTab?.newTabPageViewController {
                let screenshot = homePanel.view.screenshot(quality: UIConstants.activeScreenshotQuality)
                tab.setScreenshot(screenshot)
            } else {
                tab.setScreenshot(nil)
            }
        } else {
            let configuration = WKSnapshotConfiguration()
            //This is for a bug in certain iOS 13 versions, snapshots cannot be taken correctly without this boolean being set
            configuration.afterScreenUpdates = false
            
            webView.takeSnapshot(with: configuration) { image, error in
                if let image = image {
                    tab.setScreenshot(image)
                } else if let error = error {
                    log.error(error)
                    tab.setScreenshot(nil)
                } else {
                    log.error("Cannot snapshot Tab Screenshot - No error description")
                    tab.setScreenshot(nil)
                }
            }
        }
    }

    /// Takes a screenshot after a small delay.
    /// Trying to take a screenshot immediately after didFinishNavigation results in a screenshot
    /// of the previous page, presumably due to an iOS bug. Adding a brief delay fixes this.
    func takeDelayedScreenshot(_ tab: Tab) {
        let time = DispatchTime.now() + Double(Int64(100 * NSEC_PER_MSEC)) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: time) {
            // If the view controller isn't visible, the screenshot will be blank.
            // Wait until the view controller is visible again to take the screenshot.
            guard self.viewIsVisible else {
                tab.pendingScreenshot = true
                return
            }

            self.takeScreenshot(tab)
        }
    }

    func takePendingScreenshots(_ tabs: [Tab]) {
        for tab in tabs where tab.pendingScreenshot {
            tab.pendingScreenshot = false
            takeDelayedScreenshot(tab)
        }
    }
}

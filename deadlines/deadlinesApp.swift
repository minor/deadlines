//
//  deadlinesApp.swift
//  deadlines
//
//  Created by saurish on 6/13/25.
//

import SwiftUI
import AppKit

@main
struct deadlinesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    // Observers and event monitor for auto-dismissing the popover when the
    // user interacts with the system (e.g. opens Spotlight, Mission Control,
    // switches spaces, etc.)
    private var eventMonitor: Any?
    private var systemKeyMonitor: Any?
    private var notificationObservers: [NSObjectProtocol] = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusButton = statusItem?.button {
            statusButton.image = NSImage(systemSymbolName: "clock.badge.exclamationmark", accessibilityDescription: "Deadlines")
            statusButton.action = #selector(togglePopover)
            statusButton.target = self
            statusButton.sendAction(on: [.leftMouseUp, .rightMouseUp])
            
            // Remove any visual indicators/carets
            statusButton.imagePosition = .imageOnly
            statusButton.bezelStyle = .regularSquare
            statusButton.isBordered = false
            statusButton.wantsLayer = true
            statusButton.layer?.cornerRadius = 0
        }
        
        // Create popover
        popover = NSPopover()
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarView())
        
        // Hide dock icon and menu bar for menu bar only app
        NSApp.setActivationPolicy(.accessory)

        // MARK: - Auto-dismiss handling
        // 1. Global mouse/key monitor – closes the popover when the user clicks
        //    anywhere else or presses a key while the popover is showing.
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] _ in
            self?.closePopoverIfNeeded()
        }

        // Listen for Mission Control / App Exposé function-key events so we can
        // dismiss the pop-over the moment the gesture or key is invoked.
        systemKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            guard let self = self, event.subtype == .screenChanged else { return }

            // Bits 16-23 of data1 hold the 'NX keycode'. 0x0A = Mission Control,
            // 0x0B = App Exposé (Show All Windows).
            let keyCode = (event.data1 & 0x00FF0000) >> 16
            if keyCode == 0x0A || keyCode == 0x0B {
                self.closePopoverIfNeeded()
            }
        }

        // 2. Notification when the app resigns active (e.g. Spotlight opens)
        let resignObserver = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification,
                                                                     object: nil,
                                                                     queue: .main) { [weak self] _ in
            self?.closePopoverIfNeeded()
        }

        // 3. Notification when the active space changes (Mission Control or
        //    swipe between Desktops).
        let spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
                                                                              object: nil,
                                                                              queue: .main) { [weak self] _ in
            self?.closePopoverIfNeeded()
        }

        // 4. Mission Control or any other app becomes active (Dock, etc.)
        let activateObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                                                 object: nil,
                                                                                 queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let activatedApp = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               activatedApp != NSRunningApplication.current {
                self.closePopoverIfNeeded()
            }
        }

        notificationObservers = [resignObserver, spaceObserver, activateObserver]
    }
    
    @objc func togglePopover() {
        guard let statusButton = statusItem?.button else { return }
        
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: statusButton.bounds, of: statusButton, preferredEdge: .minY)
                // Do NOT activate the application here; keeping the app in the
                // background allows system gestures like Mission Control or
                // switching spaces to dismiss the pop-over automatically, just
                // like the built-in menu-bar extras (Wi-Fi, Clock, etc.).
            }
        }
    }

    // MARK: - Helpers
    @objc private func closePopoverIfNeeded() {
        if popover?.isShown == true {
            popover?.performClose(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up the monitors/observers to avoid leaks.
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        if let systemKeyMonitor = systemKeyMonitor {
            NSEvent.removeMonitor(systemKeyMonitor)
        }
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        notificationObservers.removeAll()
    }
}


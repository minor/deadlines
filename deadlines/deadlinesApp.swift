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
    }
    
    @objc func togglePopover() {
        guard let statusButton = statusItem?.button else { return }
        
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: statusButton.bounds, of: statusButton, preferredEdge: .minY)
                // Activate the app to ensure proper focus
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

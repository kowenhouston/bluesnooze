//
//  AppDelegate.swift
//  Bluesnooze
//
//  Created by Oliver Peate on 07/04/2020.
//  Copyright © 2020 Oliver Peate. All rights reserved.
//

import Cocoa
import IOBluetooth
// import LaunchAtLogin  // Temporarily disabled - needs Carthage build

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var launchAtLoginMenuItem: NSMenuItem!

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var lockWatcher: LockWatcher?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        initStatusItem()
        setLaunchAtLoginState()
        setupNotificationHandlers()
        setBluetooth(powerOn: true)
        setupLockWatcher()
    }
    
    private func setupLockWatcher() {
        lockWatcher = LockWatcher()
        lockWatcher?.start(
            onLock: { self.setBluetooth(powerOn: false) },
            onUnlock: { self.setBluetooth(powerOn: true) }
        )
    }

    // MARK: Click handlers

    @IBAction func launchAtLoginClicked(_ sender: NSMenuItem) {
        // LaunchAtLogin.isEnabled = !LaunchAtLogin.isEnabled  // Temporarily disabled
        // setLaunchAtLoginState()  // Temporarily disabled
    }

    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }

    // MARK: Notification handlers

    func setupNotificationHandlers() {
        [
            NSWorkspace.willSleepNotification: #selector(onPowerDown(note:)),
            NSWorkspace.willPowerOffNotification: #selector(onPowerDown(note:)),
            NSWorkspace.didWakeNotification: #selector(onPowerUp(note:))
        ].forEach { notification, sel in
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: sel, name: notification, object: nil)
        }
    }

    @objc func onPowerDown(note: NSNotification) {
        setBluetooth(powerOn: false)
    }

    @objc func onPowerUp(note: NSNotification) {
        setBluetooth(powerOn: true)
    }

    private func setBluetooth(powerOn: Bool) {
        IOBluetoothPreferenceSetControllerPowerState(powerOn ? 1 : 0)
    }

    // MARK: UI state

    private func initStatusItem() {
        if UserDefaults.standard.bool(forKey: "hideIcon") {
            return
        }

        if let icon = NSImage(named: "bluesnooze") {
            icon.isTemplate = true
            statusItem.button?.image = icon
        } else {
            statusItem.button?.title = "Bluesnooze"
        }
        statusItem.menu = statusMenu
    }

    private func setLaunchAtLoginState() {
        // let state = LaunchAtLogin.isEnabled ? NSControl.StateValue.on : NSControl.StateValue.off  // Temporarily disabled
        // launchAtLoginMenuItem.state = state  // Temporarily disabled
        launchAtLoginMenuItem.state = .off  // Default to off for now
    }
}

final class LockWatcher {
    private var lockObserver: NSObjectProtocol?
    private var unlockObserver: NSObjectProtocol?
    private let dnc = DistributedNotificationCenter.default()

    func start(onLock: @escaping () -> Void, onUnlock: @escaping () -> Void) {
        lockObserver = dnc.addObserver(forName: Notification.Name("com.apple.screenIsLocked"),
                                       object: nil, queue: .main) { _ in onLock() }
        unlockObserver = dnc.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"),
                                         object: nil, queue: .main) { _ in onUnlock() }
    }

    deinit {
        if let o = lockObserver { dnc.removeObserver(o) }
        if let o = unlockObserver { dnc.removeObserver(o) }
    }
}

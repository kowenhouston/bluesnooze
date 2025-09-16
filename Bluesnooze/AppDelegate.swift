//
//  AppDelegate.swift
//  Bluesnooze
//
//  Created by Oliver Peate on 07/04/2020.
//  Copyright © 2020 Oliver Peate. All rights reserved.
//

import Cocoa
import IOBluetooth
import LaunchAtLogin

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var launchAtLoginMenuItem: NSMenuItem!
    @IBOutlet weak var snoozeOnLockscreenMenuItem: NSMenuItem!

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var lockWatcher: LockWatcher?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        initStatusItem()
        setLaunchAtLoginState()
        setSnoozeOnLockscreenState()
        setupNotificationHandlers()
        setBluetooth(powerOn: true)
        setupLockWatcher()
    }

    private func setupLockWatcher() {
        lockWatcher = LockWatcher()
        lockWatcher?.start(
            onLock: {
                if UserDefaults.standard.bool(forKey: "snoozeOnLockscreen") {
                    self.setBluetooth(powerOn: false)
                }
            },
            onUnlock: {
                if UserDefaults.standard.bool(forKey: "snoozeOnLockscreen") {
                    self.setBluetooth(powerOn: true)
                }
            }
        )
    }

    // MARK: Click handlers

    @IBAction func launchAtLoginClicked(_ sender: NSMenuItem) {
        LaunchAtLogin.isEnabled = !LaunchAtLogin.isEnabled
        setLaunchAtLoginState()
    }

    @IBAction func snoozeOnLockscreenClicked(_ sender: NSMenuItem) {
        let currentState = UserDefaults.standard.bool(forKey: "snoozeOnLockscreen")
        UserDefaults.standard.set(!currentState, forKey: "snoozeOnLockscreen")
        setSnoozeOnLockscreenState()
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
        let state = LaunchAtLogin.isEnabled ? NSControl.StateValue.on : NSControl.StateValue.off
        launchAtLoginMenuItem.state = state
    }

    private func setSnoozeOnLockscreenState() {
        let isEnabled = UserDefaults.standard.bool(forKey: "snoozeOnLockscreen")
        snoozeOnLockscreenMenuItem.state = isEnabled ? .on : .off
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
        if let observer = lockObserver { dnc.removeObserver(observer) }
        if let observer = unlockObserver { dnc.removeObserver(observer) }
    }
}

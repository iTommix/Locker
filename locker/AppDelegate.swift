//
//  AppDelegate.swift
//  locker
//
//  Created by Thomas on 12.07.18.
//  Copyright © 2018 outraxx.de. All rights reserved.
//

import Cocoa
import IOBluetooth
import Foundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var mRssi: NSMenuItem!
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var setup: NSWindow!
    @IBOutlet weak var mQuit: NSMenuItem!
    @IBOutlet weak var lockModeMenu: NSMenu!
    @IBOutlet weak var debug: NSMenuItem!
    
    
    @IBOutlet weak var password: NSSecureTextFieldCell!
    @IBOutlet weak var macAddress: NSTextFieldCell!
    
    @IBOutlet weak var rssiLock: NSMenu!
    @IBOutlet weak var rssiUnlock: NSMenu!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let defaults = UserDefaults.standard
    let formatter = DateFormatter()
    

    var counter = 0
    var rssi = 0
    var scriptObject : NSAppleScript?
    var timer = Timer()
    
    var canLock = false
    var canunlock = false
    var locked = false
    var ready = false
    var manualUnlock = false
    var menuOpen = false
    var debugMode = false
    
    /* Default Values */
    var lockMode = 0 // 0=off, 1=lock, 2=Screensaver
    var lockValue = -70
    var unlockValue = -65
    var address = ""
    var unlockPassword = ""
    
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
       
        //self.macAddress.sendAction(on: [.leftMouseDown])
        //self.macAddress.action = #selector(setMacInput)
        
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(AppDelegate.screenLocked), name: NSNotification.Name(rawValue: "com.apple.screenIsLocked"), object: nil)
        center.addObserver(self, selector: #selector(AppDelegate.screenUnlocked), name: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"), object: nil)
        
        for i in stride(from: 100, to: 30, by: -5) {
            let editMenuItem = NSMenuItem()
            editMenuItem.title = "-"+String(i)+" dBm"
            editMenuItem.action = #selector(setLockRssi(_:))
            rssiLock.addItem(editMenuItem)
        }

        if let button = statusItem.button {
            button.image = NSImage(named:NSImage.Name("lock"))
        }
        statusItem.menu = statusMenu
        statusMenu.delegate = self
        loadData()
        buildUnlockMenu()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        

        
        
        
        

        if !self.macAddress.stringValue.isEmpty && !self.password.stringValue.isEmpty {
            self.ready = true
        }
        self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.displayRSSI), userInfo: nil, repeats: true)
        DispatchQueue.global(qos: .utility).async {
            print("This is run on the background queue")
            // Get the Device
            if self.ready==true {
                guard let bluetoothDevice = IOBluetoothDevice(addressString: self.address) else {
                    print("Device not found")
                    return
                }
                while 1==1 {
                    if !self.menuOpen {
                        if bluetoothDevice.isConnected()==false {
                            //print("Device not connected")
                            bluetoothDevice.openConnection()
                        }
                        else {
                            self.rssi = Int(bluetoothDevice.rawRSSI())
                            if self.rssi<0 {
                                if self.rssi < self.lockValue {
                                    self.counter=self.counter+1
                                    if self.counter==10 {
                                        self.canLock=true
                                        self.canunlock=false
                                    }
                                }
                                else if self.rssi >= self.unlockValue {
                                    self.counter=0
                                    self.canLock=false
                                    self.canunlock=true
                                }
                            }
                            /*
                             print(self.average)
                             print("\(self.rssi) => \(self.lockValue) => \(self.unlockValue)")
                             print(self.canLock)
                             print("-----------------")
                             print(self.rssi)
                             sleep(1)
                             
                             
                             print("\(self.rssi) => \(self.locked) => \(self.manualUnlock) => \(self.canLock) => \(self.canunlock)")
                             sleep(1)
                             */
                            
                            if self.canLock {
                                if self.locked==false && self.manualUnlock==false{
                                    print("LOCK")
                                    self.getOutRangeScript()
                                    self.locked=true
                                    sleep(3)
                                }
                            }
                            else if self.canunlock {
                                if self.locked==true && !self.manualUnlock {
                                    print("UNLOCK")
                                    if self.lockMode==2 {
                                        keysend(0x24, useCommandFlag: false)
                                        sleep(1)
                                    }
                                    for i in self.unlockPassword {
                                        keysend(keymap[i]!, useCommandFlag: false)
                                    }
                                    keysend(0x24, useCommandFlag: false)
                                    self.locked=false
                                    sleep(3)
                                }
                                else {
                                    self.manualUnlock = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    

    
    func buildUnlockMenu() {
        rssiUnlock.removeAllItems()
        let start=abs(Int(self.lockValue))-5
        var checked = false
        for i in stride(from: start, to: 30, by: -5) {
            let editMenuItem = NSMenuItem()
            editMenuItem.title = "-"+String(i)+" dBm"
            editMenuItem.action = #selector(setUnlockRssi(_:))
            if checked==false {
                if self.unlockValue < (0-start) && i==start{
                    editMenuItem.state = NSControl.StateValue.on
                    self.unlockValue = 0-i
                    checked = true
                }
                else if self.unlockValue==0-i {
                    editMenuItem.state = NSControl.StateValue.on
                    checked = true
                }
            }
            rssiUnlock.addItem(editMenuItem)
        }
    }

    func getOutRangeScript() {
        var myAppleScript=""
        if self.lockMode>0 {
            if self.lockMode>1 {
                myAppleScript = "tell application \"System Events\" \n" +
                    "start current screen saver \n" +
                "end tell \n"
                var error: NSDictionary?
                NSAppleScript(source: myAppleScript)?.executeAndReturnError(&error)
                writeDebug("Device out of Range. Locking to Screensaver with RSSI " + String(self.rssi))
            }
            else {
                self.shell("/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession", "-suspend")
                writeDebug("Device out of Range. Locking to Lockscreen with RSSI " + String(self.rssi))
            }
        }
        return
    }
    

    
    func getInRangeScript() {
        if self.lockMode>0 {
            let myAppleScript = "on run\n"
                //+ "tell application \"/System/Library/Frameworks/ScreenSaver.framework/Versions/A/Resources/ScreenSaverEngine.app\" to quit\n"
                + "tell application \"System Events\" to keystroke return\n"
                + "delay 2.0\n"
                + "tell application \"System Events\" to keystroke \"" + (self.unlockPassword) + "\"\n"
                + "delay 0.5\n"
                + "tell application \"System Events\" to keystroke return\n"
                + "end run\n"
            var error: NSDictionary?
            NSAppleScript(source: myAppleScript)?.executeAndReturnError(&error)
            writeDebug("Device in Range. Unlocking with RSSI " + String(self.rssi))
        }
        return
    }
    
    @objc func screenLocked(_ sender: Any) {
        print("Manual Lock")
        writeDebug("Manual Lock initiated")
    }
   
    @objc func screenUnlocked(_ sender: Any) {
        print("Manual unlock")
        self.manualUnlock=true
        self.locked=false
        writeDebug("Manual Unlock initiated")
    }
    
    @objc func displayRSSI() {
        if self.rssi<0 {
            self.mRssi.title="Rssi : "+String(self.rssi)
        }
        else {
            self.mRssi.title="Not Connected"
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    @IBAction func setDebugMode(_ sender: NSMenuItem?) {
        sender?.state = sender?.state.rawValue==0 ? NSControl.StateValue.on : NSControl.StateValue.off
    }
    
    @objc func setLockRssi(_ sender: NSMenuItem?) {
        let val = sender?.title.replacingOccurrences(of: " dBm", with: "")
        sender?.state = NSControl.StateValue.on
        let checked = rssiLock.item(withTitle: String(self.lockValue)+" dBm")
        checked?.state = NSControl.StateValue.off
        self.lockValue = Int(val!)!
        defaults.set(self.lockValue, forKey: "lock")
        buildUnlockMenu()
        writeDebug("Lock-Value changed to " + String(self.lockValue))
    }
    
    @objc func setUnlockRssi(_ sender: NSMenuItem?) {
        let val = sender?.title.replacingOccurrences(of: " dBm", with: "")
        sender?.state = NSControl.StateValue.on
        let checked = rssiUnlock.item(withTitle: String(self.unlockValue)+" dBm")
        checked?.state = NSControl.StateValue.off
        self.unlockValue = Int(val!)!
        defaults.set(self.unlockValue, forKey: "unlock")
        writeDebug("Unlock-Value changed to " + String(self.unlockValue))
    }
    
    @IBAction func qAction(_ sender: Any) {
        NSApplication.shared.terminate(self)
        writeDebug("App terminated")
    }
    
    
    
    @IBAction func passwordChanged(_ sender: NSSecureTextFieldCell) {
        self.ready=false
        self.unlockPassword = sender.stringValue
        defaults.set(self.unlockPassword, forKey: "password")
        if !self.macAddress.stringValue.isEmpty && !self.password.stringValue.isEmpty {
            self.ready=true
        }
        writeDebug("Password changed")
    }
    
    @IBAction func macAddressChanged(_ sender: NSTextFieldCell) {
        self.ready=false
        self.address = sender.stringValue
        defaults.set(self.address, forKey: "address")
        if !self.macAddress.stringValue.isEmpty && !self.password.stringValue.isEmpty {
            self.ready=true
        }
        writeDebug("Mac-Address changed")
    }
    
    @IBAction func lockOff(_ sender: NSMenuItem?) {
        lockModeMenu.item(at: self.lockMode)?.state = NSControl.StateValue.off
        self.lockMode = 0
        sender?.state = NSControl.StateValue.on
        defaults.set(self.lockMode, forKey: "lockMode")
        writeDebug("Lock-Mode changed to OFF")
    }
    
    @IBAction func lockLock(_ sender: NSMenuItem?) {
        lockModeMenu.item(at: self.lockMode)?.state = NSControl.StateValue.off
        self.lockMode = 1
        sender?.state = NSControl.StateValue.on
        defaults.set(self.lockMode, forKey: "lockMode")
        writeDebug("Lock-Mode changed to Lockscreen")
    }
    
    @IBAction func lockSaver(_ sender: NSMenuItem?) {
        lockModeMenu.item(at: self.lockMode)?.state = NSControl.StateValue.off
        self.lockMode = 2
        sender?.state = NSControl.StateValue.on
        defaults.set(self.lockMode, forKey: "lockMode")
        writeDebug("Lock-Mode changed to Screensaver")
    }
    
    
    func loadData() {
        let address = defaults.string(forKey: "address")
        self.macAddress.stringValue = address ?? ""
        let password = defaults.string(forKey: "password")
        self.password.stringValue = password ?? ""
        let lock = defaults.integer(forKey: "lock")
        let unlock = defaults.integer(forKey: "unlock")
        let mode = defaults.integer(forKey: "lockMode")
        
        var checked = rssiLock.item(withTitle: String(lock)+" dBm")
        checked?.state = NSControl.StateValue.on
        checked = rssiUnlock.item(withTitle: String(unlock)+" dBm")
        checked?.state = NSControl.StateValue.on
        
        
        
        self.unlockValue = unlock
        self.lockValue = lock
        self.address = self.macAddress.stringValue
        self.unlockPassword = self.password.stringValue
        self.lockMode = mode
        lockModeMenu.item(at: self.lockMode)?.state = NSControl.StateValue.on
    }
    
    func shell(_ args: String...) {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = args
        task.launch()
        task.waitUntilExit()
    }
    
    func writeDebug(_ text: String) {
        let date = formatter.string(from: Date())
        
        if self.debug.state.rawValue==1 {
            if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = dir.appendingPathComponent("locker_debug.txt")
                var old = ""
                do {
                    old = try String(contentsOf: fileURL, encoding: .utf8)
                }
                catch {
                    
                }
                let out = old + date + " : " + text + "\n"
                
                do {
                    try out.write(to: fileURL, atomically: false, encoding: .utf8)
                }
                catch{
                    print("Could not Write Debug")
                }
            }
        }
    }
    
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.menuOpen = true
        let btDelegate = BlueDelegate()
        let ibdi = IOBluetoothDeviceInquiry(delegate: btDelegate)
        ibdi?.updateNewDeviceNames = true
        //ibdi?.start()
    }
    
    func menuDidClose(_ menu: NSMenu) {
        self.menuOpen = false
    }
}

class BlueDelegate : IOBluetoothDeviceInquiryDelegate {
    func deviceInquiryStarted(_ sender: IOBluetoothDeviceInquiry) {
        print("Inquiry Started...")
    }
    func deviceInquiryDeviceFound(_ sender: IOBluetoothDeviceInquiry, device: IOBluetoothDevice) {
        print("\(device.addressString!)")
    }
}



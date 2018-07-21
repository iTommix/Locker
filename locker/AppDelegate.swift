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
    @IBOutlet weak var lockFrom: NSTextField!
    @IBOutlet weak var unlockFrom: NSTextField!
    @IBOutlet weak var macAddress: NSTextField!
    @IBOutlet weak var password: NSSecureTextField!


    
    @IBOutlet weak var rssiLock: NSMenu!
    
    
    let statusItem = NSStatusBar.system.statusItem(withLength: -1)
    let defaults = UserDefaults.standard
    var locked = false
    var ready = false
    var average = 0
    var rssi = 0
    var lockValue = -70
    var unlockValue = -70
    var address = ""
    var unlockPassword = ""
    var canLock = false
    var canunlock = false

    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        for i in stride(from: 70, to: 30, by: -5) {
            let editMenuItem = NSMenuItem()
            editMenuItem.title = "-"+String(i)+" dBm"
            editMenuItem.action = #selector(setLockRssi(_:))
            rssiLock.addItem(editMenuItem)
        }
        
        if let button = statusItem.button {
            button.image = NSImage(named:NSImage.Name("lock"))
            button.action = #selector(AppDelegate.displayRSSI(_:))
            //button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            //button.target = self
        }
        statusItem.menu = statusMenu
        loadData()

        if !self.macAddress.stringValue.isEmpty && !self.password.stringValue.isEmpty {
            self.setup!.orderOut(self)
            self.ready = true
            
        }

        DispatchQueue.global(qos: .utility).async {
            print("This is run on the background queue")
            // Get the Device
            if self.ready==true {
                guard let bluetoothDevice = IOBluetoothDevice(addressString: self.address) else {
                    print("Device not found")
                    return
                }
                while 1==1 {
                    if bluetoothDevice.isConnected()==false {
                        print("Device not connected")
                        bluetoothDevice.openConnection()
                        
                    }
                    else {
                        self.rssi = Int(bluetoothDevice.rawRSSI())
                        if self.rssi<0 {
                            if self.rssi < self.lockValue {
                                self.average=self.average+1
                                if self.average==10 {
                                    self.canLock=true
                                    self.canunlock=false
                                }
                            }
                            else {
                                self.average=0
                                self.canLock=false
                                self.canunlock=true
                            }
                        }
                        /*
                        print(self.average)
                        print("\(self.rssi) => \(self.lockValue) => \(self.unlockValue)")
                        print(self.canLock)
                        print("-----------------")
                        sleep(1)
                        */
                        if self.canLock {
                            if self.locked==false {
                                print("LOCK")
                                self.shell("/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession", "-suspend")
                                self.locked=true
                                sleep(3)
                            }
                        }
                        else if self.canunlock {
                            if self.locked==true {
                                print("UNLOCK")
                                
                                for i in self.unlockPassword {
                                    keysend(keymap[i]!, useCommandFlag: false)
                                }
                                keysend(0x24, useCommandFlag: false)
                                
                                self.locked=false
                                sleep(3)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func closeSetup(_ sender: Any) {
        defaults.set(self.macAddress.stringValue, forKey: "address")
        defaults.set(self.password.stringValue, forKey: "password")
        
        //defaults.set(self.unlock.integerValue, forKey: "unlock")
        if !self.macAddress.stringValue.isEmpty && !self.password.stringValue.isEmpty {
            self.ready=true
        }
        loadData()
        self.setup!.orderOut(self)
    }
    

   
    @objc func displayRSSI(_ sender: Any?) {
        print("*****")
        self.mRssi.title="Rssi : "+String(self.rssi)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    @objc func setLockRssi(_ sender: NSMenuItem?) {
        var val = sender?.title.replacingOccurrences(of: " dBm", with: "")
        print(val)
        sender?.state = NSControl.StateValue.on
        var checked = rssiLock.item(withTitle: String(self.lockValue)+" dBm")
        checked?.state = NSControl.StateValue.off
        self.lockValue = Int(val!)!
        defaults.set(self.lockValue, forKey: "lock")
    }
    
    @IBAction func qAction(_ sender: Any) {
        NSApplication.shared.terminate(self)
    }

    @IBAction func sAction(_ sender: Any) {
        self.setup!.orderFront(self)
        

    }
    
    func loadData() {
        let address = defaults.string(forKey: "address")
        self.macAddress.stringValue = address ?? ""
        let password = defaults.string(forKey: "password")
        self.password.stringValue = password ?? ""
        let lock = defaults.integer(forKey: "lock")
        //self.lock.integerValue = lock ?? self.lockValue
        //let unlock = defaults.integer(forKey: "unlock")
        //self.unlock.integerValue = unlock ?? self.unlockValue
        
        var checked = rssiLock.item(withTitle: String(lock)+" dBm")
        checked?.state = NSControl.StateValue.on
        
        
        self.lockValue = lock
        self.address = self.macAddress.stringValue
        self.unlockPassword = self.password.stringValue
    }
    
    func shell(_ args: String...) -> Int32 {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = args
        task.launch()
        task.waitUntilExit()
        return task.terminationStatus
    }
    
}






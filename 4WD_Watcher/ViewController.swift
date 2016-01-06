//
//  ViewController.swift
//  4WD_Watcher
//
//  Created by toshiyuki on 2015/12/25.
//  Copyright © 2015年 toshiyuki. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    let SERVICE_UUID = CBUUID(string: "c8d6ea62-4076-4561-bfc8-90af4ed78f4a")
    let TX_CHARA = CBUUID(string: "d53116fc-4b96-4446-b89f-d960001cea91")
    let RX_CHARA = CBUUID(string: "d946286e-b6ae-4e75-8c8d-cb18434a1398")
    var manager: CBCentralManager?
    var peripheral : CBPeripheral?
    var txCaracteristic : CBCharacteristic?
    var rxCaracteristic : CBCharacteristic?

    @IBOutlet weak var xLabel: UILabel!
    @IBOutlet weak var yLabel: UILabel!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!

    @IBOutlet weak var statusLabel: UILabel!
    
    @IBOutlet weak var leftArrow: UILabel!
    @IBOutlet weak var rightArrow: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        manager = CBCentralManager(delegate: self, queue: nil)
        indicatorView.hidden = true
        statusLabel.hidden = true
    }

    @IBOutlet weak var zLabel: UILabel!
    @IBOutlet weak var speedLabel: UILabel!
    @IBAction func reScan(sender: AnyObject) {
        disconnect();
        scan()
    }
    
    func disconnect() {
        txCaracteristic = nil
        rxCaracteristic = nil
        if peripheral != nil {
            manager?.cancelPeripheralConnection(peripheral!);
        }
        peripheral = nil;
        updateStatus("disconnected.")
    }
    
    func scan() {
        manager?.scanForPeripheralsWithServices([SERVICE_UUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        dispatch_async_main {
            self.indicatorView.hidden = false
            self.statusLabel.hidden = false
            self.updateStatus("scanning...")
        }
    }
    
    func updateStatus(statusMessage : String) {
        dispatch_async_main {
            self.statusLabel.text = statusMessage
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // ####################################################################
    // CBCentralManagerDelegate
    // ####################################################################
    func centralManagerDidUpdateState(central: CBCentralManager) {
        if central.state == CBCentralManagerState.PoweredOn {
            scan()
        }
        if central.state == CBCentralManagerState.PoweredOff {
            manager?.stopScan()
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        updateStatus("found peripheral")
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        central.connectPeripheral(self.peripheral!, options: [
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ])
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        updateStatus("connecting...")
        self.peripheral?.discoverServices([SERVICE_UUID])
    }
    
    // ####################################################################
    // CBPeripheralDelegate
    // ####################################################################
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        updateStatus("subscribing...")
        for service in self.peripheral!.services! {
            self.peripheral?.discoverCharacteristics([RX_CHARA, TX_CHARA], forService: service)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        for c in service.characteristics! {
            if c.UUID.UUIDString == TX_CHARA.UUIDString {
                txCaracteristic = c
            }
            if c.UUID.UUIDString == RX_CHARA.UUIDString {
                rxCaracteristic = c
            }
        }
        if txCaracteristic != nil && rxCaracteristic != nil {
            updateStatus("connected.")
            dispatch_async_main {
                self.indicatorView.hidden = true
            }
            self.peripheral?.setNotifyValue(true, forCharacteristic: self.rxCaracteristic!)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {

        var buffer = [UInt8](count:(characteristic.value?.length)!, repeatedValue:0)
        characteristic.value?.getBytes(&buffer, length:(characteristic.value?.length)!)
        
        let x = UnsafePointer<Float>(Array(buffer[0..<4])).memory
        let y = UnsafePointer<Float>(Array(buffer[4..<8])).memory
        let z = UnsafePointer<Float>(Array(buffer[8..<12])).memory
        let s = UnsafePointer<Float>(Array(buffer[12..<16])).memory
        
        dispatch_async_main {
            self.xLabel.text = String(format: "%04.2f", x)
            self.leftArrow.hidden = true
            self.rightArrow.hidden = true
            if y > 0.1 {
                self.rightArrow.hidden = false
            }
            if y < -0.1 {
                self.leftArrow.hidden = false
            }
            self.yLabel.text = String(format: "%04.2f", abs(y))
            self.zLabel.text = String(format: "%04.2f", z)
            self.speedLabel.text = String(format: "%05.2f", abs(s))
        }
    }
    
    // ####################################################################
    // Utils
    // ####################################################################
    func toByteArray<T>(var value: T) -> [UInt8] {
        return withUnsafePointer(&value) {
            Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>($0), count: sizeof(T)))
        }
    }
    func dispatch_async_main(block: () -> ()) {
        dispatch_async(dispatch_get_main_queue(), block)
    }
}


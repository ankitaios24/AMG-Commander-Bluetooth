//
//  ViewController.swift
//  AMGLABCOMMA028
//
//  Created by Ankita Thakur on 25/08/24.
// follow my youtube & instagram  ankeecodeverse   :-)

import UIKit
import CoreBluetooth



class ViewController: UIViewController, BluetoothManagerDelegate {
    
    @IBOutlet var lblBluetoothName : UILabel!
    @IBOutlet var lbltimer : UILabel!
    @IBOutlet var lblmilisec : UILabel!
    @IBOutlet var lblcurrentShotTime : UILabel!
    
    var bluetoothManager: BluetoothManager?
    var peripherals: [CBPeripheral] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize and set up the BluetoothManager
        bluetoothManager = BluetoothManager()
        bluetoothManager?.delegate = self
        bluetoothManager?.setUp()
        bluetoothManager?.centralManager?.scanForPeripherals(withServices: [CBUUID(string: ServiceIdentifiers.uartServiceUUIDString)])
        
    }
    @IBAction func btnStartTimer(_ sender: UIButton){
        sender.isSelected =  !sender.isSelected
        let command: [UInt8] = [0x01, 0x02, 0x03] // Example command
        bluetoothManager?.send(command: command)
        if sender.isSelected{
            sender.setTitle("Stop", for: .normal)
            bluetoothManager?.send(command: "COM START")
        }else{
            sender.setTitle("Start", for: .normal)
            bluetoothManager?.send(command: "COM STOP")
        }
    }

    // Implement the delegate methods here
    func centralManagerDidUpdateState(state: CBManagerState) {
        switch state {
        case .poweredOn:
            print("Bluetooth is powered on.")
        case .poweredOff:
            print("Bluetooth is powered off.")
        default:
            print("Bluetooth state: \(state)")
        }
    }

    func requestedConnect(peripheral: CBPeripheral) {
        print("Request to connect to peripheral: \(peripheral.name ?? "Unknown")")
    }

    func didConnectPeripheral(deviceName aName: String?) {
        print("Connected to device: \(aName ?? "Unknown")")
    }

    func didDisconnectPeripheral() {
        print("Disconnected from the peripheral.")
    }

    func peripheralNotSupported() {
        print("The peripheral is not supported.")
    }

//    func didRecieveShotData(shotData: ShotModel) {
//        print("Received shot data: \(shotData)")
//        
//        // Update UI or handle the shot data here
//    }

    func didRecieveShotData(shotData: ShotModel) {
        if shotData.isActive == .stopped
        {
            // self.calculateTimer()
        }
        else if shotData.isActive == .start
        {
            
        }
        else{
            
            let next = (shotData.currentShotTime?.string ?? "").components(separatedBy: ".")
            self.lbltimer.text = String(format: "%02d",(Int(next[0]) ?? 0))+"."
            self.lblmilisec.text = String(format: "%02d", (Int(next[1]) ?? 0))
            self.lblcurrentShotTime.text =  shotData.currentShotTime?.string ?? ""
            
            
        }
    }
    func peripheralDeviceFound(peripherals: [CBPeripheral]) {
        print("Discovered peripherals: \(peripherals)")
        // Handle discovered peripherals, like displaying them in a list
        lblBluetoothName.text = peripherals.first?.name ?? "Connect"
        if let peripheral = peripherals.first{
            bluetoothManager?.connectPeripheral(peripheral:peripheral)
        }
       
    }
}

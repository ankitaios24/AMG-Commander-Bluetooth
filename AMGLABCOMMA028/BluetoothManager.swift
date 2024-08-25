//
//  BluetoothManager.swift
//  AMGLABCOMMA028
//
//  Created by Ankita Thakur on 25/08/24.
//

import UIKit
import CoreBluetooth

// Enum representing different states of a shot
enum ShotState: Int {
    case active = 03
    case start = 05
    case stopped = 08
}

// Protocol defining the delegate methods for Bluetooth manager events
protocol BluetoothManagerDelegate {
    func centralManagerDidUpdateState(state: CBManagerState)
    func requestedConnect(peripheral: CBPeripheral)
    func didConnectPeripheral(deviceName aName: String?)
    func didDisconnectPeripheral()
    func peripheralNotSupported()
    func didRecieveShotData(shotData: ShotModel)
    func peripheralDeviceFound(peripherals: [CBPeripheral])
}

// Service UUIDs for UART communication
class ServiceIdentifiers: NSObject {
    static let uartServiceUUIDString = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    static let uartTXCharacteristicUUIDString = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    static let uartRXCharacteristicUUIDString = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
}

// Custom error for Bluetooth manager
enum BluetoothManagerError: Error {
    case cannotFindPeripheral
    
    var localizedDescription: String {
        return "Cannot find peripheral"
    }
}

// Bluetooth manager class handling BLE operations
class BluetoothManager: NSObject, CBPeripheralDelegate, CBCentralManagerDelegate {
    
    //MARK: - Delegate Properties
    var delegate: BluetoothManagerDelegate?
    
    //MARK: - Class Properties
    private let UARTServiceUUID: CBUUID
    private let UARTRXCharacteristicUUID: CBUUID
    private let UARTTXCharacteristicUUID: CBUUID
    
    var centralManager: CBCentralManager?
    var bluetoothPeripheral: CBPeripheral?
    private var uartRXCharacteristic: CBCharacteristic?
    private var uartTXCharacteristic: CBCharacteristic?
    
    var connected = false
    var peripherals: [CBPeripheral] = []
    private var shotData: ShotModel?
    private var status: ShotState = .stopped
    
    //MARK: - Initialization
    required override init() {
        UARTServiceUUID = CBUUID(string: ServiceIdentifiers.uartServiceUUIDString)
        UARTTXCharacteristicUUID = CBUUID(string: ServiceIdentifiers.uartTXCharacteristicUUIDString)
        UARTRXCharacteristicUUID = CBUUID(string: ServiceIdentifiers.uartRXCharacteristicUUIDString)
        super.init()
    }
    
    // Setup method for central manager
    func setUp(withManager manager: CBCentralManager = CBCentralManager()) {
        centralManager = manager
        centralManager?.delegate = self
    }
    
    //MARK: - BluetoothManager API
    
    // Connects to the given peripheral
    func connectPeripheral(peripheral: CBPeripheral) {
        delegate?.requestedConnect(peripheral: peripheral)
        
        bluetoothPeripheral = peripheral
        bluetoothPeripheral?.delegate = self
        
        if let name = peripheral.name {
            print("Connecting to: \(name)...")
        } else {
            print("Connecting to device...")
        }
        
        guard let p = centralManager?.retrievePeripherals(withIdentifiers: [peripheral.identifier]).first else {
            centralManager?.delegate?.centralManager?(centralManager ?? CBCentralManager(), didFailToConnect: peripheral, error: BluetoothManagerError.cannotFindPeripheral)
            return
        }
        
        centralManager?.connect(p, options: nil)
    }
    
    // Disconnects the current peripheral connection
    func cancelPeripheralConnection() {
        guard let bluetoothPeripheral = bluetoothPeripheral else {
            print("Peripheral not set")
            return
        }
        
        if connected {
            print("Disconnecting...")
        } else {
            print("Cancelling connection...")
        }
        
        centralManager?.cancelPeripheralConnection(bluetoothPeripheral)
        
        if !connected {
            self.bluetoothPeripheral = nil
            delegate?.didDisconnectPeripheral()
        }
    }
    
    // Checks if the peripheral is connected
    func isConnected() -> Bool {
        return connected
    }
    
    // Sends a command to the connected peripheral
    func send(command: String) {
        guard let uartRXCharacteristic = uartRXCharacteristic else {
            print("UART RX Characteristic not found")
            return
        }
        
        let writeData = command.data(using: .utf8) ?? Data()
        bluetoothPeripheral?.writeValue(writeData, for: uartRXCharacteristic, type: .withResponse)
    }
    func send(command: [UInt8]) {
        guard let uartRXCharacteristic = uartRXCharacteristic else {
            print("UART RX Characteristic not found")
            return
        }
        
        let writeData = Data(command)
        bluetoothPeripheral?.writeValue(writeData, for: uartRXCharacteristic, type: .withResponse)
    }
    //MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state: String
        
        switch central.state {
        case .poweredOn:
            state = "Powered ON"
            centralManager?.scanForPeripherals(withServices: [UARTServiceUUID])
        case .poweredOff:
            state = "Powered OFF"
        case .resetting:
            state = "Resetting"
        case .unauthorized:
            state = "Unauthorized"
        case .unsupported:
            state = "Unsupported"
        default:
            state = "Unknown"
        }
        
        delegate?.centralManagerDidUpdateState(state: central.state)
        print("Central Manager did update state to: \(state)")
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if !peripherals.contains(peripheral) {
            peripherals.append(peripheral)
        }
        
        delegate?.peripheralDeviceFound(peripherals: peripherals)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Central Manager did connect peripheral")
        
        if let name = peripheral.name {
            print("Connected to: \(name)")
        } else {
            print("Connected to device")
        }
        
        status = .start
        connected = true
        bluetoothPeripheral = peripheral
        bluetoothPeripheral?.delegate = self
        delegate?.didConnectPeripheral(deviceName: peripheral.name)
        
        print("Discovering services...")
        peripheral.discoverServices([UARTServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            print("Central Manager did disconnect peripheral with error: \(error.localizedDescription)")
        } else {
            print("Central Manager did disconnect peripheral successfully")
        }
        
        connected = false
        delegate?.didDisconnectPeripheral()
        bluetoothPeripheral?.delegate = nil
        bluetoothPeripheral = nil
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            print("Central Manager did fail to connect to peripheral with error: \(error.localizedDescription)")
        } else {
            print("Central Manager did fail to connect to peripheral")
        }
        
        connected = false
        delegate?.didDisconnectPeripheral()
        bluetoothPeripheral?.delegate = nil
        bluetoothPeripheral = nil
    }
    
    //MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Service discovery failed: \(error!.localizedDescription)")
            return
        }
        
        print("Services discovered")
        
        if let services = peripheral.services {
            for service in services where service.uuid == UARTServiceUUID {
                print("UART Service found")
                peripheral.discoverCharacteristics(nil, for: service)
                return
            }
        }
        
        print("UART Service not found. Try turning Bluetooth off and on again to clear the cache.")
        delegate?.peripheralNotSupported()
        cancelPeripheralConnection()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Characteristics discovery failed")
            return
        }
        print("Characteristics discovered")
        
        if service.uuid.isEqual(UARTServiceUUID) {
            for aCharacteristic: CBCharacteristic in service.characteristics! {
                if aCharacteristic.uuid.isEqual(UARTRXCharacteristicUUID) {
                    print("RX Characteristic found")
                    uartRXCharacteristic = aCharacteristic
                } else if aCharacteristic.uuid.isEqual(UARTTXCharacteristicUUID) {
                    print("TX Characteristic found")
                    uartTXCharacteristic = aCharacteristic
                }
            }
            // Enable notifications on TX Characteristic
            if uartTXCharacteristic != nil && uartRXCharacteristic != nil {
                print("Enabling notifications for \(uartTXCharacteristic!.uuid.uuidString)")
                peripheral.setNotifyValue(true, for: uartTXCharacteristic!)
            } else {
                print("UART service does not have required characteristics. Try to turn Bluetooth Off and On again to clear cache.")
                delegate?.peripheralNotSupported()
                cancelPeripheralConnection()
            }
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Enabling notifications failed: \(error!.localizedDescription)")
            return
        }
        
        if characteristic.isNotifying {
            print("Notifications enabled for characteristic: \(characteristic.uuid.uuidString)")
        } else {
            print("Notifications disabled for characteristic: \(characteristic.uuid.uuidString)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Writing value to characteristic failed: \(error!.localizedDescription)")
            return
        }
        
        print("Data written successfully to characteristic: \(characteristic.uuid.uuidString)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Reading value from characteristic failed: \(error!.localizedDescription)")
            return
        }
        
        guard let value = characteristic.value else {
            print("No data received")
            return
        }
        
        let response = [UInt8](value)
        
        print("Data received from characteristic: \(response)")
        
        if characteristic.uuid == UARTTXCharacteristicUUID {
            // Process the received data
            // processReceivedData(response)
            guard let bytesReceived = characteristic.value else {
              print("Notification received from: \(characteristic.uuid.uuidString), with empty value")
              print("Empty packet received")
              return
            }
            DispatchQueue.main.async {
                if let _shotData  = self.shotData(hexStringArray: bytesReceived.hexEncodedString()) {
                    self.delegate?.didRecieveShotData(shotData: _shotData)
                }else{
                    print("Invalid hexString")
                }
            }
        }
    }
    
    //MARK: - Helper Methods
    func shotData(hexStringArray : [String]) -> ShotModel?{
        if hexStringArray.count >= 14{
            let shotState = ShotState(rawValue: Int(hexStringArray[1] ) ?? 0) ?? .active
            
            let cureentShotTime = hexStringArray[4] + hexStringArray[5]
            
            let splitTime = hexStringArray[6] + hexStringArray[7]
            
            let firstShot = hexStringArray[8] + hexStringArray[9]
            
            let secondShot = hexStringArray[10] + hexStringArray[11]
            
            let currentRound = hexStringArray[12] + hexStringArray[13]
            
            status = shotState
            //
            //      if hexStringArray[2].hexaToDecimal != 0  && shotState != .stopped{
            //
            return ShotModel(isActive: shotState,
                             currentShot: hexStringArray[2].hexaToDecimal,
                             totalShot: hexStringArray[3].hexaToDecimal,
                             splitTime: splitTime.hexaToDecimal.withCommas(),
                             firstShotTime: Double(firstShot.hexaToDecimal)/100,
                             currentShotTime: Double(cureentShotTime.hexaToDecimal)/100,
                             lastShotTime: Double(secondShot.hexaToDecimal)/100,
                             currentRound: currentRound.hexaToDecimal)
            //      }else{
            //        return nil
            //      }
        }else{
            print("Invalid HexString")
            return nil
        }
    }
}


class ShotModel{
  var isActive :ShotState?
  var currentShot :Int?
  var totalShot:Int?
  var splitTime : String?
  var firstShotTime :Double?
  var lastShotTime:Double?
  var currentShotTime :Double?
  var currentRound:Int?
  
  init(isActive:ShotState,currentShot:Int,totalShot:Int,splitTime:String,firstShotTime:Double,currentShotTime:Double,lastShotTime:Double,currentRound:Int){
    self.isActive = isActive
    self.currentShot = currentShot
    self.totalShot = totalShot
    self.splitTime = splitTime
    self.firstShotTime = firstShotTime
    self.lastShotTime = lastShotTime
    self.currentRound = currentRound
    self.currentShotTime = currentShotTime
  }
}

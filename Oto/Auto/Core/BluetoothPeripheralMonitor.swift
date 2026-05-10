import IOBluetooth
import Foundation
import Observation

struct BluetoothPeripheral: Identifiable {
    var id: String { address }
    let address: String
    let name: String
    let kind: BluetoothPeripheralKind
}

enum BluetoothPeripheralKind {
    case keyboard, mouse, headset, gamepad, phone, computer, other

    static func from(classOfDevice cod: BluetoothClassOfDevice) -> Self {
        let major = (cod >> 8) & 0x1F
        let minor = (cod >> 2) & 0x3F
        switch major {
        case 0x05: // Peripheral / HID
            let sub = (minor >> 4) & 0x03
            switch sub {
            case 1, 3: return .keyboard
            case 2:    return .mouse
            default:
                // Minor subtype bits [3:0]: 0x03 = gamepad, 0x04 = joystick
                let sub2 = minor & 0x0F
                if sub2 == 0x03 || sub2 == 0x04 { return .gamepad }
                return .other
            }
        case 0x04: return .headset   // Audio/Video
        case 0x01: return .computer
        case 0x02: return .phone
        default:   return .other
        }
    }

    var systemImage: String {
        switch self {
        case .keyboard:  return "keyboard"
        case .mouse:     return "computermouse"
        case .headset:   return "headphones"
        case .gamepad:   return "gamecontroller"
        case .phone:     return "iphone"
        case .computer:  return "laptopcomputer"
        case .other:     return "wave.3.right"
        }
    }

    var label: String {
        switch self {
        case .keyboard:  return "Keyboard"
        case .mouse:     return "Mouse"
        case .headset:   return "Headset"
        case .gamepad:   return "Game Controller"
        case .phone:     return "Phone"
        case .computer:  return "Computer"
        case .other:     return "Bluetooth"
        }
    }
}

@Observable
@MainActor
final class BluetoothPeripheralMonitor {
    private(set) var connectedDevices: [BluetoothPeripheral] = []

    init() { refresh() }

    func refresh() {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            connectedDevices = []
            return
        }
        connectedDevices = paired
            .filter { $0.isConnected() }
            .compactMap { device in
                guard let name = device.name, !name.isEmpty,
                      let address = device.addressString
                else { return nil }
                return BluetoothPeripheral(
                    address: address,
                    name: name,
                    kind: .from(classOfDevice: device.classOfDevice)
                )
            }
    }
}

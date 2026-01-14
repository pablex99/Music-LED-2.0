import 'package:flutter_blue/flutter_blue.dart';

class BluetoothService {
  final FlutterBlue flutterBlue = FlutterBlue.instance;
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? ledCharacteristic;

  // Cambia estos UUIDs por los de tu ESP32
  static const String serviceUuid = "0000ffe0-0000-1000-8000-00805f9b34fb";
  static const String charUuid = "0000ffe1-0000-1000-8000-00805f9b34fb";

  Future<List<BluetoothDevice>> scanForDevices() async {
    List<BluetoothDevice> foundDevices = [];
    flutterBlue.startScan(timeout: const Duration(seconds: 4));
    await for (ScanResult r in flutterBlue.scanResults.expand((x) => x)) {
      if (!foundDevices.any((d) => d.id == r.device.id)) {
        foundDevices.add(r.device);
      }
    }
    flutterBlue.stopScan();
    return foundDevices;
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    await device.connect();
    connectedDevice = device;
    List<BluetoothService> services = await device.discoverServices();
    for (var s in services) {
      if (s.uuid.toString() == serviceUuid) {
        for (var c in s.characteristics) {
          if (c.uuid.toString() == charUuid) {
            ledCharacteristic = c;
            return true;
          }
        }
      }
    }
    return false;
  }

  Future<void> sendColor(Color color) async {
    if (ledCharacteristic != null) {
      // Envía RGB como bytes: [R, G, B]
      await ledCharacteristic!.write([
        color.red,
        color.green,
        color.blue
      ]);
    }
  }

  void disconnect() {
    connectedDevice?.disconnect();
    connectedDevice = null;
    ledCharacteristic = null;
  }
}

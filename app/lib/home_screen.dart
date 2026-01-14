import 'package:flutter/material.dart';

class ColorMode {
  final String name;
  final IconData icon;
  ColorMode(this.name, this.icon);
}

final List<ColorMode> modes = [
  ColorMode('Manual', Icons.palette),
  ColorMode('Música', Icons.music_note),
  ColorMode('Arcoíris', Icons.gradient),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedMode = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Controlador RGB')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // Barra de modos
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(modes.length, (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ElevatedButton.icon(
                    icon: Icon(modes[i].icon),
                    label: Text(modes[i].name),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedMode == i ? Colors.blue : Colors.grey[300],
                      foregroundColor: selectedMode == i ? Colors.white : Colors.black,
                    ),
                    onPressed: () => setState(() => selectedMode = i),
                  ),
                )),
              ),
              const SizedBox(height: 32),
              if (selectedMode == 0) ManualControlSection(),
              if (selectedMode == 1) MusicControlSection(),
              if (selectedMode == 2) RainbowControlSection(),
            ],
          ),
        ),
      ),
    );
  }
}

import 'color_wheel_picker.dart';
import 'bluetooth_service.dart';

class ManualControlSection extends StatefulWidget {
  @override
  State<ManualControlSection> createState() => _ManualControlSectionState();
}

  Color selectedColor = Colors.blue;
  String statusMsg = '';
  BluetoothService btService = BluetoothService();
  bool isConnected = false;

  Future<void> connectBluetooth() async {
    setState(() { statusMsg = 'Buscando dispositivos...'; });
    var devices = await btService.scanForDevices();
    if (devices.isNotEmpty) {
      // Por simplicidad, conectar al primer dispositivo encontrado
      bool ok = await btService.connectToDevice(devices.first);
      setState(() {
        isConnected = ok;
        statusMsg = ok ? 'Conectado a ${devices.first.name}' : 'No se pudo conectar';
      });
    } else {
      setState(() { statusMsg = 'No se encontraron dispositivos.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Control Manual', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ColorWheelPicker(
          initialColor: selectedColor,
          onColorChanged: (color) => setState(() => selectedColor = color),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: isConnected ? null : connectBluetooth,
              child: const Text('Conectar Bluetooth'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: isConnected
                  ? () async {
                      await btService.sendColor(selectedColor);
                      setState(() { statusMsg = 'Color enviado: #${selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}'; });
                    }
                  : null,
              child: const Text('Aplicar color'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(statusMsg, style: const TextStyle(color: Colors.purple)),
      ],
    );
  }
}

import 'bluetooth_service.dart';

class MusicControlSection extends StatefulWidget {
  @override
  State<MusicControlSection> createState() => _MusicControlSectionState();
}

  double beatThreshold = 400;
  int musicSubmode = 0; // 0 = monocolor, 1 = multicolor
  double musicStepMs = 200;
  BluetoothService btService = BluetoothService();
  String statusMsg = '';
  bool isConnected = false;

  Future<void> connectBluetooth() async {
    setState(() { statusMsg = 'Buscando dispositivos...'; });
    var devices = await btService.scanForDevices();
    if (devices.isNotEmpty) {
      bool ok = await btService.connectToDevice(devices.first);
      setState(() {
        isConnected = ok;
        statusMsg = ok ? 'Conectado a ${devices.first.name}' : 'No se pudo conectar';
      });
    } else {
      setState(() { statusMsg = 'No se encontraron dispositivos.'; });
    }
  }

  Future<void> sendMusicConfig() async {
    // Ejemplo: enviar configuración como string "MUSIC,{umbral},{submodo},{stepMs}"
    if (btService.ledCharacteristic != null) {
      String msg = 'MUSIC,${beatThreshold.round()},$musicSubmode,${musicStepMs.round()}';
      await btService.ledCharacteristic!.write(msg.codeUnits);
      setState(() { statusMsg = 'Configuración enviada'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Modo Música', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.surround_sound, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text('Sensibilidad Beat'),
          ],
        ),
        Slider(
          min: 0,
          max: 2000,
          value: beatThreshold,
          onChanged: (v) => setState(() => beatThreshold = v),
          label: beatThreshold.round().toString(),
        ),
        Text('Umbral actual: ${beatThreshold.round()}'),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => setState(() => musicSubmode = 0),
              style: ElevatedButton.styleFrom(
                backgroundColor: musicSubmode == 0 ? Colors.blue : Colors.grey[300],
                foregroundColor: musicSubmode == 0 ? Colors.white : Colors.black,
              ),
              child: const Text('Monocolor'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => setState(() => musicSubmode = 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: musicSubmode == 1 ? Colors.blue : Colors.grey[300],
                foregroundColor: musicSubmode == 1 ? Colors.white : Colors.black,
              ),
              child: const Text('Multicolor'),
            ),
          ],
        ),
        if (musicSubmode == 1) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer, color: Colors.orange),
              const SizedBox(width: 8),
              Text('Duración paso multicolor'),
            ],
          ),
          Slider(
            min: 5,
            max: 5000,
            value: musicStepMs,
            onChanged: (v) => setState(() => musicStepMs = v),
            label: musicStepMs.round().toString(),
          ),
          Text('${musicStepMs.round()} ms'),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: isConnected ? null : connectBluetooth,
              child: const Text('Conectar Bluetooth'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: isConnected ? sendMusicConfig : null,
              child: const Text('Aplicar configuración'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(statusMsg, style: const TextStyle(color: Colors.purple)),
      ],
    );
  }
}

import 'bluetooth_service.dart';

class RainbowControlSection extends StatefulWidget {
  @override
  State<RainbowControlSection> createState() => _RainbowControlSectionState();
}

  double rainbowSpeed = 30; // ms entre pasos
  double rainbowBrightness = 100; // porcentaje
  BluetoothService btService = BluetoothService();
  String statusMsg = '';
  bool isConnected = false;

  Future<void> connectBluetooth() async {
    setState(() { statusMsg = 'Buscando dispositivos...'; });
    var devices = await btService.scanForDevices();
    if (devices.isNotEmpty) {
      bool ok = await btService.connectToDevice(devices.first);
      setState(() {
        isConnected = ok;
        statusMsg = ok ? 'Conectado a ${devices.first.name}' : 'No se pudo conectar';
      });
    } else {
      setState(() { statusMsg = 'No se encontraron dispositivos.'; });
    }
  }

  Future<void> sendRainbowConfig() async {
    // Ejemplo: enviar configuración como string "RAINBOW,{velocidad},{brillo}"
    if (btService.ledCharacteristic != null) {
      String msg = 'RAINBOW,${rainbowSpeed.round()},${rainbowBrightness.round()}';
      await btService.ledCharacteristic!.write(msg.codeUnits);
      setState(() { statusMsg = 'Configuración enviada'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Modo Arcoíris', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.speed, color: Colors.green),
            const SizedBox(width: 8),
            Text('Velocidad'),
          ],
        ),
        Slider(
          min: 5,
          max: 2000,
          value: rainbowSpeed,
          onChanged: (v) => setState(() => rainbowSpeed = v),
          label: rainbowSpeed.round().toString(),
        ),
        Text('${rainbowSpeed.round()} ms'),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.brightness_6, color: Colors.amber),
            const SizedBox(width: 8),
            Text('Brillo'),
          ],
        ),
        Slider(
          min: 0,
          max: 100,
          value: rainbowBrightness,
          onChanged: (v) => setState(() => rainbowBrightness = v),
          label: '${rainbowBrightness.round()}%',
        ),
        Text('${rainbowBrightness.round()}%'),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: isConnected ? null : connectBluetooth,
              child: const Text('Conectar Bluetooth'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: isConnected ? sendRainbowConfig : null,
              child: const Text('Aplicar configuración'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(statusMsg, style: const TextStyle(color: Colors.purple)),
      ],
    );
  }
}

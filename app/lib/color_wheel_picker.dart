import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorWheelPicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;
  const ColorWheelPicker({super.key, required this.initialColor, required this.onColorChanged});

  @override
  State<ColorWheelPicker> createState() => _ColorWheelPickerState();
}

class _ColorWheelPickerState extends State<ColorWheelPicker> {
  late Color currentColor;

  @override
  void initState() {
    super.initState();
    currentColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ColorPicker(
          pickerColor: currentColor,
          onColorChanged: (color) {
            setState(() => currentColor = color);
            widget.onColorChanged(color);
          },
          colorPickerWidth: 300,
          pickerAreaHeightPercent: 0.8,
          enableAlpha: false,
          displayThumbColor: true,
          showLabel: false,
          pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        const SizedBox(height: 8),
        Text('Color seleccionado: #${currentColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}'),
      ],
    );
  }
}

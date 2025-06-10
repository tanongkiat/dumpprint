import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart'; // Add this import

class MenuPage extends StatelessWidget {
  final BluetoothDevice device;
  final BluetoothCharacteristic serialCharacteristic;
  const MenuPage({
    Key? key,
    required this.device,
    required this.serialCharacteristic,
  }) : super(key: key);

  List<int> buildTxtTscCommand(String text) {
    String command =
        '''
SIZE 72 mm,10 mm
GAP 0 mm,0 mm
SPEED 4
DENSITY 12
CODEPAGE UTF-8
SET TEAR ON
SET CUTTER OFF
CLS
DIRECTION 0
TEXT 100,20,"courmon.TTF",0,12,12, "$text"
PRINT 1,1
''';
    return command.codeUnits;
  }

  Future<void> printTscCommand(BuildContext context, int menuIndex) async {
    List<int> tscCommand;
    if (menuIndex == 0) {
      tscCommand = buildTxtTscCommand("Hello TSC!");
    } else if (menuIndex == 1) {
      tscCommand = await loadTscFromAssets('assets/Delivery.txt');
    } else if (menuIndex == 2) {
      tscCommand = await loadTscFromAssets('assets/Delivery2_fixmm.txt');
    } else if (menuIndex == 3) {
      tscCommand = await loadTscFromAssets('assets/Delivery2_addcomma.txt');
    } else if (menuIndex == 4) {
      tscCommand = await loadTscFromAssets('assets/Delivery2.txt');
    } else if (menuIndex == 5) {
      tscCommand = await loadTscFromAssets('assets/Flash.txt');
    } else if (menuIndex == 6) {
      tscCommand = await loadTscFromAssets('assets/J_T.txt');
    } else if (menuIndex == 7) {
      tscCommand = await loadTscFromAssets('assets/Slip.txt');
    } else if (menuIndex == 8) {
      tscCommand = await loadTscFromAssets('assets/Slip2.txt');
    } else if (menuIndex == 9) {
      tscCommand = await loadTscFromAssets('assets/Slip2_removeQ.txt');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No print action for menu $menuIndex')),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      const chunkSize = 200;
      for (var i = 0; i < tscCommand.length; i += chunkSize) {
        final chunk = tscCommand.sublist(
          i,
          (i + chunkSize > tscCommand.length)
              ? tscCommand.length
              : i + chunkSize,
        );
        await serialCharacteristic.write(chunk, withoutResponse: true);
        await Future.delayed(const Duration(milliseconds: 10));
      }
      Navigator.pop(context); // Remove loading dialog
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('TSC print command sent')));
    } catch (e) {
      Navigator.pop(context); // Remove loading dialog
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    }
  }

  void onMenuClick(BuildContext context, int index) {
    if (index == 0 ||
        index == 1 ||
        index == 2 ||
        index == 3 ||
        index == 4 ||
        index == 5 ||
        index == 6 ||
        index == 7 ||
        index == 8 ||
        index == 9) {
      printTscCommand(context, index);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Menu ${index + 1} clicked')));
    }
  }

  Future<List<int>> loadTscFromAssets(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List();

    // Debug: Print the first 100 bytes as string and as hex
    debugPrint('Loaded ${bytes.length} bytes from $assetPath');
    debugPrint('As String: ${String.fromCharCodes(bytes.take(100))}');
    debugPrint(
      'As Hex: ${bytes.take(200).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    final menuLabels = [
      'Print Hello TSC!',
      'Dump SpeedyFixed..(Multiple Fixed))',
      'Dump Speedy (Only mm added)', // BITMAP 0,0, x, y, ==> x ==mm y = (mmx8)+7
      'Dump Speedy fix Delivery2.txt (Only comma added)', // BITMAP 0,0, x, y, ==> x ==mm y = (mmx8)+7
      'Dump Speedy non Delivery2.txt',
      'Dump Flash.txt',
      'Dump J_T.txt',
      'Dump POS..(Multiple Fixed)',
      'Dump POS.. (Original)',
      'Dump POS.. (Remove Only Q Command)',
    ];

    return Scaffold(
      appBar: AppBar(title: Text(device.platformName)),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: menuLabels.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton(
              onPressed: () => onMenuClick(context, index),
              child: Text(menuLabels[index]),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'menu_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const BluetoothScanPage(),
    );
  }
}

class BluetoothScanPage extends StatefulWidget {
  const BluetoothScanPage({super.key});

  @override
  State<BluetoothScanPage> createState() => _BluetoothScanPageState();
}

class _BluetoothScanPageState extends State<BluetoothScanPage> {
  List<ScanResult> scanResults = [];
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();

    setState(() {
      isScanning = true;
      scanResults.clear();
    });

    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    setState(() {
      isScanning = false;
    });
  }

  void _onDeviceTap(BluetoothDevice device) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await device.connect(timeout: const Duration(seconds: 10));
    } catch (e) {
      // Ignore if already connected
    }

    // Wait until the device is connected
    BluetoothConnectionState state = await device.connectionState
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) {
            sink.add(BluetoothConnectionState.disconnected);
            sink.close();
          },
        )
        .firstWhere(
          (s) =>
              s == BluetoothConnectionState.connected ||
              s == BluetoothConnectionState.disconnected,
        );

    Navigator.pop(context); // Remove loading dialog

    if (state == BluetoothConnectionState.connected) {
      // Discover services and find the serial characteristic
      try {
        List<BluetoothService> services = await device.discoverServices();
        // Replace these UUIDs with your printer's serial service/characteristic UUIDs if known
        const serialServiceUUID = "49535343-fe7d-4ae5-8fa9-9fafd205e455";
        const serialCharUUID = "49535343-8841-43f4-a8d4-ecbe34729bb3";
        final service = services.firstWhere(
          (s) => s.uuid.str.toLowerCase() == serialServiceUUID,
          orElse: () => throw Exception('Serial service not found'),
        );
        final characteristic = service.characteristics.firstWhere(
          (c) => c.uuid.str.toLowerCase() == serialCharUUID,
          orElse: () => throw Exception('Serial characteristic not found'),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MenuPage(device: device, serialCharacteristic: characteristic),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Serial characteristic not found: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect to device.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter out devices with empty names and sort by name
    final filteredResults =
        scanResults.where((r) => r.device.name.isNotEmpty).toList()
          ..sort((a, b) => a.device.name.compareTo(b.device.name));

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Bluetooth Devices')),
      body: isScanning
          ? const Center(child: CircularProgressIndicator())
          : filteredResults.isEmpty
          ? const Center(child: Text('No Bluetooth devices found.'))
          : ListView.builder(
              itemCount: filteredResults.length,
              itemBuilder: (context, index) {
                final result = filteredResults[index];
                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(result.device.name),
                  subtitle: Text(result.device.id.toString()),
                  onTap: () => _onDeviceTap(result.device),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startScan,
        child: const Icon(Icons.refresh),
        tooltip: 'Scan Again',
      ),
    );
  }
}

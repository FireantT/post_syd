import 'package:flutter/material.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

class BarcodeService {
  // Scan barcode
  Future<String?> scanBarcode(BuildContext context) async {
    try {
      final result = await SimpleBarcodeScanner.scanBarcode(
        context, 
        barcodeAppBar: const BarcodeAppBar(
          appBarTitle: "Scan Barcode",
          centerTitle: false,
          enableBackButton: false,
          backButtonIcon: Icon(Icons.arrow_back, color: Colors.white),
        ),
        isShowFlashIcon: true,
        delayMillis: 2000,
        cameraFace: CameraFace.back,
      );
      
      // Check if the scan was successful
      if (result != null && result != '-1' && result.isNotEmpty) {
        return result;
      }
      return null;
    } catch (e) {
      print('Barcode scanning error: $e');
      return null;
    }
  }
}
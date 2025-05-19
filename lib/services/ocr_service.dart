import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  CameraController? cameraController;
  bool isCameraInitialized = false;
  
  bool isProcessingFrame = false;
  String recognizedText = '';
  bool isLiveOcrRunning = false;
  
  // Initialize camera for OCR
  Future<void> initializeCamera(List<CameraDescription> cameras) async {
    if (cameras.isEmpty) return;
    
    cameraController = CameraController(
      cameras[0],
      ResolutionPreset.medium,
    );

    try {
      await cameraController!.initialize();
      isCameraInitialized = true;
    } catch (e) {
      print("Camera initialization error: $e");
    }
  }
  
  // Process image for OCR
  Future<String> processImageForOcr(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFilePath(imagePath);
    
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      print("Recognized text: ${recognizedText.text}");
      return recognizedText.text;
    } catch (e) {
      print("Text recognition error: $e");
      return "";
    } finally {
      textRecognizer.close();
    }
  }
  
  // Start live OCR
  void startLiveOcr(Function(String) onTextRecognized) async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      return;
    }
    
    isLiveOcrRunning = true;
    recognizedText = "Starting OCR...";
    onTextRecognized(recognizedText);
    
    Future.doWhile(() async {
      if (!isLiveOcrRunning) return false;
      
      if (!isProcessingFrame) {
        isProcessingFrame = true;
        
        try {
          final XFile file = await cameraController!.takePicture();
          
          final result = await processImageForOcr(file.path);
          
          if (result.isNotEmpty) {
            recognizedText = result;
            onTextRecognized(result);
          }
        } catch (e) {
          print("Error during OCR process: $e");
        } finally {
          isProcessingFrame = false;
        }
      }
      
      await Future.delayed(const Duration(milliseconds: 1000));
      return true;
    });
  }
  
  // Stop live OCR
  void stopLiveOcr() {
    isLiveOcrRunning = false;
  }
  
  // Toggle live OCR
  void toggleLiveOcr(Function(String) onTextRecognized) {
    if (isLiveOcrRunning) {
      stopLiveOcr();
    } else {
      startLiveOcr(onTextRecognized);
    }
  }
  
  void dispose() {
    stopLiveOcr();
    cameraController?.dispose();
    cameraController = null;
    isCameraInitialized = false;
  }
}
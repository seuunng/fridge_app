

import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

Future<void> testStorageUpload() async {
try {
final ref = FirebaseStorage.instance.ref().child('C:\\Users\\mnbxo\\OneDrive\\바탕 화면\\물개.png');
final uploadTask = await ref.putFile(File('path_to_your_test_image'));
final downloadUrl = await ref.getDownloadURL();
print('Image uploaded successfully. Download URL: $downloadUrl');
} catch (e) {
print('Error uploading image: $e');
}
}


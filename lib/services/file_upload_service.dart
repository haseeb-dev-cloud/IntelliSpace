import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart';

class FileUploadService {
  final storage = FirebaseStorage.instance;
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  Future<void> pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) return;

    final file = File(result.files.single.path!);
    final fileName = basename(file.path);
    final user = auth.currentUser;
    final fileType = result.files.single.extension ?? 'unknown';
    final fileSize = await file.length();

    if (user == null) {
      print("User not logged in.");
      return;
    }

    // Folder structure: userId/category/filename
    final storageRef = storage
        .ref()
        .child('user_files')
        .child(user.uid)
        .child(fileType)
        .child(fileName);

    final uploadTask = storageRef.putFile(file);
    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    // Save metadata to Firestore
    await firestore
        .collection('users')
        .doc(user.uid)
        .collection('uploaded_files')
        .add({
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'url': downloadUrl,
      'uploadTime': Timestamp.now(),
    });

    print("File uploaded and metadata saved.");
  }
}

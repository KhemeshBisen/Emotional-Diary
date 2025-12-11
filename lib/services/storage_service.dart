import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  static Future<String> uploadAudio(File file, String uid) async {
    // 1) unique file naam
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.m4a';

    // 2) storage path decide karo
    final ref = FirebaseStorage.instance
        .ref()
        .child('audio')
        .child(uid)
        .child(fileName);

    // 3) file upload karo
    final uploadTask = await ref.putFile(file);

    // 4) download URL lo (yeh hum Firestore me rakhenge)
    final url = await uploadTask.ref.getDownloadURL();
    return url;
  }
}

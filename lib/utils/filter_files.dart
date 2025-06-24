import 'package:mime/mime.dart';

bool isVideo(String filePath, {bool failUnmatched = true}) {
  final String? mimeType = lookupMimeType(filePath);

  if (mimeType == null) {
    if (failUnmatched) {
      return false;
    } else {
      return true;
    }
  }

  final splitMime = mimeType.split('/');
  if (splitMime[0] == 'video') {
    return true;
  } else {
    return false;
  }
}

import 'package:mime/mime.dart';

/// Evaluate whether the provided file is a video file.
///
/// Detection is accomplished by assessing the leading component of the file's MIME type definition.
/// A file is assumed to be a video if the leading component is `video/`.
///
/// By default, this function will return `false` if the MIME type cannot be determined, this
/// behavior can be controlled by the [failUnmatched] flag.
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

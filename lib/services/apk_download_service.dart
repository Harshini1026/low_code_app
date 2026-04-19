import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';

class ApkDownloadService {
  static Future<void> downloadApk({
    required String downloadUrl,
    required Function(double) onProgress,
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    if (kIsWeb) {
      onError('Download not supported on web');
      return;
    }
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      onError('Storage permission denied');
      return;
    }
    final dir = await getExternalStorageDirectory();
    final savePath = '${dir!.path}/app-release.apk';
    final dio = Dio();
    await dio.download(
      downloadUrl,
      savePath,
      onReceiveProgress: (received, total) {
        if (total != -1) onProgress(received / total);
      },
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'application/vnd.android.package-archive'},
      ),
    );
    onSuccess(savePath);
    await OpenFile.open(savePath);
  }
}

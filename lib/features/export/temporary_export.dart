import 'package:rosid/data/files/private_file_store.dart';

Future<T> withTemporaryExport<T>({
  required PrivateFileStore fileStore,
  required Future<String> Function() create,
  required Future<T> Function(String path) use,
}) async {
  String? path;
  try {
    path = await create();
    return await use(path);
  } finally {
    if (path != null) await fileStore.deleteExportIfPresent(path);
  }
}

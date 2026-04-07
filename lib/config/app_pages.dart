import 'package:get/get.dart';

import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/splash_page.dart';
import '../features/camera/pages/camera_page.dart';
import '../ui/folder_detail/folder_detail_page.dart';
import '../ui/folders/folders_page.dart';
import '../ui/image_viewer/image_viewer_page.dart';
import '../ui/report/report_page.dart';
import '../ui/settings/settings_page.dart';

/// Declarative routes for [GetMaterialApp] (replaces go_router).
class AppPages {
  AppPages._();

  static final List<GetPage<dynamic>> routes = <GetPage<dynamic>>[
    GetPage<void>(name: '/', page: () => const SplashPage()),
    GetPage<void>(name: '/login', page: () => const LoginPage()),
    GetPage<void>(name: '/folders', page: () => const FoldersPage()),
    GetPage<void>(
      name: '/folder/:folderId',
      page: () => FolderDetailPage(folderId: Get.parameters['folderId']!),
    ),
    GetPage<void>(
      name: '/camera/:folderId',
      page: () => CameraPage(folderId: Get.parameters['folderId']!),
    ),
    GetPage<void>(
      name: '/image/:folderId/:imageId',
      page: () => ImageViewerPage(
        folderId: Get.parameters['folderId']!,
        imageId: Get.parameters['imageId']!,
      ),
    ),
    GetPage<void>(
      name: '/report/:folderId',
      page: () {
        final folderId = Get.parameters['folderId']!;
        final args = Get.arguments;
        return ReportPage(
          folderId: folderId,
          reportData: args is Map<String, dynamic> ? args : null,
        );
      },
    ),
    GetPage<void>(name: '/settings', page: () => const SettingsPage()),
  ];
}

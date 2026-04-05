import 'package:go_router/go_router.dart';
import '../features/auth/pages/splash_page.dart';
import '../features/auth/pages/login_page.dart';
import '../ui/folders/folders_page.dart';
import '../ui/folder_detail/folder_detail_page.dart';
import '../features/camera/pages/camera_page.dart';
import '../ui/image_viewer/image_viewer_page.dart';
import '../ui/report/report_page.dart';
import '../ui/settings/settings_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashPage()),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(path: '/folders', builder: (context, state) => const FoldersPage()),
    GoRoute(path: '/folder/:folderId', builder: (context, state) => FolderDetailPage(folderId: state.pathParameters['folderId']!)),
    GoRoute(path: '/camera/:folderId', builder: (context, state) => CameraPage(folderId: state.pathParameters['folderId']!)),
    GoRoute(path: '/image/:folderId/:imageId', builder: (context, state) => ImageViewerPage(folderId: state.pathParameters['folderId']!, imageId: state.pathParameters['imageId']!)),
    GoRoute(path: '/report/:folderId', builder: (context, state) => ReportPage(folderId: state.pathParameters['folderId']!, reportData: state.extra as Map<String, dynamic>?)),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
  ],
);


// final GoRouter appRouter = GoRouter(
//   initialLocation: '/',
//   routes: [
//     GoRoute(path: '/', builder: (context, state) => const SplashPage()),
//     GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
//     GoRoute(path: '/folders', builder: (context, state) => const FoldersPage()),
//     GoRoute(path: '/folder/:folderId', builder: (context, state) => FolderDetailPage(folderId: state.pathParameters['folderId']!)),
//     GoRoute(path: '/camera/:folderId', builder: (context, state) => CameraPage(folderId: state.pathParameters['folderId']!)),
//     GoRoute(path: '/image/:folderId/:imageId', builder: (context, state) => ImageViewerPage(folderId: state.pathParameters['folderId']!, imageId: state.pathParameters['imageId']!)),
//     GoRoute(path: '/report/:folderId', builder: (context, state) => ReportPage(folderId: state.pathParameters['folderId']!, reportData: state.extra as Map<String, dynamic>?)),
//     GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
//   ],
// );

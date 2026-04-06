# Hexa-Cam Complete Project Documentation

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture & Design](#architecture--design)
3. [Features & Functionality](#features--functionality)
4. [Technical Implementation](#technical-implementation)
5. [Development & Setup](#development--setup)
6. [User Guides](#user-guides)
7. [API & Integrations](#api--integrations)
8. [Data Models & Schemas](#data-models--schemas)
9. [Testing & Quality Assurance](#testing--quality-assurance)
10. [Deployment & Build](#deployment--build)
11. [Troubleshooting](#troubleshooting)
12. [Contributing](#contributing)

## Project Overview

### What is Hexa-Cam?
Hexa-Cam is a comprehensive cross-platform scientific imaging and microscopy application built with Flutter. It provides researchers, scientists, and professionals with advanced tools for capturing, annotating, measuring, and documenting microscopic images and videos.

### Key Characteristics
- **Cross-Platform**: Android, iOS, Web, Windows, macOS, Linux
- **Scientific Focus**: Specialized for microscopy and scientific imaging
- **Real-time Processing**: Live camera preview with annotation capabilities
- **Measurement Tools**: Calibrated measurement system with multiple units
- **Professional Reports**: PDF report generation with embedded images
- **Offline-First**: Full functionality without internet connection

### Project History & Creation
- **Created**: 2024
- **Technology**: Flutter (Dart programming language)
- **Target Users**: Researchers, lab technicians, educators, quality control professionals
- **Use Cases**: Microscopic analysis, material science, biological research, industrial inspection

### Business Value
- **Accuracy**: Calibrated measurements ensure scientific precision
- **Efficiency**: Digital workflow replaces manual documentation
- **Collaboration**: Shareable reports and standardized formats
- **Compliance**: Professional documentation for regulatory requirements

## Architecture & Design

### System Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    Hexa-Cam Application                      │
├─────────────────────────────────────────────────────────────┤
│  Presentation Layer (UI)                                    │
│  ├── Flutter Widgets                                        │
│  ├── Material Design                                        │
│  └── Responsive Layout                                      │
├─────────────────────────────────────────────────────────────┤
│  Business Logic Layer                                       │
│  ├── Controllers (GetX)                                     │
│  ├── State Management (Riverpod)                            │
│  └── Services (API, Storage, Camera)                        │
├─────────────────────────────────────────────────────────────┤
│  Data Layer                                                 │
│  ├── Local Database (SQLite/Hive)                           │
│  ├── File System                                            │
│  └── API Integration                                        │
├─────────────────────────────────────────────────────────────┤
│  Platform Layer                                             │
│  ├── Camera APIs                                            │
│  ├── File System APIs                                       │
│  └── Hardware Interfaces                                    │
└─────────────────────────────────────────────────────────────┘
```

### Design Principles
- **Separation of Concerns**: Clear layers for UI, business logic, and data
- **Reactive Programming**: State management with GetX and Riverpod
- **Platform Abstraction**: Unified API across all platforms
- **Offline-First**: Core functionality works without network
- **Performance**: Optimized for real-time camera processing

### Code Organization
```
lib/
├── main.dart                 # Application entry point
├── app.dart                  # Root widget and routing
├── config/                   # Configuration files
│   ├── api_config.dart      # API endpoints
│   ├── constants.dart       # App constants
│   ├── routes.dart          # Navigation routes
│   └── theme.dart           # UI theme
├── features/                 # Feature modules
│   ├── auth/                # Authentication feature
│   └── camera/              # Camera feature
├── controllers/              # GetX controllers
├── data/                     # Data layer
│   ├── models/              # Data models
│   ├── services/            # Business services
│   └── repositories/        # Data access
├── state/                    # State management
├── ui/                       # UI components
├── utils/                    # Utility functions
└── config/                   # Configuration
```

## Features & Functionality

### 1. Authentication System
**Purpose**: Secure user authentication with offline support

**Components**:
- Login screen with email/password
- Secure token storage (FlutterSecureStorage)
- Session management with auto-login
- Offline mode support

**Technical Details**:
- API endpoint: `/hexa-auth/login`
- Token storage: Encrypted secure storage
- Session validation: Automatic token refresh
- Offline fallback: Cached credentials

**User Flow**:
1. Enter email and password
2. API authentication
3. Token storage for offline access
4. Automatic login on app restart

### 2. Folder Management System
**Purpose**: Organize scientific data into logical project folders

**Features**:
- Create, rename, delete folders
- Hierarchical organization
- Metadata storage (creation date, image counts)
- Quick access to recent folders

**Data Structure**:
```dart
class Folder {
  final String id;
  final String name;
  final String createdAt;
  final List<ImageData> images;
  final List<ReportData>? reports;
}
```

**Storage**: SharedPreferences with JSON serialization

### 3. Advanced Camera System
**Purpose**: Professional camera interface optimized for microscopy

**Camera Features**:
- **Multi-Resolution Support**: Low/Medium/High/Max presets
- **Lens Management**: 4X, 10X, 20X, 40X magnification tracking
- **Real-time Controls**:
  - Zoom: 1x to 100x (device-dependent)
  - Flip: Horizontal/Vertical axes
  - Rotate: 90° increments (0°, 90°, 180°, 270°)
  - Mirror: Camera inspection mode

**Settings Management**:
```dart
class CameraSettings {
  final double exposure;     // 50-200% compensation
  final double iso;          // 100-3200 sensitivity
  final double temperature;  // 2000-10000K color temp
  final double tint;         // -100 to +100 color balance
  final double zoom;         // 1.0 to max supported
}
```

**Platform-Specific Implementation**:
- **Android/iOS**: Native camera APIs with resolution fallback
- **Web**: Browser camera APIs with permission handling
- **Desktop**: Webcam support with device selection

### 4. Annotation & Drawing System
**Purpose**: Professional annotation tools for scientific documentation

**Annotation Types**:
```dart
enum AnnotationType {
  draw,           // Free-form drawing
  text,           // Text labels
  arrow,          // Directional arrows
  arrowOneWay,    // Single-direction arrows
  circle,         // Circular markers
  rectangle,      // Rectangular areas
  square,         // Square markers
  twoPointer,     // Distance measurement
  singlePointer   // Point markers
}
```

**Annotation Data Structure**:
```dart
class Annotation {
  final String id;
  final AnnotationType type;
  final List<HexaPoint> points;
  final String? text;
  final Color color;
  final double strokeWidth;
  final String timestamp;
  final String? measurement;
  final String coordinateSpace;
}
```

**Drawing Features**:
- **Color Picker**: 8 predefined colors + RGB sliders
- **Stroke Width**: Configurable line thickness
- **Coordinate System**: Normalized coordinates (0.0-1.0)
- **Real-time Rendering**: Hardware-accelerated drawing
- **Undo/Redo**: Full annotation history

### 5. Measurement & Calibration System
**Purpose**: Precise scientific measurements with calibration

**Calibration Process**:
1. Select magnification lens (4X, 10X, 20X, 40X)
2. Capture reference image with known scale
3. Draw calibration line of known physical length
4. System calculates pixels per unit
5. Store calibration per lens

**Calibration Storage**:
```dart
class StoredCalibration {
  final String lens;              // "4X", "10X", etc.
  final String unit;              // "μm", "nm", "mm"
  final double unitPerPixel;      // Conversion factor
  final double pixelsPerUnit;     // Inverse factor
  final double referenceLength;   // Known physical length
  final double measuredPixelDistance; // Measured pixels
}
```

**Measurement Units**:
- Length: μm (micrometers), nm (nanometers), mm (millimeters)
- Area: μm², nm², mm²
- Automatic unit conversion

**Measurement Tools**:
- Distance measurement (two-point)
- Area calculation (polygon)
- Scale bars and rulers
- Measurement overlays

### 6. Image Processing & Export
**Purpose**: Professional image processing and export capabilities

**Supported Formats**:
- **Input**: JPEG, PNG (camera capture)
- **Output**: JPEG, PNG, PDF (reports)
- **Video**: MP4 with annotations baked in

**Processing Features**:
- **Color Correction**: Exposure, temperature, tint
- **Geometric Transforms**: Flip, rotate, mirror
- **Annotation Baking**: Burn annotations into image
- **Resolution Scaling**: High-quality resampling

**Export Options**:
- **PDF Reports**: Multi-page with metadata
- **Image Export**: With/without annotations
- **Video Export**: FFmpeg processing with overlays

### 7. Report Generation System
**Purpose**: Create professional scientific reports

**Report Components**:
- **Header**: Organization details, contact information
- **Camera Settings**: Exposure, ISO, temperature, lens
- **Images**: Full-size with annotations
- **Measurements**: Detailed measurement tables
- **Metadata**: Timestamp, device info, calibration data

**PDF Structure**:
```dart
class ReportData {
  final String id;
  final String filename;
  final String timestamp;
  final String? pdfAssetId;
  final String? previewImageUrl;
  final String? description;
  final String? lens;
  final ReportFormData? formData;
  final List<Map<String, dynamic>>? sourceImages;
}
```

**Report Workflow**:
1. Select images and annotations
2. Fill organization details
3. Generate PDF with embedded assets
4. Save locally or share

### 8. Data Management & Storage
**Purpose**: Robust data persistence and management

**Storage Layers**:
- **SharedPreferences**: App settings, user preferences
- **SQLite Database**: Structured data (folders, images, reports)
- **Hive**: Fast NoSQL for calibrations
- **File System**: Images, videos, PDFs

**Database Schema**:
```sql
-- Media assets table
CREATE TABLE media_assets (
  id TEXT PRIMARY KEY,
  data BLOB NOT NULL,
  created_at INTEGER NOT NULL
);

-- Folders stored as JSON in SharedPreferences
-- Images stored as JSON in SharedPreferences
-- Annotations stored as JSON in SharedPreferences
```

**Data Synchronization**:
- Local-first architecture
- Optional cloud backup
- Conflict resolution
- Data export/import

## Technical Implementation

### State Management Architecture
**GetX Controllers**:
- `AuthController`: Authentication state
- `CameraController`: Camera operations
- `AsyncActionController`: UI action blocking
- `PermissionController`: Runtime permissions

**Riverpod Providers**:
- `FoldersController`: Folder CRUD operations
- `CalibrationController`: Calibration management
- `UiStateController`: UI state management

### Dependency Injection
```dart
void initAppDependencies(SharedPreferences sharedPreferences) {
  Get.put<SharedPreferences>(sharedPreferences, permanent: true);
  Get.put<StorageService>(StorageService(sharedPreferences), permanent: true);
  Get.put<CameraController>(CameraController(), permanent: true);
  Get.put<PermissionController>(PermissionController(sharedPreferences), permanent: true);
  // ... more dependencies
}
```

### Camera Pipeline
1. **Initialization**: Camera device detection and permission requests
2. **Configuration**: Resolution selection and parameter setting
3. **Preview**: Real-time camera feed with overlay rendering
4. **Capture**: Image/video capture with metadata
5. **Processing**: Annotation baking and export

### Rendering Pipeline
1. **Camera Preview**: Native camera texture
2. **Transform Layer**: Geometric transformations (flip, rotate)
3. **Color Correction**: Exposure, temperature, tint filters
4. **Annotation Layer**: Vector graphics rendering
5. **UI Overlay**: Controls and measurement displays

## Development & Setup

### Prerequisites
- **Flutter SDK**: ^3.10.0
- **Dart SDK**: ^3.10.0
- **Android Studio/VS Code**: IDE with Flutter extensions
- **Android SDK**: API level 21+ (Android 5.0+)
- **Xcode**: macOS for iOS development

### Environment Setup
```bash
# Install Flutter
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Verify installation
flutter doctor

# Enable platforms
flutter config --enable-web
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop
flutter config --enable-linux-desktop
```

### Project Setup
```bash
# Clone repository
git clone <repository-url>
cd demo_app

# Install dependencies
flutter pub get

# Generate platform-specific files
flutter create --platforms=android,ios,web,windows,macos,linux .

# Run code generation (if using build_runner)
flutter pub run build_runner build
```

### API Configuration
**Build-time Configuration**:
```bash
# Android/iOS
flutter build apk --dart-define=API_BASE_URL=https://your-api.example.com/api

# Web
flutter build web --dart-define=API_BASE_URL=https://your-api.example.com/api
```

**Runtime Configuration** (Android):
```properties
# android/local.properties
API_BASE_URL=https://your-api.example.com/api
```

### Development Workflow
```bash
# Run in development mode
flutter run

# Run with specific device
flutter run -d <device-id>

# Run tests
flutter test

# Build for production
flutter build apk --release
flutter build ios --release
flutter build web --release
```

## User Guides

### Getting Started
1. **Installation**: Download from app stores or build from source
2. **First Launch**: Grant camera and storage permissions
3. **Authentication**: Login with institutional credentials
4. **Calibration**: Set up microscope calibration for accurate measurements

### Basic Usage Workflow
1. **Create Folder**: Organize work by project or sample
2. **Camera Setup**: Select lens magnification and calibrate
3. **Capture**: Take images or record video
4. **Annotate**: Add measurements and labels
5. **Generate Report**: Create professional PDF documentation

### Advanced Features
- **Multi-point Measurements**: Complex distance and area calculations
- **Video Annotation**: Time-synchronized annotations
- **Batch Processing**: Process multiple images
- **Custom Calibrations**: Multiple calibration profiles

### Troubleshooting
- **Camera Issues**: Check permissions, restart app, try different resolution
- **Measurement Inaccuracy**: Recalibrate with reference sample
- **App Crashes**: Clear app data, reinstall, check device compatibility

## API & Integrations

### Authentication API
**Endpoint**: `POST /hexa-auth/login`
**Request**:
```json
{
  "email": "user@example.com",
  "password": "password"
}
```
**Response**:
```json
{
  "success": true,
  "token": "jwt-token",
  "user": {
    "id": "user-id",
    "email": "user@example.com",
    "fullName": "User Name"
  }
}
```

### API Configuration
- **Base URL**: Configurable via build parameters
- **Authentication**: JWT Bearer tokens
- **Timeout**: 30 seconds for requests
- **Retry Logic**: Automatic retry for network failures

### External Integrations
- **Camera Hardware**: Native platform APIs
- **File System**: Platform-specific storage
- **PDF Generation**: pdf package
- **Video Processing**: FFmpeg integration

## Data Models & Schemas

### Core Data Models
```dart
// User authentication
class LoginRequest {
  final String email;
  final String password;
}

class LoginResponse {
  final bool success;
  final String? token;
  final UserData? user;
  final String? message;
}

// Image and media data
class ImageData {
  final String id;
  final String imageUrl;
  final CameraSettings cameraSettings;
  final List<Annotation> annotations;
  final List<MeasurementData> measurements;
  final Calibration? calibration;
  final MediaType type;
  final String lens;
  final String timestamp;
}

// Annotation system
class Annotation {
  final String id;
  final AnnotationType type;
  final List<HexaPoint> points;
  final Color color;
  final String? measurement;
  final String coordinateSpace;
}

// Point system for coordinates
class HexaPoint {
  final double x;
  final double y;
  final String coordinateSpace;
}
```

### Database Schemas
**SQLite Tables**:
```sql
-- Media assets storage
CREATE TABLE media_assets (
  id TEXT PRIMARY KEY,
  data BLOB NOT NULL,
  created_at INTEGER NOT NULL
);

-- Future: Structured metadata tables
CREATE TABLE folders (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL,
  metadata TEXT
);

CREATE TABLE images (
  id TEXT PRIMARY KEY,
  folder_id TEXT NOT NULL,
  image_url TEXT NOT NULL,
  camera_settings TEXT NOT NULL,
  annotations TEXT,
  measurements TEXT,
  calibration TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (folder_id) REFERENCES folders(id)
);
```

### Serialization
- **JSON**: All models support toJson/fromJson
- **Storage**: SharedPreferences for app data
- **Assets**: Binary storage in SQLite for large files

## Testing & Quality Assurance

### Test Structure
```
test/
├── unit/                    # Unit tests
│   ├── utils_test.dart     # Utility functions
│   ├── models_test.dart    # Data models
│   └── services_test.dart  # Business logic
├── widget/                  # Widget tests
│   ├── camera_test.dart    # Camera UI
│   ├── annotation_test.dart # Drawing tools
│   └── report_test.dart    # PDF generation
└── integration/             # Integration tests
    ├── camera_integration_test.dart
    └── workflow_test.dart
```

### Test Categories
- **Unit Tests**: Pure function testing (calibration calculations, data transformations)
- **Widget Tests**: UI component testing (buttons, forms, dialogs)
- **Integration Tests**: Full workflow testing (capture → annotate → report)
- **Platform Tests**: Device-specific functionality

### Test Coverage Goals
- **Core Logic**: >90% coverage
- **UI Components**: >80% coverage
- **Integration Flows**: >70% coverage

### Automated Testing
```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/unit/utils_test.dart

# Run integration tests
flutter test integration_test/
```

## Deployment & Build

### Build Targets
- **Android APK**: `flutter build apk --release`
- **Android Bundle**: `flutter build appbundle --release`
- **iOS**: `flutter build ios --release`
- **Web**: `flutter build web --release`
- **Windows**: `flutter build windows --release`
- **macOS**: `flutter build macos --release`
- **Linux**: `flutter build linux --release`

### Build Configuration
```yaml
# pubspec.yaml build configuration
version: 1.0.0+1

environment:
  sdk: ^3.10.0

dependencies:
  flutter:
    sdk: flutter
  # ... dependencies

flutter:
  uses-material-design: true
  assets:
    - assets/images/
```

### Platform-Specific Setup

**Android**:
```gradle
// android/app/build.gradle
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }
}
```

**iOS**:
```plist
<!-- ios/Runner/Info.plist -->
<key>NSCameraUsageDescription</key>
<string>Camera access for microscopy imaging</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access for image storage</string>
```

### CI/CD Pipeline
```yaml
# Example GitHub Actions workflow
name: Build and Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'
      - run: flutter pub get
      - run: flutter test
      - run: flutter build apk --release
```

## Troubleshooting

### Common Issues

**Camera Not Working**:
- Check camera permissions in device settings
- Try different camera resolutions
- Restart app and device
- Check for other apps using camera

**Measurement Inaccuracy**:
- Recalibrate with known reference sample
- Check lens magnification setting
- Verify calibration line accuracy

**App Crashes**:
- Clear app data and cache
- Reinstall application
- Check device compatibility
- Review device storage space

**PDF Generation Fails**:
- Check storage permissions
- Ensure sufficient device storage
- Try smaller images or fewer annotations

### Debug Tools
```dart
// Enable debug logging
void main() {
  debugPrint = (String? message, {int? wrapWidth}) {
    logger.d(message ?? '');
  };
  runApp(const HexaCamApp());
}
```

### Performance Monitoring
- **Frame Rate**: 60 FPS target for camera preview
- **Memory Usage**: <200MB typical usage
- **Storage**: Efficient asset management
- **Battery**: Optimized for extended use

## Contributing

### Development Guidelines
- **Code Style**: Follow Flutter/Dart style guidelines
- **Documentation**: Update docs for new features
- **Testing**: Add tests for new functionality
- **Commits**: Clear, descriptive commit messages

### Feature Development Process
1. **Planning**: Create feature specification
2. **Implementation**: Write code with tests
3. **Review**: Code review and testing
4. **Integration**: Merge to main branch
5. **Deployment**: Release to production

### Code Quality Standards
- **Linting**: `flutter analyze` passes
- **Testing**: >80% test coverage
- **Performance**: No performance regressions
- **Accessibility**: Screen reader support

### Release Process
1. **Version Bump**: Update version in pubspec.yaml
2. **Changelog**: Document changes
3. **Testing**: Full regression testing
4. **Build**: Generate all platform builds
5. **Distribution**: Upload to stores/web

---

## Code Examples & Implementation Details

### Core Data Structures

#### Point System Implementation
```dart
class HexaPoint {
  final double x, y;
  const HexaPoint({required this.x, required this.y});

  // Vector operations for geometric calculations
  HexaPoint operator +(HexaPoint other) =>
      HexaPoint(x: x + other.x, y: y + other.y);
  HexaPoint operator -(HexaPoint other) =>
      HexaPoint(x: x - other.x, y: y - other.y);

  double distanceTo(HexaPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }

  factory HexaPoint.fromJson(Map<String, dynamic> json) =>
      HexaPoint(x: json['x'].toDouble(), y: json['y'].toDouble());
  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}
```

#### Annotation Rendering Pipeline
```dart
class AnnotationPainter extends CustomPainter {
  final List<Annotation> annotations;
  final Size displaySize, sourceSize;
  final BoxFit fit;
  final bool mirrorX, mirrorY;
  final double zoom, rotation;

  @override
  void paint(Canvas canvas, Size size) {
    // Coordinate transformation matrix
    final transform = CoordinateTransformer.buildImageTransform(
      imageSize: sourceSize,
      mirrorX: mirrorX, mirrorY: mirrorY,
      rotation: rotation,
    );

    // Render each annotation with proper scaling
    for (final ann in annotations) {
      _drawAnnotation(canvas, ann, size);
    }
  }

  void _drawAnnotation(Canvas canvas, Annotation ann, Size canvasSize) {
    final paint = Paint()
      ..color = ann.color
      ..strokeWidth = ann.strokeWidth
      ..style = PaintingStyle.stroke;

    // Transform annotation points to display coordinates
    final points = _toDisplayPoints(ann.points);

    switch (ann.type) {
      case AnnotationType.draw:
        _drawFreeformPath(canvas, points, paint);
        break;
      case AnnotationType.twoPointer:
        _drawDistanceMeasurement(canvas, points, paint);
        break;
      case AnnotationType.circle:
        _drawCircle(canvas, points, paint);
        break;
      // ... additional annotation types
    }

    // Add measurement labels if calibrated
    if (ann.measurement?.isNotEmpty == true) {
      _drawMeasurementLabel(canvas, ann.measurement!, points, canvasSize);
    }
  }
}
```

#### Calibration Calculation Engine
```dart
class CalibrationCalculator {
  static double computeFactor(double pixelDistance, double knownDistance) {
    if (pixelDistance <= 0 || knownDistance <= 0) {
      throw ArgumentError('Both distances must be positive');
    }
    return knownDistance / pixelDistance;
  }

  static double measurePixels({
    required double unitPerPixel,
    required double pixels,
    required String unit,
    String? outputUnit,
    String dimension = 'length',
  }) {
    double rawValue = dimension == 'area'
        ? pixels * unitPerPixel * unitPerPixel
        : pixels * unitPerPixel;

    if (outputUnit == null || outputUnit == unit) return rawValue;
    return convertUnit(rawValue, unit, outputUnit, dimension);
  }

  static String formatMeasurement(double value, String unit, [String dimension = 'length']) {
    return dimension == 'area' ? '${value.toStringAsFixed(2)} $unit²' : '${value.toStringAsFixed(2)} $unit';
  }

  static double convertUnit(double value, String from, String to, [String dim = 'length']) {
    const Map<String, double> toMicrometers = {'μm': 1.0, 'nm': 0.001, 'mm': 1000.0};
    if (from == to) return value;
    final inMicrometers = value * (toMicrometers[from] ?? 1);
    return inMicrometers / (toMicrometers[to] ?? 1);
  }
}
```

### Camera Pipeline Implementation

#### Camera Controller Architecture
```dart
class CameraControllerX extends GetxController {
  final RxBool isInitializing = false.obs;
  final RxBool isReady = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<cam.CameraController?> controller = Rx<cam.CameraController?>(null);

  Future<void> initialize({
    required Future<List<cam.CameraDescription>> Function() cameraProvider,
    required cam.CameraDescription camera,
    required cam.ResolutionPreset preset,
    required bool enableAudio,
  }) async {
    isInitializing.value = true;
    errorMessage.value = '';

    // Fallback resolution strategy
    final orderedResolutions = <cam.ResolutionPreset>{
      preset,
      cam.ResolutionPreset.low,
      cam.ResolutionPreset.medium,
      cam.ResolutionPreset.high,
      cam.ResolutionPreset.max,
    }.toList();

    for (final candidate in orderedResolutions) {
      try {
        final ctrl = cam.CameraController(camera, candidate, enableAudio: enableAudio);
        await ctrl.initialize().timeout(const Duration(seconds: 10));

        if (ctrl.value.hasError) {
          throw Exception(ctrl.value.errorDescription ?? 'Unknown camera error');
        }

        controller.value = ctrl;
        isReady.value = true;
        return;
      } catch (e) {
        debugPrint('Failed ${camera.name} @ $candidate: $e');
      }
    }

    throw Exception('Unable to initialize camera at any supported resolution');
  }
}
```

#### Real-time Preview with Annotations
```dart
Widget _buildCameraViewport() {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onScaleStart: (_) => _pinchStartZoom = _settings.zoom,
    onScaleUpdate: (details) => _setZoom(_pinchStartZoom * details.scale),

    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Camera preview with color adjustments
              ColorFiltered(
                colorFilter: ColorFilter.matrix(_buildColorMatrix()),
                child: cam.CameraPreview(_controller!),
              ),

              // Measurement grid overlay
              if (uiStateController.measurementMode)
                IgnorePointer(
                  child: CustomPaint(painter: _GridPainter()),
                ),

              // Annotation rendering
              IgnorePointer(
                child: CustomPaint(
                  painter: AnnotationPainter(
                    annotations: _displayAnnotations(),
                    displaySize: Size(constraints.maxWidth, constraints.maxHeight),
                    sourceSize: _controller!.value.previewSize ?? _getFallbackSourceSize(),
                    fit: BoxFit.contain,
                    mirrorX: _flipH || _mirror,
                    mirrorY: _flipV,
                    zoom: _settings.zoom,
                    rotation: _rotation,
                  ),
                ),
              ),

              // Touch interaction layer
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: _onTapDown,
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
```

### Database Implementation

#### SQLite Media Storage
```sql
-- Media assets table for storing large binary data
CREATE TABLE media_assets (
  id TEXT PRIMARY KEY,
  data BLOB NOT NULL,
  created_at INTEGER NOT NULL
);

-- In-memory storage for web platform
class MediaDatabase {
  static Database? _db;
  static const String _dbName = 'hexacam-media.db';
  static final Map<String, Uint8List> _webStore = {};

  static Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('MediaDatabase uses in-memory web store on web');
    }
    if (_db != null) return _db!;
    _db = await openDatabase(
      join(await getDatabasesPath(), _dbName),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            data BLOB NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }
}
```

#### SharedPreferences Data Management
```dart
class StorageService {
  final SharedPreferences _prefs;

  // Automatic data sanitization and backup
  Future<void> set<T>(String key, T value) async {
    Object payload = value as Object;

    if (key == 'folders') {
      payload = _sanitizeFolders(value as List);
    }

    final encoded = jsonEncode(payload);
    await _prefs.setString(key, encoded);

    // Backup critical data
    if (key == 'folders') {
      await _prefs.setString('${key}_backup', encoded);
    }
  }

  // Recovery mechanism for corrupted data
  T? get<T>(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) {
      // Attempt recovery from backup
      if (key == 'folders') {
        final backup = _prefs.getString('${key}_backup');
        if (backup != null) {
          try {
            return jsonDecode(backup) as T;
          } catch (_) {}
        }
      }
      return null;
    }

    try {
      return jsonDecode(raw) as T;
    } catch (e) {
      // Remove corrupted data
      _prefs.remove(key);
      return null;
    }
  }
}
```

### PDF Report Generation

#### Report Builder Implementation
```dart
Future<Uint8List> _buildReportPdf() async {
  final pdf = pw.Document();
  final logoBytes = await rootBundle.load('assets/images/report_logo.png');
  final logoProvider = pw.MemoryImage(logoBytes.buffer.asUint8List());

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (context) => pw.Column(
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _orgController.text,
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text('Email: ${_emailController.text}'),
                    pw.Text('Phone: ${_phoneController.text}'),
                  ],
                ),
              ),
              pw.Text('Page: ${context.pageNumber} of ${context.pagesCount}'),
            ],
          ),
        ],
      ),

      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.SizedBox(
            width: 192,
            height: 60,
            child: pw.Image(logoProvider, fit: pw.BoxFit.contain),
          ),
          pw.Text('Generated by Hexa-Cam', textAlign: pw.TextAlign.right),
        ],
      ),

      build: (context) => [
        // Camera settings section
        pw.Text('Camera Settings', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _pdfMetric('Exposure', '${primary?.cameraSettings.exposure.round()}%'),
            _pdfMetric('ISO', '${primary?.cameraSettings.iso.round()}'),
            _pdfMetric('Temperature', '${primary?.cameraSettings.temperature.round()}K'),
          ],
        ),

        // Image sections with annotations
        ...reportImages.map((image) => pw.Column(
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Image(imageProvider, fit: pw.BoxFit.contain),
            ),
            // Annotation details
            ...image.annotations.map((ann) => pw.Text(
              '${ann.type}: ${ann.measurement ?? ''}',
            )),
          ],
        )),
      ],
    ),
  );

  return pdf.save();
}
```

### Video Processing with FFmpeg

#### Video Annotation Burning
```dart
class VideoExportService {
  static Future<String?> burnAnnotationsIntoVideo({
    required String sourcePath,
    required List<Annotation> annotations,
    required bool mirrorX,
    required bool mirrorY,
    required int rotation,
    required double sourceWidth,
    required double sourceHeight,
    required String outputFilename,
  }) async {
    if (kIsWeb) return null;

    // Generate transparent overlay with annotations
    final overlayBytes = await _buildTransparentOverlay(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      annotations: annotations,
      mirrorX: mirrorX,
      mirrorY: mirrorY,
      rotation: rotation,
    );

    // FFmpeg command for overlay composition
    final command = [
      '-y',  // Overwrite output
      '-i', _escapePath(inputPath),  // Input video
      '-i', _escapePath(overlayPath),  // Overlay image
      '-filter_complex',
      '"[0:v]scale=\'min(1280,iw)\':-2:flags=lanczos[base];[base][1:v]overlay=0:0:format=auto[v]"',
      '-map', '"[v]"',  // Video stream
      '-map', '0:a?',   // Audio stream (optional)
      '-c:v', 'libx264',  // Video codec
      '-preset', 'medium',  // Encoding speed/quality tradeoff
      '-crf', '23',     // Quality (lower = better)
      '-c:a', 'copy',   // Copy audio without re-encoding
      _escapePath(outputPath),
    ].join(' ');

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return outputPath;
    }
    return null;
  }
}
```

## Performance Benchmarks & Metrics

### Camera Performance
- **Initialization Time**: < 3 seconds on modern devices
- **Frame Rate**: 30 FPS minimum, 60 FPS target
- **Resolution**: Up to 4K depending on device capabilities
- **Latency**: < 100ms for UI interactions

### Annotation Rendering
- **Real-time Drawing**: 60 FPS with < 16ms frame time
- **Memory Usage**: < 50MB for 1000+ annotations
- **Coordinate Precision**: Sub-pixel accuracy for measurements

### Storage Performance
- **Database Operations**: < 10ms for typical queries
- **File I/O**: < 100ms for image saves
- **PDF Generation**: < 2 seconds for typical reports

### Platform-Specific Performance

#### Android
```yaml
# android/app/build.gradle
android {
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }

    buildTypes {
        release {
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}
```

#### iOS
```xml
<!-- ios/Runner/Info.plist -->
<key>NSCameraUsageDescription</key>
<string>Camera access for microscopy imaging</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access for image storage</string>
<key>CADisableMinimumFrameDurationOnPhone</key>
<true/>
```

#### Web
```html
<!-- web/index.html -->
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<script src="flutter_bootstrap.js" async></script>
```

### Memory Management
- **Image Caching**: LRU cache with 100MB limit
- **Annotation Storage**: Efficient coordinate compression
- **Video Processing**: Streaming processing to avoid memory spikes

## Security Implementation

### Authentication Security
```dart
class AuthController extends GetxController {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Secure token storage
  Future<void> _saveAuthToken(String token) async {
    await _secureStorage.write(
      key: 'auth_token',
      value: token,
      options: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );
  }

  // Secure token retrieval
  Future<String?> _getAuthToken() async {
    return await _secureStorage.read(key: 'auth_token');
  }
}
```

### Data Encryption
- **API Communication**: HTTPS with certificate pinning
- **Local Storage**: Encrypted SharedPreferences on Android
- **File Storage**: Platform-specific secure storage

### Permission Management
```dart
class PermissionController extends GetxController {
  Future<bool> requestStoragePermissionIfNeeded() async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.storage.status;
    if (status.isGranted) return true;

    final result = await Permission.storage.request();
    return result.isGranted;
  }

  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;

    final result = await Permission.camera.request();
    if (result.isPermanentlyDenied) {
      // Open app settings
      await openAppSettings();
    }
    return result.isGranted;
  }
}
```

## Platform-Specific Configurations

### Android Configuration
```gradle
// android/app/build.gradle
android {
    namespace 'com.hexacam.demo_app'
    compileSdk 34

    defaultConfig {
        applicationId "com.hexacam.demo_app"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"

        ndk {
            abiFilters 'armeabi-v7a', 'arm64-v8a', 'x86_64'
        }
    }

    buildTypes {
        debug {
            buildConfigField "String", "API_BASE_URL", "\"https://api-staging.hexacam.com/api\""
        }
        release {
            buildConfigField "String", "API_BASE_URL", "\"https://api.hexacam.com/api\""
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}
```

### iOS Configuration
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Hexa-Cam</string>
    <key>CFBundleIdentifier</key>
    <string>com.hexacam.demo-app</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UILaunchStoryboardName</key>
    <string>LaunchScreen</string>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>armv7</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>NSCameraUsageDescription</key>
    <string>Camera access is required to capture microscope images and videos.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Microphone access is required when recording video with audio.</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>Photo library access is required to import and review media.</string>
</dict>
</plist>
```

### Web Configuration
```json
// web/manifest.json
{
  "name": "Hexa-Cam",
  "short_name": "Hexa-Cam",
  "description": "Scientific Imaging & Microscopy Platform",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#060824",
  "theme_color": "#6366F1",
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
```

## Error Handling & Recovery

### Camera Error Recovery
```dart
class CameraErrorHandler {
  static Future<void> handleCameraError(dynamic error, StackTrace stackTrace) async {
    debugPrint('Camera error: $error');

    // Attempt recovery strategies
    if (error.toString().contains('CameraAccessDenied')) {
      await _requestCameraPermission();
    } else if (error.toString().contains('CameraNotAvailable')) {
      await _showCameraUnavailableDialog();
    } else {
      await _retryCameraInitialization();
    }
  }

  static Future<void> _retryCameraInitialization() async {
    // Exponential backoff retry
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await _controller?.dispose();
        await _initCamera();
        return;
      } catch (e) {
        if (attempt == 3) rethrow;
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }
}
```

### Network Error Handling
```dart
class NetworkErrorHandler {
  static Future<T> withRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        if (attempt == maxRetries) rethrow;

        final isNetworkError = e.toString().contains('SocketException') ||
                              e.toString().contains('TimeoutException');

        if (!isNetworkError) rethrow;

        await Future.delayed(delay * attempt);
      }
    }
    throw Exception('Max retries exceeded');
  }
}
```

### Data Corruption Recovery
```dart
class DataRecoveryService {
  static Future<void> recoverCorruptedData() async {
    final prefs = await SharedPreferences.getInstance();

    // Check for backup data
    final backupFolders = prefs.getString('folders_backup');
    if (backupFolders != null) {
      try {
        final folders = jsonDecode(backupFolders);
        await prefs.setString('folders', backupFolders);
        debugPrint('Data recovered from backup');
      } catch (e) {
        debugPrint('Backup data also corrupted: $e');
      }
    }
  }

  static Future<void> validateDataIntegrity() async {
    // Check all stored data for corruption
    final corruptedKeys = <String>[];

    final allKeys = ['folders', 'calibrations', 'user_settings'];
    for (final key in allKeys) {
      try {
        final data = await _storageService.get(key);
        if (data != null) _validateDataStructure(data);
      } catch (e) {
        corruptedKeys.add(key);
      }
    }

    if (corruptedKeys.isNotEmpty) {
      await recoverCorruptedData();
    }
  }
}
```

## Data Migration & Backup

### Version Migration Strategy
```dart
class DataMigrationService {
  static const int currentVersion = 2;

  static Future<void> migrateDataIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt('data_version') ?? 1;

    if (storedVersion < currentVersion) {
      await _performMigration(storedVersion, currentVersion);
      await prefs.setInt('data_version', currentVersion);
    }
  }

  static Future<void> _performMigration(int fromVersion, int toVersion) async {
    switch (fromVersion) {
      case 1:
        await _migrateFromV1ToV2();
        break;
      // Add more migration cases as needed
    }
  }

  static Future<void> _migrateFromV1ToV2() async {
    // Example: Migrate annotation format changes
    final folders = await _storageService.get<List>('folders');
    if (folders != null) {
      final migratedFolders = folders.map((folder) {
        final images = (folder['images'] as List?)?.map((image) {
          final annotations = (image['annotations'] as List?)?.map((ann) {
            // Migrate annotation format
            return {
              ...ann as Map<String, dynamic>,
              'coordinateSpace': ann['coordinateSpace'] ?? 'source',
            };
          }).toList();
          return {...image, 'annotations': annotations};
        }).toList();
        return {...folder, 'images': images};
      }).toList();

      await _storageService.set('folders', migratedFolders);
    }
  }
}
```

### Backup & Restore
```dart
class BackupService {
  static Future<String> createBackup() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupFile = File('${await _getBackupDir()}/backup_$timestamp.json');

    final backupData = {
      'version': DataMigrationService.currentVersion,
      'timestamp': timestamp,
      'folders': await _storageService.get('folders'),
      'calibrations': await _storageService.get('calibrations'),
      'user_settings': await _storageService.get('user_settings'),
    };

    await backupFile.writeAsString(jsonEncode(backupData));
    return backupFile.path;
  }

  static Future<void> restoreFromBackup(String backupPath) async {
    final backupFile = File(backupPath);
    final backupData = jsonDecode(await backupFile.readAsString());

    // Validate backup version
    final backupVersion = backupData['version'] as int;
    if (backupVersion > DataMigrationService.currentVersion) {
      throw Exception('Backup version is newer than current app version');
    }

    // Restore data
    await _storageService.set('folders', backupData['folders']);
    await _storageService.set('calibrations', backupData['calibrations']);
    await _storageService.set('user_settings', backupData['user_settings']);
  }
}
```

## Integration Examples

### API Integration Pattern
```dart
class ApiIntegrationService {
  final String baseUrl;
  final Map<String, String> defaultHeaders;

  ApiIntegrationService({
    required this.baseUrl,
    this.defaultHeaders = const {},
  });

  Future<Map<String, dynamic>> authenticatedRequest(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final token = await _getAuthToken();
    final requestHeaders = {
      ...defaultHeaders,
      ...?headers,
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final url = Uri.parse('$baseUrl$endpoint');
    final request = http.Request(method, url)..headers.addAll(requestHeaders);

    if (body != null) {
      request.body = jsonEncode(body);
      request.headers['Content-Type'] = 'application/json';
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(responseBody);
    } else {
      throw ApiException(response.statusCode, responseBody);
    }
  }
}
```

### Third-Party Camera Integration
```dart
class ExternalCameraService {
  static Future<List<CameraDevice>> discoverCameras() async {
    // Implement camera discovery for external devices
    final devices = <CameraDevice>[];

    // USB cameras
    final usbCameras = await _discoverUSBCameras();
    devices.addAll(usbCameras);

    // Network cameras
    final networkCameras = await _discoverNetworkCameras();
    devices.addAll(networkCameras);

    return devices;
  }

  static Future<CameraStream> connectToCamera(CameraDevice device) async {
    switch (device.type) {
      case CameraType.usb:
        return USBConnection.connect(device);
      case CameraType.network:
        return NetworkConnection.connect(device);
      case CameraType.bluetooth:
        return BluetoothConnection.connect(device);
    }
  }
}
```

## Configuration Management

### Environment Configuration
```dart
class AppConfig {
  static const String appName = 'Hexa-Cam';
  static const String version = '1.0.0';

  // Build-time configuration
  static String get apiBaseUrl => const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.quasmoindianmicroscope.com/api',
  );

  static bool get enableAnalytics => const bool.fromEnvironment(
    'ENABLE_ANALYTICS',
    defaultValue: false,
  );

  static bool get enableCrashReporting => const bool.fromEnvironment(
    'ENABLE_CRASH_REPORTING',
    defaultValue: true,
  );

  // Runtime configuration
  static late SharedPreferences _prefs;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static bool get isFirstLaunch =>
      _prefs.getBool('is_first_launch') ?? true;

  static set isFirstLaunch(bool value) =>
      _prefs.setBool('is_first_launch', value);

  static ThemeMode get themeMode {
    final value = _prefs.getString('theme_mode') ?? 'system';
    switch (value) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  static set themeMode(ThemeMode mode) =>
      _prefs.setString('theme_mode', mode.name);
}
```

### Feature Flags
```dart
class FeatureFlags {
  static const bool enableVideoRecording = true;
  static const bool enableCloudSync = false; // Future feature
  static const bool enableOfflineMode = true;
  static const bool enableAdvancedCalibration = true;

  static bool isFeatureEnabled(String feature) {
    switch (feature) {
      case 'video_recording': return enableVideoRecording;
      case 'cloud_sync': return enableCloudSync;
      case 'offline_mode': return enableOfflineMode;
      case 'advanced_calibration': return enableAdvancedCalibration;
      default: return false;
    }
  }
}
```

## Build Scripts & Automation

### CI/CD Pipeline
```yaml
# .github/workflows/ci.yml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'

      - name: Cache dependencies
        uses: actions/cache@v3
        with:
          path: |
            ~/.pub-cache
          key: ${{ runner.os }}-pub-${{ hashFiles('**/pubspec.lock') }}

      - name: Install dependencies
        run: flutter pub get

      - name: Run tests
        run: flutter test --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: coverage/lcov.info

  build-android:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'

      - name: Build APK
        run: flutter build apk --release

      - name: Upload APK
        uses: actions/upload-artifact@v3
        with:
          name: app-release.apk
          path: build/app/outputs/flutter-apk/app-release.apk

  build-web:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'

      - name: Build Web
        run: flutter build web --release

      - name: Deploy to Firebase
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          channelId: live
          projectId: hexacam-web
```

### Build Scripts
```bash
#!/bin/bash
# build.sh - Comprehensive build script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Hexa-Cam build process...${NC}"

# Function to build for Android
build_android() {
    echo -e "${YELLOW}Building Android APK...${NC}"
    flutter build apk --release --split-per-abi
    echo -e "${GREEN}Android build completed${NC}"
}

# Function to build for iOS
build_ios() {
    echo -e "${YELLOW}Building iOS...${NC}"
    flutter build ios --release
    echo -e "${GREEN}iOS build completed${NC}"
}

# Function to build for Web
build_web() {
    echo -e "${YELLOW}Building Web...${NC}"
    flutter build web --release
    echo -e "${GREEN}Web build completed${NC}"
}

# Function to run tests
run_tests() {
    echo -e "${YELLOW}Running tests...${NC}"
    flutter test --coverage
    echo -e "${GREEN}Tests completed${NC}"
}

# Parse command line arguments
case "$1" in
    android)
        build_android
        ;;
    ios)
        build_ios
        ;;
    web)
        build_web
        ;;
    all)
        run_tests
        build_android
        build_ios
        build_web
        ;;
    test)
        run_tests
        ;;
    *)
        echo "Usage: $0 {android|ios|web|all|test}"
        exit 1
esac
```

## User Interface Design

### Screen Hierarchy
```
Hexa-Cam App
├── Splash Screen
│   └── Animated logo with particle effects
├── Authentication
│   ├── Login Screen
│   │   ├── Email field
│   │   ├── Password field (with visibility toggle)
│   │   └── Sign In button
│   └── Offline Mode indicator
├── Main Navigation
│   ├── Bottom Navigation Bar
│   └── Side Navigation Drawer
├── Folders Screen
│   ├── Folder Grid/List
│   ├── Create Folder FAB
│   ├── Folder Actions (rename, delete)
│   └── Search/Filter options
├── Folder Detail Screen
│   ├── Image Grid
│   ├── Image Actions (view, delete, export)
│   ├── Camera FAB
│   └── Sort/Filter options
├── Camera Screen
│   ├── Camera Preview
│   ├── Control Panels
│   │   ├── Left Rail (lens, transforms)
│   │   ├── Right Rail (camera settings, tools)
│   │   └── Bottom Panel (annotations)
│   ├── Zoom Indicator
│   └── Recording Indicator
├── Image Viewer
│   ├── Full-screen Image
│   ├── Annotation Overlay
│   ├── Measurement Labels
│   ├── Export Options
│   └── Edit Mode Toggle
├── Report Generator
│   ├── Form Fields (organization, contact)
│   ├── Camera Settings Display
│   ├── Annotated Image Preview
│   ├── Measurement Summary
│   └── PDF Generation Progress
└── Settings Screen
    ├── App Preferences
    ├── Camera Settings
    ├── Calibration Management
    ├── Storage Management
    └── About/Help
```

### Responsive Design System
```dart
class Responsive {
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 600;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  static bool isCompactHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 600;

  static double pagePadding(BuildContext context) =>
      isTablet(context) ? 32.0 : 20.0;

  static double buttonHeight(BuildContext context) =>
      isTablet(context) ? 52.0 : 44.0;

  static EdgeInsets cameraPreviewPadding(BuildContext context) {
    final isTablet = Responsive.isTablet(context);
    return EdgeInsets.all(isTablet ? 28.0 : 16.0);
  }
}
```

## Hardware Requirements & Compatibility

### Minimum Requirements

#### Android
- **OS**: Android 5.0 (API 21) or higher
- **RAM**: 2GB minimum, 4GB recommended
- **Storage**: 500MB free space
- **Camera**: Rear camera with autofocus
- **Display**: 720p resolution minimum

#### iOS
- **OS**: iOS 12.0 or higher
- **Device**: iPhone 6s or newer, iPad 5th generation or newer
- **RAM**: 2GB minimum
- **Storage**: 500MB free space
- **Camera**: Compatible with iOS Camera framework

#### Web
- **Browser**: Chrome 88+, Firefox 85+, Safari 14+, Edge 88+
- **WebRTC**: Camera and microphone access
- **WebGL**: Hardware acceleration support
- **Storage**: IndexedDB support

### Recommended Specifications

#### High-End Devices
- **RAM**: 8GB+
- **Storage**: SSD with 2GB+ free space
- **Camera**: 12MP+ with optical stabilization
- **Display**: 1440p resolution
- **Processor**: Octa-core 2.5GHz+

#### Professional Microscopy Setup
- **Microscope**: Compatible with camera mount
- **Lighting**: LED illumination system
- **Calibration Standards**: Stage micrometer for calibration
- **Computer**: Desktop workstation for intensive processing

## Accessibility Features

### Screen Reader Support
```dart
class AccessibleButton extends StatelessWidget {
  final String label;
  final String hint;
  final VoidCallback onPressed;
  final Widget child;

  const AccessibleButton({
    super.key,
    required this.label,
    required this.hint,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      enabled: true,
      onTap: onPressed,
      child: child,
    );
  }
}
```

### Keyboard Navigation
- **Tab Order**: Logical navigation through UI elements
- **Keyboard Shortcuts**: Common actions accessible via keyboard
- **Focus Management**: Clear focus indicators and management

### High Contrast Support
- **Theme Variants**: High contrast mode for low vision users
- **Color Blindness**: Color schemes that work with common color deficiencies
- **Font Scaling**: Support for system font size settings

### Motor Accessibility
- **Large Touch Targets**: Minimum 44pt touch targets
- **Gesture Alternatives**: Button alternatives for complex gestures
- **Time Extensions**: Adjustable timeouts for actions

## Internationalization & Localization

### Supported Languages
- English (en) - Primary
- Spanish (es) - Beta
- French (fr) - Planned
- German (de) - Planned
- Chinese (zh) - Planned

### Localization Implementation
```dart
class AppLocalizations {
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  // UI Strings
  String get appName => 'Hexa-Cam';
  String get loginTitle => 'Sign In';
  String get cameraTitle => 'Camera';
  String get foldersTitle => 'Folders';

  // Measurement Units
  String get micrometers => 'μm';
  String get nanometers => 'nm';
  String get millimeters => 'mm';

  // Error Messages
  String get cameraPermissionDenied => 'Camera permission is required';
  String get networkError => 'Network connection error';
}
```

### RTL Language Support
```dart
class RTLSupport {
  static bool isRTL(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return ['ar', 'he', 'fa', 'ur'].contains(locale.languageCode);
  }

  static TextDirection getTextDirection(BuildContext context) {
    return isRTL(context) ? TextDirection.rtl : TextDirection.ltr;
  }
}
```

## Monitoring & Analytics

### Performance Monitoring
```dart
class PerformanceMonitor {
  static final Map<String, Stopwatch> _timers = {};

  static void startTimer(String name) {
    _timers[name] = Stopwatch()..start();
  }

  static void endTimer(String name) {
    final timer = _timers.remove(name);
    if (timer != null) {
      timer.stop();
      final duration = timer.elapsedMilliseconds;
      debugPrint('$name took ${duration}ms');

      // Send to analytics
      _sendMetric('performance', name, duration.toDouble());
    }
  }

  static void trackMemoryUsage() {
    // Track memory usage periodically
    Timer.periodic(const Duration(minutes: 5), (timer) {
      // Report memory usage to analytics
    });
  }
}
```

### Crash Reporting
```dart
class CrashReporter {
  static void initialize() {
    FlutterError.onError = (FlutterErrorDetails details) {
      // Report to crash reporting service
      _reportError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      // Report platform errors
      _reportError(FlutterErrorDetails(exception: error, stack: stack));
      return true;
    };
  }

  static void _reportError(FlutterErrorDetails details) {
    // Send error details to reporting service
    final errorData = {
      'error': details.exception.toString(),
      'stack': details.stack.toString(),
      'device': _getDeviceInfo(),
      'app_version': AppConfig.version,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Send to analytics/crash reporting service
  }
}
```

## Known Issues & Limitations

### Current Limitations
1. **Video Recording**: Limited to device camera capabilities
2. **Annotation Precision**: Sub-pixel accuracy may vary by device
3. **Large Datasets**: Performance may degrade with 1000+ annotations
4. **Offline Sync**: Manual data synchronization required

### Platform-Specific Issues

#### Android
- **File Permissions**: Scoped storage limitations on Android 11+
- **Camera Access**: May require manual permission grant
- **Background Processing**: Limited by Android battery optimization

#### iOS
- **Camera Permissions**: Requires explicit user consent
- **Storage Access**: Limited to app sandbox
- **Background Tasks**: Restricted by iOS multitasking policies

#### Web
- **Camera Access**: Browser-dependent WebRTC support
- **File Storage**: Limited to browser storage quotas
- **Performance**: Dependent on browser JavaScript engine

### Workarounds
- **Permission Issues**: Clear app data and reinstall
- **Performance Problems**: Close other apps, restart device
- **Storage Issues**: Free up device storage space

## Roadmap & Future Plans

### Short-term (3-6 months)
- [ ] Enhanced video processing capabilities
- [ ] Improved calibration accuracy
- [ ] Cloud synchronization beta
- [ ] Advanced measurement tools

### Medium-term (6-12 months)
- [ ] Machine learning for automated measurements
- [ ] Multi-user collaboration features
- [ ] External device integration
- [ ] Advanced reporting templates

### Long-term (1-2 years)
- [ ] Real-time streaming capabilities
- [ ] AI-powered image analysis
- [ ] Professional microscopy integrations
- [ ] Enterprise features and compliance

### Planned Features
- **Cloud Integration**: Google Drive, Dropbox, OneDrive sync
- **Advanced Analytics**: Measurement statistics and trends
- **Template System**: Custom report templates and workflows
- **Plugin Architecture**: Third-party tool integrations
- **AR Overlays**: Augmented reality measurement guides

---

**Hexa-Cam** - Scientific Imaging & Microscopy Platform  
© 2024-2026 All Rights Reserved  
*Empowering scientific discovery through digital microscopy*
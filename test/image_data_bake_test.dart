import 'package:demo_app/data/models/camera_settings.dart';
import 'package:demo_app/data/models/image_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ImageData defaults markings to not baked', () {
    final image = ImageData(
      id: '1',
      imageUrl: 'file://image.png',
      timestamp: '2026-04-06T00:00:00.000Z',
      cameraSettings: const CameraSettings(),
    );

    expect(image.isMarkingsBaked, isFalse);
  });

  test('ImageData roundtrips baked flag through json', () {
    final image = ImageData(
      id: '1',
      imageUrl: 'file://image.png',
      timestamp: '2026-04-06T00:00:00.000Z',
      cameraSettings: const CameraSettings(),
      isMarkingsBaked: true,
    );

    final roundTripped = ImageData.fromJson(image.toJson());
    expect(roundTripped.isMarkingsBaked, isTrue);
  });
}

import 'package:demo_app/data/models/image_data.dart';
import 'package:demo_app/data/models/camera_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ImageData preserves isMarkingsBaked through json', () {
    final image = ImageData(
      id: '1',
      imageUrl: 'file://image.png',
      timestamp: '2026-04-06T00:00:00.000Z',
      cameraSettings: const CameraSettings(),
      isMarkingsBaked: true,
    );

    final roundTrip = ImageData.fromJson(image.toJson());

    expect(roundTrip.isMarkingsBaked, isTrue);
    expect(roundTrip.imageUrl, 'file://image.png');
  });

  test('ImageData copyWith preserves isMarkingsBaked when omitted', () {
    final base = ImageData(
      id: '1',
      imageUrl: 'a',
      timestamp: 't',
      cameraSettings: const CameraSettings(),
      isMarkingsBaked: true,
    );
    final updated = base.copyWith(filename: 'x.png');
    expect(updated.isMarkingsBaked, isTrue);
    expect(updated.filename, 'x.png');
  });

  test('ImageData copyWith can set isMarkingsBaked explicitly', () {
    final base = ImageData(
      id: '1',
      imageUrl: 'a',
      timestamp: 't',
      cameraSettings: const CameraSettings(),
      isMarkingsBaked: true,
    );
    expect(base.copyWith(isMarkingsBaked: false).isMarkingsBaked, isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('Vector3 basic ops used by camera/geometry paths', () {
    final a = Vector3(3, 4, 0);
    expect(a.length, closeTo(5.0, 1e-9));
    a.normalize();
    expect(a.length, closeTo(1.0, 1e-9));
  });
}

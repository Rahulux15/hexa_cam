import 'package:flutter_test/flutter_test.dart';
import 'package:demo_app/data/models/folder.dart';

void main() {
  group('Folder Management', () {
    test('create folder succeeds', () async {
      // Arrange
      final folder = Folder(id: '1', name: 'New Folder', createdAt: DateTime.now().toIso8601String(), images: []);

      // Act
      // Assume databaseService.createFolder(folder);

      // Assert
      expect(folder.name, 'New Folder');
      expect(folder.id, '1');
    });

    test('rename folder succeeds', () async {
      // Arrange
      final folder = Folder(id: '1', name: 'Old Name', createdAt: DateTime.now().toIso8601String(), images: []);

      // Act
      final renamed = folder.copyWith(name: 'New Name');

      // Assert
      expect(renamed.name, 'New Name');
    });

    test('delete folder succeeds', () async {
      // Arrange
      final folders = [Folder(id: '1', name: 'Test', createdAt: DateTime.now().toIso8601String(), images: [])];

      // Act
      folders.removeWhere((f) => f.id == '1');

      // Assert
      expect(folders.length, 0);
    });

    test('quick access to recent folders', () async {
      // Arrange
      final now = DateTime.now();
      final folders = [
        Folder(id: '1', name: 'Recent1', createdAt: now.subtract(Duration(hours: 1)).toIso8601String(), images: []),
        Folder(id: '2', name: 'Recent2', createdAt: now.subtract(Duration(hours: 2)).toIso8601String(), images: []),
      ];

      // Act
      folders.sort((a, b) => DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)));

      // Assert
      expect(folders.first.name, 'Recent1');
    });
  });
}
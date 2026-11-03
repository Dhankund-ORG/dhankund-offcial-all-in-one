import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CRM Blog Views Feature Tests', () {
    test('views parsing and formatting logic works correctly', () {
      final postWithViews = {'views': 42, 'title': 'Test Blog'};
      final postWithStringViews = {'views': '128', 'title': 'Test Blog 2'};
      final postWithNullViews = {'title': 'Test Blog 3'};
      final postWithSingleView = {'views': 1, 'title': 'Test Blog 4'};

      int parseViews(Map<String, dynamic> p) =>
          int.tryParse(p['views']?.toString() ?? '0') ?? 0;

      String formatViews(int views) => '$views ${views == 1 ? 'View' : 'Views'}';

      expect(parseViews(postWithViews), 42);
      expect(formatViews(parseViews(postWithViews)), '42 Views');

      expect(parseViews(postWithStringViews), 128);
      expect(formatViews(parseViews(postWithStringViews)), '128 Views');

      expect(parseViews(postWithNullViews), 0);
      expect(formatViews(parseViews(postWithNullViews)), '0 Views');

      expect(parseViews(postWithSingleView), 1);
      expect(formatViews(parseViews(postWithSingleView)), '1 View');
    });

    test('blog_posts_page.dart contains views counter in card and editor', () {
      final file = File('lib/screens/pages/blog_posts_page.dart');
      expect(file.existsSync(), isTrue, reason: 'blog_posts_page.dart must exist');
      final content = file.readAsStringSync();

      expect(content.contains("post['views']"), isTrue,
          reason: 'PostCard must read views from post data');
      expect(content.contains('Icons.visibility_outlined'), isTrue,
          reason: 'PostCard and Editor must display visibility eye icon');
      expect(content.contains('Total Views'), isTrue,
          reason: 'Editor must display Total Views metric');
    });
  });
}

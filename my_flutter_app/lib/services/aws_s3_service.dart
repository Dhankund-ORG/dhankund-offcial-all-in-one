import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:minio/minio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AwsS3Service {
  static String get _bucketName => dotenv.env['AWS_S3_BUCKET_NAME'] ?? 'dhankund-loan';
  static String get _region => dotenv.env['AWS_S3_REGION'] ?? 'us-west-1';

  static Minio get _minio => Minio(
    endPoint: dotenv.env['AWS_S3_ENDPOINT'] ?? 's3.us-west-1.amazonaws.com',
    accessKey: dotenv.env['AWS_ACCESS_KEY_ID'] ?? '',
    secretKey: dotenv.env['AWS_SECRET_ACCESS_KEY'] ?? '',
    region: _region,
    useSSL: true,
  );

  /// Uploads a file to AWS S3 and returns the public URL.
  /// [bytes] is the file data.
  /// [folderPath] is the folder path inside the bucket (e.g., 'profile_pictures').
  /// [extension] is the file extension (e.g., 'jpg', 'pdf').
  static Future<String> uploadFile({
    required Uint8List bytes,
    required String folderPath,
    required String extension,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonymous';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final fileName = '${userId}_$timestamp.$extension';
      final objectName = '$folderPath/$fileName';

      // Upload file directly from bytes
      await _minio.putObject(
        _bucketName,
        objectName,
        Stream.value(bytes),
      );

      // Return the public S3 URL
      // Ensure the bucket has public read access for this to be viewable without signature
      return 'https://$_bucketName.s3.$_region.amazonaws.com/$objectName';
    } catch (e) {
      throw Exception('Failed to upload to S3: $e');
    }
  }

  static String getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf': return 'application/pdf';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      default: return 'application/octet-stream';
    }
  }
}

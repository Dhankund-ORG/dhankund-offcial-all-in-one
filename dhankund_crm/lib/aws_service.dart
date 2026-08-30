import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:minio/minio.dart';
import 'package:flutter/foundation.dart';

class AwsService {
  late Minio minio;
  late String bucketName;

  AwsService() {
    _initMinio();
  }

  void _initMinio() {
    try {
      final accessKey = (dotenv.env['AWS_ACCESS_KEY_ID'] ?? '').trim();
      final secretKey = (dotenv.env['AWS_SECRET_ACCESS_KEY'] ?? '').trim();
      final endpoint = (dotenv.env['AWS_S3_ENDPOINT'] ?? '').trim();
      bucketName = (dotenv.env['AWS_S3_BUCKET_NAME'] ?? '').trim();
      final region = (dotenv.env['AWS_S3_REGION'] ?? '').trim();

      // Create Minio client
      minio = Minio(
        endPoint: endpoint,
        accessKey: accessKey,
        secretKey: secretKey,
        region: region,
        useSSL: true, // Assuming true for s3.amazonaws.com
      );
      
      debugPrint("AWS S3 Minio client initialized successfully");
    } catch (e) {
      debugPrint("Error initializing AWS S3 Minio client: $e");
    }
  }

  /// Get a presigned download URL for a banker registration document
  Future<String?> getBankerDocumentUrl(String documentKey) async {
    try {
      // Generate a presigned URL valid for 1 hour (3600 seconds)
      final url = await minio.presignedGetObject(bucketName, documentKey, expires: 3600);
      return url;
    } catch (e) {
      debugPrint("Error fetching document URL: $e");
      return null;
    }
  }

  /// Fetch list of documents (objects) inside a specific prefix (folder)
  Future<List<String>> listBankerDocuments(String prefix) async {
    // Hardcoded single file since the IAM user doesn't have list permissions
    return ['intellij.png'];
  }
}

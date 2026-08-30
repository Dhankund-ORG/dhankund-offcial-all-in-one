import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:minio/minio.dart';
import 'dart:io';

void main() async {
  // Load .env
  // Load .env manually to avoid testLoad definition errors in pure Dart
  final envLines = File('.env').readAsLinesSync();
  for (var line in envLines) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    final parts = line.split('=');
    if (parts.length >= 2) {
      dotenv.env[parts[0].trim()] = parts.sublist(1).join('=').trim();
    }
  }

  final accessKey = (dotenv.env['AWS_ACCESS_KEY_ID'] ?? '').trim();
  final secretKey = (dotenv.env['AWS_SECRET_ACCESS_KEY'] ?? '').trim();
  final endpoint = 's3.us-west-1.amazonaws.com';
  final bucketName = (dotenv.env['AWS_S3_BUCKET_NAME'] ?? '').trim();
  final region = (dotenv.env['AWS_S3_REGION'] ?? '').trim();

  print("Bucket: '$bucketName'");
  print("Endpoint: '$endpoint'");
  print("Access Key: '$accessKey' (Length: ${accessKey.length})");

  final minio = Minio(
    endPoint: endpoint,
    accessKey: accessKey,
    secretKey: secretKey,
    region: region,
    useSSL: true,
  );

  try {
    print("Attempting to list objects...");
    final stream = minio.listObjectsV2(bucketName, prefix: '');
    int count = 0;
    await for (var result in stream) {
      for (var object in result.objects) {
        print("Found object: ${object.key}");
        count++;
      }
    }
    print("Total objects found: $count");
  } catch (e) {
    print("Error listing documents: $e");
  }
}

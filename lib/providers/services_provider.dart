import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

// Providers for services (dependency injection)

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});


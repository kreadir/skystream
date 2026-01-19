import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/plugin_storage_service.dart';
import 'services/repository_service.dart';

// Dio Instance
final dioProvider = Provider<Dio>((ref) {
  return Dio();
});

// Repository Service Provider
final repositoryServiceProvider = Provider<RepositoryService>((ref) {
  final dio = ref.watch(dioProvider);
  return RepositoryService(dio);
});

// Plugin Storage Service Provider
final pluginStorageServiceProvider = Provider<PluginStorageService>((ref) {
  return PluginStorageService();
});

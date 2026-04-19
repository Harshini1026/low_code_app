import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/project_model.dart';

/// BuildService handles real APK build requests to backend server
class BuildService {
  static String get _baseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3001';
    }
    return 'http://127.0.0.1:3001';
  }

  /// Export project configuration as JSON for building
  static Map<String, dynamic> exportProjectConfig(ProjectModel project) {
    return {
      'id': project.id,
      'name': project.name,
      'createdAt': project.createdAt.toIso8601String(),
      'screens': project.screens
          .map(
            (screen) => {
              'id': screen.id,
              'name': screen.name,
              'widgets': screen.widgets
                  .map(
                    (widget) => {
                      'id': widget.id,
                      'type': widget.type,
                      'x': widget.x,
                      'y': widget.y,
                      'width': widget.width,
                      'height': widget.height,
                      'properties': widget.properties,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };
  }

  /// Request APK build from backend
  /// Returns the download URL if successful
  static Future<String> requestApkBuild(
    ProjectModel project, {
    required void Function(double) onProgress,
  }) async {
    try {
      final config = exportProjectConfig(project);

      // Step 1: Submit build request
      final submitResponse = await http
          .post(
            Uri.parse('$_baseUrl/api/build/submit'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(config),
          )
          .timeout(const Duration(seconds: 30));

      if (submitResponse.statusCode != 200 &&
          submitResponse.statusCode != 202) {
        throw Exception(
          'Build submission failed: ${submitResponse.statusCode} ${submitResponse.body}',
        );
      }

      final buildData = jsonDecode(submitResponse.body);
      final buildId = buildData['buildId'] as String;

      // Step 2: Poll for build status
      return _pollBuildStatus(buildId, onProgress);
    } catch (e) {
      rethrow;
    }
  }

  /// Poll the backend for build status until completion
  static Future<String> _pollBuildStatus(
    String buildId,
    void Function(double) onProgress,
  ) async {
    const maxAttempts = 360; // 30 minutes with 5-second intervals
    const pollInterval = Duration(seconds: 5);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final response = await http
            .get(
              Uri.parse('$_baseUrl/api/build/status/$buildId'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final status = data['status'] as String;
          final progress = (data['progress'] as num?)?.toDouble() ?? 0.0;

          // Update progress
          onProgress(progress / 100);

          // Build completed successfully
          if (status == 'completed') {
            final downloadUrl = data['downloadUrl'] as String?;
            if (downloadUrl == null || downloadUrl.isEmpty) {
              throw Exception('Build completed but no download URL provided');
            }
            return downloadUrl;
          }

          // Build failed
          if (status == 'failed') {
            final error = data['error'] as String? ?? 'Unknown error';
            throw Exception('Build failed: $error');
          }
        }

        // Wait before next poll
        await Future.delayed(pollInterval);
      } catch (e) {
        rethrow;
      }
    }

    throw Exception('Build timeout: No response after 30 minutes');
  }

  /// Cancel an ongoing build
  static Future<void> cancelBuild(String buildId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/build/cancel/$buildId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to cancel build: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get build logs for debugging
  static Future<List<String>> getBuildLogs(String buildId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/build/logs/$buildId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['logs'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

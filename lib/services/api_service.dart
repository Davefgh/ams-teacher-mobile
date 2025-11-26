// lib/services/api_service.dart
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../utils/constants.dart';
import 'storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  ApiService._internal();

  // Map to store cancellable requests
  final Map<String, http.Client> _activeRequests = {};

  // Future for coordinating concurrent token refresh attempts
  Future<bool>? _refreshFuture;

  // Generate unique request ID
  String _generateRequestId() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  // Create HTTP client
  // Using standard http.Client to avoid Platform._version error
  // For HTTPS with self-signed certs, you would need platform-specific handling
  http.Client _createHttpClient() {
    // For local HTTP development, standard client works fine
    // If you need HTTPS with self-signed certificates, use conditional imports
    return http.Client();
  }

  // Cancel a request by ID
  void cancelRequest(String requestId) {
    _activeRequests[requestId]?.close();
    _activeRequests.remove(requestId);
  }

  // Cancel all active requests
  void cancelAllRequests() {
    for (var client in _activeRequests.values) {
      client.close();
    }
    _activeRequests.clear();
  }

  // Helper method to make cancellable HTTP requests with automatic token refresh
  Future<http.Response> _makeRequest({
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    Object? body,
    String? requestId,
    bool retryOn401 = true, // Flag to prevent infinite refresh loops
  }) async {
    // Use custom client that accepts self-signed certificates for HTTPS
    final client = _createHttpClient();
    final reqId = requestId ?? _generateRequestId();
    _activeRequests[reqId] = client;

    try {
      http.Response response;
      switch (method.toUpperCase()) {
        case 'GET':
          response = await client
              .get(uri, headers: headers)
              .timeout(
                ApiConstants.connectionTimeout,
                onTimeout: () => throw TimeoutException('Connection timeout'),
              );
          break;
        case 'POST':
          response = await client
              .post(uri, headers: headers, body: body)
              .timeout(
                ApiConstants.connectionTimeout,
                onTimeout: () => throw TimeoutException('Connection timeout'),
              );
          break;
        case 'PATCH':
          response = await client
              .patch(uri, headers: headers, body: body)
              .timeout(
                ApiConstants.connectionTimeout,
                onTimeout: () => throw TimeoutException('Connection timeout'),
              );
          break;
        case 'PUT':
          response = await client
              .put(uri, headers: headers, body: body)
              .timeout(
                ApiConstants.connectionTimeout,
                onTimeout: () => throw TimeoutException('Connection timeout'),
              );
          break;
        case 'DELETE':
          response = await client
              .delete(uri, headers: headers, body: body)
              .timeout(
                ApiConstants.connectionTimeout,
                onTimeout: () => throw TimeoutException('Connection timeout'),
              );
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      // If we get a 401 and retry is enabled, try to refresh token and retry
      if (response.statusCode == 401 && retryOn401) {
        print('🔄 Token expired (401), attempting to refresh...');

        final refreshSuccess = await _attemptTokenRefresh();

        if (refreshSuccess) {
          // Get new token and retry the request with updated headers
          final newToken = await StorageService.getToken();
          if (newToken != null) {
            // Update headers with new token
            final updatedHeaders = Map<String, String>.from(headers ?? {});
            updatedHeaders['Authorization'] = 'Bearer $newToken';

            print('✅ Token refreshed, retrying request...');

            // Retry the request (with retryOn401 = false to prevent infinite loop)
            return await _makeRequest(
              method: method,
              uri: uri,
              headers: updatedHeaders,
              body: body,
              requestId: requestId,
              retryOn401: false,
            );
          }
        } else {
          print('❌ Token refresh failed, returning 401 response');
        }
      }

      return response;
    } finally {
      _activeRequests.remove(reqId);
      client.close();
    }
  }

  // Attempt to refresh the access token
  // Uses a shared Future to coordinate concurrent refresh attempts
  Future<bool> _attemptTokenRefresh() async {
    // If a refresh is already in progress, wait for it to complete
    if (_refreshFuture != null) {
      print('⏳ Token refresh already in progress, waiting...');
      try {
        return await _refreshFuture!;
      } catch (e) {
        print('❌ Error waiting for token refresh: $e');
        return false;
      }
    }

    // Start a new refresh attempt
    final refreshCompleter = _performTokenRefresh();
    _refreshFuture = refreshCompleter;

    try {
      final result = await refreshCompleter;
      return result;
    } finally {
      // Only clear if this is still the current refresh attempt
      // This prevents race conditions with concurrent requests
      if (_refreshFuture == refreshCompleter) {
        _refreshFuture = null;
      }
    }
  }

  // Perform the actual token refresh
  Future<bool> _performTokenRefresh() async {
    try {
      final refreshToken = await StorageService.getRefreshToken();
      final oldAccessToken = await StorageService.getAccessToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        print('❌ No refresh token available');
        return false;
      }

      print('🔄 Refreshing token...');

      final client = _createHttpClient();
      try {
        final response = await client
            .post(
              Uri.parse(
                '${ApiConstants.baseUrl}${ApiConstants.refreshEndpoint}',
              ),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'refreshToken': refreshToken,
                if (oldAccessToken != null) 'oldAccessToken': oldAccessToken,
              }),
            )
            .timeout(
              ApiConstants.connectionTimeout,
              onTimeout: () => throw TimeoutException('Token refresh timeout'),
            );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          if (data['success'] == true && data['accessToken'] != null) {
            final newAccessToken = data['accessToken'] as String;
            final newRefreshToken =
                data['refreshToken'] as String? ?? refreshToken;

            // Save new tokens
            await StorageService.saveTokens(newAccessToken, newRefreshToken);

            print('✅ Token refreshed successfully');
            return true;
          } else {
            print(
              '❌ Token refresh failed: ${data['message'] ?? 'Unknown error'}',
            );
            return false;
          }
        } else {
          print('❌ Token refresh failed with status: ${response.statusCode}');
          return false;
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('❌ Error during token refresh: $e');
      return false;
    }
  }

  // ==================== AUTH METHODS ====================

  Future<Map<String, dynamic>> login(
    String username,
    String password, {
    String? requestId,
  }) async {
    try {
      final response = await _makeRequest(
        method: 'POST',
        uri: Uri.parse('${ApiConstants.baseUrl}${ApiConstants.loginEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'username': username, 'password': password}),
        requestId: requestId,
        retryOn401:
            false, // Don't retry on login endpoint (401 means invalid credentials)
      );

      print('Login Status Code: ${response.statusCode}');
      print('Login Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 401) {
        final data = jsonDecode(response.body);

        // Detailed logging to debug response structure
        print('📦 Parsed Response Data: $data');
        print('🔑 Response Type: ${data.runtimeType}');
        print('✅ Has "success" field: ${data.containsKey("success")}');
        print('🎫 Has "accessToken" field: ${data.containsKey("accessToken")}');
        print(
          '🔄 Has "refreshToken" field: ${data.containsKey("refreshToken")}',
        );

        if (data.containsKey("success")) {
          print('   → success value: ${data["success"]}');
        }
        if (data.containsKey("accessToken")) {
          print('   → accessToken present: ${data["accessToken"] != null}');
        }
        if (data.containsKey("refreshToken")) {
          print('   → refreshToken present: ${data["refreshToken"] != null}');
        }

        // Log all keys in response
        print('📋 All response keys: ${data.keys.toList()}');

        return data;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Login error: $e');
      print(
        'Login URL attempted: ${ApiConstants.baseUrl}${ApiConstants.loginEndpoint}',
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password, {
    String? requestId,
  }) async {
    try {
      final response = await _makeRequest(
        method: 'POST',
        uri: Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.registerEndpoint}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
        requestId: requestId,
        retryOn401: false, // Don't retry on register endpoint
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Registration failed');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Manually refresh token (for explicit refresh requests)
  Future<Map<String, dynamic>> refreshToken(
    String refreshToken, {
    String? requestId,
  }) async {
    try {
      final oldAccessToken = await StorageService.getAccessToken();

      final response = await _makeRequest(
        method: 'POST',
        uri: Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.refreshEndpoint}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'refreshToken': refreshToken,
          if (oldAccessToken != null) 'oldAccessToken': oldAccessToken,
        }),
        requestId: requestId,
        retryOn401: false, // Don't retry refresh endpoint
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['accessToken'] != null) {
          final newAccessToken = data['accessToken'] as String;
          final newRefreshToken =
              data['refreshToken'] as String? ?? refreshToken;

          // Save new tokens
          await StorageService.saveTokens(newAccessToken, newRefreshToken);
        }

        return data;
      } else {
        throw Exception('Token refresh failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> logout(String accessToken, {String? requestId}) async {
    try {
      await _makeRequest(
        method: 'POST',
        uri: Uri.parse('${ApiConstants.baseUrl}${ApiConstants.logoutEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        requestId: requestId,
      );
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // ==================== INSTRUCTOR METHODS ====================

  /// Get user profile from /api/account/me endpoint
  /// Returns UserProfileResponseDto with nested instructorProfile or studentProfile
  Future<Map<String, dynamic>> getInstructorProfile({String? requestId}) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        return {'success': false, 'error': 'Not authenticated.'};
      }

      final url = '${ApiConstants.baseUrl}/api/account/me';
      print('🌐 Fetching user profile from: $url');

      final response = await _makeRequest(
        method: 'GET',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        requestId: requestId,
      );

      print('📊 Profile Response Status: ${response.statusCode}');
      print('📝 Profile Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': 'Failed to load profile: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in getInstructorProfile: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Update user profile using /api/account/profile endpoint
  Future<Map<String, dynamic>> updateInstructorProfile({
    required int instructorId,
    String? email,
    String? firstname,
    String? lastname,
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        return {'success': false, 'error': 'Not authenticated.'};
      }

      final url = '${ApiConstants.baseUrl}/api/account/profile';
      print('🌐 Updating user profile at: $url');

      // Build update body - only include non-null fields
      final Map<String, dynamic> updateData = {};
      if (email != null) updateData['email'] = email;
      if (firstname != null) updateData['firstname'] = firstname;
      if (lastname != null) updateData['lastname'] = lastname;

      print('📝 Update data: $updateData');

      final response = await _makeRequest(
        method: 'PATCH',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(updateData),
        requestId: requestId,
      );

      print('📊 Update Response Status: ${response.statusCode}');
      print('📝 Update Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // The response structure is: {success, message, updatedProfile}
        // Extract updatedProfile from the response
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'Profile updated successfully',
          'data': data['updatedProfile'], // Extract updatedProfile
        };
      } else if (response.statusCode == 400) {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Invalid data',
        };
      } else if (response.statusCode == 404) {
        return {'success': false, 'error': 'Profile not found'};
      } else {
        return {
          'success': false,
          'error': 'Failed to update profile: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in updateInstructorProfile: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  // ==================== QR CODE METHODS ====================

  Future<Map<String, dynamic>> generateQrCode({
    required int sessionId,
    required int expirationMinutes,
    required String uniqueHash, // Added required uniqueHash
    int? maxUsage,
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated.'};
      }

      final url = '${ApiConstants.baseUrl}/api/QrCode/generate';
      print('🌐 Generating QR Code at: $url');

      final body = {
        'sessionId': sessionId,
        'expirationMinutes': expirationMinutes,
        'uniqueHash': uniqueHash, // Included in body
        'maxUsage': maxUsage,
      };

      final response = await _makeRequest(
        method: 'POST',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
        requestId: requestId,
      );

      print('📊 Generate QR Response Status: ${response.statusCode}');
      print('📝 Generate QR Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data, // Should contain uniqueHash
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Failed to generate QR code',
        };
      }
    } catch (e) {
      print('💥 Error in generateQrCode: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Get QR code by session ID
  Future<Map<String, dynamic>> getQrCodeBySessionId(
    int sessionId, {
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated.'};
      }

      final url = '${ApiConstants.baseUrl}/api/QrCode/session/$sessionId';
      print('🌐 Fetching QR Code by Session ID: $url');

      final response = await _makeRequest(
        method: 'GET',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        requestId: requestId,
      );

      print('📊 Get QR Code Response Status: ${response.statusCode}');
      print('📝 Get QR Code Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'QR Code not found for this session',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to fetch QR code: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in getQrCodeBySessionId: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Get sessions by schedule ID
  Future<Map<String, dynamic>> getSessionByScheduleId(
    int scheduleId, {
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated.'};
      }

      final url = '${ApiConstants.baseUrl}/api/sessions/schedule/$scheduleId';
      print('🌐 Fetching session by schedule ID: $url');

      final response = await _makeRequest(
        method: 'GET',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        requestId: requestId,
      );

      print('📊 Get Session Response Status: ${response.statusCode}');
      print('📝 Get Session Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else if (response.statusCode == 404) {
        return {'success': true, 'data': []}; // No sessions found
      } else {
        return {
          'success': false,
          'error': 'Failed to fetch session: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in getSessionByScheduleId: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Create a new session
  Future<Map<String, dynamic>> createSession({
    required int scheduleId,
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated.'};
      }

      final url = '${ApiConstants.baseUrl}/api/sessions';
      print('🌐 Creating session at: $url');

      final body = {
        'scheduleId': scheduleId,
        'status': 'active', // Assuming 'active' is the initial status
        'sessionDate': DateTime.now().toIso8601String(),
      };

      final response = await _makeRequest(
        method: 'POST',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
        requestId: requestId,
      );

      print('📊 Create Session Response Status: ${response.statusCode}');
      print('📝 Create Session Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Failed to create session',
        };
      }
    } catch (e) {
      print('💥 Error in createSession: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Start a session
  Future<Map<String, dynamic>> startSession(
    int sessionId, {
    int? actualRoomId,
    int? attendanceCutoffMinutes,
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated.'};
      }

      final url = '${ApiConstants.baseUrl}/api/sessions/$sessionId/start';
      print('🌐 Starting session at: $url');

      final body = {
        'actualRoomId': actualRoomId,
        'attendanceCutoffMinutes': attendanceCutoffMinutes,
      };

      final response = await _makeRequest(
        method: 'PATCH',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
        requestId: requestId,
      );

      print('📊 Start Session Response Status: ${response.statusCode}');
      print('📝 Start Session Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // Response might be empty or contain session data
        if (response.body.isNotEmpty) {
          final data = jsonDecode(response.body);
          return {'success': true, 'data': data};
        }
        return {'success': true};
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Failed to start session',
        };
      }
    } catch (e) {
      print('💥 Error in startSession: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Update session room
  Future<Map<String, dynamic>> updateSessionRoom(
    int sessionId,
    int actualRoomId, {
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated.'};
      }

      final url = '${ApiConstants.baseUrl}/api/sessions/$sessionId/room';
      print('🌐 Updating session room at: $url');

      final body = {'actualRoomId': actualRoomId};

      final response = await _makeRequest(
        method: 'PATCH',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
        requestId: requestId,
      );

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final data = jsonDecode(response.body);
          return {'success': true, 'data': data};
        }
        return {'success': true};
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Failed to update session room',
        };
      }
    } catch (e) {
      print('💥 Error in updateSessionRoom: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Get sessions by date
  Future<Map<String, dynamic>> getSessionsByDate(
    DateTime date, {
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated.'};
      }

      final dateStr = date.toIso8601String();
      final url = '${ApiConstants.baseUrl}/api/sessions/date/$dateStr';
      print('🌐 Fetching sessions by date: $url');

      final response = await _makeRequest(
        method: 'GET',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        requestId: requestId,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': 'Failed to fetch sessions: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in getSessionsByDate: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Get sessions by status
  Future<Map<String, dynamic>> getSessionsByStatus(
    String status, {
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated.'};
      }

      final url = '${ApiConstants.baseUrl}/api/sessions/status/$status';
      print('🌐 Fetching sessions by status: $url');

      final response = await _makeRequest(
        method: 'GET',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        requestId: requestId,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': 'Failed to fetch sessions: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in getSessionsByStatus: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// End a session
  Future<Map<String, dynamic>> endSession(
    int sessionId, {
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated.'};
      }

      final url = '${ApiConstants.baseUrl}/api/sessions/$sessionId/end';
      print('🌐 Ending session at: $url');

      final response = await _makeRequest(
        method: 'PATCH',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        requestId: requestId,
      );

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {
          'success': false,
          'error': 'Failed to end session: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in endSession: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Delete session
  Future<Map<String, dynamic>> deleteSession(
    int sessionId, {
    String reason = 'Session deleted by instructor',
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated.'};
      }

      final url = '${ApiConstants.baseUrl}/api/sessions/$sessionId';
      print('🌐 Deleting session at: $url');

      final response = await _makeRequest(
        method: 'DELETE',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'reason': reason}),
        requestId: requestId,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true};
      } else {
        String errorMessage;
        try {
          if (response.body.isNotEmpty) {
            final errorData = jsonDecode(response.body);
            if (errorData['message'] != null) {
              errorMessage = errorData['message'];
            } else if (errorData['errors'] != null) {
              // Handle validation errors
              final errors = errorData['errors'];
              if (errors is Map) {
                errorMessage = errors.values.join('\n');
              } else {
                errorMessage = errors.toString();
              }
            } else if (errorData['title'] != null) {
              errorMessage = errorData['title'];
            } else {
              errorMessage = 'Failed to delete session: ${response.statusCode}';
            }
          } else {
            errorMessage = 'Failed to delete session: ${response.statusCode}';
          }
        } catch (e) {
          errorMessage = 'Failed to delete session: ${response.statusCode}';
        }

        return {'success': false, 'error': errorMessage};
      }
    } catch (e) {
      print('💥 Error in deleteSession: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Get session by ID
  Future<Map<String, dynamic>> getSessionById(
    int sessionId, {
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Not authenticated.'};
      }

      final url = '${ApiConstants.baseUrl}/api/sessions/$sessionId';
      print('🌐 Fetching session by ID: $url');

      final response = await _makeRequest(
        method: 'GET',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        requestId: requestId,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': 'Failed to fetch session: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in getSessionById: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  // ==================== SECTIONS METHODS ====================

  /// Get all sections/subjects for the logged-in instructor
  /// Groups schedules by section name and shows subjects under each section
  Future<Map<String, dynamic>> getInstructorSections({
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();
      final instructorId = await StorageService.getInstructorId();

      print('🔑 Token: ${token != null ? "Present" : "Missing"}');
      print('👤 Instructor ID: $instructorId');

      if (token == null) {
        return {
          'success': false,
          'error': 'Not authenticated. Please login again.',
        };
      }

      // We don't need instructor ID check anymore since /api/schedules uses JWT
      // Remove this check:
      // if (instructorId == null) { ... }

      // Get all schedules for this instructor (JWT-based, no ID needed)
      final url = '${ApiConstants.baseUrl}/api/schedules';
      print('🌐 Fetching instructor schedules from: $url');

      final response = await _makeRequest(
        method: 'GET',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        requestId: requestId,
      );

      print('📊 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> schedules = json.decode(response.body);
        print('🔍 Total schedules received: ${schedules.length}');

        if (schedules.isEmpty) {
          print('⚠️ No schedules found for instructor');
          return {'success': true, 'data': {}};
        }

        // Structure: Section -> [Subjects]
        // We group by Section.Name (BSCS31A, BSBA31C, etc.)
        // Each section contains multiple subjects (from schedules)

        final Map<String, List<Map<String, dynamic>>> sectionSubjects = {};

        for (var schedule in schedules) {
          print('---Processing Schedule ID: ${schedule['id']}---');

          // Extract section info
          var sectionData = schedule['section'];
          if (sectionData == null) {
            print('⏭️ Skipping - No section data');
            continue;
          }

          String sectionName = sectionData['name'] ?? 'Unknown';
          int sectionId = sectionData['id'] ?? 0;

          print('📝 Section: $sectionName (ID: $sectionId)');

          // Initialize section if not exists
          if (!sectionSubjects.containsKey(sectionName)) {
            sectionSubjects[sectionName] = [];
          }

          // Extract subject info
          var subjectData = schedule['subject'];
          String subjectName = subjectData?['name'] ?? 'Unknown Subject';
          String subjectCode = subjectData?['code'] ?? 'N/A';
          int subjectId = subjectData?['id'] ?? 0;

          print('📚 Subject: $subjectName ($subjectCode)');

          // Extract classroom info
          var classroomData = schedule['classroom'];
          String room = classroomData?['name'] ?? '';

          // Extract schedule time
          String timeIn = schedule['timeIn'] ?? '';
          String timeOut = schedule['timeOut'] ?? '';
          String dayOfWeek = schedule['dayOfWeek'] ?? '';

          String scheduleStr = '';
          if (dayOfWeek.isNotEmpty && timeIn.isNotEmpty && timeOut.isNotEmpty) {
            // Format: "Monday 08:00:00-10:00:00" -> "Monday 08:00-10:00"
            String formattedTimeIn = timeIn.substring(0, 5); // Get HH:MM
            String formattedTimeOut = timeOut.substring(0, 5); // Get HH:MM
            scheduleStr = '$dayOfWeek $formattedTimeIn-$formattedTimeOut';
          }

          print('⏰ Schedule: $scheduleStr');
          print('🏫 Room: $room');

          // Add subject to section
          sectionSubjects[sectionName]!.add({
            'sectionId': sectionId,
            'sectionName': sectionName,
            'subjectId': subjectId,
            'subjectName': subjectName,
            'subjectCode': subjectCode,
            'name': subjectName, // For display
            'code': subjectCode, // For display
            'schedule': scheduleStr,
            'room': room,
            'scheduleId': schedule['id'],
            'studentCount': 0, // Will be loaded separately
          });

          print('✅ Added subject to section');
        }

        print('✅ Grouped by section: ${sectionSubjects.keys.length} sections');
        sectionSubjects.forEach((section, subjects) {
          print('  📚 $section: ${subjects.length} subjects');
        });

        return {'success': true, 'data': sectionSubjects};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
        };
      } else if (response.statusCode == 403) {
        return {'success': false, 'error': 'Access denied.'};
      } else if (response.statusCode == 404) {
        print('❌ Not Found - No schedules for this instructor');
        return {'success': true, 'data': {}};
      } else {
        print('❌ Unexpected status: ${response.statusCode}');
        print('Response: ${response.body}');
        return {
          'success': false,
          'error': 'Failed to load sections: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in getInstructorSections: $e');
      return {
        'success': false,
        'error': e.toString().contains('timeout')
            ? 'Connection timeout. Please check your internet.'
            : 'Error: $e',
      };
    }
  }

  /// Get schedules for a specific instructor
  /// Fetches all schedules and filters by instructor ID
  Future<Map<String, dynamic>> getInstructorSchedules(
    String instructorId, {
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        return {
          'success': false,
          'error': 'Not authenticated. Please login again.',
        };
      }

      final url = '${ApiConstants.baseUrl}/api/schedules/$instructorId/all';
      print('🌐 Fetching instructor schedules from: $url');

      final response = await _makeRequest(
        method: 'GET',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        requestId: requestId,
      );

      print('📊 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> instructorSchedules = json.decode(response.body);
        print(
          '🔍 Schedules for instructor $instructorId: ${instructorSchedules.length}',
        );

        return {'success': true, 'data': instructorSchedules};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
        };
      } else if (response.statusCode == 403) {
        return {'success': false, 'error': 'Access denied.'};
      } else if (response.statusCode == 404) {
        return {'success': true, 'data': []};
      } else {
        return {
          'success': false,
          'error': 'Failed to load schedules: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in getInstructorSchedules: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Get subjects for a specific instructor
  Future<Map<String, dynamic>> getInstructorSubjects(
    String instructorId, {
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        return {
          'success': false,
          'error': 'Not authenticated. Please login again.',
        };
      }

      final url =
          '${ApiConstants.baseUrl}/api/instructors/$instructorId/subjects';
      print('🌐 Fetching instructor subjects from: $url');

      final response = await _makeRequest(
        method: 'GET',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        requestId: requestId,
      );

      print('📊 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> subjects = json.decode(response.body);
        print('🔍 Subjects for instructor $instructorId: ${subjects.length}');
        return {'success': true, 'data': subjects};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to load subjects: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in getInstructorSubjects: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Get students for a specific section
  /// This gets ALL students in a section
  Future<Map<String, dynamic>> getSectionStudents(
    int sectionId, {
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        return {
          'success': false,
          'error': 'Not authenticated. Please login again.',
        };
      }

      // Use the correct endpoint for getting section students
      final url =
          '${ApiConstants.baseUrl}/api/sections/$sectionId/all-students';
      print('🌐 Fetching students from: $url');

      final response = await _makeRequest(
        method: 'GET',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        requestId: requestId,
      );

      print('📊 Students Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> students = json.decode(response.body);

        final processedStudents = students.map((student) {
          return {
            'id': student['id'] ?? 0,
            'email': student['email'] ?? '',
            'isRegular': student['isRegular'] ?? false,
            'userId': student['userId'] ?? '',
            'sectionId': student['sectionId'] ?? 0,
            'studentId': student['id']?.toString() ?? 'N/A',
          };
        }).toList();

        print('✅ Processed ${processedStudents.length} students');

        return {'success': true, 'data': processedStudents};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
        };
      } else if (response.statusCode == 403) {
        return {'success': false, 'error': 'Access denied to this section.'};
      } else if (response.statusCode == 404) {
        return {'success': false, 'error': 'Section not found.'};
      } else {
        return {
          'success': false,
          'error': 'Failed to load students: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in getSectionStudents: $e');
      return {
        'success': false,
        'error': e.toString().contains('timeout')
            ? 'Connection timeout. Please check your internet.'
            : 'Error: $e',
      };
    }
  }

  /// Get section details
  Future<Map<String, dynamic>> getSectionDetails(
    int sectionId, {
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        return {
          'success': false,
          'error': 'Not authenticated. Please login again.',
        };
      }

      final url = '${ApiConstants.baseUrl}/api/sections/$sectionId';
      print('🌐 Fetching section details from: $url');

      final response = await _makeRequest(
        method: 'GET',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        requestId: requestId,
      );

      print('📊 Section Details Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final section = json.decode(response.body);

        return {
          'success': true,
          'data': {
            'id': section['id'] ?? 0,
            'name': section['name'] ?? 'N/A',
            'courseId': section['courseId'] ?? 0,
          },
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
        };
      } else if (response.statusCode == 403) {
        return {'success': false, 'error': 'Access denied to this section.'};
      } else {
        return {
          'success': false,
          'error': 'Failed to load section details: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in getSectionDetails: $e');
      return {
        'success': false,
        'error': e.toString().contains('timeout')
            ? 'Connection timeout. Please check your internet.'
            : 'Error: $e',
      };
    }
  }

  // ==================== ATTENDANCE METHODS ====================

  /// Get attendance records with optional filters
  Future<Map<String, dynamic>> getAttendance({
    int? studentId,
    int? sessionId,
    int? scheduleId,
    int? sectionId,
    int? subjectId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    bool? isManualEntry,
    int? pageNumber,
    int? pageSize,
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        return {
          'success': false,
          'error': 'Not authenticated. Please login again.',
        };
      }

      final uri =
          Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.attendanceEndpoint}',
          ).replace(
            queryParameters: {
              if (studentId != null) 'StudentId': studentId.toString(),
              if (sessionId != null) 'SessionId': sessionId.toString(),
              if (scheduleId != null) 'ScheduleId': scheduleId.toString(),
              if (sectionId != null) 'SectionId': sectionId.toString(),
              if (subjectId != null) 'SubjectId': subjectId.toString(),
              if (status != null) 'Status': status,
              if (startDate != null) 'StartDate': startDate.toIso8601String(),
              if (endDate != null) 'EndDate': endDate.toIso8601String(),
              if (isManualEntry != null)
                'IsManualEntry': isManualEntry.toString(),
              if (pageNumber != null) 'PageNumber': pageNumber.toString(),
              if (pageSize != null) 'PageSize': pageSize.toString(),
            },
          );

      print('🌐 Fetching attendance from: $uri');

      final response = await _makeRequest(
        method: 'GET',
        uri: uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        requestId: requestId,
      );

      print('📊 Attendance Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to load attendance: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in getAttendance: $e');
      return {
        'success': false,
        'error': e.toString().contains('timeout')
            ? 'Connection timeout. Please check your internet.'
            : 'Error: $e',
      };
    }
  }

  /// Get attendance by session ID
  Future<Map<String, dynamic>> getAttendanceBySession(
    int sessionId, {
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        return {
          'success': false,
          'error': 'Not authenticated. Please login again.',
        };
      }

      final url =
          '${ApiConstants.baseUrl}${ApiConstants.attendanceBySessionEndpoint(sessionId)}';
      print('🌐 Fetching attendance by session from: $url');

      final response = await _makeRequest(
        method: 'GET',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        requestId: requestId,
      );

      print('📊 Session Attendance Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to load session attendance: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in getAttendanceBySession: $e');
      return {
        'success': false,
        'error': e.toString().contains('timeout')
            ? 'Connection timeout. Please check your internet.'
            : 'Error: $e',
      };
    }
  }

  /// Get attendance by student ID
  Future<Map<String, dynamic>> getAttendanceByStudent(
    int studentId, {
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        return {
          'success': false,
          'error': 'Not authenticated. Please login again.',
        };
      }

      final url =
          '${ApiConstants.baseUrl}${ApiConstants.attendanceByStudentEndpoint(studentId)}';
      print('🌐 Fetching attendance by student from: $url');

      final response = await _makeRequest(
        method: 'GET',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        requestId: requestId,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to load student attendance: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in getAttendanceByStudent: $e');
      return {
        'success': false,
        'error': e.toString().contains('timeout')
            ? 'Connection timeout. Please check your internet.'
            : 'Error: $e',
      };
    }
  }

  /// Get attendance by ID
  Future<Map<String, dynamic>> getAttendanceById(
    int id, {
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        return {
          'success': false,
          'error': 'Not authenticated. Please login again.',
        };
      }

      final url =
          '${ApiConstants.baseUrl}${ApiConstants.attendanceByIdEndpoint(id)}';
      print('🌐 Fetching attendance by ID from: $url');

      final response = await _makeRequest(
        method: 'GET',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        requestId: requestId,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to load attendance: ${response.statusCode}',
        };
      }
      ;
    } catch (e) {
      print('💥 Error in getAttendanceById: $e');
      return {
        'success': false,
        'error': e.toString().contains('timeout')
            ? 'Connection timeout. Please check your internet.'
            : 'Error: $e',
      };
    }
  }

  /// Get attendance by student ID
  Future<Map<String, dynamic>> getAttendanceByStudentId(
    int studentId, {
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        return {
          'success': false,
          'error': 'Not authenticated. Please login again.',
        };
      }

      final url =
          '${ApiConstants.baseUrl}${ApiConstants.attendanceEndpoint}/student/$studentId';
      print('🌐 Fetching student attendance from: $url');

      final response = await _makeRequest(
        method: 'GET',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        requestId: requestId,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to fetch student attendance: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in getAttendanceByStudentId: $e');
      return {
        'success': false,
        'error': e.toString().contains('timeout')
            ? 'Connection timeout. Please check your internet.'
            : 'Error: $e',
      };
    }
  }

  /// Create attendance record
  Future<Map<String, dynamic>> createAttendance({
    required int studentId,
    required int sessionId,
    String? status,
    DateTime? checkInTime,
    String? notes,
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        return {
          'success': false,
          'error': 'Not authenticated. Please login again.',
        };
      }

      final url = '${ApiConstants.baseUrl}${ApiConstants.attendanceEndpoint}';
      print('🌐 Creating attendance at: $url');

      final body = {
        'studentId': studentId,
        'sessionId': sessionId,
        'status': status ?? '',
        'checkInTime': checkInTime?.toIso8601String(),
        'notes': notes,
      };

      final response = await _makeRequest(
        method: 'POST',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
        requestId: requestId,
      );

      print('📊 Create Attendance Response Status: ${response.statusCode}');
      print('📝 Create Attendance Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
        };
      } else {
        final errorBody = response.body.isNotEmpty
            ? json.decode(response.body)
            : {};
        return {
          'success': false,
          'error':
              errorBody['message'] ??
              'Failed to create attendance: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in createAttendance: $e');
      return {
        'success': false,
        'error': e.toString().contains('timeout')
            ? 'Connection timeout. Please check your internet.'
            : 'Error: $e',
      };
    }
  }

  /// Update attendance record
  Future<Map<String, dynamic>> updateAttendance({
    required int id,
    String? status,
    String? notes,
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        return {
          'success': false,
          'error': 'Not authenticated. Please login again.',
        };
      }

      final url =
          '${ApiConstants.baseUrl}${ApiConstants.attendanceByIdEndpoint(id)}';
      print('🌐 Updating attendance at: $url');

      final body = <String, dynamic>{};
      if (status != null) body['status'] = status;
      if (notes != null) body['notes'] = notes;

      final response = await _makeRequest(
        method: 'PUT',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
        requestId: requestId,
      );

      print('📊 Update Attendance Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
        };
      } else {
        final errorBody = response.body.isNotEmpty
            ? json.decode(response.body)
            : {};
        return {
          'success': false,
          'error':
              errorBody['message'] ??
              'Failed to update attendance: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in updateAttendance: $e');
      return {
        'success': false,
        'error': e.toString().contains('timeout')
            ? 'Connection timeout. Please check your internet.'
            : 'Error: $e',
      };
    }
  }

  /// Delete attendance record
  Future<Map<String, dynamic>> deleteAttendance(
    int id, {
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        return {
          'success': false,
          'error': 'Not authenticated. Please login again.',
        };
      }

      final url =
          '${ApiConstants.baseUrl}${ApiConstants.attendanceByIdEndpoint(id)}';
      print('🌐 Deleting attendance at: $url');

      final response = await _makeRequest(
        method: 'DELETE',
        uri: Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        requestId: requestId,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to delete attendance: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in deleteAttendance: $e');
      return {
        'success': false,
        'error': e.toString().contains('timeout')
            ? 'Connection timeout. Please check your internet.'
            : 'Error: $e',
      };
    }
  }

  /// Get attendance summary
  Future<Map<String, dynamic>> getAttendanceSummary({
    int? studentId,
    int? sessionId,
    int? scheduleId,
    int? sectionId,
    int? subjectId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    bool? isManualEntry,
    int? pageNumber,
    int? pageSize,
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        return {
          'success': false,
          'error': 'Not authenticated. Please login again.',
        };
      }

      final uri =
          Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.attendanceSummaryEndpoint}',
          ).replace(
            queryParameters: {
              if (studentId != null) 'StudentId': studentId.toString(),
              if (sessionId != null) 'SessionId': sessionId.toString(),
              if (scheduleId != null) 'ScheduleId': scheduleId.toString(),
              if (sectionId != null) 'SectionId': sectionId.toString(),
              if (subjectId != null) 'SubjectId': subjectId.toString(),
              if (status != null) 'Status': status,
              if (startDate != null) 'StartDate': startDate.toIso8601String(),
              if (endDate != null) 'EndDate': endDate.toIso8601String(),
              if (isManualEntry != null)
                'IsManualEntry': isManualEntry.toString(),
              if (pageNumber != null) 'PageNumber': pageNumber.toString(),
              if (pageSize != null) 'PageSize': pageSize.toString(),
            },
          );

      print('🌐 Fetching attendance summary from: $uri');

      final response = await _makeRequest(
        method: 'GET',
        uri: uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        requestId: requestId,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to load attendance summary: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in getAttendanceSummary: $e');
      return {
        'success': false,
        'error': e.toString().contains('timeout')
            ? 'Connection timeout. Please check your internet.'
            : 'Error: $e',
      };
    }
  }

  /// Get sessions (to list available sessions for attendance)
  Future<Map<String, dynamic>> getSessions({
    int? scheduleId,
    DateTime? startDate,
    DateTime? endDate,
    String? requestId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        return {
          'success': false,
          'error': 'Not authenticated. Please login again.',
        };
      }

      final uri =
          Uri.parse(
            '${ApiConstants.baseUrl}${ApiConstants.sessionsEndpoint}',
          ).replace(
            queryParameters: {
              if (scheduleId != null) 'ScheduleId': scheduleId.toString(),
              if (startDate != null) 'StartDate': startDate.toIso8601String(),
              if (endDate != null) 'EndDate': endDate.toIso8601String(),
            },
          );

      print('🌐 Fetching sessions from: $uri');

      final response = await _makeRequest(
        method: 'GET',
        uri: uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        requestId: requestId,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to load sessions: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('💥 Error in getSessions: $e');
      return {
        'success': false,
        'error': e.toString().contains('timeout')
            ? 'Connection timeout. Please check your internet.'
            : 'Error: $e',
      };
    }
  }
}

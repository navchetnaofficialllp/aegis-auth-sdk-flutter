library aegis_auth;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

/// Aegis Auth Flutter SDK
/// 
/// A comprehensive authentication SDK for Flutter applications providing:
/// - Email/Password authentication
/// - WebAuthn/Passkey support
/// - Multi-factor authentication (MFA)
/// - Biometric authentication
/// - OAuth/SSO integration
/// - JWT token management with automatic refresh
class AegisAuth {
  static const String _defaultBaseUrl = 'https://05card1j5b.execute-api.ap-south-1.amazonaws.com/prod';
  
  final String _apiKey;
  final String _baseUrl;
  final http.Client _httpClient;
  final LocalAuthentication _localAuth;
  
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiresAt;
  
  /// Initialize Aegis Auth SDK
  AegisAuth({
    required String apiKey,
    String? baseUrl,
    http.Client? httpClient,
  }) : _apiKey = apiKey,
       _baseUrl = baseUrl ?? _defaultBaseUrl,
       _httpClient = httpClient ?? http.Client(),
       _localAuth = LocalAuthentication();

  /// Register a new user with email and password
  Future<AuthResult> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final response = await _makeRequest(
        'POST',
        '/auth/register',
        body: {
          'email': email,
          'password': password,
          if (firstName != null) 'firstName': firstName,
          if (lastName != null) 'lastName': lastName,
        },
      );

      if (response['success'] == true) {
        final data = response['data'];
        await _storeTokens(
          data['accessToken'],
          data['refreshToken'],
          data['expiresIn'],
        );
        
        return AuthResult.success(User.fromJson(data['user']));
      } else {
        return AuthResult.error(response['message'] ?? 'Registration failed');
      }
    } catch (e) {
      return AuthResult.error(e.toString());
    }
  }

  /// Login with email and password
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _makeRequest(
        'POST',
        '/auth/login',
        body: {
          'email': email,
          'password': password,
        },
      );

      if (response['success'] == true) {
        final data = response['data'];
        await _storeTokens(
          data['accessToken'],
          data['refreshToken'],
          data['expiresIn'],
        );
        
        return AuthResult.success(User.fromJson(data['user']));
      } else {
        return AuthResult.error(response['message'] ?? 'Login failed');
      }
    } catch (e) {
      return AuthResult.error(e.toString());
    }
  }

  /// Logout current user
  Future<bool> logout() async {
    try {
      if (_accessToken != null) {
        await _makeAuthenticatedRequest('POST', '/auth/logout');
      }
      await _clearTokens();
      return true;
    } catch (e) {
      await _clearTokens();
      return false;
    }
  }

  /// Get current user profile
  Future<User?> getCurrentUser() async {
    try {
      await _ensureValidToken();
      final response = await _makeAuthenticatedRequest('GET', '/auth/profile');
      
      if (response['success'] == true) {
        return User.fromJson(response['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Initiate WebAuthn registration
  Future<WebAuthnChallenge?> initiateWebAuthnRegistration() async {
    try {
      await _ensureValidToken();
      final response = await _makeAuthenticatedRequest('POST', '/auth/webauthn/register/initiate');
      
      if (response['success'] == true) {
        return WebAuthnChallenge.fromJson(response['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Complete WebAuthn registration
  Future<bool> completeWebAuthnRegistration(String credential) async {
    try {
      await _ensureValidToken();
      final response = await _makeAuthenticatedRequest(
        'POST',
        '/auth/webauthn/register/complete',
        body: {'credential': credential},
      );
      
      return response['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Enable MFA for current user
  Future<MFASetup?> enableMFA() async {
    try {
      await _ensureValidToken();
      final response = await _makeAuthenticatedRequest('POST', '/auth/mfa/enable');
      
      if (response['success'] == true) {
        return MFASetup.fromJson(response['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Verify MFA token
  Future<bool> verifyMFA(String token) async {
    try {
      await _ensureValidToken();
      final response = await _makeAuthenticatedRequest(
        'POST',
        '/auth/mfa/verify',
        body: {'token': token},
      );
      
      return response['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Authenticate with biometrics
  Future<bool> authenticateWithBiometrics({
    String localizedFallbackTitle = 'Use PIN',
    String signInTitle = 'Sign in with biometrics',
  }) async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      if (!isAvailable) return false;

      final isAuthenticated = await _localAuth.authenticate(
        localizedFallbackTitle: localizedFallbackTitle,
        authMessages: [
          AndroidAuthMessages(signInTitle: signInTitle),
          IOSAuthMessages(lockOut: signInTitle),
        ],
      );

      return isAuthenticated;
    } catch (e) {
      return false;
    }
  }

  /// Check if user is authenticated
  bool isAuthenticated() {
    return _accessToken != null && 
           _tokenExpiresAt != null && 
           DateTime.now().isBefore(_tokenExpiresAt!);
  }

  /// Private methods
  Future<Map<String, dynamic>> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final requestHeaders = {
      'Content-Type': 'application/json',
      'X-API-Key': _apiKey,
      'User-Agent': 'AegisAuth-Flutter/1.0.0',
      ...?headers,
    };

    http.Response response;
    
    switch (method.toUpperCase()) {
      case 'GET':
        response = await _httpClient.get(uri, headers: requestHeaders);
        break;
      case 'POST':
        response = await _httpClient.post(
          uri,
          headers: requestHeaders,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PUT':
        response = await _httpClient.put(
          uri,
          headers: requestHeaders,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await _httpClient.delete(uri, headers: requestHeaders);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> _makeAuthenticatedRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    if (_accessToken == null) {
      throw Exception('Not authenticated');
    }

    return _makeRequest(
      method,
      endpoint,
      body: body,
      headers: {'Authorization': 'Bearer $_accessToken'},
    );
  }

  Future<void> _ensureValidToken() async {
    if (_tokenExpiresAt != null && DateTime.now().isAfter(_tokenExpiresAt!)) {
      await _refreshAccessToken();
    }
  }

  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) {
      throw Exception('No refresh token available');
    }

    try {
      final response = await _makeRequest(
        'POST',
        '/auth/refresh',
        body: {'refreshToken': _refreshToken},
      );

      if (response['success'] == true) {
        final data = response['data'];
        await _storeTokens(
          data['accessToken'],
          data['refreshToken'],
          data['expiresIn'],
        );
      } else {
        await _clearTokens();
        throw Exception('Token refresh failed');
      }
    } catch (e) {
      await _clearTokens();
      rethrow;
    }
  }

  Future<void> _storeTokens(String accessToken, String refreshToken, int expiresIn) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _tokenExpiresAt = DateTime.now().add(Duration(seconds: expiresIn));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('aegis_access_token', accessToken);
    await prefs.setString('aegis_refresh_token', refreshToken);
    await prefs.setString('aegis_token_expires_at', _tokenExpiresAt!.toIso8601String());
  }

  Future<void> _clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiresAt = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('aegis_access_token');
    await prefs.remove('aegis_refresh_token');
    await prefs.remove('aegis_token_expires_at');
  }

  /// Load stored tokens on initialization
  Future<void> loadStoredTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('aegis_access_token');
    _refreshToken = prefs.getString('aegis_refresh_token');
    
    final expiresAtString = prefs.getString('aegis_token_expires_at');
    if (expiresAtString != null) {
      _tokenExpiresAt = DateTime.parse(expiresAtString);
    }
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
  }
}

/// Data Models
class User {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final bool emailVerified;
  final bool mfaEnabled;
  final String createdAt;

  User({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    required this.emailVerified,
    required this.mfaEnabled,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      emailVerified: json['emailVerified'] ?? false,
      mfaEnabled: json['mfaEnabled'] ?? false,
      createdAt: json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'emailVerified': emailVerified,
      'mfaEnabled': mfaEnabled,
      'createdAt': createdAt,
    };
  }
}

class WebAuthnChallenge {
  final String challenge;
  final int timeout;
  final String rpId;
  final List<String> allowCredentials;

  WebAuthnChallenge({
    required this.challenge,
    required this.timeout,
    required this.rpId,
    required this.allowCredentials,
  });

  factory WebAuthnChallenge.fromJson(Map<String, dynamic> json) {
    return WebAuthnChallenge(
      challenge: json['challenge'],
      timeout: json['timeout'],
      rpId: json['rpId'],
      allowCredentials: List<String>.from(json['allowCredentials'] ?? []),
    );
  }
}

class MFASetup {
  final String secret;
  final String qrCode;
  final List<String> backupCodes;

  MFASetup({
    required this.secret,
    required this.qrCode,
    required this.backupCodes,
  });

  factory MFASetup.fromJson(Map<String, dynamic> json) {
    return MFASetup(
      secret: json['secret'],
      qrCode: json['qrCode'],
      backupCodes: List<String>.from(json['backupCodes'] ?? []),
    );
  }
}

/// Result classes
sealed class AuthResult {
  const AuthResult();
  
  factory AuthResult.success(User user) = AuthSuccess;
  factory AuthResult.error(String message) = AuthError;
}

class AuthSuccess extends AuthResult {
  final User user;
  const AuthSuccess(this.user);
}

class AuthError extends AuthResult {
  final String message;
  const AuthError(this.message);
}
# Aegis Auth Flutter SDK

[![pub package](https://img.shields.io/pub/v/aegis_auth.svg)](https://pub.dev/packages/aegis_auth)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.10%2B-blue.svg)](https://flutter.dev/)

Aegis Auth is a unified identity management system providing secure Flutter authentication. Consolidation of disparate identity providers into a single canonical source.

## Features

- 🔐 **Email/Password Authentication** - Traditional login with secure password handling
- 🔑 **WebAuthn/Passkey Support** - Passwordless authentication using biometrics
- 🛡️ **Multi-Factor Authentication (MFA)** - TOTP-based additional security layer
- 📱 **Biometric Authentication** - Fingerprint and face recognition
- 🔗 **OAuth/SSO Integration** - Google, GitHub, Microsoft, and custom providers
- 🎫 **JWT Token Management** - Automatic token refresh and secure storage
- 📊 **Session Analytics** - User behavior tracking and insights
- 🏢 **Multi-Tenant Support** - Organization and project-based user management
- 🔄 **Cross-Platform** - Works on iOS, Android, Web, and Desktop

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  aegis_auth: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Initialize the SDK

```dart
import 'package:aegis_auth/aegis_auth.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AegisAuth aegisAuth;

  @override
  void initState() {
    super.initState();
    
    aegisAuth = AegisAuth(
      apiKey: 'your_api_key_here',
      baseUrl: 'https://your-aegis-instance.com', // Optional
    );
    
    // Load stored tokens
    aegisAuth.loadStoredTokens();
  }

  @override
  void dispose() {
    aegisAuth.dispose();
    super.dispose();
  }
}
```

### 2. User Registration

```dart
class RegisterScreen extends StatelessWidget {
  final AegisAuth aegisAuth;
  
  RegisterScreen({required this.aegisAuth});

  Future<void> _register() async {
    final result = await aegisAuth.register(
      email: 'user@example.com',
      password: 'securePassword123',
      firstName: 'John',
      lastName: 'Doe',
    );

    switch (result) {
      case AuthSuccess(user: final user):
        // Registration successful
        print('User registered: ${user.email}');
        Navigator.pushReplacementNamed(context, '/home');
        
      case AuthError(message: final message):
        // Handle error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
    }
  }
}
```

### 3. User Login

```dart
// Email/Password login
Future<void> _login() async {
  final result = await aegisAuth.login(
    email: 'user@example.com',
    password: 'password123',
  );

  switch (result) {
    case AuthSuccess(user: final user):
      // Login successful
      print('Welcome back, ${user.email}!');
      Navigator.pushReplacementNamed(context, '/home');
      
    case AuthError(message: final message):
      // Handle login error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
  }
}
```

### 4. Biometric Authentication

```dart
// Authenticate with biometrics
Future<void> _authenticateWithBiometrics() async {
  final isAuthenticated = await aegisAuth.authenticateWithBiometrics(
    signInTitle: 'Sign in to Aegis Auth',
    localizedFallbackTitle: 'Use PIN',
  );

  if (isAuthenticated) {
    print('Biometric authentication successful');
    Navigator.pushReplacementNamed(context, '/home');
  } else {
    print('Biometric authentication failed');
  }
}
```

### 5. WebAuthn/Passkey Authentication

```dart
// Initiate WebAuthn registration
Future<void> _registerWebAuthn() async {
  final challenge = await aegisAuth.initiateWebAuthnRegistration();
  
  if (challenge != null) {
    // Use platform WebAuthn implementation
    // This is a simplified example - actual implementation depends on platform
    final credential = await _createWebAuthnCredential(challenge);
    
    if (credential != null) {
      final success = await aegisAuth.completeWebAuthnRegistration(credential);
      if (success) {
        print('WebAuthn registration successful');
      }
    }
  }
}

// Platform-specific WebAuthn implementation would go here
Future<String?> _createWebAuthnCredential(WebAuthnChallenge challenge) async {
  // Implementation depends on platform and WebAuthn library
  // This is a placeholder
  return null;
}
```

### 6. Multi-Factor Authentication (MFA)

```dart
// Enable MFA
Future<void> _enableMFA() async {
  final mfaSetup = await aegisAuth.enableMFA();
  
  if (mfaSetup != null) {
    // Show QR code for authenticator app
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Setup MFA'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Display QR code
            Image.network(mfaSetup.qrCode),
            Text('Scan this QR code with your authenticator app'),
          ],
        ),
      ),
    );
    
    // Store backup codes securely
    await _storeBackupCodes(mfaSetup.backupCodes);
  }
}

// Verify MFA token
Future<void> _verifyMFA(String token) async {
  final isValid = await aegisAuth.verifyMFA(token);
  
  if (isValid) {
    print('MFA verification successful');
  } else {
    print('Invalid MFA token');
  }
}
```

### 7. User Profile Management

```dart
// Get current user
Future<void> _getCurrentUser() async {
  final user = await aegisAuth.getCurrentUser();
  
  if (user != null) {
    setState(() {
      // Update UI with user data
      _userEmail = user.email;
      _userName = '${user.firstName} ${user.lastName}';
    });
  }
}

// Check authentication status
bool get isLoggedIn => aegisAuth.isAuthenticated();

// Auto-redirect based on auth status
@override
void initState() {
  super.initState();
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (aegisAuth.isAuthenticated()) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  });
}
```

### 8. Logout

```dart
// Logout user
Future<void> _logout() async {
  final success = await aegisAuth.logout();
  
  if (success) {
    Navigator.pushReplacementNamed(context, '/login');
  }
}
```

## Advanced Usage

### Custom Configuration

```dart
final aegisAuth = AegisAuth(
  apiKey: 'your_api_key',
  baseUrl: 'https://custom-domain.com',
  httpClient: http.Client(), // Custom HTTP client
);
```

### Error Handling with Pattern Matching

```dart
Future<void> handleAuthResult(AuthResult result) async {
  switch (result) {
    case AuthSuccess(user: final user):
      // Handle successful authentication
      await _navigateToHome(user);
      
    case AuthError(message: final message):
      // Handle different types of errors
      if (message.contains('network')) {
        _showNetworkError();
      } else if (message.contains('credentials')) {
        _showCredentialsError();
      } else {
        _showGenericError(message);
      }
  }
}
```

### State Management Integration

```dart
// With Provider
class AuthProvider extends ChangeNotifier {
  final AegisAuth _aegisAuth;
  User? _currentUser;
  
  AuthProvider(this._aegisAuth);
  
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _aegisAuth.isAuthenticated();
  
  Future<void> login(String email, String password) async {
    final result = await _aegisAuth.login(email: email, password: password);
    
    if (result is AuthSuccess) {
      _currentUser = result.user;
      notifyListeners();
    }
  }
}

// With Riverpod
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(AegisAuth(apiKey: 'your_api_key'));
});
```

## Platform Setup

### Android

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
```

### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to authenticate</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Access local network for authentication</string>
```

## API Reference

### AegisAuth Class

#### Methods

- `Future<AuthResult> register({required String email, required String password, String? firstName, String? lastName})`
- `Future<AuthResult> login({required String email, required String password})`
- `Future<bool> logout()`
- `Future<User?> getCurrentUser()`
- `Future<WebAuthnChallenge?> initiateWebAuthnRegistration()`
- `Future<bool> completeWebAuthnRegistration(String credential)`
- `Future<MFASetup?> enableMFA()`
- `Future<bool> verifyMFA(String token)`
- `Future<bool> authenticateWithBiometrics({String localizedFallbackTitle, String signInTitle})`
- `bool isAuthenticated()`
- `Future<void> loadStoredTokens()`
- `void dispose()`

### Data Classes

#### User
```dart
class User {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final bool emailVerified;
  final bool mfaEnabled;
  final String createdAt;
}
```

#### AuthResult
```dart
sealed class AuthResult {
  factory AuthResult.success(User user) = AuthSuccess;
  factory AuthResult.error(String message) = AuthError;
}
```

## Security Features

- 🔒 **TLS 1.3 Encryption** - All API communications encrypted
- 🎫 **JWT Tokens** - Secure token-based authentication
- 🔄 **Automatic Token Refresh** - Seamless session management
- 🛡️ **Certificate Pinning** - Protection against MITM attacks
- 📱 **Biometric Integration** - Hardware-backed security
- 🔐 **Secure Storage** - Platform keychain integration
- 🚫 **No Data Collection** - Privacy-first approach

## Platform Support

| Platform | Support | Biometrics | WebAuthn |
|----------|---------|------------|----------|
| Android  | ✅      | ✅         | ✅       |
| iOS      | ✅      | ✅         | ✅       |
| Web      | ✅      | ❌         | ✅       |
| macOS    | ✅      | ✅         | ✅       |
| Windows  | ✅      | ❌         | ✅       |
| Linux    | ✅      | ❌         | ✅       |

## Support

- **Documentation**: https://aegis.navchetna.tech
- **GitHub Issues**: https://github.com/navchetnaofficialllp/aegis-auth-sdk-flutter/issues
- **Email Support**: hello@navchetna.tech
- **Publisher**: https://pub.dev/publishers/navchetna.tech

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## About Navchetna Technologies

Aegis Auth is developed and maintained by [Navchetna Technologies](https://navchetna.tech), a leading provider of identity and access management solutions.

---

**Aegis Auth by Navchetna Technologies** - Secure, Scalable, Simple Authentication for Flutter
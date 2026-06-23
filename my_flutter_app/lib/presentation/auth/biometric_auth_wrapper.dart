import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class BiometricAuthWrapper extends StatefulWidget {
  final Widget child;

  static bool authenticatedThisSession = false;

  const BiometricAuthWrapper({super.key, required this.child});

  @override
  State<BiometricAuthWrapper> createState() => _BiometricAuthWrapperState();
}

class _BiometricAuthWrapperState extends State<BiometricAuthWrapper>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isBiometricEnabled = false;
  bool _isAuthenticated = false;
  bool _isScanning = false;
  bool _showSuccessAnimation = false;
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;
  String _message = 'Tap fingerprint sensor to unlock';

  bool _isBiometricSupported = true;
  bool _showPasswordFallback = false;
  bool _isPasswordVisible = false;
  bool _isVerifyingPassword = false;
  String? _passwordError;
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
    if (BiometricAuthWrapper.authenticatedThisSession) {
      _isAuthenticated = true;
      _isLoading = false;
    } else {
      _checkBiometricPreference();
    }
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('biometric_enabled') ?? false;

      final LocalAuthentication auth = LocalAuthentication();
      final bool canCheck = await auth.canCheckBiometrics;
      final bool isSupported = canCheck || await auth.isDeviceSupported();

      if (mounted) {
        setState(() {
          _isBiometricEnabled = enabled;
          _isBiometricSupported = isSupported;
          _isLoading = false;
          if (!isSupported && enabled) {
            _showPasswordFallback = true;
          }
        });
        if (enabled && isSupported) {
          // Auto-trigger biometric authentication on launch
          _authenticate();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticated) return;

    if (kIsWeb) {
      // Simulate Web Biometrics for Chrome testing
      setState(() {
        _isScanning = true;
        _message = 'Scanning fingerprint...';
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        setState(() {
          _isScanning = false;
          _isAuthenticated = true;
          _message = 'Success!';
        });
      }
      return;
    }

    // Native Biometrics (Android, iOS, Windows, macOS)
    final LocalAuthentication auth = LocalAuthentication();
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        setState(() {
          _message = 'Biometrics not supported on this device';
          _isBiometricSupported = false;
          _showPasswordFallback = true;
        });
        return;
      }

      setState(() {
        _isScanning = true;
        _message = 'Waiting for scan...';
        _passwordError = null;
      });

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Scan your fingerprint or use PIN to unlock Dhankund',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (mounted) {
        if (didAuthenticate) {
          setState(() {
            _isScanning = false;
            _showSuccessAnimation = true;
            _message = 'Authenticated successfully!';
          });

          await Future.delayed(const Duration(milliseconds: 1000));

          if (mounted) {
            setState(() {
              _isAuthenticated = true;
              BiometricAuthWrapper.authenticatedThisSession = true;
            });
          }
        } else {
          setState(() {
            _isScanning = false;
            _message = 'Fingerprint not recognized. Tap icon to try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _message = 'Biometric unlock failed. Tap icon to retry.';
        });
      }
    }
  }

  Future<void> _verifyPassword() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;

    setState(() {
      _isVerifyingPassword = true;
      _passwordError = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        if (mounted) {
          setState(() {
            _isVerifyingPassword = false;
            _showSuccessAnimation = true;
            _message = 'Authenticated successfully!';
          });

          await Future.delayed(const Duration(milliseconds: 1000));

          if (mounted) {
            setState(() {
              _isAuthenticated = true;
              BiometricAuthWrapper.authenticatedThisSession = true;
              _passwordController.clear();
            });
          }
        }
      } else {
        await _logout();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingPassword = false;
          _passwordError = 'Incorrect password. Please try again.';
        });
      }
    }
  }

  Future<void> _verifyWithGoogle() async {
    setState(() {
      _isVerifyingPassword = true;
      _passwordError = null;
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.currentUser?.reauthenticateWithCredential(credential);
        if (mounted) {
          setState(() {
            _isVerifyingPassword = false;
            _showSuccessAnimation = true;
            _message = 'Authenticated successfully!';
          });

          await Future.delayed(const Duration(milliseconds: 1000));

          if (mounted) {
            setState(() {
              _isAuthenticated = true;
              BiometricAuthWrapper.authenticatedThisSession = true;
            });
          }
        }
      } else {
        setState(() {
          _isVerifyingPassword = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingPassword = false;
          _passwordError = 'Google authentication failed. Please try again.';
        });
      }
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Remove biometric preference so they are not blocked on next login
      await prefs.remove('biometric_enabled');
      BiometricAuthWrapper.authenticatedThisSession = false;
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out: $e')),
      );
    }
  }

  Widget _buildPasswordFallbackUI() {
    final user = FirebaseAuth.instance.currentUser;
    final isGoogleUser = user?.providerData.any((info) => info.providerId == 'google.com') ?? false;

    if (isGoogleUser) {
      return Column(
        children: [
          const Text(
            'Unlock with Google',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'You signed in using Google. Re-authenticate to unlock.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_passwordError != null) ...[
            Text(
              _passwordError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isVerifyingPassword ? null : _verifyWithGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 24),
              label: _isVerifyingPassword
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Verify Google Account', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A3AFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isBiometricSupported)
            TextButton(
              onPressed: () {
                setState(() {
                  _showPasswordFallback = false;
                  _passwordError = null;
                });
                _authenticate();
              },
              child: const Text('Use Biometrics', style: TextStyle(color: Colors.white70)),
            ),
        ],
      );
    }

    return Column(
      children: [
        const Text(
          'Unlock with Password',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white24),
          ),
          child: TextField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter your password',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white70,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
        if (_passwordError != null) ...[
          const SizedBox(height: 12),
          Text(
            _passwordError!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            if (_isBiometricSupported) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _showPasswordFallback = false;
                      _passwordError = null;
                    });
                    _authenticate();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Biometrics'),
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: _isVerifyingPassword ? null : _verifyPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A3AFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isVerifyingPassword
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Unlock', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3F5F9),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4A3AFF))),
      );
    }

    // If fingerprint lock is off, or we are already authenticated, render dashboard directly!
    if (!_isBiometricEnabled || _isAuthenticated) {
      return widget.child;
    }

    // Biometric lock screen overlay
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0C20), Color(0xFF15102A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // App Logo Placeholder / Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.account_balance,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'DHANKUND',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Loan Services',
                  style: TextStyle(
                    color: Colors.deepPurple[100],
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                
                if (_showPasswordFallback) ...[
                  _buildPasswordFallbackUI(),
                ] else ...[
                  // Pulsing / Glowing Fingerprint Scanner button
                  GestureDetector(
                    onTap: _authenticate,
                    child: SizedBox(
                      width: 180,
                      height: 180,
                      child: AnimatedBuilder(
                        animation: _rippleAnimation,
                        builder: (context, child) {
                          Color activeColor = const Color(0xFF4A3AFF);
                          if (_showSuccessAnimation) {
                            activeColor = const Color(0xFF27AE60);
                          } else if (_message.toLowerCase().contains('failed') || 
                                     _message.toLowerCase().contains('not recognized')) {
                            activeColor = Colors.redAccent;
                          } else if (_isScanning) {
                            activeColor = const Color(0xFF00FF88); // glowing electric green
                          }

                          return CustomPaint(
                            painter: RipplePainter(_rippleAnimation.value, activeColor),
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: activeColor.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: activeColor.withOpacity(0.25),
                                      blurRadius: 25,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Icon(
                                    _showSuccessAnimation ? Icons.check_circle_outline : Icons.fingerprint,
                                    key: ValueKey<bool>(_showSuccessAnimation),
                                    size: 80,
                                    color: activeColor,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  Text(
                    _isScanning ? 'Scan active' : 'Locked',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _message,
                    style: TextStyle(
                      color: _message.contains('failed') ? Colors.redAccent : Colors.white70,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showPasswordFallback = true;
                        _passwordError = null;
                      });
                    },
                    child: const Text(
                      'Unlock with Password',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
                
                const Spacer(),
                // Switch / Logout options
                TextButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.white60, size: 16),
                  label: const Text(
                    'LOG OUT / SWITCH ACCOUNT',
                    style: TextStyle(
                      color: Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(color: Colors.white12, width: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  RipplePainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final currentProgress = (progress + (i / 3)) % 1.0;
      final radius = maxRadius * currentProgress;
      final opacity = (1.0 - currentProgress) * 0.45;

      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);

      final fillPaint = Paint()
        ..color = color.withOpacity(opacity * 0.1)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

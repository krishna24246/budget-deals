import 'package:flutter/material.dart';
import '../services/cross_platform_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _auraController;
  String _displayedText = '';
  final String _fullText = 'Hot deals. Smart savings.';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _auraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _animationController.forward();
    _startTypewriterAnimation();
  }

  void _startTypewriterAnimation() async {
    for (int i = 0; i <= _fullText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        setState(() {
          _displayedText = _fullText.substring(0, i);
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _auraController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = CrossPlatformAuthService();
      final user = await authService.signInWithGoogle();

      if (user != null && mounted) {
        Navigator.pushReplacementNamed(context, '/main');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Sign in error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.blue[900]?.withValues(alpha: 0.2) ??
                  Colors.blue.shade900.withValues(alpha: 0.2),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 80),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: AnimatedBuilder(
                        animation: _auraController,
                        builder: (context, child) {
                          final pulse = _auraController.value;
                          final glowMultiplier = 1.0 + (pulse * 0.3);

                          return Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.blue.shade900.withOpacity(0.8),
                                  Colors.blue.shade700.withOpacity(0.6),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.7, 1.0],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.shade900.withOpacity(
                                    0.5 * glowMultiplier,
                                  ),
                                  blurRadius: 25 * glowMultiplier,
                                  spreadRadius: 5 * glowMultiplier,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: Colors.blue.shade800.withOpacity(
                                    0.4 * glowMultiplier,
                                  ),
                                  blurRadius: 40 * glowMultiplier,
                                  spreadRadius: 8 * glowMultiplier,
                                  offset: const Offset(0, 6),
                                ),
                                BoxShadow(
                                  color: Colors.blue.shade700.withOpacity(
                                    0.3 * glowMultiplier,
                                  ),
                                  blurRadius: 60 * glowMultiplier,
                                  spreadRadius: 12 * glowMultiplier,
                                  offset: const Offset(0, 3),
                                ),
                                BoxShadow(
                                  color: Colors.blue.shade600.withOpacity(
                                    0.2 * glowMultiplier,
                                  ),
                                  blurRadius: 80 * glowMultiplier,
                                  spreadRadius: 15 * glowMultiplier,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'photos/login_logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        colors: [
                                          Colors.blue.shade400,
                                          Colors.blue.shade700,
                                        ],
                                        stops: const [0.3, 1.0],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.local_fire_department,
                                      size: 50,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Color(0xFF64B5F6),
                                          blurRadius: 15,
                                          offset: Offset(0, 0),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 40),

                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        'Budget Deals',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: const Color.fromARGB(255, 73, 72, 74),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _displayedText,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade300,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 0.5,
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _animationController.value,
                                child: Container(
                                  margin: const EdgeInsets.only(left: 2),
                                  child: Text(
                                    '|',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade300,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 80),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        icon: _isLoading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.login, size: 24),
                        label: Text(
                          _isLoading ? 'Signing in...' : 'Sign in with Google',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shadowColor: Colors.blue.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

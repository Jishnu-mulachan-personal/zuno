import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_theme.dart';
import 'auth_service.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar('Please enter a valid email address');
      return;
    }
    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters');
      return;
    }

    final success = _isLogin
        ? await ref.read(authProvider.notifier).signIn(email, password)
        : await ref.read(authProvider.notifier).signUp(email, password);

    if (!mounted) return;

    final state = ref.read(authProvider);
    if (success) {
      if (state.needsVerification) {
        // The UI will update based on auth.needsVerification
      } else {
        // Redirection is handled by router based on auth state & profile existence
      }
    } else {
      if (state.error != null) {
        _showSnackBar(state.error!);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.plusJakartaSans()),
        backgroundColor: ZunoTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    final success = await ref.read(authProvider.notifier).signInWithGoogle();
    if (!mounted) return;

    if (success) {
      // Redirection is handled by router based on auth state & profile existence
    } else {
      final err = ref.read(authProvider).error;
      if (err != null) {
        _showSnackBar(err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: ZunoTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              // Logo
              Text(
                'Zuno',
                style: GoogleFonts.notoSerif(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: ZunoTheme.primary,
                ),
              ),
              const SizedBox(height: 56),

              if (auth.needsVerification)
                _buildVerificationState()
              else
                _buildAuthForm(auth),

              const SizedBox(height: 40),
              // Decorative footer
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 14, color: ZunoTheme.tertiary),
                  const SizedBox(width: 6),
                  Text(
                    'END-TO-END ENCRYPTED DATA',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.8,
                      color: ZunoTheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthForm(AuthState auth) {
    return Column(
      children: [
        // Hero text
        Text(
          _isLogin ? 'Welcome Back' : 'Join Zuno',
          style: GoogleFonts.notoSerif(
            fontSize: 42,
            fontWeight: FontWeight.w600,
            color: ZunoTheme.onSurface,
            height: 1.15,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _isLogin
              ? 'SIGN IN TO YOUR PRIVATE SPACE.'
              : 'SECURE & PRIVATE FOR YOU.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.2,
            color: ZunoTheme.onSurfaceVariant.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 48),
        // Form card
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: ZunoTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: ZunoTheme.onSurface.withOpacity(0.04),
                blurRadius: 40,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Google Sign-In (Recommended)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: _HighlightedGoogleCta(
                      label: 'Continue with Google',
                      isLoading: auth.isLoading,
                      onTap: auth.isLoading ? null : _signInWithGoogle,
                    ),
                  ),
                  Positioned(
                    top: -10,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ZunoTheme.tertiary,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: ZunoTheme.tertiary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'RECOMMENDED',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Fastest and most secure way to join Zuno.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: ZunoTheme.onSurfaceVariant.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              Row(
                children: [
                  Expanded(child: Divider(color: ZunoTheme.outlineVariant.withOpacity(0.5))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: ZunoTheme.outlineVariant.withOpacity(0.5))),
                ],
              ),
              const SizedBox(height: 32),

              // Email Field
              Text(
                'EMAIL ADDRESS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                  color: ZunoTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: ZunoTheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'you@example.com',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Password Field
              Text(
                'PASSWORD',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                  color: ZunoTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: ZunoTheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: ZunoTheme.onSurfaceVariant,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // CTA button
              SizedBox(
                width: double.infinity,
                child: _GradientCta(
                  label: _isLogin ? 'Sign In' : 'Create Account',
                  isLoading: auth.isLoading,
                  onTap: auth.isLoading ? null : _handleAuth,
                ),
              ),
              const SizedBox(height: 16),
              // Toggle Login/Signup
              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _isLogin = !_isLogin;
                    ref.read(authProvider.notifier).reset();
                  }),
                  child: Text(
                    _isLogin
                        ? "Don't have an account? Sign Up"
                        : "Already have an account? Sign In",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ZunoTheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ZunoTheme.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ZunoTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mark_email_read, size: 40, color: ZunoTheme.primary),
          ),
          const SizedBox(height: 24),
          Text(
            'Check your inbox',
            style: GoogleFonts.notoSerif(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: ZunoTheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'We have sent a verification link to\n${_emailController.text}',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: ZunoTheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          _GradientCta(
            label: 'Back to Login',
            onTap: () {
              setState(() {
                _isLogin = true;
                ref.read(authProvider.notifier).reset();
              });
            },
          ),
        ],
      ),
    );
  }
}

// ── Shared gradient CTA ────────────────────────────────────────────────────

class _GradientCta extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  const _GradientCta({required this.label, this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: onTap != null
              ? ZunoTheme.primaryGradient
              : const LinearGradient(colors: [Colors.grey, Colors.grey]),
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
              color: ZunoTheme.primary.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  label.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 2.2,
                  ),
                ),
        ),
      ),
    );
  }
}

class _HighlightedGoogleCta extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  const _HighlightedGoogleCta({required this.label, this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: ZunoTheme.primary.withOpacity(0.3), width: 2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: ZunoTheme.primary.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: ZunoTheme.primary, strokeWidth: 2),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/google_logo.png',
                      height: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ZunoTheme.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}


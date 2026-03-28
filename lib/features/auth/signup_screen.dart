import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../../app_theme.dart';
import 'auth_service.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _phoneController = TextEditingController();
  String _countryCode = '+91';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final phone = '$_countryCode${_phoneController.text.trim()}';
    if (phone.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enter a valid phone number',
              style: GoogleFonts.plusJakartaSans()),
          backgroundColor: ZunoTheme.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    await ref.read(authProvider.notifier).sendOTP(phone);
    if (!mounted) return;
    final err = ref.read(authProvider).error;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: ZunoTheme.error),
      );
    } else {
      context.go('/otp', extra: phone);
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
              // Hero text
              Text(
                'Welcome Home',
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
                'SECURE & PRIVATE FOR YOU.',
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
                    // Label
                    Text(
                      'MOBILE NUMBER',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.8,
                        color: ZunoTheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Phone row
                    Row(
                      children: [
                        // Country code
                        Container(
                          decoration: BoxDecoration(
                            color: ZunoTheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: CountryCodePicker(
                            onChanged: (c) => setState(
                                () => _countryCode = c.dialCode ?? '+91'),
                            initialSelection: 'IN',
                            showCountryOnly: false,
                            showOnlyCountryWhenClosed: false,
                            alignLeft: false,
                            textStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ZunoTheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Number
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: ZunoTheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: '000 000 0000',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                color:
                                    ZunoTheme.onSurfaceVariant.withOpacity(0.4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Send Code button
                    SizedBox(
                      width: double.infinity,
                      child: _GradientCta(
                        label: 'Send Code',
                        isLoading: auth.isLoading,
                        onTap: auth.isLoading ? null : _sendOTP,
                      ),
                    ),
                  ],
                ),
              ),
              // Decorative image
              const SizedBox(height: 40),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    'https://images.unsplash.com/photo-1513689125086-6c432170e843?w=600&q=80',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: ZunoTheme.primaryFixed,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 14, color: ZunoTheme.tertiary),
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
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  Text('By continuing, you agree to our ',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: ZunoTheme.onSurfaceVariant.withOpacity(0.5))),
                  GestureDetector(
                    child: Text('Terms',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: ZunoTheme.onSurfaceVariant.withOpacity(0.5),
                            decoration: TextDecoration.underline)),
                  ),
                  Text(' and ',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: ZunoTheme.onSurfaceVariant.withOpacity(0.5))),
                  GestureDetector(
                    child: Text('Privacy Policy',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: ZunoTheme.onSurfaceVariant.withOpacity(0.5),
                            decoration: TextDecoration.underline)),
                  ),
                  Text('.',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: ZunoTheme.onSurfaceVariant.withOpacity(0.5))),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
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

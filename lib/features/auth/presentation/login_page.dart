import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/auth.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  // 0 = Admin, 1 = Chauffeur
  int _selectedTab = 0;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_emailController.text.isEmpty ||
          !_emailController.text.contains('@')) {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'Veuillez entrer une adresse email valide.',
        );
      }

      if (_passwordController.text.isEmpty) {
        throw FirebaseAuthException(
          code: 'wrong-password',
          message: 'Veuillez entrer votre mot de passe.',
        );
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connexion réussie'),
            backgroundColor: Color(0xFF10B981),
          ),
        );

        final role = _selectedTab == 0 ? UserRole.admin : UserRole.driver;
        ref.read(roleProvider.notifier).state = role;
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          switch (e.code) {
            case 'user-not-found':
              _errorMessage = 'Aucun utilisateur trouvé avec cet email.';
              break;
            case 'wrong-password':
              _errorMessage = 'Mot de passe incorrect.';
              break;
            case 'invalid-email':
              _errorMessage = 'Adresse email invalide.';
              break;
            case 'user-disabled':
              _errorMessage = 'Ce compte a été désactivé.';
              break;
            case 'invalid-credential':
              _errorMessage = 'Identifiants incorrects.';
              break;
            default:
              _errorMessage =
                  e.message ?? 'Une erreur est survenue (${e.code}).';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Une erreur inattendue est survenue: $e';
        });
      }
    }
  }

  static bool _googleSignInInitialized = false;

  //sing up
  Future<void> _handleSignUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_emailController.text.isEmpty ||
          !_emailController.text.contains('@')) {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'Veuillez entrer une adresse email valide.',
        );
      }

      if (_passwordController.text.length < 6) {
        throw FirebaseAuthException(
          code: 'weak-password',
          message: 'Le mot de passe doit contenir au moins 6 caractères.',
        );
      }

      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compte créé avec succès'),
            backgroundColor: Color(0xFF10B981),
          ),
        );

        final role = _selectedTab == 0 ? UserRole.admin : UserRole.driver;
        ref.read(roleProvider.notifier).state = role;
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          switch (e.code) {
            case 'email-already-in-use':
              _errorMessage = 'Cet email est déjà utilisé.';
              break;
            case 'weak-password':
              _errorMessage = 'Le mot de passe est trop faible.';
              break;
            case 'invalid-email':
              _errorMessage = 'Adresse email invalide.';
              break;
            default:
              _errorMessage =
                  e.message ?? 'Une erreur est survenue (${e.code}).';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Une erreur inattendue est survenue: $e';
        });
      }
    }
  }

  /// Web Client ID from Firebase (Authentication → Google → Web SDK configuration).
  /// Override via: --dart-define=GOOGLE_SERVER_CLIENT_ID=...
  static const _kGoogleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '133894196998-fvgpatsma849lu4cb242kunabq333bnh.apps.googleusercontent.com',
  );

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final googleSignIn = GoogleSignIn.instance;
      if (!_googleSignInInitialized) {
        final isAndroid =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
        if (isAndroid && _kGoogleServerClientId.isEmpty) {
          throw FirebaseAuthException(
            code: 'missing-server-client-id',
            message:
                'GOOGLE_SERVER_CLIENT_ID doit être défini pour Android. '
                'Utilisez --dart-define=GOOGLE_SERVER_CLIENT_ID=votre_web_client_id',
          );
        }
        await googleSignIn.initialize(
          serverClientId: isAndroid ? _kGoogleServerClientId : null,
        );
        _googleSignInInitialized = true;
      }

      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw FirebaseAuthException(
          code: 'missing-google-token',
          message: 'Impossible de récupérer le token Google.',
        );
      }

      // Create a new credential (v7 authentication exposes idToken)
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Use selected tab role for now
        final role = _selectedTab == 0 ? UserRole.admin : UserRole.driver;
        ref.read(roleProvider.notifier).state = role;
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _googleSignInErrorMessage(e.description);
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _googleSignInErrorMessage(e.message);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _googleSignInErrorMessage(e.toString());
        });
      }
    }
  }

  /// Message utilisateur en cas d'erreur Google Sign-In, avec aide si
  /// "Developer console is not set up correctly".
  static String _googleSignInErrorMessage(String? raw) {
    if (raw == null || raw.isEmpty) {
      return 'Erreur lors de la connexion Google.';
    }
    final lower = raw.toLowerCase();
    if (lower.contains('developer console') ||
        lower.contains('not set up correctly') ||
        lower.contains('developer_error') ||
        lower.contains('apiException: 10')) {
      return 'Configuration Google Sign-In manquante.\n\n'
          'Dans Firebase Console :\n'
          '• Projet → Paramètres (engrenage) → Vos applications → Android\n'
          '• Ajoutez l’empreinte SHA-1 (debug : keytool -list -v -keystore android/app/debug.keystore)\n'
          '• Téléchargez le nouveau google-services.json\n\n'
          'Vérifiez aussi que le Web Client ID (--dart-define=GOOGLE_SERVER_CLIENT_ID=…) correspond au projet.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    // Responsive Layout
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Blanc/Gris clair
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            // Desktop: Split View
            return Row(
              children: [
                Expanded(flex: 1, child: _buildLeftSection(context)),
                Expanded(flex: 1, child: _buildRightSection(context)),
              ],
            );
          } else {
            // Mobile: Stacked
            return CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      // Form Section (Flexible height based on content)
                      _buildLeftSection(context),

                      // Branding Section (Expand to fill remaining space)
                      Expanded(child: _buildRightSection(context)),
                    ],
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildLeftSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Allow minimum size
            children: [
              // Logo SHTT (Placeholder)
              Row(
                children: [
                  Image.asset(
                    'assets/images/logo_shtt.jpeg',
                    height: 40,
                    errorBuilder: (c, e, s) => const Icon(
                      LucideIcons.truck,
                      color: Color(0xFF3B82F6),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'SHTT',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Bienvenue dans SHTT',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connectez-vous pour gérer votre flotte',
                style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),

              // Tabs
              _buildTabs(),
              const SizedBox(height: 32),

              // Form
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.alertCircle,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFEF4444),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ).animate().shake(duration: 300.ms),
                ),

              _buildTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'votre.email@exemple.com',
                icon: LucideIcons.mail,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _passwordController,
                label: 'Mot de passe',
                hint: 'Entrez votre mot de passe',
                icon: LucideIcons.lock,
                isPassword: true,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: Text(
                    'Mot de passe oublié ?',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Login Button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Se connecter',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OU',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                ],
              ),
              const SizedBox(height: 24),

              // Google Button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleLogin,
                  icon: const Icon(
                    LucideIcons.chrome,
                    size: 20,
                  ), // Placeholder for Google Icon
                  label: Text(
                    'Continuer avec Google',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Pas encore de compte ? ',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF1F2937),
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: _isLoading ? null : _handleSignUp,
                      child: Text(
                        "S'inscrire",
                        style: GoogleFonts.inter(
                          color: const Color(0xFF3B82F6),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),
        ),
      ),
    );
  }

  Widget _buildRightSection(BuildContext context) {
    return Container(
      width: double.infinity, // Ensure full width
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
        ),
      ),
      child: Stack(
        children: [
          // Background Pattern (Bubbles)
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 24.0,
            ),
            child:
                SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.truck,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'SHTT - Smart Heavy Truck Transport',
                            style: GoogleFonts.poppins(
                              fontSize:
                                  24, // Smaller title for mobile responsiveness
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Suivez vos camions en direct, optimisez vos routes, augmentez votre rentabilité',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Features
                          _buildFeatureItem(
                            LucideIcons.mapPin,
                            'Suivi GPS en temps réel',
                          ),
                          const SizedBox(height: 12),
                          _buildFeatureItem(
                            LucideIcons.gauge,
                            'Données OBD2 en direct',
                          ),
                          const SizedBox(height: 12),
                          _buildFeatureItem(
                            LucideIcons.trendingUp,
                            'Rapports et statistiques',
                          ),

                          const SizedBox(height: 32),
                          // Testimonial
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: Color(0xFFFBBF24),
                                      size: 16,
                                    ),
                                    Icon(
                                      Icons.star,
                                      color: Color(0xFFFBBF24),
                                      size: 16,
                                    ),
                                    Icon(
                                      Icons.star,
                                      color: Color(0xFFFBBF24),
                                      size: 16,
                                    ),
                                    Icon(
                                      Icons.star,
                                      color: Color(0xFFFBBF24),
                                      size: 16,
                                    ),
                                    Icon(
                                      Icons.star,
                                      color: Color(0xFFFBBF24),
                                      size: 16,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '"SHTT a augmenté notre rentabilité de 35%"',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '- By Iheb Fredj',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .slideX(begin: 0.1, end: 0, delay: 200.ms)
                    .fadeIn(duration: 500.ms),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 16),
        Flexible(
          // Allow text wrap
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14, // Slightly smaller
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _buildTabItem(0, 'Administrateur', LucideIcons.shield),
          _buildTabItem(1, 'Chauffeur', LucideIcons.user),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF1F2937)
                      : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword && !_isPasswordVisible,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: const Color(0xFF9CA3AF)),
            prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _isPasswordVisible ? LucideIcons.eye : LucideIcons.eyeOff,
                      color: const Color(0xFF9CA3AF),
                      size: 20,
                    ),
                    onPressed: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF3B82F6)),
            ),
          ),
        ),
      ],
    );
  }
}

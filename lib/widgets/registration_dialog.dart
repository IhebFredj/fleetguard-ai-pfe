import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/auth.dart';

/// Couleurs SHTT - Design system
class SHTTColors {
  static const primary = Color(0xFF3B82F6);
  static const primaryDark = Color(0xFF1E40AF);
  static const accent = Color(0xFF10B981);
  static const textDark = Color(0xFF1F2937);
  static const textGrey = Color(0xFF6B7280);
  static const textLightGrey = Color(0xFF9CA3AF);
  static const background = Color(0xFFFFFFFF);
  static const backgroundGrey = Color(0xFFF9FAFB);
  static const borderGrey = Color(0xFFE5E7EB);
  static const error = Color(0xFFEF4444);
}

/// Registration Dialog for creating new user accounts
class RegistrationDialog extends ConsumerStatefulWidget {
  const RegistrationDialog({super.key});

  @override
  ConsumerState<RegistrationDialog> createState() => _RegistrationDialogState();
}

class _RegistrationDialogState extends ConsumerState<RegistrationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _acceptTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  UserRole _selectedRole = UserRole.driver;
  String? _errorMessage;

  // Password strength
  int _passwordStrength = 0; // 0: weak, 1: medium, 2: strong

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
    int strength = 0;
    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    setState(() {
      if (strength <= 1) {
        _passwordStrength = 0;
      } else if (strength == 2) {
        _passwordStrength = 1;
      } else {
        _passwordStrength = 2;
      }
    });
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptTerms) {
      setState(() {
        _errorMessage = 'Veuillez accepter les conditions d\'utilisation';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Create user with Firebase Auth
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      // Update display name
      await userCredential.user?.updateDisplayName(
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
      );

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compte créé avec succès !'),
            backgroundColor: SHTTColors.accent,
          ),
        );

        // Close dialog
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
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
            _errorMessage = e.message ?? 'Une erreur est survenue';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Une erreur inattendue est survenue: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(),

            // Form content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Error message
                      if (_errorMessage != null) _buildErrorMessage(),

                      const SizedBox(height: 16),

                      // First Name and Last Name row
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _firstNameController,
                              label: 'Prénom',
                              hint: 'Prénom',
                              icon: LucideIcons.user,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Champ requis';
                                }
                                if (value.length < 2) {
                                  return 'Minimum 2 caractères';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _lastNameController,
                              label: 'Nom',
                              hint: 'Nom',
                              icon: LucideIcons.user,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Champ requis';
                                }
                                if (value.length < 2) {
                                  return 'Minimum 2 caractères';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Email field
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'votre.email@exemple.com',
                        icon: LucideIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un email';
                          }
                          final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                          if (!emailRegex.hasMatch(value)) {
                            return 'Format email invalide';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Password field
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Mot de passe',
                        hint: 'Entrez un mot de passe',
                        icon: LucideIcons.lock,
                        obscureText: _obscurePassword,
                        onChanged: _checkPasswordStrength,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? LucideIcons.eyeOff
                                : LucideIcons.eye,
                            size: 20,
                            color: SHTTColors.textGrey,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un mot de passe';
                          }
                          if (value.length < 8) {
                            return 'Minimum 8 caractères';
                          }
                          if (!value.contains(RegExp(r'[A-Z]'))) {
                            return 'Doit contenir une majuscule';
                          }
                          if (!value.contains(RegExp(r'[0-9]'))) {
                            return 'Doit contenir un chiffre';
                          }
                          return null;
                        },
                      ),

                      // Password strength indicator
                      if (_passwordController.text.isNotEmpty)
                        _buildPasswordStrengthIndicator(),

                      const SizedBox(height: 16),

                      // Confirm password field
                      _buildTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirmer le mot de passe',
                        hint: 'Confirmez le mot de passe',
                        icon: LucideIcons.lock,
                        obscureText: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? LucideIcons.eyeOff
                                : LucideIcons.eye,
                            size: 20,
                            color: SHTTColors.textGrey,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez confirmer le mot de passe';
                          }
                          if (value != _passwordController.text) {
                            return 'Les mots de passe ne correspondent pas';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Role dropdown
                      _buildRoleDropdown(),

                      const SizedBox(height: 16),

                      // Phone field (optional)
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Téléphone (optionnel)',
                        hint: '+216 XX XXX XXX',
                        icon: LucideIcons.phone,
                        keyboardType: TextInputType.phone,
                      ),

                      const SizedBox(height: 16),

                      // Terms checkbox
                      _buildTermsCheckbox(),

                      const SizedBox(height: 24),

                      // Action buttons
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SHTTColors.borderGrey)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enregistrer un nouveau compte',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: SHTTColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Remplissez les informations ci-dessous',
                style: TextStyle(fontSize: 13, color: SHTTColors.textGrey),
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(LucideIcons.x, size: 20),
            color: SHTTColors.textGrey,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SHTTColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SHTTColors.error),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.alertCircle,
            color: SHTTColors.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: SHTTColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: SHTTColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: SHTTColors.textLightGrey),
            prefixIcon: Icon(icon, color: SHTTColors.textGrey, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: SHTTColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: SHTTColors.borderGrey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: SHTTColors.borderGrey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: SHTTColors.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: SHTTColors.error),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    Color color;
    String text;

    switch (_passwordStrength) {
      case 0:
        color = SHTTColors.error;
        text = 'Faible';
        break;
      case 1:
        color = Colors.orange;
        text = 'Moyen';
        break;
      case 2:
        color = SHTTColors.accent;
        text = 'Fort';
        break;
      default:
        color = SHTTColors.error;
        text = 'Faible';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(
              value: (_passwordStrength + 1) / 3,
              backgroundColor: SHTTColors.borderGrey,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rôle',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: SHTTColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<UserRole>(
          value: _selectedRole,
          decoration: InputDecoration(
            prefixIcon: const Icon(
              LucideIcons.shield,
              color: SHTTColors.textGrey,
              size: 20,
            ),
            filled: true,
            fillColor: SHTTColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: SHTTColors.borderGrey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: SHTTColors.borderGrey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: SHTTColors.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
          ),
          items: const [
            DropdownMenuItem(
              value: UserRole.admin,
              child: Text('Administrateur'),
            ),
            DropdownMenuItem(value: UserRole.driver, child: Text('Chauffeur')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedRole = value;
              });
            }
          },
          validator: (value) {
            if (value == null) {
              return 'Veuillez sélectionner un rôle';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _acceptTerms,
          onChanged: (value) {
            setState(() {
              _acceptTerms = value ?? false;
            });
          },
          activeColor: SHTTColors.primary,
        ),
        Expanded(
          child: Wrap(
            children: [
              const Text(
                'J\'accepte les ',
                style: TextStyle(fontSize: 13, color: SHTTColors.textDark),
              ),
              GestureDetector(
                onTap: () {
                  // Navigate to terms page
                },
                child: const Text(
                  'conditions d\'utilisation',
                  style: TextStyle(
                    fontSize: 13,
                    color: SHTTColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: SHTTColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Enregistrement en cours...'),
                    ],
                  )
                : const Text(
                    'S\'enregistrer',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: SHTTColors.textGrey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: SHTTColors.borderGrey),
              ),
            ),
            child: const Text(
              'Annuler',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }
}

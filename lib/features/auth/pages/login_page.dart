import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_locale.dart';
import '../bloc/auth_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _serverCtrl = TextEditingController(text: 'http://localhost:8064');
  final _dbCtrl = TextEditingController(text: 'hagbes');
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadSavedServerUrl();
  }

  Future<void> _loadSavedServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('odoo_server_url');
    if (url != null && url.isNotEmpty && mounted) {
      setState(() {
        _serverCtrl.text = url;
      });
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _serverCtrl.dispose();
    _dbCtrl.dispose();
    _loginCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(LoginRequested(
            serverUrl: _serverCtrl.text.trim(),
            db: '',
            login: _loginCtrl.text.trim(),
            password: _passCtrl.text,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (ctx, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: context.appColors.danger,
              ),
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topRight,
              radius: 1.3,
              colors: [
                context.appColors.primarySoft,
                context.appColors.background,
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Hagbes Logo
                          Container(
                            width: 76,
                            height: 76,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: context.appColors.surface,
                              borderRadius: BorderRadius.circular(22),
                              border:
                                  Border.all(color: context.appColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: context.appColors.primary
                                      .withValues(alpha: .18),
                                  blurRadius: 32,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(19),
                              child: Image.asset(
                                'assets/images/hagbes_logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            context.tr('welcomeBack'),
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: context.appColors.text,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr('signInSubtitle'),
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: context.appColors.textMuted),
                          ),
                          const SizedBox(height: 32),

                          // Form Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: context.appColors.surface
                                  .withValues(alpha: .94),
                              borderRadius: BorderRadius.circular(24),
                              border:
                                  Border.all(color: context.appColors.border),
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  _buildField(
                                    controller: _loginCtrl,
                                    label: context.tr('username'),
                                    hint: context.tr('enterUsername'),
                                    icon: Icons.person_outline_rounded,
                                    validator: (v) => v == null || v.isEmpty
                                        ? context.tr('usernameRequired')
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildField(
                                    controller: _passCtrl,
                                    label: context.tr('password'),
                                    hint: '••••••••',
                                    icon: Icons.lock_outline_rounded,
                                    obscure: _obscurePass,
                                    toggleObscure: () => setState(
                                        () => _obscurePass = !_obscurePass),
                                    validator: (v) => v == null || v.isEmpty
                                        ? context.tr('passwordRequired')
                                        : null,
                                  ),
                                  const SizedBox(height: 10),
                                  Theme(
                                    data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent,
                                    ),
                                    child: ExpansionTile(
                                      tilePadding: EdgeInsets.zero,
                                      childrenPadding:
                                          const EdgeInsets.only(bottom: 8),
                                      leading: Icon(Icons.dns_outlined,
                                          size: 19,
                                          color: context.appColors.textSubtle),
                                      title: Text(
                                        context.tr('serverSettings'),
                                        style: TextStyle(
                                          color: context.appColors.textMuted,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      children: [
                                        _buildField(
                                          controller: _serverCtrl,
                                          label: context.tr('workshopServer'),
                                          hint: 'http://192.168.x.x:8064',
                                          icon: Icons.link_rounded,
                                          validator: (v) =>
                                              v == null || v.isEmpty
                                                  ? context.tr('serverRequired')
                                                  : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  BlocBuilder<AuthBloc, AuthState>(
                                    builder: (ctx, state) {
                                      final loading = state is AuthLoading;
                                      return SizedBox(
                                        width: double.infinity,
                                        height: 52,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                context.appColors.primary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            elevation: 0,
                                          ),
                                          onPressed: loading ? null : _submit,
                                          child: loading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Text(
                                                  context
                                                      .tr('continueToWorkshop'),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 12,
                  child: PopupMenuButton<String>(
                    tooltip: context.tr('language'),
                    initialValue: AppLocaleController.instance.value,
                    onSelected: AppLocaleController.instance.setLanguage,
                    icon: Icon(Icons.language_rounded,
                        color: context.appColors.textMuted),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                          value: 'en', child: Text(context.tr('english'))),
                      PopupMenuItem(
                          value: 'am', child: Text(context.tr('amharic'))),
                      PopupMenuItem(
                          value: 'om', child: Text(context.tr('oromo'))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? toggleObscure,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.inter(color: context.appColors.text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            GoogleFonts.inter(color: context.appColors.textMuted, fontSize: 13),
        hintStyle: GoogleFonts.inter(
            color: context.appColors.textSubtle, fontSize: 13),
        prefixIcon: Icon(icon, color: context.appColors.textMuted, size: 20),
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: context.appColors.textMuted,
                  size: 20,
                ),
                onPressed: toggleObscure,
              )
            : null,
        filled: true,
        fillColor: context.appColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.appColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.appColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.appColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.appColors.danger),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }
}

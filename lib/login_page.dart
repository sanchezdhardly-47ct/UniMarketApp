import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  Future<void> _mostrarFormularioBienvenida(User user) async {
    if (!mounted) return;
    
    final nombreController = TextEditingController();
    final apodoController = TextEditingController();
    bool _guardando = false;

    if (user.displayName != null && user.displayName!.isNotEmpty) {
      nombreController.text = user.displayName!;
      
      final parts = user.displayName!.split(' ');
      if (parts.isNotEmpty) {
        apodoController.text = parts[0].toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('¡Bienvenido a UniMarket!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Solo necesitamos un par de datos más para crear tu perfil.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre Completo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: apodoController,
                    decoration: const InputDecoration(
                      labelText: 'Apodo (ej: juanito)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_guardando)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text(
                            'Guardando...',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _guardando 
                      ? null
                      : () async {
                    final nombre = nombreController.text.trim();
                    final apodo = apodoController.text.trim();
                    
                    if (nombre.isEmpty || apodo.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Por favor, completa todos los campos.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setDialogState(() {
                      _guardando = true;
                    });

                    try {
                      await _firestore.collection('users').doc(user.uid).set({
                        'nombre': nombre,
                        'apodo': apodo,
                        'email': user.email,
                        'tipo': 'espontaneo',
                        'createdAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));
                      
                      print('✅ Perfil guardado exitosamente para: $nombre');
                      
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                      
                    } catch (e) {
                      print('❌ Error guardando perfil: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al guardar: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        setDialogState(() {
                          _guardando = false;
                        });
                      }
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secundario, // ✅ VERDE LIMA
                  ),
                  child: const Text('Guardar y Entrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _signInWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, completa todos los campos.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      String errorMsg;
      switch (e.code) {
        case 'user-not-found':
          errorMsg = 'No se encontró un usuario con ese correo.';
          break;
        case 'wrong-password':
          errorMsg = 'La contraseña es incorrecta.';
          break;
        case 'invalid-email':
          errorMsg = 'El formato del correo no es válido.';
          break;
        default:
          errorMsg = 'Error al iniciar sesión. Intenta de nuevo.';
      }
      setState(() {
        _errorMessage = errorMsg;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ocurrió un error inesperado.';
      });
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _registerWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, completa todos los campos para registrarte.';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      User? user = userCredential.user;
      if (user != null) {
        await _mostrarFormularioBienvenida(user);
      }
      
    } on FirebaseAuthException catch (e) {
      String errorMsg;
      switch (e.code) {
        case 'email-already-in-use':
          errorMsg = 'Este correo ya está en uso. Intenta iniciar sesión.';
          break;
        case 'weak-password':
          errorMsg = 'La contraseña es muy débil (mínimo 6 caracteres).';
          break;
        case 'invalid-email':
          errorMsg = 'El formato del correo no es válido.';
          break;
        default:
          errorMsg = 'Error al registrarse. Intenta de nuevo.';
      }
      setState(() {
        _errorMessage = errorMsg;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ocurrió un error inesperado.';
      });
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        
        if (!doc.exists) {
          await _mostrarFormularioBienvenida(user);
        }
      }
    } catch (e) {
      print('❌ Error Google Sign-In: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al iniciar sesión con Google.';
        });
      }
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.fondo,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: AppColors.secundario, // ✅ VERDE LIMA para el loader
            ),
            const SizedBox(height: 20),
            Text(
              'Conectando...',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textoPrincipal,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🔥 LOGO CON FONDO CELESTE
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primario.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_cart_rounded,
                    size: 60,
                    color: AppColors.primario,
                  ),
                ),
                const SizedBox(height: 20),
                
                // TÍTULO EN CELESTE
                Text(
                  'UNIMARKET',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primario, // ✅ CELESTE
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa a tu cuenta',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textoSecundario,
                  ),
                ),
                const SizedBox(height: 40),

                // FORMULARIO O LOADING
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isLoading
                      ? _buildLoadingIndicator()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // MENSAJE DE ERROR
                            if (_errorMessage != null)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.error.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            
                            if (_errorMessage != null) const SizedBox(height: 16),
                            
                            // CAMPO EMAIL
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                labelStyle: TextStyle(color: AppColors.textoSecundario),
                                prefixIcon: Icon(
                                  Icons.email_outlined, 
                                  color: AppColors.primario, // ✅ CELESTE
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.primario, // ✅ CELESTE
                                    width: 2,
                                  ),
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // CAMPO CONTRASEÑA
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                labelStyle: TextStyle(color: AppColors.textoSecundario),
                                prefixIcon: Icon(
                                  Icons.lock_outlined, 
                                  color: AppColors.primario, // ✅ CELESTE
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword 
                                        ? Icons.visibility_off 
                                        : Icons.visibility,
                                    color: AppColors.textoSecundario,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.primario, // ✅ CELESTE
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // 🟢 BOTÓN INGRESAR - VERDE LIMA
                            ElevatedButton(
                              onPressed: _signInWithEmail,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secundario, // ✅ VERDE LIMA
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3,
                                shadowColor: AppColors.secundario.withOpacity(0.3),
                              ),
                              child: const Text(
                                'Ingresar',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // 🔵 BOTÓN REGISTRARSE - CELESTE
                            OutlinedButton(
                              onPressed: _registerWithEmail,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primario, // ✅ CELESTE
                                side: BorderSide(
                                  color: AppColors.primario, // ✅ CELESTE
                                  width: 2,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '¿No tienes cuenta? Regístrate aquí',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // DIVISOR
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: AppColors.textoSecundario.withOpacity(0.3),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                  child: Text(
                                    'O',
                                    style: TextStyle(
                                      color: AppColors.textoSecundario,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: AppColors.textoSecundario.withOpacity(0.3),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // BOTÓN GOOGLE - CON BORDE CELESTE
                            OutlinedButton.icon(
                              onPressed: _signInWithGoogle,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textoPrincipal,
                                side: BorderSide(
                                  color: AppColors.primario.withOpacity(0.5), // ✅ CELESTE suave
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: Colors.white,
                              ),
                              icon: Image.asset(
                                'assets/google_logo.png',
                                height: 24,
                                width: 24,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.g_mobiledata, 
                                    color: AppColors.primario, // ✅ CELESTE
                                    size: 24,
                                  );
                                },
                              ),
                              label: const Text(
                                'Continuar con Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                
                const SizedBox(height: 24),
                
                // TEXTO INFORMATIVO
                Text(
                  'Conecta con emprendedores de tu universidad',
                  style: TextStyle(
                    color: AppColors.textoSecundario,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
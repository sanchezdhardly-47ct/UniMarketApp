import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:unimarket/app_colors.dart';

class PublicarProductoPage extends StatefulWidget {
  const PublicarProductoPage({super.key});

  @override
  State<PublicarProductoPage> createState() => _PublicarProductoPageState();
}

class _PublicarProductoPageState extends State<PublicarProductoPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  File? _imagenProducto;
  File? _imagenQR;
  bool _subiendo = false;
  final ImagePicker _picker = ImagePicker();

  String? _metodoCobro; // 'efectivo', 'qr', 'ambos'
  String? _modoPublicacion; // 'espontaneo', 'empresarial'
  Map<String, dynamic>? _userData;
  bool _cargandoUsuario = true;

  final String _cloudinaryCloudName = 'dg1m1gslr';
  final String _uploadPreset = 'unimarket_ueb';

  // 🎬 Controladores para animaciones
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final AnimationController _pulseController;
  
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // 🎬 Inicializar animaciones
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Iniciar animaciones
    _fadeController.forward();
    _slideController.forward();
    
    _cargarDatosUsuario();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _nombreController.dispose();
    _precioController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosUsuario() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          _userData = userDoc.data()!;
          _cargandoUsuario = false;
          
          final userType = _userData!['tipo'] ?? 'espontaneo';
          if (userType == 'espontaneo') {
            _modoPublicacion = 'espontaneo';
          } else if (userType == 'dual' || userType == 'empresarial') {
            _modoPublicacion = 'empresarial';
          }
        });
      } else {
        setState(() {
          _cargandoUsuario = false;
          _modoPublicacion = 'espontaneo';
        });
      }
    } catch (e) {
      print('❌ Error cargando datos usuario: $e');
      setState(() {
        _cargandoUsuario = false;
        _modoPublicacion = 'espontaneo';
      });
    }
  }

  // ✅ MÉTODO MEJORADO PARA OBTENER NOMBRE DEL VENDEDOR
  String _obtenerNombreVendedor() {
    if (_modoPublicacion != 'empresarial') {
      return 'Vendedor Espontáneo';
    }
    
    if (_userData == null || !_userData!.containsKey('nombreEmpresa')) {
      return 'Mi Empresa';
    }
    
    final nombreEmpresa = _userData!['nombreEmpresa']?.toString();
    return nombreEmpresa != null && nombreEmpresa.isNotEmpty 
        ? nombreEmpresa 
        : 'Mi Empresa';
  }

  // ✅ MÉTODO MEJORADO PARA OBTENER NOMBRE DEL USUARIO
  String _obtenerNombreUsuario() {
    if (_userData == null || !_userData!.containsKey('nombre')) {
      return 'Vendedor Anónimo';
    }
    
    final nombre = _userData!['nombre']?.toString();
    return nombre != null && nombre.isNotEmpty 
        ? nombre 
        : 'Vendedor Anónimo';
  }

  void _mostrarConfirmacionPublicacion() {
    if (!_formKey.currentState!.validate()) {
      _mostrarError('Por favor, corrige los errores en el formulario.', Icons.warning);
      return;
    }
    if (_imagenProducto == null) {
      _mostrarError('Selecciona una imagen del producto.', Icons.photo_library);
      return;
    }
    if (_metodoCobro == null) {
      _mostrarError('Selecciona un método de cobro.', Icons.payment);
      return;
    }
    if ((_metodoCobro == 'qr' || _metodoCobro == 'ambos') && _imagenQR == null) {
      _mostrarError('Para pagos con QR, debes seleccionar una imagen del código QR.', Icons.qr_code);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => FadeTransition(
        opacity: _fadeAnimation,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.cloud_upload, color: AppColors.primario),
              const SizedBox(width: 8),
              const Text('Confirmar publicación'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿Estás seguro de publicar este producto?'),
              const SizedBox(height: 12),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.fondoGris,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nombreController.text,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primario,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Precio: Bs. ${_precioController.text}',
                            style: TextStyle(
                              color: AppColors.acento,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Vendido como: ${_obtenerNombreVendedor()}',
                            style: TextStyle(
                              color: AppColors.textoSecundario,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textoSecundario,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _publicarProducto();
              },
              child: const Text('Confirmar y Publicar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primario,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _publicarProducto() async {
    if (_formKey.currentState!.validate() && _imagenProducto != null && _metodoCobro != null && !_subiendo) {
      setState(() {
        _subiendo = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          _mostrarError('No estás autenticado.', Icons.error);
          return;
        }

        // 1. Subir imagen del producto a Cloudinary
        String? imagenProductoUrl = await _subirImagenACloudinary(_imagenProducto!);

        // 2. Subir imagen QR si existe
        String? imagenQRUrl;
        if ((_metodoCobro == 'qr' || _metodoCobro == 'ambos') && _imagenQR != null) {
          imagenQRUrl = await _subirImagenACloudinary(_imagenQR!);
        }

        if (imagenProductoUrl == null) {
          _mostrarError('Error al subir la imagen del producto.', Icons.cloud_off);
          return;
        }

        // 3. Preparar datos del producto
        Map<String, dynamic> datosProducto = {
          'nombre': _nombreController.text.trim(),
          'precio': double.parse(_precioController.text.trim()),
          'descripcion': _descripcionController.text.trim(),
          'imagenUrl': imagenProductoUrl,
          'vendedorId': user.uid,
          'vendedorName': _obtenerNombreUsuario(),
          'metodoCobro': _metodoCobro,
          'qrUrl': imagenQRUrl,
          'fechaCreacion': FieldValue.serverTimestamp(),
          'tipoVendedor': _modoPublicacion,
          'stock': 1,
        };

        // 4. Añadir datos de empresa si es modo empresarial
        if (_modoPublicacion == 'empresarial') {
          final nombreEmpresa = _obtenerNombreVendedor();
          if (nombreEmpresa != 'Mi Empresa') {
            datosProducto['nombreEmpresa'] = nombreEmpresa;
          }
        }

        // 5. Guardar en Firestore
        await FirebaseFirestore.instance.collection('productos').add(datosProducto);

        if (mounted) {
          _mostrarExito('¡Producto publicado con éxito!');
          Navigator.pop(context);
        }

      } catch (e) {
        print('❌ Error publicando producto: $e');
        _mostrarError('Ocurrió un error: ${e.toString()}', Icons.error);
      } finally {
        if (mounted) {
          setState(() {
            _subiendo = false;
          });
        }
      }
    }
  }

  Future<String?> _subirImagenACloudinary(File imageFile) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final responseJson = json.decode(responseData);
        return responseJson['secure_url'];
      } else {
        print('❌ Error Cloudinary: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error subiendo a Cloudinary: $e');
      return null;
    }
  }

  Future<void> _seleccionarImagen(ImageSource source, {bool esQR = false}) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          if (esQR) {
            _imagenQR = File(pickedFile.path);
          } else {
            _imagenProducto = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      print('❌ Error seleccionando imagen: $e');
      _mostrarError('Error al seleccionar imagen: ${e.toString()}', Icons.error);
    }
  }

  void _mostrarSelectorImagen({bool esQR = false}) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.primario),
                title: const Text('Galería'),
                onTap: () {
                  _seleccionarImagen(ImageSource.gallery, esQR: esQR);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: AppColors.primario),
                title: const Text('Cámara'),
                onTap: () {
                  _seleccionarImagen(ImageSource.camera, esQR: esQR);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarError(String mensaje, IconData icono) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icono, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: AppColors.exito,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildSelectorImagen(File? imagen, String texto, {bool esQR = false, int delay = 0}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: InkWell(
            onTap: () => _mostrarSelectorImagen(esQR: esQR),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.fondoGris,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.textoSecundario.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: imagen != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.file(
                        imagen,
                        fit: esQR ? BoxFit.contain : BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            esQR ? Icons.qr_code_scanner : Icons.add_a_photo,
                            size: 40,
                            color: AppColors.textoSecundario,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            texto,
                            style: TextStyle(color: AppColors.textoSecundario),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeccionTitulo(String titulo, {int delay = 0}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + delay),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(-20 * (1 - value), 0),
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Text(
                titulo,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primario,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? prefixText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    int delay = 0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                prefixText: prefixText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primario, width: 2),
                ),
              ),
              keyboardType: keyboardType,
              maxLines: maxLines,
              validator: validator,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publicar Producto'),
        backgroundColor: AppColors.primario,
        foregroundColor: Colors.white,
      ),
      body: _cargandoUsuario
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: CircularProgressIndicator(
                          color: AppColors.acento,
                          strokeWidth: 3,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'Cargando tu información...',
                      style: TextStyle(
                        color: AppColors.textoSecundario,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- MODO DE PUBLICACIÓN ---
                    if (_userData?['tipo'] == 'dual') ...[
                      _buildSeccionTitulo('Modo de Publicación', delay: 0),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: DropdownButtonFormField<String>(
                                value: _modoPublicacion,
                                decoration: InputDecoration(
                                  labelText: 'Publicar como...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'espontaneo',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person, color: AppColors.textoSecundario),
                                        const SizedBox(width: 8),
                                        const Text('Vendedor Espontáneo'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'empresarial',
                                    child: Row(
                                      children: [
                                        Icon(Icons.business, color: AppColors.primario),
                                        const SizedBox(width: 8),
                                        Text(_obtenerNombreVendedor()),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (valor) {
                                  setState(() {
                                    _modoPublicacion = valor;
                                  });
                                },
                                validator: (value) =>
                                    value == null ? 'Selecciona un modo' : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ],

                    // --- DETALLES DEL PRODUCTO ---
                    _buildSeccionTitulo('Detalles del Producto', delay: 100),
                    
                    _buildTextField(
                      controller: _nombreController,
                      label: 'Nombre del Producto',
                      validator: (value) => value == null || value.isEmpty ? 'Campo requerido' : null,
                      delay: 150,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _precioController,
                      label: 'Precio (Bs.)',
                      prefixText: 'Bs. ',
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Campo requerido';
                        if (double.tryParse(value) == null) return 'Ingresa un número válido';
                        return null;
                      },
                      delay: 200,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _descripcionController,
                      label: 'Descripción',
                      keyboardType: TextInputType.multiline,
                      maxLines: 4,
                      validator: (value) => value == null || value.isEmpty ? 'Campo requerido' : null,
                      delay: 250,
                    ),

                    // --- IMAGEN DEL PRODUCTO ---
                    _buildSeccionTitulo('Imagen del Producto', delay: 300),
                    _buildSelectorImagen(_imagenProducto, 'Toca para subir una foto', delay: 350),

                    // --- MÉTODO DE COBRO ---
                    _buildSeccionTitulo('Método de Cobro', delay: 400),
                    
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 550),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: DropdownButtonFormField<String>(
                              value: _metodoCobro,
                              decoration: InputDecoration(
                                labelText: '¿Cómo prefieres cobrar?',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'efectivo',
                                  child: Row(
                                    children: [
                                      Icon(Icons.money, color: AppColors.exito),
                                      const SizedBox(width: 8),
                                      const Text('Solo Efectivo'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'qr',
                                  child: Row(
                                    children: [
                                      Icon(Icons.qr_code, color: AppColors.primario),
                                      const SizedBox(width: 8),
                                      const Text('Solo QR'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'ambos',
                                  child: Row(
                                    children: [
                                      Icon(Icons.sync_alt, color: Colors.orange),
                                      const SizedBox(width: 8),
                                      const Text('Ambos (Efectivo y QR)'),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (valor) {
                                setState(() {
                                  _metodoCobro = valor;
                                });
                              },
                              validator: (value) =>
                                  value == null ? 'Selecciona un método' : null,
                            ),
                          ),
                        );
                      },
                    ),

                    // --- IMAGEN QR (CONDICIONAL) ---
                    if (_metodoCobro == 'qr' || _metodoCobro == 'ambos') ...[
                      const SizedBox(height: 8),
                      _buildSeccionTitulo('Imagen de tu QR', delay: 450),
                      _buildSelectorImagen(_imagenQR, 'Toca para subir tu QR', esQR: true, delay: 500),
                    ],

                    // --- BOTÓN PUBLICAR ---
                    const SizedBox(height: 32),
                    
                    _subiendo
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            decoration: BoxDecoration(
                              color: AppColors.fondoGris,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                ScaleTransition(
                                  scale: _pulseAnimation,
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: AppColors.primario.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: AppColors.acento,
                                        strokeWidth: 3,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOut,
                                  builder: (context, value, child) {
                                    return Opacity(
                                      opacity: value,
                                      child: Column(
                                        children: [
                                          Text(
                                            'Publicando producto...',
                                            style: TextStyle(
                                              color: AppColors.primario,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'No cierres la aplicación',
                                            style: TextStyle(
                                              color: AppColors.textoSecundario,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          )
                        : TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.elasticOut,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: ElevatedButton.icon(
                                  onPressed: _mostrarConfirmacionPublicacion,
                                  icon: const Icon(Icons.upload, size: 20),
                                  label: const Text(
                                    'Publicar producto',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primario,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
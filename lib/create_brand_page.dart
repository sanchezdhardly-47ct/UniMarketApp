import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CreateBrandPage extends StatefulWidget {
  const CreateBrandPage({super.key});

  @override
  State<CreateBrandPage> createState() => _CreateBrandPageState();
}

class _CreateBrandPageState extends State<CreateBrandPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreEmpresaController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _horarioController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  
  File? _logoImage;
  File? _bannerImage; // 🆕 NUEVO: Banner de la marca
  List<String> _categoriasSeleccionadas = [];
  bool _isLoading = false;
  
  // 🔑 CONFIGURACIÓN CLOUDINARY
  final String _cloudinaryCloudName = 'dg1m1gslr';
  final String _uploadPreset = 'unimarket_ueb';
  
  // Categorías disponibles
  final List<String> _categoriasDisponibles = [
    'Tecnología', 'Ropa', 'Comida', 'Hogar', 'Deportes',
    'Libros', 'Belleza', 'Juguetes', 'Electrodomésticos', 'Otros'
  ];

  // 🆕 MÉTODO PARA SELECCIONAR BANNER
  Future<void> _seleccionarBanner() async {
    try {
      final XFile? imagen = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );
      
      if (imagen != null && mounted) {
        setState(() {
          _bannerImage = File(imagen.path);
        });
      }
    } catch (e) {
      _mostrarError('Error al seleccionar banner: $e');
    }
  }

  Future<void> _seleccionarLogo() async {
    try {
      final XFile? imagen = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
      );
      
      if (imagen != null && mounted) {
        setState(() {
          _logoImage = File(imagen.path);
        });
      }
    } catch (e) {
      _mostrarError('Error al seleccionar logo: $e');
    }
  }

  // 🆕 MÉTODO PARA SUBIR IMAGEN A CLOUDINARY
  Future<String> _subirImagenACloudinary(File imagen) async {
    try {
      var uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload',
      );
      
      var request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imagen.path));

      var response = await request.send().timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Tiempo de espera agotado al subir imagen');
        },
      );

      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);
      
      if (response.statusCode == 200) {
        return jsonResponse['secure_url'];
      } else {
        throw Exception('Error Cloudinary: ${jsonResponse['error']?['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('Error subiendo a Cloudinary: $e');
    }
  }

  Future<void> _crearMarca() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_categoriasSeleccionadas.isEmpty) {
      _mostrarError('Selecciona al menos una categoría');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');
      
      // 🆕 SUBIR LOGO Y BANNER
      String logoUrl = '';
      String bannerUrl = '';
      
      if (_logoImage != null) {
        logoUrl = await _subirImagenACloudinary(_logoImage!);
      }
      
      if (_bannerImage != null) {
        bannerUrl = await _subirImagenACloudinary(_bannerImage!);
      }
      
      // Actualizar usuario a tipo DUAL y agregar datos empresariales
      await _firestore.collection('users').doc(user.uid).update({
        'tipo': 'dual',
        'userType': 'dual',
        'nombreEmpresa': _nombreEmpresaController.text.trim(),
        'descripcionEmpresa': _descripcionController.text.trim(),
        'horarioAtencion': _horarioController.text.trim(),
        'telefonoContacto': _telefonoController.text.trim(),
        'logoUrl': logoUrl,
        'bannerUrl': bannerUrl, // 🆕 NUEVO CAMPO
        'categoriasEmpresa': _categoriasSeleccionadas,
        'verificado': false,
        'fechaCreacionEmpresa': FieldValue.serverTimestamp(),
        'ventasTotales': 0, // 🆕 INICIALIZAR ESTADÍSTICAS
        'productosPublicados': 0,
        'clientesAtendidos': 0,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('¡Marca creada exitosamente!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        Navigator.pop(context); // Volver al perfil
      }
      
    } catch (e) {
      _mostrarError('Error creando marca: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Crear Mi Marca'),
        backgroundColor: Color(0xFF0A2F75),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Crea tu marca empresarial',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A2F75),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Vende productos bajo el nombre de tu empresa/marca personal',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 24),
              
              // 🆕 BANNER DE LA MARCA
              Text(
                'Banner de tu marca (recomendado)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              _bannerImage == null
                  ? Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: OutlinedButton.icon(
                        onPressed: _seleccionarBanner,
                        icon: Icon(Icons.add_photo_alternate),
                        label: Text('Seleccionar Banner'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(0xFF0A2F75),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_bannerImage!, fit: BoxFit.cover),
                          ),
                        ),
                        SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _seleccionarBanner,
                          child: Text('Cambiar Banner'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Color(0xFF0A2F75),
                          ),
                        ),
                      ],
                    ),
              
              SizedBox(height: 20),
              
              // LOGO DE LA MARCA
              Text(
                'Logo de tu marca (opcional)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              _logoImage == null
                  ? OutlinedButton.icon(
                      onPressed: _seleccionarLogo,
                      icon: Icon(Icons.add_photo_alternate),
                      label: Text('Seleccionar Logo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Color(0xFF0A2F75),
                        side: BorderSide(color: Color(0xFF0A2F75)),
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_logoImage!, fit: BoxFit.cover),
                          ),
                        ),
                        SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _seleccionarLogo,
                          child: Text('Cambiar Logo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Color(0xFF0A2F75),
                            side: BorderSide(color: Color(0xFF0A2F75)),
                          ),
                        ),
                      ],
                    ),
              
              SizedBox(height: 24),
              
              // NOMBRE DE LA EMPRESA
              TextFormField(
                controller: _nombreEmpresaController,
                decoration: InputDecoration(
                  labelText: 'Nombre de tu marca/empresa *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business, color: Color(0xFF0A2F75)),
                  hintText: 'Ej: TechStore Bolivia, Moda Joven, etc.',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa el nombre de tu marca';
                  }
                  if (value.length < 3) {
                    return 'El nombre debe tener al menos 3 caracteres';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 16),
              
              // DESCRIPCIÓN
              TextFormField(
                controller: _descripcionController,
                decoration: InputDecoration(
                  labelText: 'Descripción de tu empresa',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description, color: Color(0xFF0A2F75)),
                  hintText: '¿Qué productos vendes? ¿Qué hace especial a tu marca?',
                ),
                maxLines: 3,
              ),
              
              SizedBox(height: 16),
              
              // HORARIO DE ATENCIÓN
              TextFormField(
                controller: _horarioController,
                decoration: InputDecoration(
                  labelText: 'Horario de atención',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.schedule, color: Color(0xFF0A2F75)),
                  hintText: 'Ej: Lunes a Viernes 9:00-18:00, Sábados 10:00-14:00',
                ),
              ),
              
              SizedBox(height: 16),
              
              // TELÉFONO DE CONTACTO
              TextFormField(
                controller: _telefonoController,
                decoration: InputDecoration(
                  labelText: 'Teléfono de contacto',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone, color: Color(0xFF0A2F75)),
                  hintText: 'Ej: +591 12345678',
                ),
                keyboardType: TextInputType.phone,
              ),
              
              SizedBox(height: 24),
              
              // CATEGORÍAS
              Text(
                'Categorías de tus productos *',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Selecciona las categorías que mejor describan tus productos:',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categoriasDisponibles.map((categoria) {
                  final bool seleccionada = _categoriasSeleccionadas.contains(categoria);
                  return FilterChip(
                    label: Text(categoria),
                    selected: seleccionada,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _categoriasSeleccionadas.add(categoria);
                        } else {
                          _categoriasSeleccionadas.remove(categoria);
                        }
                      });
                    },
                    selectedColor: Color(0xFF8CC63F),
                    checkmarkColor: Colors.white,
                    backgroundColor: Colors.grey[100],
                    labelStyle: TextStyle(
                      color: seleccionada ? Colors.white : Colors.black87,
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 8),
              if (_categoriasSeleccionadas.isEmpty)
                Text(
                  'Selecciona al menos una categoría',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              if (_categoriasSeleccionadas.isNotEmpty)
                Text(
                  'Seleccionadas: ${_categoriasSeleccionadas.length} categoría(s)',
                  style: TextStyle(color: Color(0xFF8CC63F), fontSize: 12),
                ),
              
              SizedBox(height: 32),
              
              // INFORMACIÓN ADICIONAL
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF0A2F75), size: 20),
                        SizedBox(width: 8),
                        Text(
                          '¿Qué significa crear una marca?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A2F75),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Tus productos aparecerán bajo el nombre de tu marca\n'
                      '• Los clientes verán tu información empresarial\n'
                      '• Podrás establecer horarios de atención\n'
                      '• Tendrás un perfil más profesional con estadísticas\n'
                      '• Los clientes podrán ver tu página de marca dedicada',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 24),
              
              // BOTÓN CREAR MARCA
              _isLoading
                  ? Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: Color(0xFF8CC63F)),
                          SizedBox(height: 16),
                          Text(
                            'Creando tu marca...',
                            style: TextStyle(
                              color: Color(0xFF0A2F75),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _categoriasSeleccionadas.isEmpty ? null : _crearMarca,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _categoriasSeleccionadas.isEmpty 
                            ? Colors.grey 
                            : Color(0xFF8CC63F),
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Crear Mi Marca',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
              
              SizedBox(height: 16),
              
              // BOTÓN CANCELAR
              if (!_isLoading)
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF0A2F75),
                    side: BorderSide(color: Color(0xFF0A2F75)),
                    minimumSize: Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Cancelar'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nombreEmpresaController.dispose();
    _descripcionController.dispose();
    _horarioController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }
}
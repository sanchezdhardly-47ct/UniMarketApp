import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unimarket/app_colors.dart'; // ✅ IMPORT CENTRALIZADO
import 'create_brand_page.dart';
import 'brand_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  int _productosCount = 0;
  int _chatsCount = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final productosSnapshot = await _firestore
          .collection('productos')
          .where('vendedorId', isEqualTo: currentUser.uid)
          .get();

      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      if (mounted) {
        setState(() {
          _productosCount = productosSnapshot.docs.length;
          _chatsCount = chatsSnapshot.docs.length;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print('❌ Error cargando estadísticas: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _auth.signOut();
      } catch (e) {
        print('❌ Error cerrando sesión: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cerrar sesión: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return _buildUnauthenticatedState();
    }

    return Scaffold(
      appBar: AppBar(
        //title: const Text('Mi Perfil'),
        backgroundColor: AppColors.primario,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _mostrarOpciones(context),
            tooltip: 'Opciones',
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(currentUser.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState('Error al cargar perfil: ${snapshot.error}');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildNoProfileState(currentUser);
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          return _buildProfileContent(userData, currentUser);
        },
      ),
    );
  }

  Widget _buildUnauthenticatedState() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Usuario no autenticado',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Inicia sesión para ver tu perfil',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primario,
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando perfil...',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoProfileState(User currentUser) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_add,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Perfil no encontrado',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Completa tu información de perfil',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _crearPerfilAutomatico,
            child: const Text('Crear Perfil'),
          ),
        ],
      ),
    );
  }

  Future<void> _crearPerfilAutomatico() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore.collection('users').doc(currentUser.uid).set({
        'nombre': currentUser.displayName ?? currentUser.email?.split('@').first ?? 'Usuario',
        'email': currentUser.email ?? '',
        'fechaCreacion': FieldValue.serverTimestamp(),
        'tipo': 'espontaneo',
        'fotoUrl': currentUser.photoURL ?? '',
        'perfilCompletado': false,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Perfil creado correctamente'),
            backgroundColor: AppColors.exito,
          ),
        );
      }
    } catch (e) {
      print('❌ Error creando perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creando perfil: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildProfileContent(Map<String, dynamic> userData, User currentUser) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar/ Foto de perfil
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: AppColors.primario,
                child: userData['fotoUrl']?.isNotEmpty == true
                    ? CircleAvatar(
                        radius: 58,
                        backgroundImage: NetworkImage(userData['fotoUrl']),
                      )
                    : Text(
                        _getInitials(userData['nombre']),
                        style: const TextStyle(
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primario),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    size: 16,
                    color: AppColors.primario,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Nombre
          Text(
            userData['nombre'],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          
          // Email
          Text(
            userData['email'],
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          
          // BADGE DE TIPO DE USUARIO
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getUserTypeColor(userData['tipo']),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getUserTypeIcon(userData['tipo']), size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  _getUserTypeText(userData['tipo']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          
          // Estado de verificación
          if (userData['perfilCompletado'] == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.acento.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.acento),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, size: 14, color: AppColors.acento),
                  const SizedBox(width: 4),
                  Text(
                    'Perfil completado',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.acento,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),

          // BOTÓN "CREAR MARCA" (solo para espontáneos)
          if (userData['tipo'] == 'espontaneo')
            Container(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CreateBrandPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.acento,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                icon: Icon(Icons.add_business),
                label: Text('Crear Mi Marca Empresarial'),
              ),
            ),

          // INFORMACIÓN EMPRESARIAL (solo para dual/empresarial)
          if (userData['tipo'] == 'dual' || userData['tipo'] == 'empresarial')
            Column(
              children: [
                _buildEmpresaInfo(userData),
                SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BrandProfilePage(userId: currentUser.uid),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primario,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: Icon(Icons.business_center),
                    label: Text('Ver Mi Marca'),
                  ),
                ),
              ],
            ),
          
          const SizedBox(height: 24),
          
          // Estadísticas
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Mis Estadísticas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primario,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _isLoadingStats
                      ? CircularProgressIndicator(color: AppColors.primario)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Productos', _productosCount.toString()),
                            _buildStatItem('Chats', _chatsCount.toString()),
                            _buildStatItem('Activo', _getActiveStatus(userData)),
                          ],
                        ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Acciones rápidas
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Acciones Rápidas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primario,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: Icon(Icons.add, size: 16, color: AppColors.primario),
                        label: const Text('Nuevo Producto'),
                        onPressed: () => _navegarAPublicar(),
                      ),
                      ActionChip(
                        avatar: Icon(Icons.chat, size: 16, color: AppColors.primario),
                        label: const Text('Mis Mensajes'),
                        onPressed: () => _navegarAMensajes(),
                      ),
                      ActionChip(
                        avatar: Icon(Icons.edit, size: 16, color: AppColors.primario),
                        label: const Text('Editar Perfil'),
                        onPressed: _editarPerfil,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Botón cerrar sesión
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _cerrarSesion(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar Sesión'),
            ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Color _getUserTypeColor(String tipo) {
    switch (tipo) {
      case 'espontaneo': return AppColors.primario;
      case 'empresarial': return AppColors.acento;
      case 'dual': return AppColors.acento;
      default: return Colors.grey;
    }
  }

  IconData _getUserTypeIcon(String tipo) {
    switch (tipo) {
      case 'espontaneo': return Icons.person;
      case 'empresarial': return Icons.business_center;
      case 'dual': return Icons.switch_account;
      default: return Icons.person;
    }
  }

  String _getUserTypeText(String tipo) {
    switch (tipo) {
      case 'espontaneo': return 'Vendedor Espontáneo';
      case 'empresarial': return 'Vendedor Empresarial';
      case 'dual': return 'Vendedor Dual';
      default: return 'Usuario';
    }
  }

  Widget _buildEmpresaInfo(Map<String, dynamic> userData) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: AppColors.acento),
                SizedBox(width: 8),
                Text(
                  'Mi Marca',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.acento,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (userData['nombreEmpresa'] != null)
              _buildEmpresaItem('Empresa', userData['nombreEmpresa']!),
            if (userData['descripcionEmpresa']?.isNotEmpty == true)
              _buildEmpresaItem('Descripción', userData['descripcionEmpresa']!),
            if (userData['horarioAtencion']?.isNotEmpty == true)
              _buildEmpresaItem('Horario', userData['horarioAtencion']!),
            if (userData['telefonoContacto']?.isNotEmpty == true)
              _buildEmpresaItem('Teléfono', userData['telefonoContacto']!),
            if (userData['categoriasEmpresa'] is List && (userData['categoriasEmpresa'] as List).isNotEmpty)
              _buildEmpresaItem('Categorías', (userData['categoriasEmpresa'] as List).join(', ')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpresaItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _getInitials(String nombre) {
    final parts = nombre.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (nombre.isNotEmpty) {
      return nombre.substring(0, 1).toUpperCase();
    }
    return 'U';
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primario,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _getActiveStatus(Map<String, dynamic> userData) {
    final fechaCreacion = userData['fechaCreacion']?.toDate();
    if (fechaCreacion != null) {
      final diferencia = DateTime.now().difference(fechaCreacion);
      if (diferencia.inDays < 7) return 'Nuevo';
      if (diferencia.inDays < 30) return 'Activo';
    }
    return 'Experto';
  }

  void _navegarAPublicar() {
    // Navegar a página de publicar
  }

  void _navegarAMensajes() {
    // Navegar a página de mensajes
  }

  void _editarPerfil() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Edición de perfil - Próximamente'),
        ),
      );
    }
  }

  void _mostrarOpciones(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Ayuda y Soporte'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacidad'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Acerca de'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancelar'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
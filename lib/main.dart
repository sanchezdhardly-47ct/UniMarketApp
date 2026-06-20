import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'auth_gate.dart';
import 'app_colors.dart';
import 'app_theme.dart'; // ✅ Importa el nuevo archivo de tema

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // ✅ INICIALIZACIÓN SEGURA DE FIREBASE
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase inicializado correctamente');
    
    // ✅ EJECUTAR SCRIPTS DE REPARACIÓN CON MANEJO DE ERRORES
    await _ejecutarScriptsIniciales();
    
    runApp(const MyApp());
    
  } catch (e) {
    // ✅ MANEJO DE ERRORES CRÍTICOS DURANTE INICIALIZACIÓN
    print('❌ Error crítico durante inicialización: $e');
    runApp(const ErrorApp());
  }
}

// 👇 MÉTODO SEGURO PARA EJECUTAR SCRIPTS INICIALES
Future<void> _ejecutarScriptsIniciales() async {
  try {
    print('🔄 Ejecutando scripts iniciales...');
    
    // Ejecutar scripts en secuencia con manejo individual de errores
    await _crearPerfilesParaUsuariosExistentes();
    await _repararProductosExistentes();
    
    print('✅ Scripts iniciales ejecutados correctamente');
  } catch (e) {
    print('⚠️ Advertencia en scripts iniciales: $e');
    // No relanzar el error - son scripts no críticos
  }
}

// 👇 MÉTODO MEJORADO PARA CREAR PERFILES
Future<void> _crearPerfilesParaUsuariosExistentes() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'nombre': user.displayName ?? user.email?.split('@').first ?? 'Usuario',
          'email': user.email ?? '',
          'fechaCreacion': FieldValue.serverTimestamp(),
          'tipo': 'estudiante',
          'fotoUrl': user.photoURL ?? '',
          'perfilCompletado': false,
        }, SetOptions(merge: true));
        
        print('✅ Perfil creado para usuario existente: ${user.email}');
      } else {
        print('ℹ️ Usuario ya tiene perfil: ${user.email}');
      }
    } else {
      print('ℹ️ No hay usuario autenticado al iniciar');
    }
  } catch (e) {
    print('❌ Error creando perfil para usuario existente: $e');
    // No relanzar - es opcional
  }
}

// 👇 SCRIPT TEMPORAL MEJORADO PARA REPARAR PRODUCTOS
Future<void> _repararProductosExistentes() async {
  try {
    print('🔄 Iniciando reparación de productos existentes...');
    
    final productosSnapshot = await FirebaseFirestore.instance
        .collection('productos')
        .limit(50) // ✅ LIMITAR PARA NO SOBRECARGAR
        .get();
    
    print('📦 Encontrados ${productosSnapshot.docs.length} productos para verificar');
    
    int productosReparados = 0;
    int productosConProblemas = 0;
    
    for (final doc in productosSnapshot.docs) {
      try {
        final producto = doc.data();
        final vendedorId = producto['vendedorId'];
        
        if (vendedorId != null && vendedorId is String) {
          // Verificar si el vendedor tiene perfil
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(vendedorId)
              .get();
          
          // Si no tiene perfil, crearlo
          if (!userDoc.exists) {
            await FirebaseFirestore.instance.collection('users').doc(vendedorId).set({
              'nombre': 'Vendedor${vendedorId.substring(0, 6)}',
              'email': 'vendedor@unimarket.com',
              'fechaCreacion': FieldValue.serverTimestamp(),
              'tipo': 'estudiante',
              'fotoUrl': '',
              'reparado': true,
              'perfilCompletado': false,
            }, SetOptions(merge: true));
            
            productosReparados++;
            print('✅ Perfil reparado para vendedor: $vendedorId');
          }
        } else {
          productosConProblemas++;
          print('⚠️ Producto ${doc.id} tiene vendedorId inválido: $vendedorId');
        }
      } catch (e) {
        productosConProblemas++;
        print('❌ Error procesando producto ${doc.id}: $e');
      }
    }
    
    print('🎉 REPARACIÓN COMPLETADA:');
    print('   ✅ $productosReparados perfiles creados');
    print('   ⚠️ $productosConProblemas productos con problemas');
    
  } catch (e) {
    print('❌ Error en reparación de productos: $e');
    // No relanzar - es script temporal
  }
}

// 👇 APP DE FALLBACK PARA ERRORES CRÍTICOS
class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red[50],
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                SizedBox(height: 24),
                Text(
                  'Error de Inicialización',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Lo sentimos, hubo un problema al iniciar la aplicación.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Por favor, cierra la app y vuelve a intentarlo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    // Intentar reiniciar la app
                    runApp(const MyApp());
                  },
                  icon: Icon(Icons.refresh),
                  label: Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unimarket UEB',
      debugShowCheckedModeBanner: false,
      
      // ✅ REEMPLAZA COMPLETAMENTE CON EL NUEVO TEMA
      theme: AppTheme.lightTheme,
      
      home: const AuthGate(),
    );
  }
}

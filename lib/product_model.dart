import 'package:cloud_firestore/cloud_firestore.dart';

class Producto {
  final String id; // ID del documento en Firestore
  final String nombre;
  final double precio;
  final String descripcion;
  final String imagenUrl;
  final String vendedorId;
  final String metodoCobro; // 'efectivo', 'qr', 'ambos'
  final String? qrUrl; // Puede ser null
  final DateTime fechaCreacion;

  // 🆕 NUEVOS CAMPOS PARA SISTEMA DE TIPOS
  final String tipoVendedor; // 'espontaneo', 'empresarial', 'dual'
  final String? nombreEmpresa; // Solo para empresarial/dual
  final String vendedorName; // Nombre del vendedor
  final int stock; // Para sistema de comisiones y LAC

  Producto({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.descripcion,
    required this.imagenUrl,
    required this.vendedorId,
    required this.metodoCobro,
    this.qrUrl,
    required this.fechaCreacion,
    // 🆕 Inicializar nuevos campos
    required this.tipoVendedor,
    this.nombreEmpresa,
    required this.vendedorName,
    this.stock = 1, // Default 1 para productos espontáneos
  });

  // Factory method para crear un Producto desde un documento de Firestore
  factory Producto.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // ==================  👇👇 SOLUCIÓN DEFINITIVA 👇👇 ==================
    //
    // Usamos la función auxiliar para convertir la fecha de forma segura.
    // No importa si es un String o un Timestamp, esto lo manejará.
    //
    DateTime fechaCreacion = _convertirFecha(data['fechaCreacion']);
    //
    // ==================  👆👆 FIN DE LA SOLUCIÓN 👆👆 ==================
    
    return Producto(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      precio: (data['precio'] ?? 0.0).toDouble(),
      descripcion: data['descripcion'] ?? '',
      imagenUrl: data['imagenUrl'] ?? '',
      vendedorId: data['vendedorId'] ?? '',
      metodoCobro: data['metodoCobro'] ?? 'efectivo',
      qrUrl: data['qrUrl'],
      fechaCreacion: fechaCreacion, // Usamos la fecha ya convertida
      // 🆕 Nuevos campos con valores por defecto
      tipoVendedor: data['tipoVendedor'] ?? 'espontaneo',
      nombreEmpresa: data['nombreEmpresa'],
      vendedorName: data['vendedorName'] ?? 'Vendedor',
      stock: (data['stock'] ?? 1).toInt(),
    );
  }

  // Método para convertir a Map (útil si luego quieres actualizar)
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'precio': precio,
      'descripcion': descripcion,
      'imagenUrl': imagenUrl,
      'vendedorId': vendedorId,
      'metodoCobro': metodoCobro,
      'qrUrl': qrUrl,
      // Al guardar, usamos Timestamp (Opción A, que ya debes tener)
      'fechaCreacion': Timestamp.fromDate(fechaCreacion), 
      'tipoVendedor': tipoVendedor,
      'nombreEmpresa': nombreEmpresa,
      'vendedorName': vendedorName,
      'stock': stock,
    };
  }

  // ==================  👇👇 FUNCIÓN AUXILIAR NUEVA 👇👇 ==================
  /// Convierte un valor dinámico de Firestore (String o Timestamp) a DateTime.
  static DateTime _convertirFecha(dynamic data) {
    if (data == null) {
      return DateTime.now(); // Valor por defecto si es nulo
    }
    
    // CASO 1: El dato ya es un Timestamp (¡Correcto!)
    if (data is Timestamp) {
      return data.toDate();
    }
    
    // CASO 2: El dato es un String (El dato antiguo que da error)
    if (data is String) {
      try {
        // Intenta convertir el String a DateTime
        return DateTime.parse(data); 
      } catch (e) {
        // Si el String tiene un formato raro y no se puede convertir
        print('Error al parsear fecha String: $e');
        return DateTime.now(); // Devuelve fecha actual como último recurso
      }
    }
    
    // Si es cualquier otra cosa (un número, etc.)
    return DateTime.now();
  }
  // ==================  👆👆 FIN DE FUNCIÓN AUXILIAR 👆👆 ==================

}

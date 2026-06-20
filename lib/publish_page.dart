import 'package:flutter/material.dart';
import 'package:unimarket/app_colors.dart'; // ✅ IMPORT AÑADIDO
// 👇 Asegúrate de que la ruta coincida con la ubicación real de tu archivo
import 'add_product_page.dart'; // ✅ este archivo contiene la clase PublicarProductoPage

class PublishPage extends StatelessWidget {
  const PublishPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ÍCONO GRANDE
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.secundario.withOpacity(0.1), // ✅ FONDO VERDE LIMA CLARO
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                size: 60,
                color: AppColors.secundario, // ✅ VERDE LIMA
              ),
            ),
            const SizedBox(height: 24),
            
            // TEXTO DESCRIPTIVO
            Text(
              'Comparte tus productos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textoPrincipal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Llega a más compradores de tu universidad',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textoSecundario,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // 🟢 BOTÓN VERDE LIMA
            ElevatedButton.icon(
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "Crear nueva publicación",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secundario, // ✅ VERDE LIMA
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                shadowColor: AppColors.secundario.withOpacity(0.3),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  // ✅ usa el nombre real de la clase:
                  MaterialPageRoute(builder: (_) => const PublicarProductoPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
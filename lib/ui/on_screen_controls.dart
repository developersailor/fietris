import 'package:flutter/material.dart';
import '../game/fietris_game.dart'; // FietrisGame'e erişim için

class OnScreenControlsWidget extends StatelessWidget {
  final FietrisGame game; // Oyuna referans

  const OnScreenControlsWidget({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    // SafeArea kullanarak sistem çubuklarından kaçın
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Kenarlardan boşluk
        child: Stack(
          // Butonları serbestçe konumlandırmak için Stack
          children: [
            // Sol/Sağ Butonlar (Sol Alt Köşe)
            Align(
              alignment: Alignment.bottomLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ControlButton(
                      icon: Icons.arrow_left, onPressed: game.moveBlockLeft),
                  const SizedBox(width: 20), // Butonlar arası boşluk
                  ControlButton(
                      icon: Icons.arrow_right, onPressed: game.moveBlockRight),
                ],
              ),
            ),

            // Döndürme/Düşürme Butonları (Sağ Alt Köşe)
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ControlButton(
                      icon: Icons.rotate_right, onPressed: game.rotateBlock),
                  const SizedBox(width: 20),
                  ControlButton(
                      icon: Icons.arrow_downward,
                      onPressed: game.softDropBlock),
                  const SizedBox(width: 20),
                  ControlButton(
                      icon: Icons.vertical_align_bottom,
                      onPressed: game.performHardDrop)
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Tekrar kullanılabilir buton widget'ı
class ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const ControlButton({super.key, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.7,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 30.0),
          ),
        ),
      ),
    );
  }
}

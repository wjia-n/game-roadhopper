import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const RoadHopperApp());

class RoadHopperApp extends StatelessWidget {
  const RoadHopperApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.graffitiWall,
      title: 'Road Hopper',
      tagline: 'Hop across roads and rivers without getting squashed',
      emoji: '🐸',
      slug: 'roadhopper',
      howToPlay: '• Swipe (or tap) to hop up, down, left, right\n'
          '• Dodge the cars — they do not brake for frogs\n'
          '• Ride logs and turtles across the river\n'
          '• Fill all 5 home slots to level up. Beat the clock!',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) =>
          RoadHopperScreen(players: players, callbacks: cb),
    );
  }
}

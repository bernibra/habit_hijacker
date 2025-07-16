import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const HabitHijackerApp());
}

class HabitHijackerApp extends StatelessWidget {
  const HabitHijackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Hijacker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LandingPage(),
    );
  }
}

// Define a Trigger class to hold text and type
class Trigger {
  final String text;
  final bool isPositive; // true = positive, false = negative
  Trigger({required this.text, required this.isPositive});
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  // List of triggers, with a default negative item
  final List<Trigger> _triggers = [
    Trigger(text: 'are you drinking?', isPositive: false),
  ];

  // Add a new trigger to the list
  void _addTrigger(String triggerText, bool isPositive) {
    setState(() {
      _triggers.add(Trigger(text: triggerText, isPositive: isPositive));
    });
  }

  // Show dialog to input new trigger and select type
  void _showAddTriggerDialog() {
    String newTrigger = '';
    bool isPositive = false; // default to negative
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Trigger'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Enter trigger'),
                onChanged: (value) {
                  newTrigger = value;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Type:', style: TextStyle(fontFamily: 'monospace')),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Negative', style: TextStyle(fontFamily: 'monospace')),
                    selected: !isPositive,
                    onSelected: (selected) {
                      isPositive = false;
                      (context as Element).markNeedsBuild();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Positive', style: TextStyle(fontFamily: 'monospace')),
                    selected: isPositive,
                    onSelected: (selected) {
                      isPositive = true;
                      (context as Element).markNeedsBuild();
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (newTrigger.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                  _addTrigger(newTrigger.trim(), isPositive);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Show celebratory feedback: confetti, buzz, sound
  void _showCelebration() async {
    _confettiController.play();
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 300);
    }
    // Play a default short sound (using built-in asset)
    await _audioPlayer.play(AssetSource('assets/success.mp3'));
  }

  // Show sober message
  void _showSoberMessage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("it's ok, you'll manage next time", style: TextStyle(fontFamily: monoFont)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(fontFamily: monoFont)),
          ),
        ],
      ),
    );
  }

  // Handle trigger action logic
  void _handleTriggerAction(Trigger trigger, bool averted) {
    // averted: true if user clicked 'averted', false if 'indulged'
    final isPositive = trigger.isPositive;
    if ((averted && !isPositive) || (!averted && isPositive)) {
      // Success: averted negative or indulged positive
      _showCelebration();
    } else {
      // Sober message: indulged negative or averted positive
      _showSoberMessage();
    }
  }

  // Show dialog for trigger action (averted/indulged)
  void _showTriggerActionDialog(Trigger trigger) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: Colors.white,
          title: Text(
            trigger.text,
            style: const TextStyle(fontFamily: monoFont, fontWeight: FontWeight.bold, fontSize: 18),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _handleTriggerAction(trigger, true); // averted
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('averted', style: TextStyle(fontFamily: monoFont, fontSize: 15)),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _handleTriggerAction(trigger, false); // indulged
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: negativeColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('indulged', style: TextStyle(fontFamily: monoFont, fontSize: 15)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Modern color palette
  static const Color negativeColor = Color(0xFFEF476F); // Vibrant pink-red
  static const Color positiveColor = Color(0xFF118AB2); // Modern blue
  static const Color backgroundColor = Color(0xFFF8F9FA); // Light background
  static const Color accentColor = Color(0xFF06D6A0); // Mint green
  static const String monoFont = 'monospace'; // Use system monospace

  // Get color based on trigger type
  Color _triggerColor(bool isPositive) {
    return isPositive ? positiveColor : negativeColor;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: const Text('your triggers', style: TextStyle(fontFamily: monoFont, fontWeight: FontWeight.bold, fontSize: 22)),
            backgroundColor: Colors.white,
            elevation: 2,
            foregroundColor: positiveColor,
            centerTitle: true,
          ),
          body: ListView.builder(
            itemCount: _triggers.length,
            itemBuilder: (context, index) {
              final trigger = _triggers[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _triggerColor(trigger.isPositive),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: Colors.black26,
                  ),
                  onPressed: () {
                    _showTriggerActionDialog(trigger);
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      trigger.text,
                      style: const TextStyle(fontFamily: monoFont, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showAddTriggerDialog,
            backgroundColor: accentColor,
            child: const Icon(Icons.add, color: Colors.white),
            tooltip: 'Add Trigger',
            elevation: 4,
          ),
        ),
        // Confetti widget overlay
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [accentColor, positiveColor, negativeColor, Colors.amber],
            numberOfParticles: 30,
            maxBlastForce: 20,
            minBlastForce: 8,
            emissionFrequency: 0.1,
            gravity: 0.3,
          ),
        ),
      ],
    );
  }
}

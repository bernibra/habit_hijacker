import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

// --- Custom Colors from CSS ---
const Color cssBackground = Color(0xFF3D405B); // #3D405B
const Color cssText = Color(0xFFF4F1DE);      // #F4F1DE
const Color cssAccent = Color(0xFFF4BA02);    // #F4BA02
const Color cssSecondary = Color(0xFF494C64); // #494C64
const Color cssShadow = Color(0x26F4BA02);    // #F4BA02, 15% opacity
const String cssMonoFont = 'monospace';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(TriggerResponseAdapter());
  await Hive.openBox<TriggerResponse>('responses');
  runApp(const HabitHijackerApp());
}

class HabitHijackerApp extends StatelessWidget {
  const HabitHijackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Hijacker',
      theme: ThemeData(
        scaffoldBackgroundColor: cssBackground,
        primaryColor: cssAccent,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: cssAccent,
          secondary: cssSecondary,
          background: cssBackground,
        ),
        fontFamily: cssMonoFont,
        textTheme: TextTheme(
          bodyLarge: TextStyle(fontFamily: cssMonoFont, color: cssText, fontSize: 16),
          bodyMedium: TextStyle(fontFamily: cssMonoFont, color: cssText, fontSize: 14),
          titleLarge: TextStyle(fontFamily: cssMonoFont, color: cssText, fontWeight: FontWeight.bold, fontSize: 22),
          titleMedium: TextStyle(fontFamily: cssMonoFont, color: cssText, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: cssBackground,
          foregroundColor: cssText,
          elevation: 2,
          centerTitle: true,
          titleTextStyle: TextStyle(fontFamily: cssMonoFont, color: cssText, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        dialogBackgroundColor: cssSecondary,
        dialogTheme: DialogThemeData(
          backgroundColor: cssSecondary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          titleTextStyle: TextStyle(fontFamily: cssMonoFont, color: cssAccent, fontWeight: FontWeight.bold, fontSize: 18),
          contentTextStyle: TextStyle(fontFamily: cssMonoFont, color: cssText, fontSize: 15),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
              if (states.contains(MaterialState.pressed) || states.contains(MaterialState.hovered)) {
                return cssAccent;
              }
              return cssText;
            }),
            foregroundColor: MaterialStateProperty.all<Color>(cssBackground),
            overlayColor: MaterialStateProperty.all<Color>(cssShadow),
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            elevation: MaterialStateProperty.all<double>(4),
            shadowColor: MaterialStateProperty.all<Color>(cssShadow),
            textStyle: MaterialStateProperty.all<TextStyle>(
              TextStyle(fontFamily: cssMonoFont, fontWeight: FontWeight.w600, fontSize: 15),
            ),
            padding: MaterialStateProperty.all<EdgeInsets>(
              const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            ),
          ),
        ),
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

// Model for storing responses
@HiveType(typeId: 0)
class TriggerResponse extends HiveObject {
  @HiveField(0)
  final String triggerText;
  @HiveField(1)
  final bool isPositive;
  @HiveField(2)
  final bool averted;
  @HiveField(3)
  final DateTime timestamp;
  TriggerResponse({required this.triggerText, required this.isPositive, required this.averted, required this.timestamp});
}
class TriggerResponseAdapter extends TypeAdapter<TriggerResponse> {
  @override
  final int typeId = 0;
  @override
  TriggerResponse read(BinaryReader reader) {
    return TriggerResponse(
      triggerText: reader.readString(),
      isPositive: reader.readBool(),
      averted: reader.readBool(),
      timestamp: DateTime.parse(reader.readString()),
    );
  }
  @override
  void write(BinaryWriter writer, TriggerResponse obj) {
    writer.writeString(obj.triggerText);
    writer.writeBool(obj.isPositive);
    writer.writeBool(obj.averted);
    writer.writeString(obj.timestamp.toIso8601String());
  }
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
          title: Text('Add Trigger', style: TextStyle(fontFamily: cssMonoFont, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                autofocus: true,
                style: TextStyle(fontFamily: cssMonoFont, fontSize: 14),
                decoration: InputDecoration(hintText: 'Enter trigger', contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10)),
                onChanged: (value) {
                  newTrigger = value;
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ChoiceChip(
                    label: Text('Negative', style: TextStyle(fontFamily: cssMonoFont, fontSize: 13)),
                    selected: !isPositive,
                    onSelected: (selected) {
                      isPositive = false;
                      (context as Element).markNeedsBuild();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Positive', style: TextStyle(fontFamily: cssMonoFont, fontSize: 13)),
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
              child: Text('Cancel', style: TextStyle(fontFamily: cssMonoFont, fontSize: 13)),
            ),
            TextButton(
              onPressed: () {
                if (newTrigger.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                  _addTrigger(newTrigger.trim(), isPositive);
                }
              },
              child: Text('Add', style: TextStyle(fontFamily: cssMonoFont, fontSize: 13)),
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
        backgroundColor: cssSecondary,
        title: Text("it's ok, you'll manage next time", style: TextStyle(fontFamily: cssMonoFont, color: cssAccent)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: TextStyle(fontFamily: cssMonoFont, color: cssAccent)),
          ),
        ],
      ),
    );
  }

  // Handle trigger action logic
  void _handleTriggerAction(Trigger trigger, bool averted) async {
    // averted: true if user clicked 'averted', false if 'indulged'
    final isPositive = trigger.isPositive;
    final isCelebration = (averted && !isPositive) || (!averted && isPositive);
    // Store response
    final box = Hive.box<TriggerResponse>('responses');
    await box.add(TriggerResponse(
      triggerText: trigger.text,
      isPositive: trigger.isPositive,
      averted: averted,
      timestamp: DateTime.now(),
    ));
    // Navigate to result page
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ResultPage(
          trigger: trigger,
          averted: averted,
          isCelebration: isCelebration,
        ),
      ),
    );
  }

  // Show dialog for trigger action (averted/indulged)
  void _showTriggerActionDialog(Trigger trigger) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: cssSecondary,
          title: Text(
            trigger.text,
            style: TextStyle(fontFamily: cssMonoFont, color: cssAccent, fontWeight: FontWeight.bold, fontSize: 18),
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
                    backgroundColor: cssAccent,
                    foregroundColor: cssBackground,
                    minimumSize: const Size.fromHeight(36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: cssAccent, width: 2),
                    elevation: 4,
                    shadowColor: cssShadow,
                  ),
                  child: Text('averted', style: TextStyle(fontFamily: cssMonoFont, fontSize: 15)),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _handleTriggerAction(trigger, false); // indulged
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cssSecondary,
                    foregroundColor: cssText,
                    minimumSize: const Size.fromHeight(36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: cssText, width: 2),
                    elevation: 4,
                    shadowColor: cssShadow,
                  ),
                  child: Text('indulged', style: TextStyle(fontFamily: cssMonoFont, fontSize: 15)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Show modal with info, delete info, and delete trigger options
  void _showTriggerOptions(Trigger trigger, int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      backgroundColor: cssSecondary,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Info
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: cssAccent, size: 32),
                    onPressed: () {
                      Navigator.of(context).pop();
                      // TODO: Show info about this trigger
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Info for "${trigger.text}" coming soon!', style: TextStyle(fontFamily: cssMonoFont))),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text('Info', style: TextStyle(fontFamily: cssMonoFont, color: cssAccent, fontSize: 12)),
                ],
              ),
              // Delete info
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.cleaning_services_outlined, color: cssAccent, size: 32),
                    onPressed: () {
                      Navigator.of(context).pop();
                      // TODO: Delete info for this trigger
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Delete info for "${trigger.text}" coming soon!', style: TextStyle(fontFamily: cssMonoFont))),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text('Delete Info', style: TextStyle(fontFamily: cssMonoFont, color: cssAccent, fontSize: 12)),
                ],
              ),
              // Delete trigger
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 32),
                    onPressed: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _triggers.removeAt(index);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Trigger deleted.', style: TextStyle(fontFamily: cssMonoFont))),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text('Delete', style: TextStyle(fontFamily: cssMonoFont, color: Colors.redAccent, fontSize: 12)),
                ],
              ),
            ],
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
          backgroundColor: cssBackground,
          appBar: AppBar(
            title: Text('your triggers', style: TextStyle(fontFamily: cssMonoFont, fontSize: 18)),
            backgroundColor: cssBackground,
            elevation: 2,
            foregroundColor: cssText,
            centerTitle: true,
          ),
          body: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            itemCount: _triggers.length,
            itemBuilder: (context, index) {
              final trigger = _triggers[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: trigger.isPositive ? cssAccent : cssSecondary,
                    foregroundColor: trigger.isPositive ? cssBackground : cssText,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: cssShadow,
                    side: BorderSide(color: trigger.isPositive ? cssAccent : cssText, width: 2),
                  ),
                  onPressed: () {
                    _showTriggerActionDialog(trigger);
                  },
                  onLongPress: () {
                    _showTriggerOptions(trigger, index);
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      trigger.text,
                      style: TextStyle(fontFamily: cssMonoFont, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5),
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
            backgroundColor: cssAccent,
            child: Icon(Icons.add, color: cssBackground, size: 22),
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
            colors: [cssAccent, cssSecondary, cssText, Colors.amber],
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

class ResultPage extends StatelessWidget {
  final Trigger trigger;
  final bool averted; // true if averted, false if indulged
  final bool isCelebration; // true for confetti, false for sober message
  const ResultPage({super.key, required this.trigger, required this.averted, required this.isCelebration});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cssBackground,
      appBar: AppBar(
        title: Text('Result', style: TextStyle(fontFamily: cssMonoFont, fontSize: 18)),
        backgroundColor: cssBackground,
        elevation: 2,
        foregroundColor: cssText,
        centerTitle: true,
      ),
      body: Center(
        child: isCelebration
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 180,
                    child: ConfettiWidget(
                      confettiController: ConfettiController(duration: const Duration(seconds: 2))..play(),
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      colors: [cssAccent, cssSecondary, cssText, Colors.amber],
                      numberOfParticles: 30,
                      maxBlastForce: 20,
                      minBlastForce: 8,
                      emissionFrequency: 0.1,
                      gravity: 0.3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('🎉 Great job!', style: TextStyle(fontFamily: cssMonoFont, fontSize: 20, color: cssAccent)),
                  const SizedBox(height: 8),
                  Text(averted ? 'You averted a negative trigger.' : 'You indulged a positive trigger.', style: TextStyle(fontFamily: cssMonoFont, fontSize: 15, color: cssText)),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: cssAccent, size: 48),
                  const SizedBox(height: 24),
                  Text("it's ok, you'll manage next time", style: TextStyle(fontFamily: cssMonoFont, fontSize: 18, color: cssAccent)),
                  const SizedBox(height: 8),
                  Text(averted ? 'You averted a positive trigger.' : 'You indulged a negative trigger.', style: TextStyle(fontFamily: cssMonoFont, fontSize: 15, color: cssText)),
                ],
              ),
      ),
    );
  }
}

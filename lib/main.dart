import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart';

// --- Custom Colors from CSS ---
// These colors are used throughout the app for consistent theming.
const Color cssBackground = Color(0xFF3D405B); // #3D405B
const Color cssText = Color(0xFFF4F1DE);      // #F4F1DE
const Color cssAccent = Color(0xFFF4BA02);    // #F4BA02
const Color cssSecondary = Color(0xFF494C64); // #494C64
const Color cssShadow = Color(0x26F4BA02);    // #F4BA02, 15% opacity
const String cssMonoFont = 'monospace';

// --- New Color Palette ---
// Used for feedback and charting
const Color superPositiveColor = Color(0xFF66BD63);   // #66bd63
const Color positiveColor      = Color(0xFFDAE8C8);   // #DAE8C8
const Color neutralColor       = Color(0xFFF4F1DE);   // #F4F1DE
const Color negativeColor      = Color(0xFFF4D9C2);   // #F4D9C2
const Color superNegativeColor = Color(0xFFF46D43);   // #f46d43

// Entry point of the app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(TriggerResponseAdapter());
  // await Hive.deleteBoxFromDisk('responses'); // Removed after migration
  await Hive.openBox<TriggerResponse>('responses');
  runApp(const HabitHijackerApp());
}

// Main app widget, sets up theme and home page
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

// Represents a user-defined trigger for a habit (e.g. "Are you drinking?")
class Trigger {
  final String id; // Unique identifier for this trigger
  final String text; // The trigger text/question
  final bool isPositive; // true = positive habit, false = negative habit
  final String habit; // The habit this trigger is associated with
  Trigger({required this.id, required this.text, required this.isPositive, required this.habit});
}

// Hive model for storing user responses to triggers
@HiveType(typeId: 0)
class TriggerResponse extends HiveObject {
  @HiveField(0)
  final String triggerId; // The id of the trigger this response is for
  @HiveField(1)
  final String triggerText; // The text of the trigger (for display)
  @HiveField(2)
  final bool isPositive; // Whether the trigger is positive or negative
  @HiveField(3)
  final bool averted; // true if user averted the trigger, false if indulged
  @HiveField(4)
  final DateTime timestamp; // When the response was recorded
  TriggerResponse({required this.triggerId, required this.triggerText, required this.isPositive, required this.averted, required this.timestamp});
}

// Hive adapter for TriggerResponse (required for Hive to store custom objects)
class TriggerResponseAdapter extends TypeAdapter<TriggerResponse> {
  @override
  final int typeId = 0;
  @override
  TriggerResponse read(BinaryReader reader) {
    return TriggerResponse(
      triggerId: reader.readString(),
      triggerText: reader.readString(),
      isPositive: reader.readBool(),
      averted: reader.readBool(),
      timestamp: DateTime.parse(reader.readString()),
    );
  }
  @override
  void write(BinaryWriter writer, TriggerResponse obj) {
    writer.writeString(obj.triggerId);
    writer.writeString(obj.triggerText);
    writer.writeBool(obj.isPositive);
    writer.writeBool(obj.averted);
    writer.writeString(obj.timestamp.toIso8601String());
  }
}

// The main landing page where users add triggers and log responses
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  // List of triggers, with a default negative item
  final List<Trigger> _triggers = [
    Trigger(id: 'default-0', text: 'Are you drinking?', isPositive: false, habit: 'smoking'),
  ];

  // Add a new trigger to the list
  void _addTrigger(String triggerText, bool isPositive, String habit) {
    // Limit to 30 chars and capitalize
    String limitedText = triggerText.length > 30 ? triggerText.substring(0, 30) : triggerText;
    if (limitedText.isNotEmpty) {
      limitedText = limitedText[0].toUpperCase() + limitedText.substring(1);
    }
    String habitText = habit.trim();
    // Generate a unique id for the new trigger
    String id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _triggers.add(Trigger(id: id, text: limitedText, isPositive: isPositive, habit: habitText));
    });
  }

  // Show dialog to input new trigger and select type
  void _showAddTriggerDialog() {
    String newTrigger = '';
    String newHabit = '';
    bool isPositive = false; // default to negative
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What is your habit?', style: TextStyle(fontFamily: cssMonoFont, fontSize: 15, color: cssAccent, fontWeight: FontWeight.normal)),
              // Habit input
              TextField(
                autofocus: true,
                style: TextStyle(fontFamily: cssMonoFont, fontSize: 14, color: cssText),
                decoration: InputDecoration(
                  hintText: 'e.g. smoking',
                  hintStyle: TextStyle(color: cssText.withOpacity(0.7)),
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  counterStyle: TextStyle(color: cssText),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: cssText),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: cssText),
                  ),
                ),
                maxLength: 30,
                onChanged: (value) {
                  newHabit = value;
                },
              ),
              const SizedBox(height: 8),
              Text('What is your trigger?', style: TextStyle(fontFamily: cssMonoFont, fontSize: 15, color: cssAccent, fontWeight: FontWeight.normal)),
              // Trigger input
              TextField(
                style: TextStyle(fontFamily: cssMonoFont, fontSize: 14, color: cssText),
                decoration: InputDecoration(
                  hintText: 'e.g. Are you drinking?',
                  hintStyle: TextStyle(color: cssText.withOpacity(0.7)),
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  counterStyle: TextStyle(color: cssText),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: cssText),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: cssText),
                  ),
                ),
                maxLength: 50,
                onChanged: (value) {
                  newTrigger = value;
                },
              ),
              const SizedBox(height: 23),
              // Choice between negative and positive habit
              Row(
                children: [
                  ChoiceChip(
                    label: Text('Negative',
                        style: TextStyle(
                          fontFamily: cssMonoFont,
                          fontSize: 13,
                          color: !isPositive ? cssBackground : cssAccent,
                        )),
                    selected: !isPositive,
                    selectedColor: cssAccent,
                    backgroundColor: cssSecondary,
                    side: BorderSide(color: !isPositive ? cssBackground : cssAccent),
                    onSelected: (selected) {
                      isPositive = false;
                      (context as Element).markNeedsBuild();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Positive',
                        style: TextStyle(
                          fontFamily: cssMonoFont,
                          fontSize: 13,
                          color: isPositive ? cssBackground : cssAccent,
                        )),
                    selected: isPositive,
                    selectedColor: cssAccent,
                    backgroundColor: cssSecondary,
                    side: BorderSide(color: isPositive ? cssBackground : cssAccent),
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
                if (newTrigger.trim().isNotEmpty && newHabit.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                  _addTrigger(newTrigger.trim(), isPositive, newHabit.trim());
                }
              },
              child: Text('Add', style: TextStyle(fontFamily: cssMonoFont, fontSize: 13)),
            ),
          ],
        );
      },
    );
  }

  // Confetti and audio controllers for celebration feedback
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

  // Show sober message (when user indulges a negative habit or averts a positive one)
  void _showSoberMessage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cssSecondary,
        title: Text("It's ok, next time!", style: TextStyle(fontFamily: cssMonoFont, color: cssAccent)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: TextStyle(fontFamily: cssMonoFont, color: cssAccent)),
          ),
        ],
      ),
    );
  }

  // Handle trigger action logic and navigate to stats page
  void _handleTriggerAction(Trigger trigger, bool averted) async {
    // averted: true if user clicked 'averted', false if 'indulged'
    final isPositive = trigger.isPositive;
    // Celebration if: averted a negative, or indulged a positive
    final isCelebration = (averted && !isPositive) || (!averted && isPositive);
    // Store response in Hive
    final box = Hive.box<TriggerResponse>('responses');
    await box.add(TriggerResponse(
      triggerId: trigger.id,
      triggerText: trigger.text,
      isPositive: trigger.isPositive,
      averted: averted,
      timestamp: DateTime.now(),
    ));
    // Navigate directly to stats page with message
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StatsPage(
          triggerId: trigger.id,
          triggerText: trigger.text,
          habit: trigger.habit,
          isPositive: trigger.isPositive,
          showCelebration: isCelebration,
          averted: averted,
        ),
      ),
    );
  }

  // Show dialog for trigger action (averted/indulged)
  void _showTriggerActionDialog(Trigger trigger) {
    showDialog(
      context: context,
      builder: (context) {
        // Determine button colors based on habit type
        final bool isPositive = trigger.isPositive;
        // For negative habit: averted=positiveColor, indulged=negativeColor
        // For positive habit: indulged=positiveColor, averted=negativeColor
        final Color avertedbuttonBorderColor = isPositive ? superNegativeColor : superPositiveColor;
        final Color indulgedbuttonBorderColor = isPositive ? superPositiveColor : superNegativeColor;
        final Color avertedbuttonTextColor = isPositive ? superNegativeColor : superPositiveColor;
        final Color indulgedbuttonTextColor = isPositive ? superPositiveColor : superNegativeColor;
        final Color avertedBg = cssSecondary;
        final Color indulgedBg = cssSecondary;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: cssSecondary,
          title: Text(
            'How did you do?',
            style: TextStyle(fontFamily: cssMonoFont, color: cssText, fontWeight: FontWeight.normal, fontSize: 18),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Averted button
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _handleTriggerAction(trigger, true); // averted
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: avertedBg,
                    foregroundColor: avertedbuttonTextColor,
                    minimumSize: const Size.fromHeight(36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: avertedbuttonBorderColor, width: 1.2),
                    elevation: 4,
                    shadowColor: cssShadow,
                  ),
                  child: Text('averted', style: TextStyle(fontFamily: cssMonoFont, fontSize: 15)),
                ),
                const SizedBox(height: 10),
                // Indulged button
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _handleTriggerAction(trigger, false); // indulged
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: indulgedBg,
                    foregroundColor: indulgedbuttonTextColor,
                    minimumSize: const Size.fromHeight(36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: indulgedbuttonBorderColor, width: 1.2),
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
              // Info button: show stats for this trigger
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: cssAccent, size: 32),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => StatsPage(triggerId: trigger.id, triggerText: trigger.text, habit: trigger.habit, isPositive: trigger.isPositive, averted: null),
                      ));
                    },
                  ),
                  const SizedBox(height: 4),
                  Text('Info', style: TextStyle(fontFamily: cssMonoFont, color: cssAccent, fontSize: 12)),
                ],
              ),
              // Delete info: remove all responses for this trigger
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.cleaning_services_outlined, color: cssAccent, size: 32),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: cssSecondary,
                          title: Text('Delete all data for this trigger?', style: TextStyle(fontFamily: cssMonoFont, color: cssAccent)),
                          content: Text('This will remove all your responses for "${trigger.text}". Are you sure?', style: TextStyle(fontFamily: cssMonoFont, color: cssText)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text('Cancel', style: TextStyle(fontFamily: cssMonoFont, color: cssAccent)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text('Delete', style: TextStyle(fontFamily: cssMonoFont, color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        final box = Hive.box<TriggerResponse>('responses');
                        final toDelete = box.values.where((r) => r.triggerId == trigger.id).toList();
                        for (final r in toDelete) {
                          r.delete();
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('All data for "${trigger.text}" deleted.', style: TextStyle(fontFamily: cssMonoFont))),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  Text('Delete Info', style: TextStyle(fontFamily: cssMonoFont, color: cssAccent, fontSize: 12)),
                ],
              ),
              // Delete trigger: remove trigger and all its data
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 32),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: cssSecondary,
                          title: Text('Delete this trigger?', style: TextStyle(fontFamily: cssMonoFont, color: cssAccent)),
                          content: Text('This will remove the trigger and all its data. Are you sure?', style: TextStyle(fontFamily: cssMonoFont, color: cssText)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text('Cancel', style: TextStyle(fontFamily: cssMonoFont, color: cssAccent)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text('Delete', style: TextStyle(fontFamily: cssMonoFont, color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        setState(() {
                          _triggers.removeAt(index);
                        });
                        final box = Hive.box<TriggerResponse>('responses');
                        final toDelete = box.values.where((r) => r.triggerId == trigger.id).toList();
                        for (final r in toDelete) {
                          r.delete();
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Trigger and all data deleted.', style: TextStyle(fontFamily: cssMonoFont))),
                        );
                      }
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

  // Get color based on trigger type (positive/negative)
  Color _triggerColor(bool isPositive) {
    return isPositive ? positiveColor : negativeColor;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final hasTriggers = _triggers.isNotEmpty;
    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          backgroundColor: cssBackground,
          body: Column(
            children: [
              SizedBox(height: screenHeight * 0.10), // More top margin
              // Top image, centered, 25% of screen height
              SizedBox(
                height: screenHeight * 0.25,
                child: Center(
                  child: Image.asset(
                    'assets/background.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.06), // More space between image and triggers
              // List of triggers
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                  itemCount: _triggers.length,
                  itemBuilder: (context, index) {
                    final trigger = _triggers[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10), // Less vertical margin
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cssBackground,
                          foregroundColor: cssText,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 4,
                          shadowColor: cssShadow,
                          side: BorderSide(color: cssText, width: 1),
                          textStyle: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w300,
                            fontSize: 15,
                          ),
                        ),
                        onPressed: () {
                          _showTriggerActionDialog(trigger);
                        },
                        onLongPress: () {
                          _showTriggerOptions(trigger, index);
                        },
                        child: Center(
                          child: Text(
                            trigger.text,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 0.5,
                              overflow: TextOverflow.ellipsis,
                              color: cssText,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showAddTriggerDialog,
            backgroundColor: cssText,
            child: Icon(Icons.add, color: cssBackground, size: 22),
            tooltip: 'Add Trigger',
            elevation: 4,
          ),
        ),
        // Confetti widget overlay (superimposed to everything)
        IgnorePointer(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: -3.14159/2, // Upwards
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
        ),
      ],
    );
  }
}

// StatsPage for a trigger: shows stats, charts, and timeline for a specific trigger
class StatsPage extends StatefulWidget {
  final String triggerId; // Unique id of the trigger
  final String triggerText; // Text of the trigger
  final String habit; // Name of the habit
  final bool isPositive; // Whether the trigger is positive or negative
  final bool showCelebration; // Whether to show celebration feedback
  final bool? averted; // Whether the last response was averted (nullable)
  const StatsPage({super.key, required this.triggerId, required this.triggerText, required this.habit, required this.isPositive, this.showCelebration = false, this.averted});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  bool _showStats = false; // Whether to show stats section

  // Helper: for negative habits, averted=1, indulged=0; for positive, averted=0, indulged=1
  double _score(TriggerResponse r) {
    if (widget.isPositive) {
      return r.averted ? 0.0 : 1.0;
    } else {
      return r.averted ? 1.0 : 0.0;
    }
  }

  // Get all responses for this trigger (by id)
  List<TriggerResponse> _getResponses() {
    final box = Hive.box<TriggerResponse>('responses');
    return box.values
        .where((r) => r.triggerId == widget.triggerId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  // Moving average with custom window size
  List<FlSpot> _movingAverage(List<TriggerResponse> responses, {int window = 5}) {
    List<FlSpot> spots = [];
    List<double> buffer = [];
    for (int i = 0; i < responses.length; i++) {
      buffer.add(_score(responses[i]));
      if (buffer.length > window) buffer.removeAt(0);
      double avg = buffer.reduce((a, b) => a + b) / buffer.length;
      spots.add(FlSpot(i.toDouble(), avg));
    }
    return spots;
  }

  // Bernoulli regression (logistic regression line for binary outcomes)
  List<FlSpot> _bernoulliRegression(List<TriggerResponse> responses) {
    if (responses.length < 2) return [];
    final n = responses.length;
    final xs = List.generate(n, (i) => i.toDouble());
    final ys = responses.map((r) => _score(r)).toList();
    double xMean = xs.reduce((a, b) => a + b) / n;
    double yMean = ys.reduce((a, b) => a + b) / n;
    double num = 0, den = 0;
    for (int i = 0; i < n; i++) {
      num += (xs[i] - xMean) * (ys[i] - yMean);
      den += (xs[i] - xMean) * (xs[i] - xMean);
    }
    double b = den == 0 ? 0 : num / den;
    double a = yMean - b * xMean;
    List<FlSpot> spots = [];
    for (int i = 0; i < n; i++) {
      double logit = a + b * xs[i];
      double p = 1 / (1 + math.exp(-logit));
      spots.add(FlSpot(xs[i], p));
    }
    return spots;
  }

  // Dot timeline: shows a dot for each response (green for success, red for failure)
  List<Widget> _dotTimeline(List<TriggerResponse> responses) {
    return [
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: responses.map((r) => Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _score(r) == 1.0 ? superPositiveColor : superNegativeColor,
          ),
        )).toList(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final responses = _getResponses();
    final movingAvgShort = _movingAverage(responses, window: 3);
    final movingAvgLong = _movingAverage(responses, window: 10);
    final bernoulli = _bernoulliRegression(responses);
    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          backgroundColor: cssBackground,
          appBar: AppBar(
            backgroundColor: cssBackground,
            elevation: 2,
            centerTitle: true,
            iconTheme: IconThemeData(color: cssText),
            title: Text(
              widget.habit.isNotEmpty ? widget.habit[0].toUpperCase() + widget.habit.substring(1) : '',
              style: TextStyle(fontFamily: cssMonoFont, color: cssText, fontSize: 20, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: cssText),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Back',
            ),
          ),
          body: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      // Show celebration or sober message if needed
                      if (widget.showCelebration)
                        ...[
                          SizedBox(
                            height: 0,
                          ),
                          Text('🎉 Great job!', textAlign: TextAlign.center, style: TextStyle(fontFamily: cssMonoFont, fontSize: 22, color: cssAccent)),
                          const SizedBox(height: 6),
                          Text(widget.averted == true ? 'You averted a negative trigger.' : 'You indulged a positive trigger.', textAlign: TextAlign.center, style: TextStyle(fontFamily: cssMonoFont, fontSize: 17, color: cssText)),
                          const SizedBox(height: 18),
                        ]
                      else if (widget.showCelebration == false && widget.averted != null)
                        ...[
                          Text("It's ok, next time!", textAlign: TextAlign.center, style: TextStyle(fontFamily: cssMonoFont, fontSize: 20, color: cssAccent)),
                          const SizedBox(height: 6),
                          Text(widget.averted == true ? 'You averted a positive trigger.' : 'You indulged a negative trigger.', textAlign: TextAlign.center, style: TextStyle(fontFamily: cssMonoFont, fontSize: 17, color: cssText)),
                          const SizedBox(height: 18),
                        ],
                      const SizedBox(height: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Button to show stats
                            if (!_showStats)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showStats = true;
                                  });
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: cssText,
                                  textStyle: TextStyle(fontFamily: cssMonoFont, fontSize: 17, fontWeight: FontWeight.w400),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('See stats', style: TextStyle(fontFamily: cssMonoFont, fontSize: 17, fontWeight: FontWeight.w400)),
                                    const SizedBox(width: 6),
                                    Icon(Icons.arrow_downward, color: cssText, size: 20),
                                  ],
                                ),
                              ),
                            // Animated stats section
                            AnimatedCrossFade(
                              firstChild: SizedBox.shrink(),
                              secondChild: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Chart area
                                  SizedBox(
                                    height: 220,
                                    child: LineChart(
                                      LineChartData(
                                        backgroundColor: cssSecondary,
                                        gridData: FlGridData(show: false),
                                        borderData: FlBorderData(show: false),
                                        titlesData: FlTitlesData(show: false),
                                        lineBarsData: [
                                          if (responses.isNotEmpty)
                                            LineChartBarData(
                                              spots: responses.length == 1
                                                  ? [FlSpot(0, _score(responses[0]))]
                                                  : movingAvgShort,
                                              isCurved: true,
                                              color: Colors.blueAccent,
                                              barWidth: 3,
                                              dotData: FlDotData(show: responses.length == 1),
                                            ),
                                          if (responses.length > 1)
                                            LineChartBarData(
                                              spots: movingAvgLong,
                                              isCurved: true,
                                              color: Colors.purple,
                                              barWidth: 3,
                                              dotData: FlDotData(show: false),
                                            ),
                                          if (bernoulli.isNotEmpty)
                                            LineChartBarData(
                                              spots: bernoulli,
                                              isCurved: true,
                                              color: Colors.orange,
                                              barWidth: 2,
                                              dotData: FlDotData(show: false),
                                              dashArray: [6, 4],
                                            ),
                                        ],
                                        minY: -0.1,
                                        maxY: 1.1,
                                        lineTouchData: LineTouchData(
                                          enabled: true,
                                          touchTooltipData: LineTouchTooltipData(
                                            tooltipBgColor: cssText.withOpacity(0.7), // Add transparency to tooltip background
                                            fitInsideHorizontally: true, // Prevent tooltip from being clipped horizontally
                                            fitInsideVertically: true,   // Prevent tooltip from being clipped vertically
                                            getTooltipItems: (touchedSpots) {
                                              return touchedSpots.map((spot) {
                                                final y = spot.y;
                                                return LineTooltipItem(
                                                  y.isNaN ? '' : y.toStringAsFixed(2),
                                                  TextStyle(
                                                    color: spot.bar.color,
                                                    fontFamily: cssMonoFont,
                                                    fontSize: 13,
                                                  ),
                                                );
                                              }).toList();
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (responses.length >= 1)
                                    Row(
                                      children: [
                                        Text('Short MA', style: TextStyle(fontFamily: cssMonoFont, color: Colors.blueAccent, fontSize: 15)),
                                        const SizedBox(width: 12),
                                        Text('Long MA', style: TextStyle(fontFamily: cssMonoFont, color: Colors.purple, fontSize: 15)),
                                        const SizedBox(width: 12),
                                        if (bernoulli.isNotEmpty)
                                          Text('Bernoulli', style: TextStyle(fontFamily: cssMonoFont, color: Colors.orange, fontSize: 15)),
                                      ],
                                    ),
                                  const SizedBox(height: 24),
                                  Text('Timeline:', style: TextStyle(fontFamily: cssMonoFont, color: cssText, fontSize: 17)),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                                    child: Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: responses.map((r) => Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _score(r) == 1.0 ? superPositiveColor : superNegativeColor,
                                        ),
                                      )).toList(),
                                    ),
                                  ),
                                ],
                              ),
                              crossFadeState: _showStats ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 350),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Confetti overlay (always on top, above everything)
        if (widget.showCelebration)
          IgnorePointer(
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
      ],
    );
  }
}

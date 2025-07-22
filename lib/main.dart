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
    // Limit to 30 chars
    final limitedText = triggerText.length > 30 ? triggerText.substring(0, 30) : triggerText;
    setState(() {
      _triggers.add(Trigger(text: limitedText, isPositive: isPositive));
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
                maxLength: 30,
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
    // Navigate directly to stats page with message
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StatsPage(
          triggerText: trigger.text,
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
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => StatsPage(triggerText: trigger.text, isPositive: trigger.isPositive),
                      ));
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
                        final toDelete = box.values.where((r) => r.triggerText == trigger.text && r.isPositive == trigger.isPositive).toList();
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
              // Delete trigger
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
                        final toDelete = box.values.where((r) => r.triggerText == trigger.text && r.isPositive == trigger.isPositive).toList();
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
        // SVG background layer
        Positioned.fill(
          child: SvgPicture.asset(
            'assets/background.svg',
            fit: BoxFit.cover,
            // Removed colorFilter for original SVG colors
          ),
        ),
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
                      maxLines: 1,
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

// StatsPage for a trigger
class StatsPage extends StatelessWidget {
  final String triggerText;
  final bool isPositive;
  final bool showCelebration;
  final bool averted;
  const StatsPage({super.key, required this.triggerText, required this.isPositive, this.showCelebration = false, this.averted = false});

  List<TriggerResponse> _getResponses() {
    final box = Hive.box<TriggerResponse>('responses');
    return box.values
        .where((r) => r.triggerText == triggerText && r.isPositive == isPositive)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  // Moving average with custom window
  List<FlSpot> _movingAverage(List<TriggerResponse> responses, {int window = 5}) {
    List<FlSpot> spots = [];
    List<double> buffer = [];
    for (int i = 0; i < responses.length; i++) {
      buffer.add(responses[i].averted ? 1.0 : 0.0);
      if (buffer.length > window) buffer.removeAt(0);
      double avg = buffer.reduce((a, b) => a + b) / buffer.length;
      spots.add(FlSpot(i.toDouble(), avg));
    }
    return spots;
  }

  // Remove CUSUM control chart
  // Bernoulli regression (as before)
  List<FlSpot> _bernoulliRegression(List<TriggerResponse> responses) {
    if (responses.length < 2) return [];
    final n = responses.length;
    final xs = List.generate(n, (i) => i.toDouble());
    final ys = responses.map((r) => r.averted ? 1.0 : 0.0).toList();
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

  // Dot timeline: now with no jitter, no blur, smaller dots, and multi-line piling
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
            color: r.averted ? Colors.green : Colors.red,
          ),
        )).toList(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final responses = _getResponses();
    if (responses.length < 2) {
      return Scaffold(
        backgroundColor: cssBackground,
        appBar: AppBar(
          backgroundColor: cssBackground,
          foregroundColor: cssText,
          elevation: 2,
          centerTitle: true,
          title: Text(
            triggerText,
            style: TextStyle(fontFamily: cssMonoFont, color: cssAccent, fontSize: 20, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: cssAccent),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
          ),
        ),
        body: SafeArea(
          child: Center(
            child: Text('Not enough data yet!', style: TextStyle(fontFamily: cssMonoFont, color: cssAccent, fontSize: 20)),
          ),
        ),
      );
    }
    final movingAvgShort = _movingAverage(responses, window: 3);
    final movingAvgLong = _movingAverage(responses, window: 10);
    final bernoulli = _bernoulliRegression(responses);
    return Scaffold(
      backgroundColor: cssBackground,
      appBar: AppBar(
        backgroundColor: cssBackground,
        foregroundColor: cssText,
        elevation: 2,
        centerTitle: true,
        title: Text(
          triggerText,
          style: TextStyle(fontFamily: cssMonoFont, color: cssAccent, fontSize: 20, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cssAccent),
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
                  if (showCelebration)
                    ...[
                      SizedBox(
                        height: 0,
                      ),
                      Text('🎉 Great job!', textAlign: TextAlign.center, style: TextStyle(fontFamily: cssMonoFont, fontSize: 22, color: cssAccent)),
                      const SizedBox(height: 6),
                      Text(averted ? 'You averted a negative trigger.' : 'You indulged a positive trigger.', textAlign: TextAlign.center, style: TextStyle(fontFamily: cssMonoFont, fontSize: 17, color: cssText)),
                      const SizedBox(height: 18),
                    ]
                  else if (showCelebration == false && (averted != null))
                    ...[
                      Icon(Icons.info_outline, color: cssAccent, size: 40),
                      const SizedBox(height: 12),
                      Text("it's ok, you'll manage next time", textAlign: TextAlign.center, style: TextStyle(fontFamily: cssMonoFont, fontSize: 20, color: cssAccent)),
                      const SizedBox(height: 6),
                      Text(averted ? 'You averted a positive trigger.' : 'You indulged a negative trigger.', textAlign: TextAlign.center, style: TextStyle(fontFamily: cssMonoFont, fontSize: 17, color: cssText)),
                      const SizedBox(height: 18),
                    ],
                  // Removed triggerText from here
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: LineChart(
                      LineChartData(
                        backgroundColor: cssSecondary,
                        gridData: FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: movingAvgShort,
                            isCurved: true,
                            color: Colors.blueAccent,
                            barWidth: 3,
                            dotData: FlDotData(show: false),
                          ),
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
                        minY: 0,
                        maxY: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: _dotTimeline(responses)),
                  ),
                ],
              ),
            ),
          ),
          // Confetti overlay (always on top)
          if (showCelebration)
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
      ),
    );
  }
}

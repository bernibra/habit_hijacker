import 'package:flutter/material.dart';

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

  // Get color based on trigger type
  Color _triggerColor(bool isPositive) {
    return isPositive ? Colors.blueAccent : Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('your triggers', style: TextStyle(fontFamily: 'monospace')),
      ),
      body: ListView.builder(
        itemCount: _triggers.length,
        itemBuilder: (context, index) {
          final trigger = _triggers[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _triggerColor(trigger.isPositive),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                // Will implement dialog in next step
              },
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  trigger.text,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 18),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTriggerDialog,
        child: const Icon(Icons.add),
        tooltip: 'Add Trigger',
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// A simple welcome page that collects basic user information.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  static const int _minAge = 5;
  static const int _maxAge = 100;
  late final FixedExtentScrollController _ageController;
  int _age = _minAge;

  String? _gender; // 'male' or 'female'
  String? _goal; // 'happier', 'successful', 'organized'

  @override
  void initState() {
    super.initState();
    _ageController = FixedExtentScrollController(initialItem: 0);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  List<Widget> _buildAgeItems() {
    return List<Widget>.generate(
      _maxAge - _minAge + 1,
      (index) => Center(child: Text('${index + _minAge}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              const Text('Age'),
              SizedBox(
                height: 100,
                child: ListWheelScrollView(
                  controller: _ageController,
                  itemExtent: 40,
                  onSelectedItemChanged: (index) {
                    setState(() {
                      _age = index + _minAge;
                    });
                  },
                  children: _buildAgeItems(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Gender'),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 40,
                    color: _gender == 'male' ? Colors.blue : Colors.grey,
                    icon: const Icon(Icons.male),
                    onPressed: () {
                      setState(() => _gender = 'male');
                    },
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    iconSize: 40,
                    color: _gender == 'female' ? Colors.pink : Colors.grey,
                    icon: const Icon(Icons.female),
                    onPressed: () {
                      setState(() => _gender = 'female');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Goal'),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Be happier'),
                    selected: _goal == 'happier',
                    onSelected: (_) {
                      setState(() => _goal = 'happier');
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Be successful'),
                    selected: _goal == 'successful',
                    onSelected: (_) {
                      setState(() => _goal = 'successful');
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Be more organized'),
                    selected: _goal == 'organized',
                    onSelected: (_) {
                      setState(() => _goal = 'organized');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    debugPrint(
                      'Name: ${_nameController.text}, Email: ${_emailController.text}, '
                      'Age: $_age, Gender: $_gender, Goal: $_goal',
                    );
                  },
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


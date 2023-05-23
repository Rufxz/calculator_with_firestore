import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:mobx/mobx.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class CalculationHistory {
  int id;
  String expression;
  String result;
  DateTime timestamp;

  CalculationHistory({
    required this.id,
    required this.expression,
    required this.result,
    required this.timestamp,
  });
}

class CalculatorModel {
  @observable
  String expression = '';

  @observable
  String result = '';

  @observable
  ObservableList<CalculationHistory> history =
  ObservableList<CalculationHistory>();

  late Database _database;

  @action
  Future<void> initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'calculator.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        db.execute('''
          CREATE TABLE calculation_history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            expression TEXT,
            result TEXT,
            timestamp TEXT
          )
        ''');
      },
    );
  }

  @action
  Future<void> addToExpression(String value) async {
    expression += value;
  }

  @action
  Future<void> clearExpression() async {
    expression = '';
  }

  @action
  Future<void> evaluateExpression() async {
    try {
      Parser parser = Parser();
      Expression exp = parser.parse(expression);
      ContextModel contextModel = ContextModel();
      result = exp.evaluate(EvaluationType.REAL, contextModel).toString();

      await addToHistory(CalculationHistory(
        id: 0,
        expression: expression,
        result: result,
        timestamp: DateTime.now(),
      ));

      expression = '';
    } catch (e) {
      result = 'Error';
    }
  }

  @action
  Future<void> addToHistory(CalculationHistory calculation) async {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(calculation.timestamp);
    final values = {
      'expression': calculation.expression,
      'result': calculation.result,
      'timestamp': timestamp,
    };

    final id = await _database.insert('calculation_history', values);
    calculation.id = id;
    history.add(calculation);
  }

  @action
  Future<void> clearHistory() async {
    await _database.delete('calculation_history');
    history.clear();
  }

  @action
  Future<void> loadHistory() async {
    final rows = await _database.query('calculation_history', orderBy: 'timestamp DESC');

    history.clear();
    for (final row in rows) {
      final id = row['id'] as int;
      final expression = row['expression'] as String;
      final result = row['result'] as String;
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').parse(row['timestamp'] as String);

      final calculation = CalculationHistory(
        id: id,
        expression: expression,
        result: result,
        timestamp: timestamp,
      );

      history.add(calculation);
    }
  }
}

void saveCalculation(String expression, String result) {
  final timestamp = DateTime.now();
  final calculationData = {
    'expression': expression,
    'result': result,
    'timestamp': timestamp.toIso8601String(),
  };
  FirebaseFirestore.instance.collection('History').add(calculationData);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final model = CalculatorModel();
  await model.initDatabase();
  await model.loadHistory();

  runApp(CalculatorApp(model: model));
}

class CalculatorApp extends StatelessWidget {
  final CalculatorModel model;

  const CalculatorApp({required this.model});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Calculator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => CalculatorView(model: model),
        '/history': (context) => HistoryScreen(model: model),
        '/converter': (context) => ConverterScreen(),
      },
    );
  }
}

class CalculatorView extends StatefulWidget {
  final CalculatorModel model;

  const CalculatorView({required this.model});

  @override
  _CalculatorViewState createState() => _CalculatorViewState();
}

class _CalculatorViewState extends State<CalculatorView> {
  final TextEditingController _expressionController = TextEditingController();
  final TextEditingController _resultController = TextEditingController();

  @override
  void dispose() {
    _expressionController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _expressionController.text = widget.model.expression;
    _resultController.text = widget.model.result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calculator'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              Navigator.pushNamed(context, '/history');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  widget.model.expression = value;
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Expression',
              ),
              controller: _expressionController,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              readOnly: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Result',
              ),
              controller: _resultController,
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              children: [
                _buildButton('7'),
                _buildButton('8'),
                _buildButton('9'),
                _buildOperatorButton('/'),
                _buildButton('4'),
                _buildButton('5'),
                _buildButton('6'),
                _buildOperatorButton('*'),
                _buildButton('1'),
                _buildButton('2'),
                _buildButton('3'),
                _buildOperatorButton('-'),
                _buildButton('0'),
                _buildButton('.'),
                TextButton(
                  child: Text('Clear'),
                  onPressed: () {
                    setState(() {
                      widget.model.clearExpression();
                      _expressionController.text = '';
                    });
                  },
                ),
                _buildOperatorButton('+'),
              ],
            ),
          ),
          ElevatedButton(
            child: Text('Calculate'),
            onPressed: () {
              setState(() {
                widget.model.evaluateExpression();
                _resultController.text = widget.model.result;
              });
            },
          ),
          ElevatedButton(
            child: Text('Converter'),
            onPressed: () {
              Navigator.pushNamed(context, '/converter');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String text) {
    return ElevatedButton(
      child: Text(text),
      onPressed: () {
        setState(() {
          widget.model.addToExpression(text);
          _expressionController.text = widget.model.expression;
        });
      },
    );
  }

  Widget _buildOperatorButton(String text) {
    return ElevatedButton(
      child: Text(text),
      onPressed: () {
        setState(() {
          widget.model.addToExpression(' $text ');
          _expressionController.text = widget.model.expression;
        });
      },
    );
  }
}

class HistoryScreen extends StatelessWidget {
  final CalculatorModel model;

  const HistoryScreen({required this.model});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calculation History'),
        actions: [
          IconButton(
            icon: Icon(Icons.clear_all),
            onPressed: () {
              model.clearHistory();
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: model.history.length,
        itemBuilder: (context, index) {
          final calculation = model.history[index];
          final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(calculation.timestamp);

          return ListTile(
            title: Text(calculation.expression),
            subtitle: Text('Result: ${calculation.result}'),
            trailing: Text(formattedDate),
          );
        },
      ),
    );
  }
}

class ConverterScreen extends StatelessWidget {
  final TextEditingController _kiloController = TextEditingController();
  final TextEditingController _poundController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Weight Converter'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                final kiloValue = double.tryParse(value);
                if (kiloValue != null) {
                  final poundValue = kiloValue * 2.20462;
                  _poundController.text = poundValue.toStringAsFixed(2);
                } else {
                  _poundController.text = '';
                }
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Kilograms',
              ),
              keyboardType: TextInputType.number,
              controller: _kiloController,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              readOnly: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Pounds',
              ),
              keyboardType: TextInputType.number,
              controller: _poundController,
            ),
          ),
        ],
      ),
    );
  }
}

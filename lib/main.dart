

 
 
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(const FinanceApp());
}

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Finance Tracker',
      theme: ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFFF5F7FB),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF2563EB),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF2563EB),
    foregroundColor: Colors.white,
    centerTitle: false,
    elevation: 0,
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.symmetric(vertical: 6),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    ),
  ),
),
      home: const HomePage(),
    );
  }
}


class Expense {
  final double amount;
  final String category;
  final String description;
  final DateTime date;

  Expense({
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'category': category,
      'description': description,
      'date': date.toIso8601String(),
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      description: json['description'] as String,
      date: DateTime.parse(json['date'] as String),
    );
  }
}



class Income {
  final double amount;
  final String category;
  final String description;
  final DateTime date;

  Income({
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'category': category,
      'description': description,
      'date': date.toIso8601String(),
    };
  }

  factory Income.fromJson(Map<String, dynamic> json) {
    return Income(
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      description: json['description'] as String,
      date: DateTime.parse(json['date'] as String),
    );
  }
}


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _finishingVoice = false;
  String _recognizedText = '';
  double? _voiceAmount;

  double? extractAmount(String text) {
    // Recognizes amounts written with digits, e.g. 180 or 45,50 TL.
    final match = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(?:tl|lira|₺)?',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  String categoryFromSpeech(String text) {
    final lower = text.toLowerCase();
    if (RegExp(r'market|alışveriş|mağaza|kıyafet|ayakkabı|bakkal')
        .hasMatch(lower)) {
      return 'Alışveriş';
    }
    if (RegExp(r'otobüs|metro|taksi|benzin|ulaşım|dolmuş|tramvay')
        .hasMatch(lower)) {
      return 'Ulaşım';
    }
    if (RegExp(r'kira|fatura|elektrik|su faturası|internet faturası|doğalgaz')
        .hasMatch(lower)) {
      return 'Faturalar';
    }
    if (RegExp(r'sinema|oyun|konser|eğlence').hasMatch(lower)) {
      return 'Eğlence';
    }
    if (RegExp(r'yemek|kahve|restoran|kafe|burger|pizza|çay')
        .hasMatch(lower)) {
      return 'Yemek';
    }
    return 'Diğer';
  }

  Future<void> startListening() async {
    if (_isListening || _finishingVoice) return;
    _recognizedText = '';
    _voiceAmount = null;
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted || !_isListening) return;
          if (status == 'done' || status == 'notListening') {
            // Some devices stop listening automatically after a pause.
            Future<void>.delayed(const Duration(milliseconds: 350), () {
              if (mounted && _isListening) {
                stopListening();
              }
            });
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ses tanıma hatası: ${error.errorMsg}')),
          );
        },
      );
      if (!mounted) return;
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konuşma tanıma kullanılamıyor.')),
        );
        return;
      }
      setState(() => _isListening = true);
      await _speech.listen(
        localeId: 'tr_TR',
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _recognizedText = result.recognizedWords;
            _voiceAmount = extractAmount(_recognizedText);
          });
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isListening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mikrofon başlatılamadı: $error')),
      );
    }
  }

  Future<void> stopListening() async {
    if (_finishingVoice) return;
    _finishingVoice = true;
    if (mounted) setState(() => _isListening = false);
    try {
      await _speech.stop();
      if (!mounted) return;
      if (_recognizedText.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konuşma algılanamadı. Tekrar deneyin.')),
        );
      } else {
        await addExpense(fromVoice: true);
      }
    } finally {
      _finishingVoice = false;
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  double monthlyBudget = 12000;
  final List<Expense> expenses = [];
  final List<Income> incomes = [];
  
@override
void initState() {
  super.initState();
  loadExpenses();
  loadIncomes();
  loadBudget();
}
Future<void> loadBudget() async {
  final prefs = await SharedPreferences.getInstance();

  final savedBudget = prefs.getDouble('monthlyBudget');

  if (!mounted) return;

  setState(() {
    monthlyBudget = savedBudget ?? 12000;
  });
}
Future<void> saveBudget(double newBudget) async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.setDouble('monthlyBudget', newBudget);

  if (!mounted) return;

  setState(() {
    monthlyBudget = newBudget;
  });
}

Future<void> editBudget() async {
  final controller = TextEditingController(
    text: monthlyBudget.toStringAsFixed(0),
  );

  final newBudget = await showDialog<double>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Aylık Bütçeyi Değiştir'),
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
        ),
        decoration: const InputDecoration(
          labelText: 'Yeni bütçe (TL)',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () {
            final value = double.tryParse(
              controller.text.trim().replaceAll(',', '.'),
            );

            if (value != null && value > 0 && value.isFinite) {
              Navigator.pop(context, value);
            }
          },
          child: const Text('Kaydet'),
        ),
      ],
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
  controller.dispose();
});

  if (!mounted || newBudget == null) return;

  await saveBudget(newBudget);
}

Future<void> saveExpenses() async {
  final prefs = await SharedPreferences.getInstance();

  final data = expenses.map((e) => e.toJson()).toList();

  await prefs.setString('expenses', jsonEncode(data));
}

Future<void> loadExpenses() async {
  final prefs = await SharedPreferences.getInstance();

  final savedData = prefs.getString('expenses');

  if (savedData == null) return;

  final List<dynamic> decoded = jsonDecode(savedData);

  if (!mounted) return;

  setState(() {
    expenses.clear();

    expenses.addAll(
      decoded.map(
        (item) => Expense.fromJson(
          Map<String, dynamic>.from(item),
        ),
      ),
    );
  });
}
Future<void> saveIncomes() async {
  final prefs = await SharedPreferences.getInstance();

  final data = incomes.map((income) => income.toJson()).toList();

  await prefs.setString('incomes', jsonEncode(data));
}

Future<void> loadIncomes() async {
  final prefs = await SharedPreferences.getInstance();

  final savedData = prefs.getString('incomes');

  if (savedData == null) return;

  final List<dynamic> decoded = jsonDecode(savedData);

  if (!mounted) return;

  setState(() {
    incomes.clear();

    incomes.addAll(
      decoded.map(
        (item) => Income.fromJson(
          Map<String, dynamic>.from(item),
        ),
      ),
    );
  });
}

double get monthlyIncome {
  final now = DateTime.now();

  return incomes
      .where(
        (income) =>
            income.date.year == now.year &&
            income.date.month == now.month,
      )
      .fold(0.0, (total, income) => total + income.amount);
}
  String formatMoney(double amount) {
    return '${amount.toStringAsFixed(2).replaceAll('.', ',')} TL';
  }

  double get monthlyTotal {
    final now = DateTime.now();

    return expenses
        .where((expense) =>
            expense.date.year == now.year &&
            expense.date.month == now.month)
        .fold<double>(
          0,
          (total, expense) => total + expense.amount,
        );
  }
  double get remainingBudget {
  return monthlyBudget - monthlyTotal;
}
double get monthlyNetBalance {
  return monthlyIncome - monthlyTotal;
}
  Map<String, double> get categoryTotals {
  final Map<String, double> totals = {};

  final now = DateTime.now();

  for (final expense in expenses) {
    if (expense.date.year == now.year &&
        expense.date.month == now.month) {
      totals[expense.category] =
          (totals[expense.category] ?? 0) + expense.amount;
    }
  }

  return totals;
}

  Future<void> addExpense({bool fromVoice = false}) async {
    final amountController = TextEditingController(
      text: fromVoice && _voiceAmount != null
          ? _voiceAmount!.toStringAsFixed(2)
          : '',
    );
    final descriptionController = TextEditingController(
      text: fromVoice ? _recognizedText : '',
    );
    String selectedCategory =
        fromVoice ? categoryFromSpeech(_recognizedText) : 'Yemek';

    final newExpense = await showDialog<Expense>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Yeni Harcama'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Tutar (TL)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        'Yemek',
                        'Ulaşım',
                        'Alışveriş',
                        'Eğlence',
                        'Faturalar',
                        'Diğer',
                      ].map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedCategory = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Açıklama',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final amount = double.tryParse(
                      amountController.text
                          .trim()
                          .replaceAll(',', '.'),
                    );

                    if (amount == null ||
                        !amount.isFinite ||
                        amount <= 0) {
                      ScaffoldMessenger.of(this.context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Geçerli bir tutar giriniz.',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      Expense(
                        amount: amount,
                        category: selectedCategory,
                        description:
                            descriptionController.text.trim(),
                        date: DateTime.now(),
                      ),
                    );
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );

    
    

    if (fromVoice) {
      _recognizedText = '';
      _voiceAmount = null;
    }
    if (!mounted || newExpense == null) return;

    setState(() {
      expenses.add(newExpense);
    });
    await saveExpenses();
  }
  Future<void> addIncome() async {
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();

  String selectedCategory = 'Burs';

  final newIncome = await showDialog<Income>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Yeni Gelir'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Tutar (TL)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Gelir Kategorisi',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      'Burs',
                      'Maaş',
                      'Harçlık',
                      'Ek Gelir',
                      'Diğer',
                    ].map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedCategory = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(
                    amountController.text.trim().replaceAll(',', '.'),
                  );

                  if (amount == null ||
                      !amount.isFinite ||
                      amount <= 0) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Geçerli bir tutar giriniz.'),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(
                    dialogContext,
                    Income(
                      amount: amount,
                      category: selectedCategory,
                      description: descriptionController.text.trim(),
                      date: DateTime.now(),
                    ),
                  );
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      );
    },
  );

  if (!mounted || newIncome == null) return;

  setState(() {
    incomes.add(newIncome);
  });

  await saveIncomes();
}

  // Small summary cards stay readable on narrow phone screens.
  Widget _summaryCard({
    required String label,
    required double amount,
    required Color color,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatMoney(amount),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cüzdanım'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
  child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Finans Takibim',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),


            
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      child: _summaryCard(
        label: 'Gider',
        amount: monthlyTotal,
        color: const Color(0xFF1F2937),
      ),
    ),
    const SizedBox(width: 6),
    Expanded(
      child: _summaryCard(
        label: 'Gelir',
        amount: monthlyIncome,
        color: Colors.green,
      ),
    ),
    const SizedBox(width: 6),
    Expanded(
      child: _summaryCard(
        label: 'Net Bakiye',
        amount: monthlyNetBalance,
        color: monthlyNetBalance >= 0 ? Colors.green : Colors.red,
      ),
    ),
  ],
),
const SizedBox(height: 20),
const Text(
  'Gelir Geçmişim',
  style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  ),
),
const SizedBox(height: 10),
if (incomes.isEmpty)
  const Text('Henüz gelir eklenmedi.'),
  if (incomes.isNotEmpty)
  ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: incomes.length,
    itemBuilder: (context, index) {
      final income = incomes[incomes.length - 1 - index];

      return Card(
        child: ListTile(
          leading: const Icon(
            Icons.attach_money,
            color: Colors.green,
          ),
          title: Text(formatMoney(income.amount)),
          subtitle: Text(
            '${income.date.day}.${income.date.month}.${income.date.year}',
          ),
          trailing: IconButton(
  icon: const Icon(
    Icons.delete_outline,
    color: Colors.red,
  ),
  onPressed: () async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Geliri Sil'),
      content: const Text(
        'Bu gelir kaydını silmek istediğine emin misin?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('İptal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text(
            'Sil',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true || !mounted) return;

  setState(() {
    incomes.removeAt(incomes.length - 1 - index);
  });

  await saveIncomes();
},
),
        ),
      );
    },
  ),
            Card(
  child: Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    const Text('Kalan Bütçem'),
    IconButton(
      onPressed: editBudget,
      icon: const Icon(Icons.edit),
      tooltip: 'Bütçeyi Değiştir',
    ),
  ],
),

        const SizedBox(height: 10),
        Text(
          formatMoney(remainingBudget),
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: remainingBudget < 0
                ? Colors.red
                : Colors.green,
          ),
        ),
      ],
    ),
  ),
),
const SizedBox(height: 20),
            if (categoryTotals.isNotEmpty) ...[
  Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Kategori Bazlı Harcamalar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: categoryTotals.entries.map((entry) {
                  final index = categoryTotals.keys
                      .toList()
                      .indexOf(entry.key);

                  final colors = [
                    Colors.teal,
                    Colors.orange,
                    Colors.blue,
                    Colors.purple,
                    Colors.red,
                  ];

                  return PieChartSectionData(
                    value: entry.value,
                    color: colors[index % colors.length],
                    title: '${(entry.value / monthlyTotal * 100).toStringAsFixed(1)}%',
                    radius: 75,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 35,
              ),
            ),
          ),
          const SizedBox(height: 15),
          ...categoryTotals.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key),
                  Text(formatMoney(entry.value)),
                ],
              ),
            );
          }),
        ],
      ),
    ),
  ),
  const SizedBox(height: 20),
],
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (expenses.isEmpty)
            
                   const Text(
                      'Henüz harcama eklenmedi.',
                      style: TextStyle(fontSize: 16),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final expense =
                            expenses[expenses.length - 1 - index];

                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.shopping_bag),
                            ),
                            title: Text(expense.category),
                            subtitle: Text(
                              expense.description.isEmpty
                                  ? 'Açıklama yok'
                                  : expense.description,
                            ),
                            
trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      formatMoney(expense.amount),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),
    IconButton(
      icon: const Icon(
        Icons.delete_outline,
        color: Colors.red,
      ),
      onPressed: () async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Harcamayı Sil'),
      content: const Text(
        'Bu harcama kaydını silmek istediğine emin misin?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('İptal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text(
            'Sil',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true || !mounted) return;

  setState(() {
    expenses.removeAt(expenses.length - 1 - index);
  });

  await saveExpenses();
},
    ),
  ],
),                  
                          ),
                        );
                      },
                    ),
            ], // children
          ),
          ], // children
        ),
      ),
      ), // SingleChildScrollView
      floatingActionButton: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    FloatingActionButton(
  heroTag: 'voiceButton',
  mini: true,
  tooltip: 'Sesli Harcama',
  onPressed: _isListening ? stopListening : startListening,
  backgroundColor: _isListening ? Colors.red : Colors.teal,
  foregroundColor: Colors.white,
  child: Icon(_isListening ? Icons.mic_off : Icons.mic),
),
const SizedBox(width: 8),
    FloatingActionButton.extended(
      heroTag: 'incomeButton',
      onPressed: addIncome,
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text('Gelir Ekle'),
    ),
    const SizedBox(width: 10),
    FloatingActionButton.extended(
      heroTag: 'expenseButton',
      onPressed: addExpense,
      icon: const Icon(Icons.remove),
      label: const Text('Harcama Ekle'),
    ),
  ],
),
    );
  }
}

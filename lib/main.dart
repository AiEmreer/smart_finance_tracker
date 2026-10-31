
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
        ),
        useMaterial3: true,
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


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double monthlyBudget = 12000;
  final List<Expense> expenses = [];
  
@override
void initState() {
  super.initState();
  loadExpenses();
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

  Future<void> addExpense() async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = 'Yemek';

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

    
    

    if (!mounted || newExpense == null) return;

    setState(() {
      expenses.add(newExpense);
    });
    await saveExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cüzdanım'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text('Bu Ayki Harcamalarım'),
                    const SizedBox(height: 10),
                    Text(
                      formatMoney(monthlyTotal),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
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
            Expanded(
              child: expenses.isEmpty
                  ? const Text(
                      'Henüz harcama eklenmedi.',
                      style: TextStyle(fontSize: 16),
                    )
                  : ListView.builder(
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
            ),
          ],
        ),
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: addExpense,
        icon: const Icon(Icons.add),
        label: const Text('Harcama Ekle'),
      ),
    );
  }
}

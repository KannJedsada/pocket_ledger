import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pie_chart/pie_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th_TH', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'รายรับ-รายจ่าย',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 207, 18, 18)),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: ''),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 1;
  double income = 0;
  double expense = 0;
  double balance = 0;
  double amountperdate = 0;
  double incomeperDate = 0;
  double expenseperDate = 0;
  String? currentDate;
  String _appBarTitle = 'รายรับ-รายจ่าย';

  List<Map<String, dynamic>> transactions = [];

  @override
  void initState() {
    super.initState();
    loadTransactions();
    fetchCurrentDate();
    _updateAppBarTitle();
  }

  void fetchCurrentDate() async {
    try {
      final response = await http
          .get(Uri.parse('https://worldtimeapi.org/api/timezone/Asia/Bangkok'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final datetime = data['datetime'];
        setState(() {
          currentDate = formatDate(datetime);
        });
        debugPrint('Formatted Date: $currentDate');
      } else {
        throw Exception('Failed to load date');
      }
    } catch (error) {
      setState(() {
        currentDate = 'Error fetching date';
      });
    }
  }

  String formatDate(String datetime) {
    DateTime dateTime = DateTime.parse(datetime).toLocal();

    final DateFormat formatter = DateFormat('d MMMM yyyy', 'th_TH');
    String formattedDate = formatter.format(dateTime);

    int buddhistYear = dateTime.year + 543;

    final DateFormat dayFormatter = DateFormat('EEEE', 'th_TH');
    String dayOfWeek = dayFormatter.format(dateTime);

    String result = '$dayOfWeek $formattedDate'
        .replaceFirst(dateTime.year.toString(), buddhistYear.toString());

    return result;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _updateAppBarTitle();
    });
  }

  void _updateAppBarTitle() {
    setState(() {
      _appBarTitle = _selectedIndex == 0 ? 'ภาพรวม' : 'รายรับ-รายจ่าย';
    });
  }

  void _addTransactionToList(
      double amount, String category, bool isIncome) async {
    // Get the current date
    DateTime currentDate = DateTime.now();

    await loadTransactions();

    setState(() {
      transactions.add({
        'amount': amount,
        'category': category,
        'isIncome': isIncome,
        'day': currentDate.day,
        'month': currentDate.month,
        'year': currentDate.year,
      });

      if (isIncome) {
        income += amount;
        incomeperDate += amount;
      } else {
        expense += amount;
        expenseperDate += amount;
        amountperdate += amount;
      }

      balance = income - expense;
      saveTransactions();
    });
  }

// Function to add income/expense with categories
  Future<void> _addTransaction(bool isIncome) async {
    double amount = 0;
    String? selectedCategory;

    List<String> incomeCategories = ['เงินเดือน', 'โบนัส', 'รายได้พิเศษ'];
    List<String> expenseCategories = ['อาหาร', 'เดินทาง', 'ช้อปปิ้ง'];

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isIncome ? 'เพิ่มรายรับ' : 'เพิ่มรายจ่าย'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  amount = double.tryParse(value) ?? 0;
                },
                decoration: const InputDecoration(hintText: 'กรอกจำนวนเงิน'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                hint: const Text('เลือกหมวดหมู่'),
                value: selectedCategory,
                items: (isIncome ? incomeCategories : expenseCategories)
                    .map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                  });
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('เพิ่ม'),
              onPressed: () {
                if (selectedCategory != null && amount > 0) {
                  _addTransactionToList(amount, selectedCategory!, isIncome);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('กรุณาเลือกหมวดหมู่และกรอกจำนวนเงิน'),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> saveTransactions() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    DateTime now = DateTime.now();
    String monthKey = '${now.year}-${now.month}';
    // String dayKey = '${now.day}';

    // แปลง transactions เป็น JSON String
    String transactionData = jsonEncode(transactions);

    // บันทึกข้อมูลที่เกี่ยวข้องกับเดือนนี้
    await prefs.setString('${monthKey}_transactions',
        transactionData); // เก็บข้อมูล transactions ตามเดือน
    await prefs.setDouble('${monthKey}_income', income); // รายรับต่อเดือน
    await prefs.setDouble('${monthKey}_expense', expense); // รายจ่ายต่อเดือน
    await prefs.setDouble('${monthKey}_balance', balance); // ยอดคงเหลือต่อเดือน
    await prefs.setDouble('_incomeperdate', incomeperDate); // รายรับต่อวัน
    await prefs.setDouble('_expenseperdate', expenseperDate); // รายจ่ายต่อวัน
    await prefs.setDouble(
        '_amountperdate', amountperdate); // ยอดรวมรายจ่ายต่อวัน

    print("Monthly data for $monthKey saved successfully.");
  }

  Future<void> loadTransactions() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // โหลดข้อมูล transaction ที่บันทึกไว้ก่อนหน้านี้
    String? transactionData = prefs.getString(
        '${DateTime.now().day}_transactions'); // ดึงข้อมูลตามวันที่ปัจจุบัน

    if (transactionData != null) {
      setState(() {
        transactions =
            List<Map<String, dynamic>>.from(jsonDecode(transactionData));
        income = prefs.getDouble('${DateTime.now().month}_income') ?? 0;
        expense = prefs.getDouble('${DateTime.now().month}_expense') ?? 0;
        balance = prefs.getDouble('${DateTime.now().month}_balance') ?? 0;
        incomeperDate = prefs.getDouble('_incomeperdate') ?? 0;
        expenseperDate = prefs.getDouble('_expenseperdate') ?? 0;
        amountperdate = prefs.getDouble('_amountperdate') ?? 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(_appBarTitle),
      ),
      body: Center(
        child: _selectedIndex == 0
            ? overviewPageState()
            : ExpenseIncomePage(
                income: income,
                expense: expense,
                balance: balance,
                amountperdate: amountperdate,
                incomeperDate: incomeperDate,
                expenseperDate: expenseperDate,
                currentDate: currentDate,
                transactions: transactions,
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (BuildContext context) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('เพิ่มรายรับ'),
                    onTap: () {
                      Navigator.pop(context);
                      _addTransaction(true);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.remove),
                    title: const Text('เพิ่มรายจ่าย'),
                    onTap: () {
                      Navigator.pop(context);
                      _addTransaction(false);
                    },
                  ),
                ],
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: 'ภาพรวม',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'รายรับ-รายจ่าย',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.red,
        onTap: _onItemTapped,
      ),
    );
  }
}

class ExpenseIncomePage extends StatefulWidget {
  final double income;
  final double expense;
  final double balance;
  final double amountperdate;
  final double incomeperDate;
  final double expenseperDate;
  final String? currentDate;
  final List<Map<String, dynamic>> transactions;

  const ExpenseIncomePage({
    super.key,
    required this.income,
    required this.expense,
    required this.balance,
    required this.amountperdate,
    required this.incomeperDate,
    required this.expenseperDate,
    required this.currentDate,
    required this.transactions,
  });

  @override
  _ExpenseIncomePageState createState() => _ExpenseIncomePageState();
}

class _ExpenseIncomePageState extends State<ExpenseIncomePage> {
  final TextEditingController _budgetController = TextEditingController();
  double dailyBudget = 0;
  double remainingBudget = 0;
  double exceedingPercentage = 0;
  double income = 0;
  double expense = 0;
  double balance = 0;
  List<Map<String, dynamic>> transactions = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    String todayKey = '${today.year}-${today.month}-${today.day}';

    // ตรวจสอบและโหลดข้อมูลรายวัน
    if (prefs.containsKey('${todayKey}_dailyBudget')) {
      dailyBudget = prefs.getDouble('${todayKey}_dailyBudget') ?? 0.0;
      remainingBudget = prefs.getDouble('${todayKey}_remainingBudget') ?? 0.0;
      exceedingPercentage =
          prefs.getDouble('${todayKey}_exceedingPercentage') ?? 0.0;
    } else {
      dailyBudget = 0.0;
      remainingBudget = 0.0;
      exceedingPercentage = 0.0;
    }

    // เพิ่มการโหลดข้อมูลรายเดือน
    String monthKey = '${today.year}-${today.month}';
    income = prefs.getDouble('${monthKey}_income') ?? 0.0;
    expense = prefs.getDouble('${monthKey}_expense') ?? 0.0;
    balance = prefs.getDouble('${monthKey}_balance') ?? 0.0;

    // โหลด transactions สำหรับเดือนนี้
    String? transactionsJson = prefs.getString('transactions');
    if (transactionsJson != null) {
      List<dynamic> loadedTransactions = jsonDecode(transactionsJson);
      transactions = List<Map<String, dynamic>>.from(loadedTransactions);
    } else {
      transactions = [];
    }

    print(transactions);

    // อัปเดตค่าใน UI
    _budgetController.text = dailyBudget.toString();
    setState(() {});
  }

  Future<void> saveData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    String todayKey = '${today.year}-${today.month}-${today.day}';

    // บันทึกข้อมูลรายวัน
    await prefs.setDouble('${todayKey}_dailyBudget', dailyBudget);
    await prefs.setDouble('${todayKey}_remainingBudget', remainingBudget);
    await prefs.setDouble(
        '${todayKey}_exceedingPercentage', exceedingPercentage);

    // บันทึกข้อมูลรายเดือน
    String monthKey = '${today.year}-${today.month}';
    await prefs.setDouble('${monthKey}_income', income);
    await prefs.setDouble('${monthKey}_expense', expense);
    await prefs.setDouble('${monthKey}_balance', balance);
  }

  @override
  Widget build(BuildContext context) {
    List<String> dateParts = widget.currentDate?.split(' ') ?? [];
    if (dateParts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    String day = dateParts[1];
    String month = dateParts[2];
    String dayOfWeek = dateParts[0];

    remainingBudget = dailyBudget - widget.amountperdate;
    exceedingPercentage =
        dailyBudget > 0 ? ((widget.amountperdate / dailyBudget) * 100) : 0;

    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      'ยอดคงเหลือ: ${widget.balance}',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    Text(
                      'เดือน: $month',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      'รายได้: ${widget.income}',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    Text(
                      'รายจ่าย: ${widget.expense}',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _budgetController,
            decoration: const InputDecoration(
              labelText: 'กรอกงบประมาณรายวัน',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                dailyBudget = double.tryParse(value) ?? 0;
                remainingBudget = dailyBudget - widget.amountperdate;
                exceedingPercentage = dailyBudget > 0
                    ? ((widget.amountperdate / dailyBudget) * 100)
                    : 0;
                saveData();
              });
            },
          ),
          const SizedBox(height: 20),
          // Display the pie chart
          SizedBox(
            height: 200,
            child: PieChart(
              dataMap: {
                'ใช้จ่าย': widget.amountperdate,
                'เกินงบประมาณ': widget.amountperdate > dailyBudget
                    ? widget.amountperdate - dailyBudget
                    : 0,
                'เหลืองบประมาณ': remainingBudget > 0 ? remainingBudget : 0,
              },
              animationDuration: const Duration(milliseconds: 800),
              chartType: ChartType.ring,
              colorList: const [
                Colors.orangeAccent,
                Colors.redAccent,
                Colors.greenAccent,
              ],
              centerWidget: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "ค่าใช้จ่ายวันนี้",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${widget.amountperdate}",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${exceedingPercentage.toStringAsFixed(1)}%",
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
              ringStrokeWidth: 30,
              legendOptions: const LegendOptions(
                showLegends: false,
                legendPosition: LegendPosition.right,
              ),
              chartValuesOptions: const ChartValuesOptions(
                showChartValues: false,
                showChartValuesInPercentage: false,
                decimalPlaces: 1,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: widget.transactions.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              day,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(dayOfWeek),
                                Text(month),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Row(
                              children: [
                                Column(
                                  children: [
                                    const Text('รายรับ',
                                        style: TextStyle(fontSize: 16)),
                                    Text(
                                      '${widget.incomeperDate}',
                                      style: const TextStyle(
                                          color: Colors.green, fontSize: 16),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  children: [
                                    const Text('รายจ่าย',
                                        style: TextStyle(fontSize: 16)),
                                    Text(
                                      '${widget.expenseperDate}',
                                      style: const TextStyle(
                                          color: Colors.red, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }
                final transaction = widget.transactions[index - 1];
                return ListTile(
                  title: Text(transaction['category']),
                  trailing: Text(
                    '${transaction['isIncome'] ? '+' : '-'}${transaction['amount']}',
                    style: TextStyle(
                      color:
                          transaction['isIncome'] ? Colors.green : Colors.red,
                      fontSize: 16,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class overviewPageState extends StatefulWidget {
  @override
  _overviewPageState createState() => _overviewPageState();
}

class _overviewPageState extends State<overviewPageState> {
  double dailyIncome = 0.0;
  double dailyExpense = 0.0;
  double monthlyIncome = 0.0;
  double monthlyExpense = 0.0;
  Map<String, double> incomeCategories = {};
  Map<String, double> expenseCategories = {};
  Map<String, double> incomeCategoriesdate = {};
  Map<String, double> expenseCategoriesdate = {};
  bool showDaily = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    DateTime today = DateTime.now();
    String monthKey = '${today.year}-${today.month}';

    // โหลดข้อมูลการทำธุรกรรมทั้งหมดของเดือนนี้
    String? transactionData = prefs.getString('${monthKey}_transactions');
    print(transactionData);

    final List<dynamic> transactions =
        transactionData != null && transactionData.isNotEmpty
            ? jsonDecode(transactionData)
            : [];

    final todayDay = today.day;
    final todayMonth = today.month;

    double tempDailyIncome = 0.0;
    double tempDailyExpense = 0.0;
    double tempMonthlyIncome = 0.0;
    double tempMonthlyExpense = 0.0;

    Map<String, double> tempIncomeCategories = {};
    Map<String, double> tempExpenseCategories = {};
    Map<String, double> tempIncomeCategoriesdate = {};
    Map<String, double> tempExpenseCategoriesdate = {};

    for (var transaction in transactions) {
      final amount = (transaction['amount'] as num).toDouble();
      final category = transaction['category'] as String;
      final isIncome = transaction['isIncome'] as bool;
      final day = transaction['day'] as int;
      final month = transaction['month'] as int;

      if (isIncome) {
        if (day == todayDay && month == todayMonth) {
          tempDailyIncome += amount;
          tempIncomeCategoriesdate.update(
            category,
            (value) => value + amount,
            ifAbsent: () => amount,
          );
        }
        if (month == todayMonth) {
          tempMonthlyIncome += amount;
          tempIncomeCategories.update(
            category,
            (value) => value + amount,
            ifAbsent: () => amount,
          );
        }
      } else {
        if (day == todayDay && month == todayMonth) {
          tempDailyExpense += amount;
          tempExpenseCategoriesdate.update(
            category,
            (value) => value + amount,
            ifAbsent: () => amount,
          );
        }
        if (month == todayMonth) {
          tempMonthlyExpense += amount;
          tempExpenseCategories.update(
            category,
            (value) => value + amount,
            ifAbsent: () => amount,
          );
        }
      }
    }

    setState(() {
      dailyIncome = tempDailyIncome;
      dailyExpense = tempDailyExpense;
      monthlyIncome = tempMonthlyIncome;
      monthlyExpense = tempMonthlyExpense;
      incomeCategories = tempIncomeCategories;
      expenseCategories = tempExpenseCategories;
      incomeCategoriesdate = tempIncomeCategoriesdate;
      expenseCategoriesdate = tempExpenseCategoriesdate;
    });
  }

  List<Color> getIncomeColors(int count) {
    return List.generate(count, (index) {
      const baseIndex = 300;
      final colorIndex = baseIndex + (index * 50);
      return Color(0xFF0000FF - (colorIndex << 16));
    });
  }

  List<Color> getExpenseColors(int count) {
    return List.generate(count, (index) {
      const baseIndex = 300;
      final colorIndex = baseIndex + (index * 50);
      return Color(0xFFFF0000 - (colorIndex << 16));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    showDaily = true;
                    loadData();
                  }),
                  child: const Text('แสดงข้อมูลรายวัน'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    showDaily = false;
                    loadData();
                  }),
                  child: const Text('แสดงข้อมูลรายเดือน'),
                ),
              ],
            ),
            if (showDaily) ...[
              // ข้อมูลรายวัน
              Text('ข้อมูลรายรับรายวัน',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              incomeCategoriesdate.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PieChart(
                          dataMap: incomeCategoriesdate, // ข้อมูลรายวัน
                          colorList:
                              getIncomeColors(incomeCategoriesdate.length),
                          chartValuesOptions: const ChartValuesOptions(
                            showChartValuesInPercentage: true,
                            showChartValues: true,
                            showChartValueBackground: false,
                            showChartValuesOutside: false,
                          ),
                          chartRadius: MediaQuery.of(context).size.width / 2,
                          legendOptions: const LegendOptions(
                            showLegends: false,
                          ),
                        ),
                        ...incomeCategoriesdate.entries.map((entry) => Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  color: getIncomeColors(
                                          incomeCategoriesdate.length)[
                                      incomeCategoriesdate.keys
                                          .toList()
                                          .indexOf(entry.key)],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                    '${entry.key}: ${entry.value.toStringAsFixed(2)} บาท'),
                              ],
                            )),
                      ],
                    )
                  : const Text('ไม่มีข้อมูลรายรับรายวัน'),
              const SizedBox(height: 24),
              // ข้อมูลรายจ่ายรายวัน
              Text('ข้อมูลรายจ่ายรายวัน',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              expenseCategoriesdate.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PieChart(
                          dataMap: expenseCategoriesdate, // ข้อมูลรายวัน
                          colorList:
                              getExpenseColors(expenseCategoriesdate.length),
                          chartValuesOptions: const ChartValuesOptions(
                            showChartValuesInPercentage: true,
                            showChartValues: true,
                            showChartValueBackground: false,
                            showChartValuesOutside: false,
                          ),
                          chartRadius: MediaQuery.of(context).size.width / 2,
                          legendOptions: const LegendOptions(
                            showLegends: false,
                          ),
                        ),
                        ...expenseCategoriesdate.entries.map((entry) => Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  color: getExpenseColors(
                                          expenseCategoriesdate.length)[
                                      expenseCategoriesdate.keys
                                          .toList()
                                          .indexOf(entry.key)],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                    '${entry.key}: ${entry.value.toStringAsFixed(2)} บาท'),
                              ],
                            )),
                      ],
                    )
                  : const Text('ไม่มีข้อมูลรายจ่ายรายวัน'),
            ] else ...[
              // ข้อมูลรายเดือน
              Text('ข้อมูลรายรับรายเดือน',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              incomeCategories.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PieChart(
                          dataMap: incomeCategories, // ข้อมูลรายเดือน
                          colorList: getIncomeColors(incomeCategories.length),
                          chartValuesOptions: const ChartValuesOptions(
                            showChartValuesInPercentage: true,
                            showChartValues: true,
                            showChartValueBackground: false,
                            showChartValuesOutside: false,
                          ),
                          chartRadius: MediaQuery.of(context).size.width / 2,
                          legendOptions: const LegendOptions(
                            showLegends: false,
                          ),
                        ),
                        ...incomeCategories.entries.map((entry) => Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  color:
                                      getIncomeColors(incomeCategories.length)[
                                          incomeCategories.keys
                                              .toList()
                                              .indexOf(entry.key)],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                    '${entry.key}: ${entry.value.toStringAsFixed(2)} บาท'),
                              ],
                            )),
                      ],
                    )
                  : const Text('ไม่มีข้อมูลรายรับรายเดือน'),
              const SizedBox(height: 24),
              // ข้อมูลรายจ่ายรายเดือน
              Text('ข้อมูลรายจ่ายรายเดือน',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              expenseCategories.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PieChart(
                          dataMap: expenseCategories, // ข้อมูลรายเดือน
                          colorList: getExpenseColors(expenseCategories.length),
                          chartValuesOptions: const ChartValuesOptions(
                            showChartValuesInPercentage: true,
                            showChartValues: true,
                            showChartValueBackground: false,
                            showChartValuesOutside: false,
                          ),
                          chartRadius: MediaQuery.of(context).size.width / 2,
                          legendOptions: const LegendOptions(
                            showLegends: false,
                          ),
                        ),
                        ...expenseCategories.entries.map((entry) => Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  color: getExpenseColors(
                                          expenseCategories.length)[
                                      expenseCategories.keys
                                          .toList()
                                          .indexOf(entry.key)],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                    '${entry.key}: ${entry.value.toStringAsFixed(2)} บาท'),
                              ],
                            )),
                      ],
                    )
                  : const Text('ไม่มีข้อมูลรายจ่ายรายเดือน'),
            ],
          ],
        ),
      ),
    );
  }
}

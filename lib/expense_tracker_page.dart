import 'live_translated_text.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'local_storage_service.dart';
import 'cache_consistency_service.dart';
import 'api_client.dart';
import 'secure_token_storage.dart';

enum ExpenseCategory {
  rent,
  utilities,
  salary,
  supplies,
  maintenance,
  marketing,
  transport,
  other
}

class Expense {
  final String id;
  final ExpenseCategory category;
  final double amount;
  final String description;
  final DateTime date;
  final String? reference;
  final String? receipt;

  Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.description,
    required this.date,
    this.reference,
    this.receipt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'category': category.name,
    'amount': amount,
    'description': description,
    'date': date.toIso8601String(),
    'reference': reference,
    'receipt': receipt,
  };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
    id: map['id']?.toString() ?? '',
    category: ExpenseCategory.values.firstWhere(
      (e) => e.name == map['category'],
      orElse: () => ExpenseCategory.other,
    ),
    amount: double.tryParse(map['amount']?.toString() ?? '0') ?? 0,
    description: map['description']?.toString() ?? '',
    date: map['date'] != null 
      ? DateTime.parse(map['date'].toString())
      : DateTime.now(),
    reference: map['reference']?.toString(),
    receipt: map['receipt']?.toString(),
  );
}

class ExpenseTrackerPage extends StatefulWidget {
  const ExpenseTrackerPage({super.key});

  @override
  State<ExpenseTrackerPage> createState() => _ExpenseTrackerPageState();
}

class _ExpenseTrackerPageState extends State<ExpenseTrackerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Expense> _expenses = [];
  bool _isLoading = true;
  String? _loadWarning;
  String _filterBy = 'all'; // all, today, week, month
  ExpenseCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final localExpenses = await LocalStorageService.loadExpenses();
      final token = await SecureTokenStorage.getToken();
      var remoteLoaded = false;
      List<Map<String, dynamic>> remoteExpenses = [];

      if (token != null && token.isNotEmpty) {
        final response = await ApiClient.getJson(
          '/expenses?limit=500',
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final rawItems = decoded is List
              ? decoded
              : decoded is Map
                  ? (decoded['expenses'] ?? decoded['results'])
                  : null;
          if (rawItems is! List) {
            throw const FormatException(
              'Expense response did not contain an expense list.',
            );
          }

          remoteExpenses = rawItems.whereType<Map>().map((raw) {
            final item = Map<String, dynamic>.from(raw);
            final serverId =
                item['id'] ?? item['expense_id'] ?? item['server_id'];
            final dateValue =
                item['expense_date'] ?? item['date'] ?? item['created_at'];
            return <String, dynamic>{
              ...item,
              if (serverId != null) 'id': serverId.toString(),
              if (serverId != null) 'server_id': serverId.toString(),
              if (serverId != null) 'expense_id': serverId.toString(),
              'date': dateValue?.toString() ?? DateTime.now().toIso8601String(),
              'sync_status': 'synced',
              'is_synced': true,
            };
          }).toList();
          remoteLoaded = true;
        }
      }

      // A page of 500 remote expenses is not permission to replace the local
      // ledger. Merge by expense identity and retain unmatched local writes.
      final merged = CacheConsistencyService.mergeLists(
        localExpenses,
        remoteExpenses,
        dataset: 'expenses',
      );

      if (remoteLoaded) {
        final confirmedServerIds = remoteExpenses
            .map((row) => row['server_id'] ?? row['id'])
            .where((value) => value != null)
            .map((value) => value.toString())
            .toSet();
        for (final row in merged) {
          final serverId =
              (row['server_id'] ?? row['expense_id'] ?? '').toString();
          if (serverId.isNotEmpty && confirmedServerIds.contains(serverId)) {
            row['sync_status'] = 'synced';
            row['is_synced'] = true;
            row.remove('is_offline');
            row.remove('pending_sync');
          }
        }
        await LocalStorageService.saveExpenses(merged);
      }

      final parsedExpenses = merged.map((raw) {
        final row = Map<String, dynamic>.from(raw);
        row['date'] ??=
            row['expense_date'] ?? row['created_at'] ?? DateTime.now().toIso8601String();
        return Expense.fromMap(row);
      }).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _expenses = parsedExpenses;
          _loadWarning = remoteLoaded
              ? null
              : 'Showing device-saved expenses. Server records will be merged when connection is restored.';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error reconciling expenses: $e');
      try {
        final expenses = await LocalStorageService.loadExpenses();
        final parsedExpenses = expenses.map((raw) {
          final row = Map<String, dynamic>.from(raw as Map);
          row['date'] ??=
              row['expense_date'] ?? row['created_at'] ?? DateTime.now().toIso8601String();
          return Expense.fromMap(row);
        }).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        if (mounted) {
          setState(() {
            _loadWarning =
                'Server could not be reached. Showing all device-saved expenses; they have not been discarded.';
            _expenses = parsedExpenses;
            _isLoading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  List<Expense> _getFilteredExpenses() {
    var filtered = _expenses;

    // Filter by category
    if (_selectedCategory != null) {
      filtered = filtered.where((e) => e.category == _selectedCategory).toList();
    }

    // Filter by date range
    final now = DateTime.now();
    switch (_filterBy) {
      case 'today':
        filtered = filtered.where((e) =>
            e.date.year == now.year &&
            e.date.month == now.month &&
            e.date.day == now.day).toList();
        break;
      case 'week':
        final weekAgo = now.subtract(const Duration(days: 7));
        filtered = filtered.where((e) =>
            e.date.isAfter(weekAgo) && e.date.isBefore(now.add(const Duration(days: 1))))
            .toList();
        break;
      case 'month':
        filtered = filtered.where((e) =>
            e.date.year == now.year && e.date.month == now.month).toList();
        break;
    }

    return filtered;
  }

  double _getTotalExpenses(List<Expense> expenses) {
    return expenses.fold(0, (sum, e) => sum + e.amount);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: LiveTranslatedText('Expense Tracker', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddExpenseDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadExpenses,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_loadWarning != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: LiveTranslatedText(
                      _loadWarning!,
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.brown.shade800),
                    ),
                  ),
                // Summary Card
                _buildSummaryCard(),
                
                // Filter Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Today', 'today'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Week', 'week'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Month', 'month'),
                      ],
                    ),
                  ),
                ),

                // Expenses List
                Expanded(
                  child: _buildExpensesList(),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard() {
    final filtered = _getFilteredExpenses();
    final total = _getTotalExpenses(filtered);
    
    // Calculate by category
    final byCategory = <ExpenseCategory, double>{};
    for (var category in ExpenseCategory.values) {
      byCategory[category] = filtered
          .where((e) => e.category == category)
          .fold(0, (sum, e) => sum + e.amount);
    }

    final topCategory = byCategory.entries
        .reduce((a, b) => a.value > b.value ? a : b);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LiveTranslatedText(
            _filterBy == 'all' ? 'Total Expenses' : 'Expenses (${_filterBy})',
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          LiveTranslatedText(
            '₹${total.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LiveTranslatedText(
                    'Top Category',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  LiveTranslatedText(
                    topCategory.key.name.toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  LiveTranslatedText(
                    'Count',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  LiveTranslatedText(
                    '${filtered.length}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterBy == value;
    
    return FilterChip(
      label: LiveTranslatedText(label, style: GoogleFonts.poppins()),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterBy = value);
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF6366F1),
      labelStyle: GoogleFonts.poppins(
        color: isSelected ? Colors.white : Colors.grey.shade600,
        fontWeight: FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildExpensesList() {
    final filtered = _getFilteredExpenses();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            LiveTranslatedText('No expenses', style: GoogleFonts.poppins()),
          ],
        ),
      );
    }

    // Group by date
    final grouped = <String, List<Expense>>{};
    for (var expense in filtered) {
      final key = DateFormat('MMM dd, yyyy').format(expense.date);
      grouped.putIfAbsent(key, () => []).add(expense);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final date = grouped.keys.toList()[index];
        final expenses = grouped[date]!;
        final dayTotal = _getTotalExpenses(expenses);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  LiveTranslatedText(
                    date,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  LiveTranslatedText(
                    '₹${dayTotal.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
            ),
            ...expenses.map((expense) => _buildExpenseCard(expense)),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    final categoryColors = {
      ExpenseCategory.rent: Colors.blue,
      ExpenseCategory.utilities: Colors.green,
      ExpenseCategory.salary: Colors.purple,
      ExpenseCategory.supplies: Colors.orange,
      ExpenseCategory.maintenance: Colors.red,
      ExpenseCategory.marketing: Colors.pink,
      ExpenseCategory.transport: Colors.cyan,
      ExpenseCategory.other: Colors.grey,
    };

    final categoryIcons = {
      ExpenseCategory.rent: Icons.home,
      ExpenseCategory.utilities: Icons.electrical_services,
      ExpenseCategory.salary: Icons.person,
      ExpenseCategory.supplies: Icons.shopping_bag,
      ExpenseCategory.maintenance: Icons.build,
      ExpenseCategory.marketing: Icons.campaign,
      ExpenseCategory.transport: Icons.local_shipping,
      ExpenseCategory.other: Icons.more_horiz,
    };

    final color = categoryColors[expense.category] ?? Colors.grey;
    final icon = categoryIcons[expense.category] ?? Icons.receipt;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LiveTranslatedText(
                    expense.description,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  LiveTranslatedText(
                    expense.category.name,
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                LiveTranslatedText(
                  '₹${expense.amount.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                LiveTranslatedText(
                  DateFormat('HH:mm').format(expense.date),
                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddExpenseDialog() async {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    var selectedCategory = ExpenseCategory.other;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: LiveTranslatedText('Add Expense', style: GoogleFonts.poppins()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    hint: LiveTranslatedText('Description'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hint: LiveTranslatedText('Amount'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButton<ExpenseCategory>(
                  value: selectedCategory,
                  isExpanded: true,
                  items: ExpenseCategory.values
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: LiveTranslatedText(e.name),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedCategory = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const LiveTranslatedText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final amount = double.tryParse(amountController.text.trim());
                  final description = descriptionController.text.trim();
                  if (amount == null || !amount.isFinite || amount <= 0 || description.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: LiveTranslatedText('Enter a description and an amount greater than zero.')),
                    );
                    return;
                  }

                  final expenseId =
                      DateTime.now().microsecondsSinceEpoch.toString();
                  final expense = Expense(
                    id: expenseId,
                    category: selectedCategory,
                    amount: amount,
                    description: description,
                    date: DateTime.now(),
                  );
                  final operationId = 'expense_$expenseId';
                  final localRecord = <String, dynamic>{
                    ...expense.toMap(),
                    'local_id': expenseId,
                    'operation_id': operationId,
                    'sync_status': 'pending',
                    'is_synced': false,
                    'local_updated_at': DateTime.now().toUtc().toIso8601String(),
                  };

                  // Commit locally before attempting HTTP. A network timeout
                  // must not undo a cashier's expense entry.
                  final expenses = await LocalStorageService.loadExpenses();
                  expenses.add(localRecord);
                  await LocalStorageService.saveExpenses(expenses);

                  final token = await SecureTokenStorage.getToken();
                  var serverConfirmed = false;
                  String? serverId;
                  if (token != null && token.isNotEmpty) {
                    try {
                      final response = await ApiClient.postJson(
                        '/expenses',
                        {
                          'category': selectedCategory.name,
                          'amount': amount,
                          'description': description,
                          'expense_date':
                              DateFormat('yyyy-MM-dd').format(expense.date),
                        },
                        headers: {'Authorization': 'Bearer $token'},
                      ).timeout(const Duration(seconds: 12));

                      if (response.statusCode >= 200 &&
                          response.statusCode < 300) {
                        try {
                          final decoded = jsonDecode(response.body);
                          final payload = decoded is Map && decoded['expense'] is Map
                              ? Map<String, dynamic>.from(decoded['expense'])
                              : decoded is Map
                                  ? Map<String, dynamic>.from(decoded)
                                  : <String, dynamic>{};
                          final value = payload['id'] ??
                              payload['expense_id'] ??
                              payload['server_id'];
                          if (value != null) serverId = value.toString();
                        } catch (_) {
                          // An empty success body cannot prove the server ID.
                        }
                        serverConfirmed = serverId != null && serverId!.isNotEmpty;
                      } else {
                        debugPrint(
                          'Expense HTTP ${response.statusCode}; local copy retained.',
                        );
                      }
                    } catch (error) {
                      debugPrint('Expense sync pending after request error: $error');
                    }
                  }

                  final latest = await LocalStorageService.loadExpenses();
                  final rowIndex = latest.indexWhere((raw) {
                    if (raw is! Map) return false;
                    final row = Map<String, dynamic>.from(raw);
                    return row['operation_id'] == operationId ||
                        row['local_id']?.toString() == expenseId;
                  });
                  if (rowIndex >= 0) {
                    final row = Map<String, dynamic>.from(latest[rowIndex] as Map);
                    if (serverConfirmed) {
                      row['id'] = serverId;
                      row['server_id'] = serverId;
                      row['expense_id'] = serverId;
                      row['sync_status'] = 'synced';
                      row['is_synced'] = true;
                      row.remove('is_offline');
                      row.remove('pending_sync');
                    } else {
                      row['sync_status'] = 'pending_confirmation';
                      row['is_synced'] = false;
                    }
                    row['updated_at'] = DateTime.now().toUtc().toIso8601String();
                    latest[rowIndex] = row;
                    await LocalStorageService.saveExpenses(latest);
                  }

                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: LiveTranslatedText(
                        serverConfirmed
                            ? 'Expense saved and confirmed on the server.'
                            : 'Expense saved on this device. Server confirmation is pending; the record has not been discarded.',
                      ),
                    ),
                  );
                  await _loadExpenses();

                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: LiveTranslatedText('Could not save expense: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
              child: const LiveTranslatedText('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'live_translated_text.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'local_storage_service.dart';
import 'visual_widgets.dart';
import 'inventory_stock_helper.dart';
import 'sync_queue_manager.dart';
import 'sync_service.dart';

class ReturnsPage extends StatefulWidget {
  const ReturnsPage({super.key});

  @override
  State<ReturnsPage> createState() => _ReturnsPageState();
}

class _ReturnsPageState extends State<ReturnsPage>
    with SingleTickerProviderStateMixin {
  // Modern SaaS Colors - synced with visual_widgets.dart
  static const Color _primary = AppColors.primary; // #635BFF

  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _returns = [];
  bool _loading = true;
  late TabController _tabController;
  late TextEditingController _phoneController;
  String _selectedInvoiceId = '';

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final sales = await LocalStorageService.loadSales();
      final returns = await LocalStorageService.loadSalesReturns();

      setState(() {
        _sales = sales
            .whereType<Map>()
            .map((s) => Map<String, dynamic>.from(s))
            .toList();
        _returns = returns
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: LiveTranslatedText('Error: $e')));
      setState(() => _loading = false);
    }
  }

  static double _num(dynamic v, [double fallback = 0]) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? fallback;
  }

  static double _round2(double v) => double.parse(v.toStringAsFixed(2));

  /// Quantity of [productName] already returned against [invoiceId].
  double _alreadyReturnedQty(String invoiceId, String productName) {
    final key = productName.trim().toLowerCase();
    var total = 0.0;
    for (final r in _returns) {
      if ((r['original_invoice_id'] ?? '').toString() != invoiceId) continue;
      if ((r['product_name'] ?? '').toString().trim().toLowerCase() != key) {
        continue;
      }
      total += _num(r['quantity_returned']);
    }
    return total;
  }

  /// Credit owed for returning [quantity] of a sold line. Uses the stored
  /// line total (discount applied, tax included) so the credit note matches
  /// what the customer was actually charged — not qty x unit price.
  static double _creditForQuantity(Map<String, dynamic> item, double quantity) {
    final qty = _num(item['qty'] ?? item['quantity'], 1);
    if (qty <= 0) return 0;
    final lineBasis = _num(
      item['total_with_tax'] ?? item['line_total'] ?? item['total'],
      -1,
    );
    final unitCredit = lineBasis >= 0
        ? lineBasis / qty
        : _num(item['unit_price'] ?? item['price']);
    return _round2(unitCredit * quantity);
  }

  Future<void> _processReturn({
    required String invoiceId,
    required String productName,
    required double quantity,
    required Map<String, dynamic> saleItem,
    String? reason,
  }) async {
    if (!mounted) return;

    final originalSale = _sales.firstWhere(
      (s) => (s['sale_id'] ?? s['id'] ?? '').toString() == invoiceId,
      orElse: () => <String, dynamic>{},
    );

    if (originalSale.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LiveTranslatedText('Original invoice not found'),
        ),
      );
      return;
    }

    // Validate against quantity actually sold minus prior returns.
    final soldQty = _num(saleItem['qty'] ?? saleItem['quantity'], 1);
    final alreadyReturned = _alreadyReturnedQty(invoiceId, productName);
    final remainingQty = soldQty - alreadyReturned;
    if (!quantity.isFinite ||
        quantity <= 0 ||
        quantity > remainingQty + 0.001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LiveTranslatedText(
            'Cannot return ₹${quantity} — only ${remainingQty.toStringAsFixed(2)} remaining of $productName.',
          ),
        ),
      );
      return;
    }

    final credit = _creditForQuantity(saleItem, quantity);

    final returnRecord = {
      'return_id': 'RET-${DateTime.now().millisecondsSinceEpoch}',
      'original_invoice_id': invoiceId,
      'product_name': productName,
      'product_id': saleItem['product_id'] ?? saleItem['id'],
      'unit': saleItem['unit'] ?? saleItem['unit_name'],
      'quantity_returned': quantity,
      'sold_quantity': soldQty,
      'return_amount': credit,
      'reason': reason ?? 'Damage/Defect',
      'original_amount': originalSale['total'],
      'customer_name': originalSale['customer_name'],
      'customer_phone': originalSale['customer_phone'],
      'return_date': DateTime.now().toUtc().toIso8601String(),
      'status': 'PROCESSED',
      'credit_note_generated': true,
    };

    // Durable persistence first — a return must survive restarts.
    await LocalStorageService.saveSalesReturn(returnRecord);

    // Record the return against the sale so revenue and stock stay consistent.
    try {
      final sales = await LocalStorageService.loadSales();
      final saleIdx = sales.indexWhere(
        (s) =>
            s is Map && (s['sale_id'] ?? s['id'] ?? '').toString() == invoiceId,
      );
      if (saleIdx >= 0 && sales[saleIdx] is Map) {
        final sale = Map<String, dynamic>.from(sales[saleIdx] as Map);
        final items = sale['items'];
        if (items is List) {
          final key = productName.trim().toLowerCase();
          for (final raw in items) {
            if (raw is! Map) continue;
            final itemName =
                (raw['product_name'] ?? raw['name'] ?? raw['item'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();
            if (itemName != key) continue;
            final prevQty = _num(raw['returned_qty']);
            final prevAmt = _num(raw['returned_amount']);
            raw['returned_qty'] = _round2(prevQty + quantity);
            raw['returned_amount'] = _round2(prevAmt + credit);
            break;
          }
        }
        final prevReturned = _num(sale['returned_amount']);
        sale['returned_amount'] = _round2(prevReturned + credit);
        final totalReturnedQty = _num(sale['returned_qty']) + quantity;
        sale['returned_qty'] = _round2(totalReturnedQty);
        final invoiceTotal = _num(
          sale['total_amount'] ?? sale['total'] ?? sale['grand_total'],
        );
        sale['return_status'] =
            totalReturnedQty > 0 &&
                (invoiceTotal <= 0 ||
                    prevReturned + credit >= invoiceTotal - 0.01)
            ? 'RETURNED'
            : 'PARTIALLY_RETURNED';
        sale['updated_at'] = DateTime.now().toUtc().toIso8601String();
        sales[saleIdx] = sale;
        await LocalStorageService.replaceSalesCanonical(sales);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: LiveTranslatedText(
              'Return saved locally; sale update failed: $e',
            ),
          ),
        );
      }
    }

    // Restore stock through the shared helper on BOTH catalog copies, then
    // enqueue a durable backend update so server stock does not stay deducted.
    try {
      await _restoreStockForReturn(
        saleItem,
        quantity,
        returnRecord['return_id'].toString(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: LiveTranslatedText(
              'Return saved; stock sync needs attention: $e',
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _returns.add(returnRecord));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LiveTranslatedText(
            'Return processed! Credit Note: ${returnRecord['return_id']} — ₹${credit.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    }
  }

  /// Adds returned quantity back to local + backend product caches and queues
  /// a backend product update when the product has a server identity.
  Future<void> _restoreStockForReturn(
    Map<String, dynamic> saleItem,
    double quantity,
    String returnId,
  ) async {
    final productId = int.tryParse(
      (saleItem['product_id'] ?? saleItem['id'] ?? '').toString(),
    );
    final name = (saleItem['product_name'] ?? saleItem['name'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (productId == null && name.isEmpty) return;

    String norm(Map<String, dynamic> p) =>
        (p['product_name'] ?? p['name'] ?? '').toString().trim().toLowerCase();

    // Backend product cache.
    final backend = await LocalStorageService.loadBackendProducts();
    int backendIdx = -1;
    Map<String, dynamic>? backendHit;
    for (var i = 0; i < backend.length; i++) {
      final raw = backend[i];
      final p = Map<String, dynamic>.from(raw);
      final pid = int.tryParse(
        (p['id'] ?? p['product_id'] ?? p['backend_id'] ?? '').toString(),
      );
      if ((productId != null && pid == productId) ||
          (name.isNotEmpty && norm(p) == name)) {
        backendIdx = i;
        backendHit = p;
        break;
      }
    }
    if (backendHit != null) {
      InventoryStockHelper.writeStock(
        backendHit,
        InventoryStockHelper.readStock(backendHit) + quantity,
      );
      backend[backendIdx] = backendHit;
      await LocalStorageService.saveBackendProducts(backend);

      final serverId = int.tryParse(
        (backendHit['id'] ?? backendHit['backend_id'] ?? '').toString(),
      );
      if (serverId != null && serverId > 0) {
        final userId = backendHit['user_id'];
        await SyncQueueManager.enqueue('update_local_product', {
          'id': serverId,
          'user_id': userId,
          'operation_id': 'RETURN_STOCK_$returnId',
          'payload': Map<String, dynamic>.from(backendHit),
        });
        unawaited(SyncService.processQueueSafe());
      }
    }

    // Local-only product cache.
    final local = await LocalStorageService.loadLocalProducts();
    var localChanged = false;
    for (final raw in local.values) {
      if (raw is! Map) continue;
      final p = Map<String, dynamic>.from(raw);
      final pid = int.tryParse((p['id'] ?? p['product_id'] ?? '').toString());
      if ((productId != null && pid == productId) ||
          (name.isNotEmpty && norm(p) == name)) {
        InventoryStockHelper.writeStock(
          p,
          InventoryStockHelper.readStock(p) + quantity,
        );
        // Write the updated fields back onto the stored map.
        for (final entry in p.entries) {
          raw[entry.key] = entry.value;
        }
        localChanged = true;
      }
    }
    if (localChanged) await LocalStorageService.saveLocalProducts(local);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const LiveTranslatedText('Returns & Credit Notes'),
          backgroundColor: _primary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final totalReturned = _returns.fold<double>(
      0,
      (sum, r) => sum + (r['return_amount'] as double? ?? 0),
    );
    final returnCount = _returns.length;

    return Scaffold(
      appBar: AppBar(
        title: const LiveTranslatedText('Returns & Credit Notes'),
        backgroundColor: _primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Create Return'),
            Tab(text: 'Returns History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Create Return Tab
          _buildCreateReturnTab(),

          // Returns History Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // KPI Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildKPICard(
                        'Total Returns',
                        '₹${totalReturned.toStringAsFixed(0)}',
                        Colors.orange,
                        Icons.undo,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKPICard(
                        'Return Count',
                        '$returnCount',
                        Colors.blue,
                        Icons.receipt,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Returns List
                LiveTranslatedText(
                  'Return History',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ..._buildReturnsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateReturnTab() {
    if (_sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            LiveTranslatedText(
              'No Sales Found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            LiveTranslatedText(
              'Create a sale first to process returns',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phone Number Input
          LiveTranslatedText(
            'Enter Phone Number',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() => _selectedInvoiceId = ''),
            decoration: InputDecoration(
              hint: LiveTranslatedText('Enter customer phone (10 digits)'),
              prefixIcon: const Icon(Icons.phone_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 20),

          LiveTranslatedText(
            'Select Original Invoice (Last 3)',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Filter invoices by phone and get last 3
          Builder(
            builder: (context) {
              final phone = _phoneController.text.trim();
              final filteredSales = phone.isEmpty
                  ? []
                  : _sales
                        .where(
                          (sale) =>
                              sale['customer_phone']?.toString().contains(
                                phone,
                              ) ??
                              false,
                        )
                        .toList()
                        .reversed
                        .take(3)
                        .toList();

              if (phone.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_rounded, color: Colors.amber.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LiveTranslatedText(
                          'Enter phone number to see available invoices',
                          style: GoogleFonts.poppins(
                            color: Colors.amber.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (filteredSales.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LiveTranslatedText(
                          'No invoices found for this phone number',
                          style: GoogleFonts.poppins(
                            color: Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Invoice Selection
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedInvoiceId.isEmpty ? null : _selectedInvoiceId,
                  items: filteredSales.map((sale) {
                    final invoiceId =
                        sale['sale_id'] ?? sale['id'] ?? 'Unknown';
                    final customerName = sale['customer_name'] ?? 'Guest';
                    final amount = sale['total'] ?? 0;

                    return DropdownMenuItem(
                      value: invoiceId.toString(),
                      child: LiveTranslatedText(
                        '$invoiceId - $customerName (₹$amount)',
                      ),
                    );
                  }).toList(),
                  onChanged: (val) =>
                      setState(() => _selectedInvoiceId = val ?? ''),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: InputBorder.none,
                    hint: LiveTranslatedText('Choose invoice'),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          if (_selectedInvoiceId.isNotEmpty) ...[
            _buildReturnForm(),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Center(
                child: LiveTranslatedText(
                  'Select an invoice above to create a return',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReturnForm() {
    final sale = _sales.firstWhere(
      (s) => (s['sale_id'] ?? s['id'] ?? '').toString() == _selectedInvoiceId,
      orElse: () => {},
    );

    if (sale.isEmpty) return const SizedBox.shrink();

    final items = (sale['items'] as List?) ?? [];

    return Column(
      children: [
        // Original Invoice Details
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  LiveTranslatedText(
                    'Invoice',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  LiveTranslatedText(
                    _selectedInvoiceId,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  LiveTranslatedText(
                    'Customer',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  LiveTranslatedText(
                    sale['customer_name'] ?? 'Other',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  LiveTranslatedText(
                    'Total Amount',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  LiveTranslatedText(
                    '₹${sale['total']}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Product Selection for Return
        LiveTranslatedText(
          'Select Product to Return',
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...items.map((entry) {
          final item = entry as Map;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: InkWell(
              onTap: () => _showReturnDialog(
                invoiceId: _selectedInvoiceId,
                productName: item['product_name']?.toString() ?? 'Unknown',
                saleItem: Map<String, dynamic>.from(item),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LiveTranslatedText(
                          item['product_name']?.toString() ?? 'Unknown',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        LiveTranslatedText(
                          'Qty: ${item['qty']} @ ₹${item['price']}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: _primary),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  void _showReturnDialog({
    required String invoiceId,
    required String productName,
    required Map<String, dynamic> saleItem,
  }) {
    final soldQty = _num(saleItem['qty'] ?? saleItem['quantity'], 1);
    final alreadyReturned = _alreadyReturnedQty(invoiceId, productName);
    final remainingQty = soldQty - alreadyReturned;
    double returnQty = remainingQty > 0 ? remainingQty : 1;
    String reason = 'Damage/Defect';
    final qtyCtrl = TextEditingController(text: returnQty.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: LiveTranslatedText("Return $productName"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  label: LiveTranslatedText(
                    'Quantity to Return (max ${remainingQty.toStringAsFixed(2)})',
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (val) =>
                    setState(() => returnQty = double.tryParse(val) ?? 0),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: reason,
                items:
                    [
                          'Damage/Defect',
                          'Wrong Item',
                          'Customer Return',
                          'Expired',
                          'Other',
                        ]
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: LiveTranslatedText(r),
                          ),
                        )
                        .toList(),
                onChanged: (val) =>
                    setState(() => reason = val ?? 'Damage/Defect'),
                decoration: InputDecoration(
                  label: LiveTranslatedText('Return Reason'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              LiveTranslatedText(
                'Return Amount: ₹${_creditForQuantity(saleItem, returnQty.isFinite && returnQty > 0 ? returnQty : 0).toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _primary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const LiveTranslatedText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _processReturn(
                  invoiceId: invoiceId,
                  productName: productName,
                  quantity: returnQty,
                  saleItem: saleItem,
                  reason: reason,
                );
                _tabController.animateTo(1);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
              child: const LiveTranslatedText('Process Return'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildReturnsList() {
    return _returns.isEmpty
        ? [
            Center(
              child: LiveTranslatedText(
                'No returns yet',
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
            ),
          ]
        : _returns.map((returnData) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      LiveTranslatedText(
                        returnData['return_id']?.toString() ?? 'Unknown',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: LiveTranslatedText(
                          'PROCESSED',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LiveTranslatedText(
                    'Invoice: ${returnData['original_invoice_id']}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  LiveTranslatedText(
                    'Product: ${returnData['product_name']} (Qty: ${returnData['quantity_returned']})',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  LiveTranslatedText(
                    'Reason: ${returnData['reason']}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      LiveTranslatedText(
                        DateFormat('yyyy-MM-dd').format(
                          DateTime.parse(
                            returnData['return_date']?.toString() ?? '',
                          ),
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      LiveTranslatedText(
                        '₹${returnData['return_amount']}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList();
  }

  Widget _buildKPICard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          LiveTranslatedText(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          LiveTranslatedText(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

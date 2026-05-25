import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/w_widgets.dart';
import '../../providers/app_provider.dart';
import '../../models/transaction.dart';
import '../../services/data_services.dart';

String _translateCat(String? name, bool isRo) {
  if (!isRo || name == null) return name ?? '';
  switch (name.toLowerCase()) {
    case 'food':          return 'Alimente';
    case 'home':          return 'Locuință';
    case 'transport':     return 'Transport';
    case 'entertainment': return 'Divertisment';
    case 'clothing':      return 'Îmbrăcăminte';
    case 'health':        return 'Sănătate';
    case 'education':     return 'Studii';
    case 'other':         return 'Altele';
    case 'salary':        return 'Salariu';
    case 'freelancing':   return 'Freelancing';
    case 'investments':   return 'Investiții';
    case 'gift':          return 'Cadou';
    default:              return name;
  }
}

class TransactionsTab extends StatefulWidget {
  const TransactionsTab({super.key});

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  String _filter = 'all';
  final _searchCtrl = TextEditingController();

  final _expenseCategories = <Map<String, dynamic>>[
    {'id': 1,  'name': 'Alimente',     'nameEn': 'Food',          'icon': 'assets/images/food.png'},
    {'id': 2,  'name': 'Locuință',     'nameEn': 'Home',          'icon': 'assets/images/home.png'},
    {'id': 3,  'name': 'Transport',    'nameEn': 'Transport',     'icon': 'assets/images/transport.png'},
    {'id': 4,  'name': 'Divertisment', 'nameEn': 'Entertainment', 'icon': 'assets/images/relax.png'},
    {'id': 5,  'name': 'Îmbrăcăminte','nameEn': 'Clothing',      'icon': 'assets/images/clothing.png'},
    {'id': 6,  'name': 'Sănătate',     'nameEn': 'Health',        'icon': 'assets/images/healthcare.png'},
    {'id': 7,  'name': 'Studii',       'nameEn': 'Education',     'icon': 'assets/images/study.png'},
    {'id': 12, 'name': 'Altele',       'nameEn': 'Other',         'icon': 'assets/images/cash-flow.png'},
  ];

  final _incomeCategories = <Map<String, dynamic>>[
    {'id': 13, 'name': 'Salariu',     'nameEn': 'Salary',      'icon': 'assets/images/cash-flow.png'},
    {'id': 14, 'name': 'Freelancing', 'nameEn': 'Freelancing', 'icon': 'assets/images/business_16102900.png'},
    {'id': 15, 'name': 'Investiții',  'nameEn': 'Investments', 'icon': 'assets/images/financial-planning.png'},
    {'id': 16, 'name': 'Cadou',       'nameEn': 'Gift',        'icon': 'assets/images/calendar.png'},
    {'id': 17, 'name': 'Altele',      'nameEn': 'Other',       'icon': 'assets/images/cash-flow.png'},
  ];

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final s    = p.s;
    final isRo = p.isRo;

    List<Transaction> filtered = List.from(p.transactions);
    if (_filter == 'income') {
      filtered = filtered.where((t) => t.isIncome).toList();
    } else if (_filter == 'expense') {
      filtered = filtered.where((t) => !t.isIncome).toList();
    }

    final query = _searchCtrl.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((t) {
        final desc = (t.description ?? '').toLowerCase();
        final cat  = _translateCat(t.category?.name, isRo).toLowerCase();
        return desc.contains(query) || cat.contains(query);
      }).toList();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // header gradient
            Container(
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/tranzactii.png',
                    height: 44,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.transactions,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showTransactionSheet(context, null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(s.add,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // search + filtre
            Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: isRo ? 'Caută tranzacții...' : 'Search transactions...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _filterChip(isRo ? 'Toate' : 'All',         'all'),
                      const SizedBox(width: 8),
                      _filterChip(isRo ? 'Venituri' : 'Income',   'income'),
                      const SizedBox(width: 8),
                      _filterChip(isRo ? 'Cheltuieli' : 'Expenses','expense'),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),

            // lista
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => p.refreshTransactions(),
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('💳', style: TextStyle(fontSize: 52)),
                            const SizedBox(height: 12),
                            Text(
                              p.transactions.isEmpty
                                  ? (isRo ? 'Nicio tranzacție încă' : 'No transactions yet')
                                  : (isRo ? 'Niciun rezultat' : 'No results'),
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                  fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final tx = filtered[i];
                          return _TxTile(
                            tx: tx,
                            isRo: isRo,
                            onEdit: () => _showTransactionSheet(context, tx),
                            onDelete: () => _confirmDelete(context, tx, p),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Transaction tx, AppProvider p) {
    final s = p.s;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(p.isRo ? 'Șterge tranzacție' : 'Delete transaction'),
        content: Text(p.isRo
            ? 'Ești sigur că vrei să ștergi această tranzacție?'
            : 'Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx), child: Text(s.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await TransactionService.deleteTransaction(tx.id);
                await p.refreshTransactions();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: Text(s.delete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showTransactionSheet(BuildContext context, Transaction? existing) {
    final p      = context.read<AppProvider>();
    final s      = p.s;
    final isRo   = p.isRo;
    final isEdit = existing != null;

    final amountCtrl = TextEditingController(
        text: isEdit ? existing.amount.toStringAsFixed(0) : '');
    final descCtrl = TextEditingController(
        text: isEdit ? (existing.description ?? '') : '');

    String type = isEdit ? (existing.isIncome ? 'income' : 'expense') : 'expense';

    final allCats = [..._expenseCategories, ..._incomeCategories];
    Map<String, dynamic>? selectedCategory;

    if (isEdit && existing.category != null) {
      final match = allCats.where((c) => c['id'] == existing.category!.id).toList();
      if (match.isNotEmpty) selectedCategory = Map<String, dynamic>.from(match.first);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) {
          final cats = type == 'expense' ? _expenseCategories : _incomeCategories;
          if (selectedCategory == null ||
              !cats.any((c) => c['id'] == selectedCategory!['id'])) {
            selectedCategory = Map<String, dynamic>.from(cats.first);
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isEdit
                        ? (isRo ? 'Editează tranzacția' : 'Edit transaction')
                        : (isRo ? 'Adaugă tranzacție' : 'Add transaction'),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(ctx).colorScheme.onSurface),
                  ),
                  const SizedBox(height: 20),

                  // toggle cheltuiala / venit
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => set(() { type = 'expense'; selectedCategory = null; }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: type == 'expense'
                                  ? AppColors.expense
                                  : AppColors.expense.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                isRo ? '💳 Cheltuială' : '💳 Expense',
                                style: TextStyle(
                                    color: type == 'expense' ? Colors.white : AppColors.expense,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => set(() { type = 'income'; selectedCategory = null; }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: type == 'income'
                                  ? AppColors.income
                                  : AppColors.income.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                isRo ? 'Venit' : 'Income',
                                style: TextStyle(
                                    color: type == 'income' ? Colors.white : AppColors.income,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(isRo ? 'Categorie' : 'Category',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: cats.map((cat) {
                      final isSel = selectedCategory?['id'] == cat['id'];
                      final catLabel = isRo ? cat['name'] : cat['nameEn'];
                      return GestureDetector(
                        onTap: () => set(() => selectedCategory = Map<String, dynamic>.from(cat)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel ? AppColors.primary : AppColors.primary.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSel ? AppColors.primary : AppColors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(cat['icon'], width: 18, height: 18,
                                  errorBuilder: (_, __, ___) => const SizedBox()),
                              const SizedBox(width: 5),
                              Text(catLabel,
                                  style: TextStyle(
                                      color: isSel ? Colors.white : AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      labelText: isRo ? 'Sumă (MDL)' : 'Amount (MDL)',
                      prefixIcon: const Icon(Icons.attach_money),
                      filled: true,
                      fillColor: AppColors.backgroundLight,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: descCtrl,
                    maxLength: 200,
                    decoration: InputDecoration(
                      labelText: isRo ? 'Descriere (opțional)' : 'Description (optional)',
                      prefixIcon: const Icon(Icons.notes),
                      filled: true,
                      fillColor: AppColors.backgroundLight,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),

                  WVioletButton(
                    label: isEdit
                        ? (isRo ? 'Salvează modificările' : 'Save changes')
                        : (isRo ? 'Salvează' : 'Save'),
                    emoji: '💾',
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text) ?? 0;
                      if (amount <= 0 || p.userId == null) return;
                      try {
                        if (isEdit) {
                          await TransactionService.updateTransaction(
                            id: existing.id,
                            categoryId: (selectedCategory?['id'] as int?) ?? 1,
                            amount: amount,
                            type: type,
                            description: descCtrl.text.isNotEmpty ? descCtrl.text : null,
                          );
                        } else {
                          final now = DateTime.now();
                          final date =
                              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                          await TransactionService.createTransaction(
                            userId: p.userId!,
                            categoryId: (selectedCategory?['id'] as int?) ?? 1,
                            amount: amount,
                            type: type,
                            date: date,
                            description: descCtrl.text.isNotEmpty ? descCtrl.text : null,
                          );
                        }
                        await p.refreshTransactions();
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx)
                              .showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// tile pentru o tranzactie din lista
class _TxTile extends StatelessWidget {
  final Transaction tx;
  final bool isRo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TxTile({
    required this.tx,
    required this.isRo,
    required this.onEdit,
    required this.onDelete,
  });

  String _iconPath(String? name, bool isIncome) {
    if (isIncome) {
      switch (name?.toLowerCase()) {
        case 'salary':
        case 'salariu':     return 'assets/images/cash-flow.png';
        case 'freelancing': return 'assets/images/business_16102900.png';
        case 'investments':
        case 'investiții':  return 'assets/images/financial-planning.png';
        case 'gift':
        case 'cadou':       return 'assets/images/calendar.png';
        default:            return 'assets/images/arrow_up.png';
      }
    } else {
      switch (name?.toLowerCase()) {
        case 'food':
        case 'alimente':      return 'assets/images/food.png';
        case 'home':
        case 'locuință':      return 'assets/images/home.png';
        case 'transport':     return 'assets/images/transport.png';
        case 'entertainment':
        case 'divertisment':  return 'assets/images/relax.png';
        case 'clothing':
        case 'îmbrăcăminte': return 'assets/images/clothing.png';
        case 'health':
        case 'sănătate':      return 'assets/images/healthcare.png';
        case 'education':
        case 'studii':        return 'assets/images/study.png';
        default:              return 'assets/images/arrow_down.png';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome     = tx.isIncome;
    final color        = isIncome ? AppColors.income : AppColors.expense;
    final categoryName = _translateCat(tx.category?.name, isRo);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: color, width: 3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Image.asset(
              _iconPath(tx.category?.name, isIncome),
              errorBuilder: (_, __, ___) =>
                  Text(isIncome ? '💰' : '🛒', style: const TextStyle(fontSize: 18)),
            ),
          ),
        ),
        title: Text(
          tx.description ?? categoryName,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface),
        ),
        subtitle: Text(tx.transactionDate,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(0)} lei',
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.primary,
              tooltip: isRo ? 'Editează' : 'Edit',
              splashRadius: 20,
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppColors.error,
              tooltip: isRo ? 'Șterge' : 'Delete',
              splashRadius: 20,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/transaction.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/data_services.dart';

// model pentru un credit activ
class CreditModel {
  final int id;
  final String description;
  final double totalAmount;
  final double monthlyPayment;
  final int totalInstallments;
  final int paidInstallments;
  final double annualInterestRate;
  final String startDate;

  CreditModel({
    required this.id,
    required this.description,
    required this.totalAmount,
    required this.monthlyPayment,
    required this.totalInstallments,
    required this.paidInstallments,
    required this.annualInterestRate,
    required this.startDate,
  });

  factory CreditModel.fromJson(Map<String, dynamic> j) => CreditModel(
        id: j['id'],
        description: j['description'] ?? '',
        totalAmount: double.tryParse(j['totalAmount'].toString()) ?? 0,
        monthlyPayment: double.tryParse(j['monthlyPayment'].toString()) ?? 0,
        totalInstallments: j['totalInstallments'] ?? 0,
        paidInstallments: j['paidInstallments'] ?? 0,
        annualInterestRate: double.tryParse(j['annualInterestRate'].toString()) ?? 0,
        startDate: j['startDate'] ?? '',
      );

  bool get isFullyPaid => paidInstallments >= totalInstallments;
  double get remainingAmount => monthlyPayment * (totalInstallments - paidInstallments);
  int get remainingInstallments => totalInstallments - paidInstallments;
  double get progress => totalInstallments == 0 ? 0 : paidInstallments / totalInstallments;
}

// stringuri localizate ro/en
class AppStrings {
  final bool isRo;
  const AppStrings(this.isRo);

  String get cancel       => isRo ? 'Anulează'    : 'Cancel';
  String get save         => isRo ? 'Salvează'    : 'Save';
  String get delete       => isRo ? 'Șterge'      : 'Delete';
  String get edit         => isRo ? 'Editează'    : 'Edit';
  String get add          => isRo ? 'Adaugă'      : 'Add';
  String get yes          => isRo ? 'Da'          : 'Yes';
  String get no           => isRo ? 'Nu'          : 'No';
  String get error        => isRo ? 'Eroare'      : 'Error';
  String get confirm      => isRo ? 'Confirmă'    : 'Confirm';

  String get dashboard    => isRo ? 'Acasă'       : 'Home';
  String get transactions => isRo ? 'Tranzacții'  : 'Transactions';
  String get budgets      => isRo ? 'Bugete'      : 'Budgets';
  String get goals        => isRo ? 'Obiective'   : 'Goals';
  String get settings     => isRo ? 'Setări'      : 'Settings';
  String get credits      => isRo ? 'Credite'     : 'Credits';

  String get logout        => isRo ? 'Deconectare' : 'Logout';
  String get logoutConfirm => isRo ? 'Ești sigur că vrei să te deconectezi?' : 'Are you sure you want to sign out?';
  String get disconnect    => isRo ? 'Deconectează' : 'Sign out';
}

String _friendlyError(String raw, bool isRo) {
  final msg = raw.toLowerCase();
  if (msg.contains('connection refused') || msg.contains('network') || msg.contains('socketerror')) {
    return isRo
        ? 'Nu s-a putut conecta la server. Verifică conexiunea.'
        : 'Could not connect to server. Check your connection.';
  }
  if (msg.contains('unauthorized') || msg.contains('401') || msg.contains('bad credentials')) {
    return isRo ? 'Email sau parolă incorectă.' : 'Incorrect email or password.';
  }
  if (msg.contains('already exists') || msg.contains('duplicate')) {
    return isRo
        ? 'Această adresă de email este deja înregistrată.'
        : 'This email address is already registered.';
  }
  if (msg.contains('timeout')) {
    return isRo ? 'Serverul nu răspunde. Încearcă din nou.' : 'Server not responding. Please try again.';
  }
  return raw.replaceAll('Exception: ', '').replaceAll('ClientException: ', '');
}

class AppProvider extends ChangeNotifier {
  // auth
  bool _isLoggedIn = false;
  int? _userId;
  String? _userName;
  String? _userEmail;

  // date
  List<Transaction> _transactions = [];
  List<Budget> _budgets           = [];
  List<Goal> _goals               = [];
  List<Debt> _debts               = [];
  List<CreditModel> _credits      = [];
  Map<String, double> _monthlyStats = {};

  // sumele ramase reale pentru datorii (dupa plati partiale)
  double _remainingIOwe     = 0.0;
  double _remainingOwedToMe = 0.0;

  // ui
  bool _isLoading = false;
  String? _error;
  bool _isDark = false;
  int _currentTab = 0;
  bool _isRo = true;

  // polling la 30s pentru date fresh
  Timer? _pollingTimer;
  static const _pollingInterval = Duration(seconds: 30);

  // getters
  bool get isLoggedIn                => _isLoggedIn;
  int? get userId                    => _userId;
  String get userName                => _userName ?? '';
  String get userEmail               => _userEmail ?? '';
  List<Transaction> get transactions => _transactions;
  List<Budget> get budgets           => _budgets;
  List<Goal> get goals               => _goals;
  List<Debt> get debts               => _debts;
  List<CreditModel> get credits      => _credits;
  Map<String, double> get monthlyStats => _monthlyStats;
  bool get isLoading  => _isLoading;
  String? get error   => _error;
  bool get isDark     => _isDark;
  int get currentTab  => _currentTab;
  bool get isRo       => _isRo;
  AppStrings get s    => AppStrings(_isRo);

  // calcule financiare
  double get totalIncome   => _monthlyStats['income']   ?? 0;
  double get totalExpenses => _monthlyStats['expenses'] ?? 0;

  double get totalMonthlyCredits =>
      _credits.where((c) => !c.isFullyPaid).fold(0.0, (s, c) => s + c.monthlyPayment);

  double get _originalIOwe =>
      _debts.where((d) => d.iOwe && d.status != 'paid').fold(0.0, (s, d) => s + d.amount);

  double get _originalOwedToMe =>
      _debts.where((d) => !d.iOwe && d.status != 'paid').fold(0.0, (s, d) => s + d.amount);

  double get totalPaidOnDebts =>
      (_originalIOwe - _remainingIOwe).clamp(0.0, double.infinity);

  double get totalReceivedFromDebts =>
      (_originalOwedToMe - _remainingOwedToMe).clamp(0.0, double.infinity);

  double get totalIOwe     => _remainingIOwe;
  double get totalOwedToMe => _remainingOwedToMe;

  // balanta = venituri - cheltuieli - rate credite - plati datorii + plati primite
  double get balance =>
      totalIncome - totalExpenses - totalMonthlyCredits
      - totalPaidOnDebts + totalReceivedFromDebts;

  void setTab(int tab) {
    _currentTab = tab;
    notifyListeners();
  }

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }

  void toggleLanguage() {
    _isRo = !_isRo;
    notifyListeners();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) async {
      if (_isLoggedIn && _userId != null) await _silentRefresh();
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _silentRefresh() async {
    if (_userId == null) return;
    try {
      final results = await Future.wait([
        TransactionService.getTransactions(_userId!),
        BudgetService.getBudgets(_userId!),
        GoalService.getGoals(_userId!),
        DebtService.getDebts(_userId!),
        TransactionService.getMonthlyStats(_userId!),
        _loadCredits(_userId!),
      ]);
      _transactions = results[0] as List<Transaction>;
      _budgets      = results[1] as List<Budget>;
      _goals        = results[2] as List<Goal>;
      _debts        = results[3] as List<Debt>;
      _monthlyStats = results[4] as Map<String, double>;
      _credits      = results[5] as List<CreditModel>;
      final totals  = await _fetchDebtTotals(_userId!);
      _remainingIOwe     = totals['iOwe']     ?? 0.0;
      _remainingOwedToMe = totals['owedToMe'] ?? 0.0;
      notifyListeners();
    } catch (_) {}
  }

  static Future<Map<String, double>> _fetchDebtTotals(int userId) async {
    double iOwe = 0.0;
    double owedToMe = 0.0;
    try {
      final r1 = await ApiService.get(
          '${ApiService.baseUrl}/api/debts/user/$userId/total/i_owe');
      if (r1.statusCode == 200) {
        final d = jsonDecode(r1.body);
        iOwe = double.tryParse(d['total']?.toString() ?? '0') ?? 0.0;
      }
    } catch (_) {}
    try {
      final r2 = await ApiService.get(
          '${ApiService.baseUrl}/api/debts/user/$userId/total/owed_to_me');
      if (r2.statusCode == 200) {
        final d = jsonDecode(r2.body);
        owedToMe = double.tryParse(d['total']?.toString() ?? '0') ?? 0.0;
      }
    } catch (_) {}
    return {'iOwe': iOwe, 'owedToMe': owedToMe};
  }

  static Future<List<CreditModel>> _loadCredits(int userId) async {
    try {
      final r = await ApiService.get(
          '${ApiService.baseUrl}/api/credits/user/$userId/active');
      if (r.statusCode == 200) {
        final List data = jsonDecode(r.body);
        return data.map((e) => CreditModel.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> checkAuth() async {
    _isLoggedIn = await ApiService.isLoggedIn();
    if (_isLoggedIn) {
      _userId   = await ApiService.getUserId();
      _userName = await ApiService.getUserName();
      _startPolling();
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final auth = await AuthService.login(email, password);
      _isLoggedIn = true;
      _userId     = auth.userId;
      _userName   = auth.fullName;
      _userEmail  = auth.email;
      await loadAllData();
      _startPolling();
      return true;
    } catch (e) {
      _error = _friendlyError(e.toString(), _isRo);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final auth = await AuthService.register(
          fullName: fullName, email: email, password: password);
      _isLoggedIn = true;
      _userId     = auth.userId;
      _userName   = auth.fullName;
      _userEmail  = auth.email;
      return true;
    } catch (e) {
      _error = _friendlyError(e.toString(), _isRo);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _stopPolling();
    await AuthService.logout();
    _isLoggedIn        = false;
    _userId            = null;
    _userName          = null;
    _transactions      = [];
    _budgets           = [];
    _goals             = [];
    _debts             = [];
    _credits           = [];
    _monthlyStats      = {};
    _remainingIOwe     = 0.0;
    _remainingOwedToMe = 0.0;
    notifyListeners();
  }

  Future<void> loadAllData() async {
    if (_userId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        TransactionService.getTransactions(_userId!),
        BudgetService.getBudgets(_userId!),
        GoalService.getGoals(_userId!),
        DebtService.getDebts(_userId!),
        TransactionService.getMonthlyStats(_userId!),
        _loadCredits(_userId!),
      ]);
      _transactions = results[0] as List<Transaction>;
      _budgets      = results[1] as List<Budget>;
      _goals        = results[2] as List<Goal>;
      _debts        = results[3] as List<Debt>;
      _monthlyStats = results[4] as Map<String, double>;
      _credits      = results[5] as List<CreditModel>;
      final debtTotals   = await _fetchDebtTotals(_userId!);
      _remainingIOwe     = debtTotals['iOwe']     ?? 0.0;
      _remainingOwedToMe = debtTotals['owedToMe'] ?? 0.0;
    } catch (e) {
      _error = _isRo
          ? 'Eroare la încărcarea datelor. Încearcă din nou.'
          : 'Error loading data. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshTransactions() async {
    if (_userId == null) return;
    try {
      _transactions = await TransactionService.getTransactions(_userId!);
      _monthlyStats = await TransactionService.getMonthlyStats(_userId!);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshGoals() async {
    if (_userId == null) return;
    try {
      _goals = await GoalService.getGoals(_userId!);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshBudgets() async {
    if (_userId == null) return;
    try {
      _budgets = await BudgetService.getBudgets(_userId!);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshDebts() async {
    if (_userId == null) return;
    try {
      _debts = await DebtService.getDebts(_userId!);
      final totals       = await _fetchDebtTotals(_userId!);
      _remainingIOwe     = totals['iOwe']     ?? 0.0;
      _remainingOwedToMe = totals['owedToMe'] ?? 0.0;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshCredits() async {
    if (_userId == null) return;
    try {
      _credits = await _loadCredits(_userId!);
      notifyListeners();
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}

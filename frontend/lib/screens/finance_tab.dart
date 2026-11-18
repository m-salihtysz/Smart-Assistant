part of '../main.dart';

class FinanceTab extends StatefulWidget {
  const FinanceTab({super.key});

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<FinanceTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<_Transaction> _transactions = [];
  final List<_WatchlistItem> _watchlist = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFinance();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFinance() async {
    final transactions = <_Transaction>[];
    for (final item in await UserStore.readList('finance_transactions')) {
      if (item is! Map) continue;
      transactions.add(
        _Transaction(
          type: normalizeTxType(item['type']),
          amount: asDouble(item['amount']) ?? 0,
          title: asString(item['title']),
          dateKey: asString(item['date']),
          category: asString(item['category']).isEmpty
              ? 'Diğer'
              : asString(item['category']),
        ),
      );
    }
    final watchlist = <_WatchlistItem>[];
    for (final item in await UserStore.readList('finance_watchlist')) {
      if (item is! Map) continue;
      watchlist.add(
        _WatchlistItem(
          name: asString(item['name']),
          symbol: asString(item['symbol']),
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _transactions
        ..clear()
        ..addAll(transactions);
      _watchlist
        ..clear()
        ..addAll(watchlist);
    });
  }

  Future<void> _saveFinance() async {
    await UserStore.setString(
      'finance_transactions',
      jsonEncode(
        _transactions
            .map(
              (t) => {
                'type': t.type,
                'amount': t.amount,
                'title': t.title,
                'date': t.dateKey,
                'category': t.category,
              },
            )
            .toList(),
      ),
    );
    await UserStore.setString(
      'finance_watchlist',
      jsonEncode(
        _watchlist.map((w) => {'name': w.name, 'symbol': w.symbol}).toList(),
      ),
    );
  }

  double get _totalGelir => _transactions
      .where((t) => t.type == 'gelir')
      .fold(0, (s, t) => s + t.amount);
  double get _totalGider => _transactions
      .where((t) => t.type == 'gider')
      .fold(0, (s, t) => s + t.amount);
  double get _balance => _totalGelir - _totalGider;

  double get _dailyGider {
    final now = DateTime.now();
    final todayKey = dateKey(now);
    return _transactions
        .where((t) => t.type == 'gider' && t.dateKey == todayKey)
        .fold(0, (s, t) => s + t.amount);
  }

  double get _monthlyGider {
    final now = DateTime.now();
    final monthPrefix = dateKey(now).substring(0, 7);
    return _transactions
        .where((t) => t.type == 'gider' && t.dateKey.startsWith(monthPrefix))
        .fold(0, (s, t) => s + t.amount);
  }

  static const List<String> _expenseCategories = [
    'Market',
    'Yemek',
    'Ulaşım',
    'Eğlence',
    'Sağlık',
    'Eğitim',
    'Fatura',
    'Diğer',
  ];
  static const List<String> _incomeCategories = ['Maaş', 'Yeni', 'Diğer'];

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Market':
        return Icons.shopping_cart_rounded;
      case 'Yemek':
        return Icons.restaurant_rounded;
      case 'Ulaşım':
        return Icons.directions_car_rounded;
      case 'Eğlence':
        return Icons.sports_esports_rounded;
      case 'Sağlık':
        return Icons.medical_services_rounded;
      case 'Eğitim':
        return Icons.school_rounded;
      case 'Fatura':
        return Icons.receipt_rounded;
      case 'Maaş':
        return Icons.payments_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Future<void> _addTransaction() async {
    String type = 'gider';
    String category = 'Market';
    final amountController = TextEditingController();
    final titleController = TextEditingController();
    String chosenDate = dateKey(DateTime.now());

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final categories = type == 'gelir'
                ? _incomeCategories
                : _expenseCategories;
            if (!categories.contains(category)) category = categories.first;

            return AlertDialog(
              title: Text('Gelir / Gider ekle'.tr(context)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'gelir',
                          label: Text('Gelir'.tr(context)),
                          icon: const Icon(Icons.arrow_downward, size: 18),
                        ),
                        ButtonSegment(
                          value: 'gider',
                          label: Text('Gider'.tr(context)),
                          icon: const Icon(Icons.arrow_upward, size: 18),
                        ),
                      ],
                      selected: {type},
                      onSelectionChanged: (s) {
                        setStateDialog(() {
                          type = s.first;
                          category =
                              (type == 'gelir'
                                      ? _incomeCategories
                                      : _expenseCategories)
                                  .first;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(
                        labelText: 'Kategori'.tr(context),
                      ),
                      items: categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.tr(context)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setStateDialog(() => category = v ?? category),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Açıklama'.tr(context),
                        hintText: 'Örn. Market alışverişi'.tr(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Tutar (₺)'.tr(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      title: Text(
                        '${'Tarih'.tr(context)}: ${formatDateKey(chosenDate)}',
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.tryParse(chosenDate) ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (p != null) {
                            setStateDialog(() {
                              chosenDate = dateKey(p);
                            });
                          }
                        },
                        child: Text('Değiştir'.tr(context)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Vazgeç'.tr(context)),
                ),
                FilledButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) return;
                    if (double.tryParse(
                          amountController.text.replaceAll(',', '.'),
                        ) ==
                        null) {
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: Text('Ekle'.tr(context)),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    final amount =
        double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;
    if (mounted) {
      setState(() {
        _transactions.insert(
          0,
          _Transaction(
            type: type,
            amount: amount,
            title: titleController.text.trim(),
            dateKey: chosenDate,
            category: category,
          ),
        );
      });
    }
    await _saveFinance();
  }

  Future<void> _deleteTransaction(int index) async {
    setState(() => _transactions.removeAt(index));
    await _saveFinance();
  }

  Future<void> _addWatchlist() async {
    final nameController = TextEditingController();
    final symbolController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Borsa takip listesine ekle'.tr(context)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Ad (Örn. Apple, BIST 100)'.tr(context),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: symbolController,
                decoration: InputDecoration(
                  labelText: 'Sembol (isteğe bağlı)'.tr(context),
                  hintText: 'AAPL, XU100'.tr(context),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Vazgeç'.tr(context)),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(context, true);
              },
              child: Text('Ekle'.tr(context)),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    if (mounted) {
      setState(() {
        _watchlist.add(
          _WatchlistItem(
            name: nameController.text.trim(),
            symbol: symbolController.text.trim(),
          ),
        );
      });
    }
    await _saveFinance();
  }

  Future<void> _removeWatchlist(int index) async {
    setState(() => _watchlist.removeAt(index));
    await _saveFinance();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: context.pal.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: context.pal.ink,
            unselectedLabelColor: context.pal.subtle,
            indicatorColor: context.pal.ink,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
            tabs: [
              Tab(text: 'Gelir-Gider'.tr(context)),
              Tab(text: 'Borsam'.tr(context)),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildGelirGider(), _buildBorsam()],
          ),
        ),
      ],
    );
  }

  Widget _buildGelirGider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSummaryHeader(),
        Expanded(
          child: _transactions.isEmpty
              ? EmptyState(
                  icon: Icons.receipt_long_rounded,
                  message: 'Henüz bir işlem yok.'.tr(context),
                  hint: 'Gelir ve giderlerini ekleyerek bütçeni takip et.'.tr(
                    context,
                  ),
                  actionLabel: 'İlk işlemini ekle'.tr(context),
                  onAction: _addTransaction,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) => _buildTransactionTile(index),
                ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: ElevatedButton.icon(
            onPressed: _addTransaction,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.pal.ink,
              foregroundColor: context.pal.onInk,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.add_card_rounded),
            label: Text(
              'Yeni İşlem Ekle'.tr(context),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  /// Bakiye başlığı + gelir/gider kutuları + bugün/bu ay özeti.
  Widget _buildSummaryHeader() {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: pal.shadow.withValues(alpha: 0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bakiye'.tr(context),
            style: TextStyle(
              color: pal.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatMoney(_balance),
            style: TextStyle(
              color: _balance < 0 ? pal.negative : pal.ink,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _flowTile(
                  'Gelir'.tr(context),
                  formatMoney(_totalGelir, signed: true),
                  Icons.south_west_rounded,
                  pal.positive,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _flowTile(
                  'Gider'.tr(context),
                  '-${formatMoney(_totalGider)}',
                  Icons.north_east_rounded,
                  pal.negative,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.today_rounded, size: 16, color: pal.muted),
              const SizedBox(width: 6),
              Text(
                '${'Günlük Gider'.tr(context)}: ${formatMoney(_dailyGider)}',
                style: TextStyle(
                  color: pal.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(Icons.calendar_month_rounded, size: 16, color: pal.muted),
              const SizedBox(width: 6),
              Text(
                '${'Aylık Gider'.tr(context)}: ${formatMoney(_monthlyGider)}',
                style: TextStyle(
                  color: pal.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _flowTile(String label, String value, IconData icon, Color color) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.fill,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: pal.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(int index) {
    final pal = context.pal;
    final t = _transactions[index];
    final isGelir = t.type == 'gelir';
    final color = isGelir ? pal.positive : pal.negative;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: pal.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(_getCategoryIcon(t.category), color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: pal.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${t.category.tr(context)} • ${formatDateKey(t.dateKey)}',
                  style: TextStyle(
                    color: pal.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isGelir ? '+' : '-'}${formatMoney(t.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              InkResponse(
                onTap: () => _deleteTransaction(index),
                radius: 20,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: pal.subtle,
                    semanticLabel: 'Sil'.tr(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBorsam() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            'Takip Listem'.tr(context),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: context.pal.ink,
            ),
          ),
        ),
        Expanded(
          child: _watchlist.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.stacked_line_chart_rounded,
                        size: 64,
                        color: context.pal.subtle,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Takip listen boş.'.tr(context),
                        style: TextStyle(
                          color: context.pal.subtle,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _watchlist.length,
                  itemBuilder: (context, index) {
                    final w = _watchlist[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: context.pal.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: context.pal.shadow.withValues(alpha: 0.04),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.pal.ink.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.show_chart_rounded,
                              color: context.pal.ink,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    color: context.pal.ink,
                                  ),
                                ),
                                if (w.symbol.isNotEmpty)
                                  Text(
                                    w.symbol,
                                    style: TextStyle(
                                      color: context.pal.ink,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: context.pal.subtle,
                            ),
                            onPressed: () => _removeWatchlist(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: ElevatedButton.icon(
            onPressed: _addWatchlist,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.pal.ink,
              foregroundColor: context.pal.onInk,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.add_chart_rounded),
            label: Text(
              'Hisse / Endeks Ekle'.tr(context),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class _Transaction {
  _Transaction({
    required this.type,
    required this.amount,
    required this.title,
    required this.dateKey,
    required this.category,
  });

  final String type;
  final double amount;
  final String title;
  final String dateKey;
  final String category;
}

class _WatchlistItem {
  _WatchlistItem({required this.name, required this.symbol});
  final String name;
  final String symbol;
}

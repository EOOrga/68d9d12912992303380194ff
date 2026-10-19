import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const appName = 'ASS SAUVEGARDE DES SITES DE LA';
const companyName = 'ASS SAUVEGARDE DES SITES DE LA CREATION';
const supportEmail = 'support@ass-sauvegarde-sites.com';
const screenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = screenshotMode
      ? OpsStore.sample(readOnly: true)
      : OpsStore(prefs: await SharedPreferences.getInstance());
  if (!screenshotMode) {
    await store.load();
  }

  runApp(OpsApp(store: store));
}

enum OpsType { appointment, task, payroll, asset }

extension OpsTypeText on OpsType {
  String get label {
    switch (this) {
      case OpsType.appointment:
        return 'Rendez-vous';
      case OpsType.task:
        return 'Tache';
      case OpsType.payroll:
        return 'Paie';
      case OpsType.asset:
        return 'Actif';
    }
  }

  String get pluralLabel {
    switch (this) {
      case OpsType.appointment:
        return 'Rendez-vous';
      case OpsType.task:
        return 'Taches';
      case OpsType.payroll:
        return 'Rapports paie';
      case OpsType.asset:
        return 'Actifs';
    }
  }

  IconData get icon {
    switch (this) {
      case OpsType.appointment:
        return Icons.event_available_outlined;
      case OpsType.task:
        return Icons.fact_check_outlined;
      case OpsType.payroll:
        return Icons.payments_outlined;
      case OpsType.asset:
        return Icons.precision_manufacturing_outlined;
    }
  }
}

class OpsItem {
  OpsItem({
    required this.id,
    required this.type,
    required this.title,
    required this.site,
    required this.owner,
    required this.schedule,
    required this.status,
    required this.note,
    required this.amountLabel,
  });

  final String id;
  final OpsType type;
  final String title;
  final String site;
  final String owner;
  final String schedule;
  final String status;
  final String note;
  final String amountLabel;

  OpsItem copyWith({String? status}) {
    return OpsItem(
      id: id,
      type: type,
      title: title,
      site: site,
      owner: owner,
      schedule: schedule,
      status: status ?? this.status,
      note: note,
      amountLabel: amountLabel,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'site': site,
    'owner': owner,
    'schedule': schedule,
    'status': status,
    'note': note,
    'amountLabel': amountLabel,
  };

  factory OpsItem.fromJson(Map<String, dynamic> json) {
    return OpsItem(
      id:
          json['id'] as String? ??
          'local-${DateTime.now().microsecondsSinceEpoch}',
      type: OpsType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => OpsType.task,
      ),
      title: json['title'] as String? ?? '',
      site: json['site'] as String? ?? '',
      owner: json['owner'] as String? ?? '',
      schedule: json['schedule'] as String? ?? '',
      status: json['status'] as String? ?? 'A traiter',
      note: json['note'] as String? ?? '',
      amountLabel: json['amountLabel'] as String? ?? '',
    );
  }
}

class OpsStore extends ChangeNotifier {
  OpsStore({SharedPreferences? prefs, this.readOnly = false}) : _prefs = prefs;

  factory OpsStore.sample({bool readOnly = false}) {
    final store = OpsStore(readOnly: readOnly);
    store._items.addAll([
      OpsItem(
        id: 'shot-1',
        type: OpsType.appointment,
        title: 'Visite client Tour Atlas',
        site: 'Site Atlas',
        owner: 'Nadia Benali',
        schedule: 'Aujourd hui 09:30',
        status: 'Confirme',
        note: 'Controle acces et briefing du chef de site.',
        amountLabel: 'Equipe A',
      ),
      OpsItem(
        id: 'shot-2',
        type: OpsType.task,
        title: 'Controle ronde nocturne',
        site: 'Zone Nord',
        owner: 'Karim S.',
        schedule: 'Ce soir',
        status: 'En cours',
        note: 'Verifier les points sensibles avant 22:00.',
        amountLabel: 'Priorite haute',
      ),
      OpsItem(
        id: 'shot-3',
        type: OpsType.payroll,
        title: 'Rapport paie avril',
        site: 'Operations centrales',
        owner: 'Finance',
        schedule: '30 avril',
        status: 'A valider',
        note: 'Heures, primes de poste et absences consolidees.',
        amountLabel: '148 200 MAD',
      ),
      OpsItem(
        id: 'shot-4',
        type: OpsType.asset,
        title: 'Radio securite R-18',
        site: 'Depot Materiel',
        owner: 'Youssef A.',
        schedule: 'Maintenance 14 mai',
        status: 'Disponible',
        note: 'Batterie remplacee, retour terrain autorise.',
        amountLabel: 'Inventaire 24/24',
      ),
      OpsItem(
        id: 'shot-5',
        type: OpsType.task,
        title: 'Briefing nouvel agent',
        site: 'Site Ocean',
        owner: 'Chef de poste',
        schedule: 'Demain 08:00',
        status: 'Planifie',
        note: 'Consignes de badge, evacuation et registre incident.',
        amountLabel: 'RH terrain',
      ),
      OpsItem(
        id: 'shot-6',
        type: OpsType.asset,
        title: 'Vehicule intervention V-07',
        site: 'Parking Est',
        owner: 'Logistique',
        schedule: 'Controle hebdo',
        status: 'Reserve',
        note: 'Affecte aux rondes du week-end.',
        amountLabel: 'Carburant OK',
      ),
    ]);
    return store;
  }

  static const _storageKey = 'ops_items_v1';
  final SharedPreferences? _prefs;
  final bool readOnly;
  final List<OpsItem> _items = [];

  List<OpsItem> get items => List.unmodifiable(_items);

  List<OpsItem> byType(OpsType type) {
    return _items.where((item) => item.type == type).toList(growable: false);
  }

  Future<void> load() async {
    final raw = _prefs?.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is List) {
      _items
        ..clear()
        ..addAll(
          decoded.whereType<Map>().map(
            (item) => OpsItem.fromJson(Map<String, dynamic>.from(item)),
          ),
        );
      notifyListeners();
    }
  }

  void addItem(OpsItem item) {
    _items.insert(0, item);
    notifyListeners();
    unawaited(_persist());
  }

  void advanceStatus(OpsItem item) {
    final next = switch (item.status) {
      'Planifie' => 'En cours',
      'A traiter' => 'En cours',
      'A valider' => 'Valide',
      'Reserve' => 'Disponible',
      'En cours' => 'Clos',
      'Confirme' => 'Clos',
      'Disponible' => 'Reserve',
      _ => 'Clos',
    };
    _replace(item.copyWith(status: next));
  }

  void removeItem(OpsItem item) {
    _items.removeWhere((existing) => existing.id == item.id);
    notifyListeners();
    unawaited(_persist());
  }

  void clearAll() {
    _items.clear();
    notifyListeners();
    unawaited(_persist());
  }

  void _replace(OpsItem updated) {
    final index = _items.indexWhere((item) => item.id == updated.id);
    if (index == -1) {
      return;
    }
    _items[index] = updated;
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    if (readOnly) {
      return;
    }
    final data = jsonEncode(_items.map((item) => item.toJson()).toList());
    await _prefs?.setString(_storageKey, data);
  }
}

class OpsApp extends StatelessWidget {
  const OpsApp({super.key, required this.store});

  final OpsStore store;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF23FBB7);
    const charcoal = Color(0xFF11181D);
    const steel = Color(0xFF23D3FB);
    const paper = Color(0xFFF5F2EC);

    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
          primary: primary,
          secondary: steel,
          surface: Colors.white,
          onSurface: charcoal,
        ),
        scaffoldBackgroundColor: paper,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: charcoal,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Color(0xFFE1DED7)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: primary.withValues(alpha: .18),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      home: OperationsShell(store: store),
    );
  }
}

class OperationsShell extends StatefulWidget {
  const OperationsShell({super.key, required this.store});

  final OpsStore store;

  @override
  State<OperationsShell> createState() => _OperationsShellState();
}

class _OperationsShellState extends State<OperationsShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(store: widget.store),
      PlanningScreen(store: widget.store),
      PayrollScreen(store: widget.store),
      AssetsScreen(store: widget.store),
      SettingsScreen(store: widget.store),
    ];

    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('ASS Operations'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  avatar: const Icon(Icons.lock_outline, size: 16),
                  label: const Text('Local'),
                  backgroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          body: SafeArea(child: pages[_index]),
          floatingActionButton: _index == 4
              ? null
              : FloatingActionButton.extended(
                  tooltip: 'Ajouter un enregistrement',
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => AddRecordSheet(
                      store: widget.store,
                      initialType: switch (_index) {
                        1 => OpsType.appointment,
                        2 => OpsType.payroll,
                        3 => OpsType.asset,
                        _ => OpsType.task,
                      },
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Accueil',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'Planning',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Paie',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: 'Actifs',
              ),
              NavigationDestination(
                icon: Icon(Icons.privacy_tip_outlined),
                selectedIcon: Icon(Icons.privacy_tip),
                label: 'Confidentialite',
              ),
            ],
          ),
        );
      },
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.store});

  final OpsStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priorityItems = store.items.take(4).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          appName,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: const Color(0xFF11181D),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pilotage quotidien des rendez-vous, taches, paie et actifs.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF52616D),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.65,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            SummaryTile(
              icon: OpsType.appointment.icon,
              label: 'Rendez-vous',
              value: store.byType(OpsType.appointment).length.toString(),
            ),
            SummaryTile(
              icon: OpsType.task.icon,
              label: 'Taches ouvertes',
              value: store.byType(OpsType.task).length.toString(),
            ),
            SummaryTile(
              icon: OpsType.payroll.icon,
              label: 'Paie',
              value: store.byType(OpsType.payroll).length.toString(),
            ),
            SummaryTile(
              icon: OpsType.asset.icon,
              label: 'Actifs suivis',
              value: store.byType(OpsType.asset).length.toString(),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionHeader(
          title: 'ASS SAUVEGARDE DES SITES DE LA',
          trailing: '${store.items.length} enregistrements',
        ),
        const SizedBox(height: 10),
        if (priorityItems.isEmpty)
          const EmptyState(
            icon: Icons.assignment_outlined,
            title: 'Aucun suivi local',
            message:
                'Ajoutez un rendez-vous, une tache, un actif ou un rapport paie.',
          )
        else
          ...priorityItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OpsItemCard(store: store, item: item),
            ),
          ),
      ],
    );
  }
}

class PlanningScreen extends StatelessWidget {
  const PlanningScreen({super.key, required this.store});

  final OpsStore store;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const Material(
            color: Colors.white,
            child: TabBar(
              tabs: [
                Tab(text: 'Rendez-vous'),
                Tab(text: 'Taches'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                RecordList(
                  store: store,
                  type: OpsType.appointment,
                  emptyTitle: 'Aucun rendez-vous',
                  emptyMessage:
                      'Planifiez une visite client ou une reunion de poste.',
                ),
                RecordList(
                  store: store,
                  type: OpsType.task,
                  emptyTitle: 'Aucune tache',
                  emptyMessage:
                      'Ajoutez les actions terrain a suivre aujourd hui.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PayrollScreen extends StatelessWidget {
  const PayrollScreen({super.key, required this.store});

  final OpsStore store;

  @override
  Widget build(BuildContext context) {
    final reports = store.byType(OpsType.payroll);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(title: 'Rapports paie', trailing: 'Local'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${reports.length} rapports suivis',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Heures, primes, absences et validations restent sur cet appareil.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (reports.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Aucun rapport paie',
            message: 'Ajoutez un rapport mensuel pour garder un suivi local.',
          )
        else
          ...reports.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OpsItemCard(store: store, item: item),
            ),
          ),
      ],
    );
  }
}

class AssetsScreen extends StatelessWidget {
  const AssetsScreen({super.key, required this.store});

  final OpsStore store;

  @override
  Widget build(BuildContext context) {
    return RecordList(
      store: store,
      type: OpsType.asset,
      headerTitle: 'Inventaire terrain',
      emptyTitle: 'Aucun actif',
      emptyMessage:
          'Ajoutez radios, vehicules, badges ou equipements critiques.',
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});

  final OpsStore store;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(title: 'Confidentialite', trailing: 'Sans compte'),
        const SizedBox(height: 10),
        InfoPanel(
          icon: Icons.phone_android_outlined,
          title: 'Stockage local uniquement',
          message:
              'Les rendez-vous, taches, rapports paie et actifs sont conserves sur ce telephone.',
        ),
        const SizedBox(height: 10),
        InfoPanel(
          icon: Icons.cloud_off_outlined,
          title: 'Aucun service distant',
          message:
              'L app ne cree pas de compte, ne synchronise pas les donnees et n utilise aucune API.',
        ),
        const SizedBox(height: 10),
        InfoPanel(
          icon: Icons.business_outlined,
          title: companyName,
          message: 'Support: $supportEmail',
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: screenshotMode
              ? null
              : () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Effacer les donnees locales'),
                      content: const Text(
                        'Cette action supprime les enregistrements stockes dans l app.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Annuler'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Effacer'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed ?? false) {
                    store.clearAll();
                  }
                },
          icon: const Icon(Icons.delete_outline),
          label: const Text('Effacer les donnees locales'),
        ),
      ],
    );
  }
}

class RecordList extends StatelessWidget {
  const RecordList({
    super.key,
    required this.store,
    required this.type,
    required this.emptyTitle,
    required this.emptyMessage,
    this.headerTitle,
  });

  final OpsStore store;
  final OpsType type;
  final String emptyTitle;
  final String emptyMessage;
  final String? headerTitle;

  @override
  Widget build(BuildContext context) {
    final items = store.byType(type);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(
          title: headerTitle ?? type.pluralLabel,
          trailing: '${items.length} actifs',
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          EmptyState(icon: type.icon, title: emptyTitle, message: emptyMessage)
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OpsItemCard(store: store, item: item),
            ),
          ),
      ],
    );
  }
}

class OpsItemCard extends StatelessWidget {
  const OpsItemCard({super.key, required this.store, required this.item});

  final OpsStore store;
  final OpsItem item;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(item.status);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          useSafeArea: true,
          builder: (_) => ItemDetailSheet(store: store, item: item),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8A00).withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        item.type.icon,
                        color: const Color(0xFFB45E00),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text('${item.site} - ${item.schedule}'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(item.status),
                    backgroundColor: color.withValues(alpha: .13),
                    side: BorderSide(color: color.withValues(alpha: .45)),
                  ),
                  Chip(
                    label: Text(item.owner),
                    avatar: const Icon(Icons.person_outline, size: 16),
                  ),
                  if (item.amountLabel.isNotEmpty)
                    Chip(
                      label: Text(item.amountLabel),
                      avatar: const Icon(
                        Icons.label_important_outline,
                        size: 16,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ItemDetailSheet extends StatelessWidget {
  const ItemDetailSheet({super.key, required this.store, required this.item});

  final OpsStore store;
  final OpsItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.type.icon, color: const Color(0xFFFF8A00)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DetailLine(label: 'Categorie', value: item.type.label),
          DetailLine(label: 'Site', value: item.site),
          DetailLine(label: 'Responsable', value: item.owner),
          DetailLine(label: 'Echeance', value: item.schedule),
          DetailLine(label: 'Statut', value: item.status),
          if (item.amountLabel.isNotEmpty)
            DetailLine(label: 'Reference', value: item.amountLabel),
          const SizedBox(height: 10),
          Text(item.note),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    store.advanceStatus(item);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.update),
                  label: const Text('Avancer statut'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Supprimer',
                onPressed: () {
                  store.removeItem(item);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AddRecordSheet extends StatefulWidget {
  const AddRecordSheet({
    super.key,
    required this.store,
    required this.initialType,
  });

  final OpsStore store;
  final OpsType initialType;

  @override
  State<AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends State<AddRecordSheet> {
  final _formKey = GlobalKey<FormState>();
  late OpsType _type = widget.initialType;
  final _title = TextEditingController();
  final _site = TextEditingController(text: 'Site principal');
  final _owner = TextEditingController(text: 'Responsable');
  final _schedule = TextEditingController(text: 'Aujourd hui');
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _site.dispose();
    _owner.dispose();
    _schedule.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Ajouter un enregistrement',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<OpsType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Categorie'),
              items: OpsType.values
                  .map(
                    (type) =>
                        DropdownMenuItem(value: type, child: Text(type.label)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Titre'),
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Titre requis' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _site,
              decoration: const InputDecoration(labelText: 'Site ou service'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _owner,
              decoration: const InputDecoration(labelText: 'Responsable'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _schedule,
              decoration: const InputDecoration(
                labelText: 'Date, periode ou echeance',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _amount,
              decoration: const InputDecoration(
                labelText: 'Montant, reference ou priorite',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _note,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    widget.store.addItem(
      OpsItem(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        type: _type,
        title: _title.text.trim(),
        site: _site.text.trim(),
        owner: _owner.text.trim(),
        schedule: _schedule.text.trim(),
        status: switch (_type) {
          OpsType.appointment => 'Planifie',
          OpsType.task => 'A traiter',
          OpsType.payroll => 'A valider',
          OpsType.asset => 'Disponible',
        },
        note: _note.text.trim().isEmpty
            ? 'Suivi ajoute depuis le telephone.'
            : _note.text.trim(),
        amountLabel: _amount.text.trim(),
      ),
    );
    Navigator.pop(context);
  }
}

class SummaryTile extends StatelessWidget {
  const SummaryTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: const Color(0xFFFF8A00)),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: const Color(0xFF52616D)),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icon, size: 42, color: const Color(0xFF52616D)),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFFF8A00), size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailLine extends StatelessWidget {
  const DetailLine({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

Color statusColor(String status) {
  if (status == 'Clos' || status == 'Valide' || status == 'Disponible') {
    return const Color(0xFF2F7D52);
  }
  if (status == 'En cours' || status == 'Confirme') {
    return const Color(0xFFB45E00);
  }
  return const Color(0xFF52616D);
}

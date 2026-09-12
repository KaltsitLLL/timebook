import 'package:flutter/material.dart';
import 'package:timebook/core/db/app_database.dart';
import 'package:timebook/features/bookkeeping/data/bookkeeping_repository.dart';

/// 分类规则：按关键词自动分类导入/记账流水。
class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key, required this.database});
  final AppDatabase database;
  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  late final BookkeepingRepository _repo;
  late Future<(List<ImportRule>, Map<int, String>)> _future;

  @override
  void initState() {
    super.initState();
    _repo = BookkeepingRepository(widget.database);
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<(List<ImportRule>, Map<int, String>)> _load() async {
    final ledgers = await _repo.ledgers();
    final names = <int, String>{};
    if (ledgers.isNotEmpty) {
      for (final c in await _repo.categories(ledgers.first.id)) {
        names[c.id] = c.name;
      }
    }
    return (await _repo.rules(), names);
  }

  Future<bool> _save(String keyword, int categoryId) async {
    final rules = await _repo.rules();
    final priority = rules.isEmpty
        ? 1
        : rules.map((r) => r.priority).reduce((a, b) => a > b ? a : b) + 1;
    await _repo.upsertRule(keyword: keyword.trim(), categoryId: categoryId, priority: priority);
    return true;
  }

  Future<void> _delete(ImportRule r) async {
    await _repo.deleteRule(r.id);
    _reload();
  }

  Future<void> _openAddSheet() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RuleAddSheet(database: widget.database, onSave: _save),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('分类规则')),
      body: FutureBuilder<(List<ImportRule>, Map<int, String>)>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (rules, names) = snap.data!;
          if (rules.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 80),
              Center(child: Text('暂无分类规则，点击下方「+ 新增规则」添加')),
            ]);
          }
          return ListView.separated(
            itemCount: rules.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final r = rules[i];
              return ListTile(
                title: Text(r.keyword),
                subtitle: Text(names[r.categoryId] ?? '分类#${r.categoryId}'),
                trailing: IconButton(
                  key: Key('rule_del_${r.id}'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(r),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.tonalIcon(
            key: const Key('rule_add'),
            onPressed: _openAddSheet,
            icon: const Icon(Icons.add),
            label: const Text('+ 新增规则'),
          ),
        ),
      ),
    );
  }
}

class _RuleAddSheet extends StatefulWidget {
  const _RuleAddSheet({required this.database, required this.onSave});
  final AppDatabase database;
  final Future<bool> Function(String keyword, int categoryId) onSave;
  @override
  State<_RuleAddSheet> createState() => _RuleAddSheetState();
}

class _RuleAddSheetState extends State<_RuleAddSheet> {
  late final BookkeepingRepository _repo;
  final _keyword = TextEditingController();
  List<Category> _cats = [];
  int? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repo = BookkeepingRepository(widget.database);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final ledgers = await _repo.ledgers();
    var list = <Category>[];
    if (ledgers.isNotEmpty) {
      list = await _repo.categories(ledgers.first.id);
    }
    if (!mounted) return;
    setState(() {
      _cats = list;
      _categoryId ??= list.isNotEmpty ? list.first.id : null;
    });
  }

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final keyword = _keyword.text.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入关键词')));
      return;
    }
    if (_categoryId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先创建分类')));
      return;
    }
    setState(() => _saving = true);
    final saved = await widget.onSave(keyword, _categoryId!);
    if (!mounted) return;
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('新增分类规则', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('rule_keyword'),
            controller: _keyword,
            decoration: const InputDecoration(
                labelText: '关键词', hintText: '如：美团', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            key: const Key('rule_category'),
            initialValue: _categoryId,
            decoration: const InputDecoration(
                labelText: '分类', border: OutlineInputBorder()),
            items: [
              for (final c in _cats)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: _cats.isEmpty
                ? null
                : (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('rule_save'),
            onPressed: _saving ? null : _submit,
            child: const Text('保存'),
          ),
        ]),
      ),
    );
  }
}
import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/models/brand.dart';
import '../../domain/models/category.dart';
import '../../domain/models/color.dart' as model;
import 'item_options.dart';

class EditItemPage extends StatefulWidget {
  const EditItemPage({
    super.key,
    required this.imagePath,
    this.options,
    this.draft,
  });
  final String imagePath;
  final ItemOptions? options;
  final ItemDraft? draft;
  @override
  State<EditItemPage> createState() => _EditItemPageState();
}

class _EditItemPageState extends State<EditItemPage> {
  late final ItemDraft _saved = widget.draft ?? ItemDraft();
  late final _noteController = TextEditingController(text: _saved.note);
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (_category == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先设置品类')));
      return;
    }
    final save = widget.options?.saveItem;
    if (save == null) return;
    setState(() => _saving = true);
    try {
      await save(widget.imagePath, _category!, _brand, _size, [
        ..._colors,
      ], _note);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存失败，请检查信息后重试')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Category? get _category => _saved.category;
  Brand? get _brand => _saved.brand;
  String? get _size => _saved.size;
  String get _note => _saved.note;
  List<model.Color?> get _colors => _saved.colors;

  Future<void> _edit(String field) async {
    FocusScope.of(context).unfocus();
    final result = await showModalBottomSheet<ItemDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _OptionsSheet(
        field: field,
        options: widget.options,
        initial: ItemDraft(
          category: _category,
          brand: _brand,
          size: _size,
          colors: _colors,
          note: _note,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _saved.category = result.category;
      _saved.brand = result.brand;
      _saved.size = result.size;
      _saved.colors = result.colors;
      _saved.note = result.note;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 752),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '保存中…' : '保存'),
                ),
              ),
            ),
          ),
        ),
      ),
      appBar: AppBar(title: const Text('编辑单品'), leading: const BackButton()),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.contain,
                            semanticLabel: '单品照片',
                            errorBuilder: (_, _, _) =>
                                const Center(child: Text('照片无法读取')),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final entry in [
                        ('品类', _category?.name),
                        ('品牌', _brand?.name),
                        ('尺寸', _size),
                        (
                          '颜色',
                          _colors
                              .whereType<model.Color>()
                              .map((c) => c.name)
                              .join('、'),
                        ),
                      ]) ...[
                        if (entry.$1 != '品类')
                          const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          title: Row(
                            children: [
                              Text(
                                entry.$1,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Text(
                                  entry.$2 == null || entry.$2!.isEmpty
                                      ? '未设置'
                                      : entry.$2!,
                                  textAlign: TextAlign.end,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _edit(entry.$1),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '备注',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _noteController,
                        minLines: 3,
                        maxLines: 6,
                        onChanged: (value) => _saved.note = value,
                        decoration: const InputDecoration(
                          hintText: '输入备注',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ItemDraft {
  ItemDraft({
    this.category,
    this.brand,
    this.size,
    List<model.Color?>? colors,
    this.note = '',
  }) : colors = colors ?? [null, null, null];
  Category? category;
  Brand? brand;
  String? size;
  List<model.Color?> colors;
  String note;
}

class _OptionsSheet extends StatefulWidget {
  const _OptionsSheet({
    required this.field,
    required this.initial,
    this.options,
  });
  final String field;
  final ItemDraft initial;
  final ItemOptions? options;
  @override
  State<_OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends State<_OptionsSheet> {
  late final ItemDraft _draft = ItemDraft(
    category: widget.initial.category,
    brand: widget.initial.brand,
    size: widget.initial.size,
    colors: [...widget.initial.colors],
    note: widget.initial.note,
  );
  final _input = TextEditingController();
  List<Category> _categories = [];
  List<Brand> _brands = [];
  List<model.Color> _palette = [];
  String? _root;
  int? _slot;
  bool _loading = true;
  bool _adding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.field == '备注') _input.text = _draft.note;
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (widget.field) {
        case '品类':
          _categories = await widget.options?.categories() ?? [];
          _categories.sort((a, b) {
            final order = a.sortOrder.compareTo(b.sortOrder);
            return order == 0 ? a.id.compareTo(b.id) : order;
          });
          _root = _draft.category?.parentId ?? _draft.category?.id;
          _root ??= _categories
              .where((c) => c.parentId == null)
              .firstOrNull
              ?.id;
        case '品牌':
          _brands = await widget.options?.brands() ?? [];
          _sortBrands();
        case '颜色':
          _palette = await widget.options?.colors() ?? [];
      }
    } catch (_) {
      _error = '加载失败，请重试';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _sortBrands() => _brands.sort((a, b) {
    final order = b.createdAt.compareTo(a.createdAt);
    return order == 0 ? a.id.compareTo(b.id) : order;
  });

  Future<void> _addBrand() async {
    final name = _input.text.trim();
    if (_adding || name.isEmpty || widget.options == null) return;
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      final brand = await widget.options!.createBrand(name);
      if (!mounted) return;
      setState(() {
        _brands.add(brand);
        _sortBrands();
        _input.clear();
        _draft.brand = brand;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '添加失败，请重试');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height:
          (MediaQuery.sizeOf(context).height -
              MediaQuery.viewInsetsOf(context).bottom) *
          .75,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.field == '备注' ? '设置备注' : '选择${widget.field}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _adding ? null : () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: _loading || _adding
                        ? null
                        : () {
                            if (widget.field == '备注') {
                              _draft.note = _input.text.trim();
                            }
                            Navigator.pop(context, _draft);
                          },
                    child: const Text('确认'),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!),
                  if (_error == '加载失败，请重试')
                    TextButton(onPressed: _load, child: const Text('重试')),
                ],
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : switch (widget.field) {
                      '品类' => _categoryChoices(),
                      '品牌' => _brandChoices(),
                      '尺寸' => ListView(
                        children: [
                          for (final size in <String?>[
                            null,
                            'XS',
                            'S',
                            'M',
                            'L',
                            'XL',
                            'XXL',
                          ])
                            ListTile(
                              title: Text(size ?? '不设置'),
                              selected: _draft.size == size,
                              trailing: _draft.size == size
                                  ? const Icon(Icons.check)
                                  : null,
                              onTap: () => setState(() => _draft.size = size),
                            ),
                        ],
                      ),
                      '颜色' => _colorChoices(),
                      _ => Padding(
                        padding: const EdgeInsets.all(20),
                        child: TextField(
                          controller: _input,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            hintText: '输入备注',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    },
            ),
          ],
        ),
      ),
    ),
  );

  Widget _categoryChoices() {
    final roots = _categories.where((c) => c.parentId == null).toList();
    final children = _categories.where((c) => c.parentId == _root).toList();
    if (roots.isEmpty) return const Center(child: Text('暂无品类'));
    return Row(
      children: [
        Expanded(
          child: ListView(
            children: [
              for (final root in roots)
                ListTile(
                  title: Text(root.name),
                  selected: _root == root.id,
                  selectedTileColor: Theme.of(context)
                      .colorScheme
                      .secondaryContainer,
                  onTap: () => setState(() {
                    _root = root.id;
                  }),
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: ListView(
            children: [
              for (final category in [
                if (children.isEmpty)
                  ...roots.where((c) => c.id == _root)
                else
                  ...children,
              ])
                ListTile(
                  title: Text(category.name),
                  selected: _draft.category?.id == category.id,
                  trailing: _draft.category?.id == category.id
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => setState(() => _draft.category = category),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _brandChoices() {
    final query = _input.text.trim().toLowerCase();
    final matches = _brands.where((b) => b.name.toLowerCase().contains(query));
    final canAdd =
        query.isNotEmpty && !_brands.any((b) => b.name.toLowerCase() == query);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final brand in matches)
                    FilterChip(
                      label: Text(brand.name),
                      selected: _draft.brand?.id == brand.id,
                      onSelected: (selected) => setState(
                        () => _draft.brand = selected ? brand : null,
                      ),
                    ),
                  if (matches.isEmpty) const Text('暂无品牌'),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: !_adding,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '输入品牌名称查询',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              if (canAdd)
                TextButton(
                  onPressed: _adding ? null : _addBrand,
                  child: Text(_adding ? '添加中' : '添加'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _swatch(model.Color color) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Color(int.parse(color.hex.replaceFirst('#', 'FF'), radix: 16)),
      border: Border.all(color: Colors.black26),
    ),
  );

  Widget _colorChoices() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () => setState(() => _slot = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _slot == i
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : null,
                      border: Border.all(
                        color: _slot == i
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black26,
                        width: _slot == i ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(['主色', '配色1', '配色2'][i]),
                        const SizedBox(height: 12),
                        if (_draft.colors[i] case final color?)
                          _swatch(color)
                        else
                          const Icon(Icons.add),
                        const SizedBox(height: 8),
                        Text(_draft.colors[i]?.name ?? '未设置'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 24),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 8,
        children: [
          const Text('颜色选项', style: TextStyle(fontWeight: FontWeight.w600)),
          if (_slot == null)
            const Text(
              '请先选择要编辑的项目',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final color in _palette)
            Opacity(
              opacity: _slot == null ? .35 : 1,
              child: FilterChip(
                avatar: _swatch(color),
                label: Text(color.name),
                selected:
                    _slot != null && _draft.colors[_slot!]?.id == color.id,
                onSelected: _slot == null
                    ? null
                    : (selected) => setState(() {
                        // A color occupies only one slot; choosing it again moves it.
                        for (var i = 0; i < 3; i++) {
                          if (_draft.colors[i]?.id == color.id) {
                            _draft.colors[i] = null;
                          }
                        }
                        _draft.colors[_slot!] = selected ? color : null;
                      }),
              ),
            ),
        ],
      ),
    ],
  );
}

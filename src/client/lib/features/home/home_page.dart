import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/models/clothing_item.dart';
import '../../domain/models/category.dart';
import '../wardrobe/wardrobe_page.dart';
import '../wardrobe/edit_image_page.dart';
import '../wardrobe/item_options.dart';
import '../wardrobe/item_detail_page.dart';
import '../profile/profile_page.dart';
import '../statistics/statistics_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.loadItems,
    this.loadCategories,
    this.imagePicker,
    this.itemOptions,
  });

  final Future<List<ClothingItem>> Function() loadItems;
  final Future<List<Category>> Function()? loadCategories;
  final ImagePicker? imagePicker;
  final ItemOptions? itemOptions;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<ClothingItem>> _items;
  int _selectedIndex = 0;
  late final ImagePicker _picker = widget.imagePicker ?? ImagePicker();
  bool _picking = false;
  int _wardrobeRevision = 0;

  @override
  void initState() {
    super.initState();
    _items = widget.loadItems();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recoverPhoto());
    }
  }

  Future<void> _recoverPhoto() async {
    try {
      final response = await _picker.retrieveLostData();
      if (!mounted) return;
      if (response.files?.isNotEmpty ?? false) {
        _selectTab(1);
        await _openEditor(response.files!.first);
      } else if (response.exception != null) {
        _showPickerError(response.exception!);
      }
    } on PlatformException catch (error) {
      if (mounted) _showPickerError(error);
    }
  }

  Future<void> _openEditor(XFile image) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            EditImagePage(imagePath: image.path, options: widget.itemOptions),
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        _wardrobeRevision++;
        _items = widget.loadItems();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('单品已保存')));
    }
  }

  void _showPickerError(PlatformException error) {
    final denied = error.code.toLowerCase().contains('access');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(denied ? '无法访问相机或相册，请在系统设置中允许访问后重试' : '无法获取照片，请重试'),
      ),
    );
  }

  Future<void> _addPhoto() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final platform = Theme.of(context).platform;
      final desktop =
          platform == TargetPlatform.windows ||
          platform == TargetPlatform.macOS;
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('拍照'),
                subtitle: desktop ? const Text('Windows/MacOS端暂不支持') : null,
                enabled: !desktop,
                onTap: desktop
                    ? null
                    : () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('从相册选择'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
      if (source == null || !mounted) return;
      final image = await _picker.pickImage(
        source: source,
        requestFullMetadata: false,
      );
      if (image != null && mounted) await _openEditor(image);
    } on PlatformException catch (error) {
      if (mounted) _showPickerError(error);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('无法获取照片，请重试')));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _refresh() async {
    final request = widget.loadItems();
    setState(() {
      _items = request;
    });
    await request;
  }

  Future<void> _openItem(ClothingItem item) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ItemDetailPage(
        item: item,
        options: widget.itemOptions,
        onChanged: () {
          if (!mounted) return;
          setState(() {
            _wardrobeRevision++;
            _items = widget.loadItems();
          });
        },
      ),
    ),
  );

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 0) _items = widget.loadItems();
    });
  }

  void _openStatistics() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => StatisticsPage(
        loadItems: widget.loadItems,
        loadCategories: widget.loadCategories ?? widget.itemOptions?.categories,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 800;
      return Scaffold(
        floatingActionButton: _selectedIndex == 1
            ? FloatingActionButton.extended(
                tooltip: '添加单品',
                onPressed: _picking ? null : _addPhoto,
                icon: const Icon(Icons.add),
                label: const Text('添加单品'),
              )
            : null,
        body: SafeArea(
          child: Row(
            children: [
              if (wide) ...[
                NavigationRail(
                  extended: constraints.maxWidth >= 1100,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerLow,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Icon(
                      Icons.checkroom_outlined,
                      size: 30,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectTab,
                  labelType: constraints.maxWidth >= 1100
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text('首页'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.checkroom_outlined),
                      selectedIcon: Icon(Icons.checkroom),
                      label: Text('衣橱'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: Text('我的'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1),
              ],
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: _buildContent(wide),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: wide ? null : _buildBottomNavigation(),
      );
    },
  );

  Widget _buildContent(bool wide) => _selectedIndex == 0
      ? FutureBuilder<List<ClothingItem>>(
          future: _items,
          builder: (context, snapshot) {
            final items = [...?snapshot.data]
              ..sort((a, b) {
                final order = b.createdAt.compareTo(a.createdAt);
                return order == 0 ? a.id.compareTo(b.id) : order;
              });
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: wide
                    ? const EdgeInsets.all(40)
                    : const EdgeInsets.fromLTRB(24, 32, 24, 32),
                children: [
                  const Text(
                    '栖色 VelaX',
                    style: TextStyle(
                      fontSize: 28,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '让每一件喜欢的衣物，都有自己的位置。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _picking ? null : _addPhoto,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('添加单品'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    Column(
                      children: [
                        const Text('衣橱加载失败，请重试'),
                        TextButton(
                          onPressed: _refresh,
                          child: const Text('重试'),
                        ),
                      ],
                    )
                  else ...[
                    _Overview(items: items, onOpen: _openStatistics),
                    const SizedBox(height: 32),
                    const Text(
                      '最近添加',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (items.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 40,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.checkroom_outlined,
                              size: 36,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            SizedBox(height: 12),
                            Text('还没有衣物'),
                            SizedBox(height: 6),
                            Text(
                              '添加后，最近的衣物照片会出现在这里',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final photoWidth = wide
                              ? (constraints.maxWidth - 48) / 5
                              : 132.0;
                          final photoHeight = photoWidth * 164 / 132;
                          return SizedBox(
                            height: photoHeight,
                            child: ListView.separated(
                              physics: wide
                                  ? const NeverScrollableScrollPhysics()
                                  : null,
                              scrollDirection: Axis.horizontal,
                              itemCount: items.length.clamp(0, 5),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) => Semantics(
                                label:
                                    '最近添加的${items[index].category.name}，第${index + 1}件',
                                image: true,
                                child: InkWell(
                                  onTap: () => _openItem(items[index]),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(
                                      File(items[index].image),
                                      width: photoWidth,
                                      height: photoHeight,
                                      fit: BoxFit.cover,
                                      cacheWidth: 400,
                                      errorBuilder: (_, _, _) => Container(
                                        width: photoWidth,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        child: Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            semanticLabel: '照片无法读取',
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ],
              ),
            );
          },
        )
      : _selectedIndex == 1
      ? WardrobePage(
          key: ValueKey(_wardrobeRevision),
          loadItems: widget.loadItems,
          loadCategories: widget.loadCategories ?? () async => <Category>[],
          wide: wide,
          onOpenItem: _openItem,
        )
      : ProfilePage(wide: wide, onOpenStatistics: _openStatistics);

  Widget _buildBottomNavigation() => NavigationBar(
    selectedIndex: _selectedIndex,
    onDestinationSelected: _selectTab,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: '首页',
      ),
      NavigationDestination(
        icon: Icon(Icons.checkroom_outlined),
        selectedIcon: Icon(Icons.checkroom),
        label: '衣橱',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: '我的',
      ),
    ],
  );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.items, required this.onOpen});

  final List<ClothingItem> items;
  final VoidCallback onOpen;

  int _count(String root) => items
      .where((item) => (item.category.parentId ?? item.category.id) == root)
      .length;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '衣橱概览',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: onOpen,
              tooltip: '查看衣橱数据',
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (final entry in [
              ('衣物', items.length),
              ('上装', _count('top')),
              ('下装', _count('bottom')),
              ('鞋履', _count('shoes')),
            ])
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${entry.$2}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.$1,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

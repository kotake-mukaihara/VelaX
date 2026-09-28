import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/models/clothing_item.dart';
import '../../domain/models/category.dart';
import '../wardrobe/wardrobe_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.loadItems, this.loadCategories});

  final Future<List<ClothingItem>> Function() loadItems;
  final Future<List<Category>> Function()? loadCategories;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<ClothingItem>> _items;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _items = widget.loadItems();
  }

  Future<void> _refresh() async {
    final request = widget.loadItems();
    setState(() {
      _items = request;
    });
    await request;
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 0) _items = widget.loadItems();
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 800;
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              if (wide) ...[
                NavigationRail(
                  extended: constraints.maxWidth >= 1100,
                  backgroundColor: Colors.white,
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
                    '栖色 Velax',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 36),
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
                    _Overview(items: items, onOpen: () => _selectTab(1)),
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.checkroom_outlined,
                              size: 36,
                              color: Color(0xFF87917F),
                            ),
                            SizedBox(height: 12),
                            Text('还没有衣物'),
                            SizedBox(height: 6),
                            Text(
                              '添加后，最近的衣物照片会出现在这里',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54),
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
                                      color: const Color(0xFFEDEEE8),
                                      child: const Center(
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          semanticLabel: '照片无法读取',
                                          color: Colors.black38,
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
          loadItems: widget.loadItems,
          loadCategories: widget.loadCategories ?? () async => <Category>[],
          wide: wide,
        )
      : const Center(child: Text('我的页面即将上线'));

  Widget _buildBottomNavigation() => NavigationBar(
    selectedIndex: _selectedIndex,
    onDestinationSelected: _selectTab,
    backgroundColor: Colors.white,
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
      color: const Color(0xFFEDEFE7),
      borderRadius: BorderRadius.circular(24),
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
              tooltip: '查看衣橱',
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
                      style: const TextStyle(color: Color(0xFF606756)),
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

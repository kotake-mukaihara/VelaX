import 'package:flutter/material.dart';

import 'backup_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.wide = false});

  final bool wide;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // UI preview only; this does not apply or persist a theme preference.
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.fromLTRB(
      widget.wide ? 40 : 24,
      20,
      widget.wide ? 40 : 24,
      32,
    ),
    children: [
      const Text(
        '我的',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 24),
      _group([
        const ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Icon(Icons.bar_chart_outlined),
          title: Text('查看衣橱数据'),
          trailing: Icon(Icons.chevron_right),
        ),
      ]),
      const SizedBox(height: 20),
      _group([
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          leading: const Icon(Icons.dark_mode_outlined),
          title: const Text('深色模式'),
          trailing: Semantics(
            label: '深色模式',
            child: Switch(
              value: _darkMode,
              onChanged: (value) => setState(() => _darkMode = value),
            ),
          ),
        ),
        const Divider(height: 1, indent: 20, endIndent: 20),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          leading: const Icon(Icons.backup_outlined),
          title: const Text('数据备份与迁移'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(
            context,
          ).push<void>(MaterialPageRoute(builder: (_) => const BackupPage())),
        ),
      ]),
    ],
  );

  Widget _group(List<Widget> children) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

import 'package:flutter/material.dart';

import 'backup_page.dart';
import '../../theme/themed_app.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.wide = false, this.onOpenStatistics});

  final bool wide;
  final VoidCallback? onOpenStatistics;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final settings = ThemeSettings.of(context);
    final followsSystem = settings.mode == ThemeMode.system;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        widget.wide ? 40 : 24,
        20,
        widget.wide ? 40 : 24,
        32,
      ),
      children: [
        const Text(
          '我的',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        _group([
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('查看衣橱数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.onOpenStatistics,
          ),
        ]),
        const SizedBox(height: 20),
        _group([
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('深色模式'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  selected: followsSystem,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 48),
                      backgroundColor: followsSystem
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : null,
                    ),
                    onPressed: () => settings.onChanged(
                      followsSystem
                          ? (dark ? ThemeMode.dark : ThemeMode.light)
                          : ThemeMode.system,
                    ),
                    child: const Text('跟随系统'),
                  ),
                ),
                Semantics(
                  label: '深色模式',
                  child: Switch(
                    value: dark,
                    onChanged: followsSystem
                        ? null
                        : (value) => settings.onChanged(
                            value ? ThemeMode.dark : ThemeMode.light,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
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
  }

  Widget _group(List<Widget> children) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

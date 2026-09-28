# VelaX client

本地数据层使用 Drift + SQLite，支持原生 Flutter 平台。领域对象位于
`lib/domain/models/`，尺寸枚举位于 `lib/domain/enums/`。
表定义位于 `lib/data/database/tables/`，预置数据位于 `lib/data/database/seed/`，
数据库入口与生成代码位于 `lib/data/database/`。各实体的 Repository 位于
`lib/data/repositories/`，图片文件存储位于 `lib/data/storage/`。

```dart
final database = AppDatabase();
final items = ClothingItemRepository(database);
final categories = await CategoryRepository(database).categories(); // 首次访问自动建表和预置数据
final image = await LocalImageStore().importFile(pickedFile);
final item = await items.saveItem(
  image: image,
  categoryId: 'top_t_shirt',
  size: 'M',
  secondaryColorIds: ['blue'],
);
await database.close(); // 由持有数据库的应用作用域在释放时调用
```

品牌使用 `BrandRepository`，只读颜色列表使用 `ColorRepository`。
领域颜色类型为 `Color`；与 Flutter 的 `Color` 同时使用时给领域导入添加别名。
`ApparelSize` / `ShoeSize` 的 `value` 对应单品的尺寸字符串。

`saveItem` 不传 ID 时创建，传 ID 时完整更新；省略的可选字段会被清空。
Repository 分配 UUID 和时间戳，保留创建时间，校验两级品类、尺寸及配色。
自定义一级品类暂无尺寸配置，仅接受空尺寸。预置品类只读，颜色只读。
在用品类和有子品类的品类禁止删除；品牌删除会清空引用；单品删除级联
删除配色。图片复制到应用文档目录，数据库只保存路径；删除单品暂不清理
图片，以免误删共享文件。当前不提供 Web 存储适配。

修改表定义后运行 `dart run build_runner build`，提交生成的
`app_database.g.dart`。升级 schemaVersion 时须补充对应迁移；当前版本为 1。
验证命令：`flutter analyze` 和 `flutter test`。

# 数据库约束

- 使用 Drift + SQLite。
- Domain Model 与数据库表模型分离。
- 图片文件存储在应用本地文件目录，数据库仅保存路径。
- ClothingItem 通过 ID 引用 Category、Brand 和 Color。
- Category、Color 的预置数据在数据库首次初始化时写入。
- 预置数据 ID 必须固定，初始化操作需幂等。
- 用户自定义 Category ID 使用 `custom_<UUID>`。
- Brand ID 和 ClothingItem ID 使用 UUID。
- secondaryColors 使用关联表存储，最多两项。
- Repository 作为 Domain/UI 与数据库之间的访问层。
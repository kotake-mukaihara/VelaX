import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velax/data/database/app_database.dart';
import 'package:velax/data/storage/local_image_store.dart';
import 'package:velax/data/repositories/clothing_item_repository.dart';
import 'package:velax/data/repositories/category_repository.dart';
import 'package:velax/data/repositories/brand_repository.dart';
import 'package:velax/data/repositories/color_repository.dart';

void main() {
  late AppDatabase db;
  late ClothingItemRepository repository;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = ClothingItemRepository(db);
  });
  tearDown(() => db.close());

  test(
    'seeds fixed categories and colors idempotently with no brands',
    () async {
      final original = await CategoryRepository(db).categories();
      expect(original, hasLength(30));
      expect(await ColorRepository(db).colors(), hasLength(15));
      expect(await BrandRepository(db).brands(), isEmpty);
      await db.seedPresets();
      expect(await CategoryRepository(db).categories(), hasLength(30));
      expect(
        (await CategoryRepository(db).categories()).first.createdAt,
        original.first.createdAt,
      );
    },
  );

  test(
    'round trips, clears nullable fields, and cascades secondary colors',
    () async {
      final brand = await BrandRepository(db).createBrand(' Brand ');
      final item = await repository.saveItem(
        image: '/local/photo.jpg',
        categoryId: 'top_shirt',
        brandId: brand.id,
        size: 'M',
        primaryColorId: 'white',
        secondaryColorIds: ['blue', 'red'],
        note: '   ',
      );
      expect(item.brand!.name, 'Brand');
      expect(item.note, isNull);
      expect(item.secondaryColors.map((c) => c.id), ['blue', 'red']);
      expect((await repository.items()).single.id, item.id);
      final updated = await repository.saveItem(
        id: item.id,
        image: item.image,
        categoryId: 'shoes',
        size: '40',
        note: ' hello ',
      );
      expect(updated.createdAt, item.createdAt);
      expect(updated.note, 'hello');
      expect(updated.brand, isNull);
      expect(updated.primaryColor, isNull);
      expect(updated.secondaryColors, isEmpty);
      await repository.saveItem(
        id: item.id,
        image: item.image,
        categoryId: 'top',
        secondaryColorIds: ['red'],
      );
      await repository.deleteItem(item.id);
      expect(await repository.getItem(item.id), isNull);
      expect(await db.select(db.itemSecondaryColors).get(), isEmpty);
    },
  );

  test(
    'invalid references roll back the item and its existing palette',
    () async {
      final item = await repository.saveItem(
        image: '/a.jpg',
        categoryId: 'top',
        secondaryColorIds: ['red'],
      );
      await expectLater(
        repository.saveItem(
          id: item.id,
          image: '/b.jpg',
          categoryId: 'top',
          secondaryColorIds: ['blue', 'missing'],
        ),
        throwsException,
      );
      final saved = (await repository.getItem(item.id))!;
      expect(saved.image, '/a.jpg');
      expect(saved.secondaryColors.single.id, 'red');
      await expectLater(
        repository.saveItem(
          image: '/a.jpg',
          categoryId: 'top',
          brandId: 'missing',
        ),
        throwsException,
      );
      expect(await repository.items(), hasLength(1));
    },
  );

  test('rejects bad sizes, duplicate colors, and too many colors', () async {
    await expectLater(
      repository.saveItem(image: '/a', categoryId: 'shoes', size: 'M'),
      throwsArgumentError,
    );
    for (final palette in [
      ['red', 'red'],
      ['red', 'blue', 'green'],
    ]) {
      await expectLater(
        repository.saveItem(
          image: '/a',
          categoryId: 'top',
          secondaryColorIds: palette,
        ),
        throwsArgumentError,
      );
    }
    final item = await repository.saveItem(
      image: '/a',
      categoryId: 'top',
      secondaryColorIds: ['red', 'blue'],
    );
    await expectLater(
      db
          .into(db.itemSecondaryColors)
          .insert(
            ItemSecondaryColorsCompanion.insert(
              itemId: item.id,
              colorId: 'green',
              position: 2,
            ),
          ),
      throwsException,
    );
    await expectLater(
      db
          .into(db.itemSecondaryColors)
          .insert(
            ItemSecondaryColorsCompanion.insert(
              itemId: item.id,
              colorId: 'green',
              position: 1,
            ),
          ),
      throwsException,
    );
  });

  test(
    'enforces two category levels and protects referenced categories',
    () async {
      final root = await CategoryRepository(db).createCategory('自定义');
      expect(root.id, startsWith('custom_'));
      final child = await CategoryRepository(db)
          .createCategory('子类', parentId: root.id);
      await expectLater(
        CategoryRepository(db).createCategory('三级', parentId: child.id),
        throwsArgumentError,
      );
      await expectLater(
        CategoryRepository(db).deleteCategory(root.id),
        throwsException,
      );
      await CategoryRepository(db)
          .updateCategory(child.id, name: '修改', sortOrder: 10);
      final item = await repository.saveItem(image: '/a', categoryId: child.id);
      await expectLater(
        CategoryRepository(db).deleteCategory(child.id),
        throwsException,
      );
      await expectLater(
        CategoryRepository(db).deleteCategory('top'),
        throwsStateError,
      );
      await repository.deleteItem(item.id);
      await CategoryRepository(db).deleteCategory(child.id);
      await CategoryRepository(db).deleteCategory(root.id);
    },
  );

  test('deleting a brand clears item references', () async {
    final brand = await BrandRepository(db).createBrand('Brand');
    await BrandRepository(db).updateBrand(brand.id, 'New');
    final item = await repository.saveItem(
      image: '/a',
      categoryId: 'top',
      brandId: brand.id,
    );
    await BrandRepository(db).deleteBrand(brand.id);
    expect((await repository.getItem(item.id))!.brand, isNull);
  });

  test('persists data across connections', () async {
    final folder = await Directory.systemTemp.createTemp('velax_db_test');
    final file = File('${folder.path}/test.sqlite');
    final first = AppDatabase.forTesting(NativeDatabase(file));
    try {
      final item = await ClothingItemRepository(first)
          .saveItem(image: '/a', categoryId: 'top');
      await first.close();
      final second = AppDatabase.forTesting(NativeDatabase(file));
      try {
        expect(
          (await ClothingItemRepository(second).getItem(item.id))!.image,
          '/a',
        );
        expect(await CategoryRepository(second).categories(), hasLength(30));
      } finally {
        await second.close();
      }
    } finally {
      await folder.delete(recursive: true);
    }
  });

  test('copies images into application storage', () async {
    final folder = await Directory.systemTemp.createTemp('velax_image_test');
    try {
      final source = await File('${folder.path}/source.png')
          .writeAsBytes([1, 2, 3]);
      final store = LocalImageStore(directory: () async => folder);
      final path = await store.importFile(source);
      expect(path, contains('wardrobe_images'));
      expect(await File(path).readAsBytes(), [1, 2, 3]);
      expect(await store.importFile(source), isNot(path));
    } finally {
      await folder.delete(recursive: true);
    }
  });
}

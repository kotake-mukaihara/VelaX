# 数据模型

## 1. ClothingItem 单品

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| id | UUID | 是 | 单品唯一标识 |
| image | String | 是 | 图片资源标识，本地阶段存储本地文件路径 |
| category | Category | 是 | 品类 |
| brand | Brand? | 否 | 品牌 |
| size | String? | 否 | 尺寸，可选值由所属一级品类决定 |
| primaryColor | Color? | 否 | 主色 |
| secondaryColors | List<Color> | 是 | 配色，0～2 个，无配色时为空列表 |
| note | String? | 否 | 备注，空白字符串保存时转换为 null |
| createdAt | DateTime | 是 | 创建时间 |
| updatedAt | DateTime | 是 | 修改时间 |

## 2. Category 品类

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| id | String | 是 | 品类唯一标识，预置品类使用固定字符串 ID，用户自定义品类使用 custom_<UUID> 作为 ID |
| name | String | 是 | 品类名称 |
| parentId | String? | 否 | 父品类 ID，顶级品类为 null |
| isPreset | Boolean | 是 | 是否为预置品类 |
| sortOrder | Int | 是 | 排序值，越小越靠前 |
| createdAt | DateTime | 是 | 创建时间 |
| updatedAt | DateTime | 是 | 修改时间 |

品类采用两级结构，并允许用户自定义添加。

一级品类预置如下：

| id | 名称 |
|---|---|
| top | 上装 |
| bottom | 下装 |
| shoes | 鞋履 |

### Top 上装

+ top_t_shirt T恤
+ top_shirt 衬衫
+ top_hoodie 卫衣/帽衫
+ top_sweater 毛衣/针织衫
+ top_vest 背心
+ top_polo POLO衫
+ top_jacket 夹克
+ top_windbreaker 风衣
+ top_coat 大衣
+ top_suit 西服
+ top_leather_jacket 皮衣
+ top_down_jacket 羽绒服
+ top_other 其他

### Bottom 下装

+ bottom_jeans 牛仔裤
+ bottom_sweatpants 卫裤
+ bottom_cargo_pants 工装裤
+ bottom_casual_pants 休闲裤
+ bottom_dress_pants 西裤
+ bottom_other 其他

### Shoes 鞋履

+ shoes_sneakers 运动鞋
+ shoes_canvas 帆布鞋
+ shoes_skate 板鞋
+ shoes_leather 皮鞋
+ shoes_boots 靴子
+ shoes_sandals 凉鞋
+ shoes_slippers 拖鞋
+ shoes_other 其他

## 3. Brand 品牌

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| id | UUID | 是 | 品牌唯一标识 |
| name | String | 是 | 品牌名称 |
| createdAt | DateTime | 是 | 创建时间 |
| updatedAt | DateTime | 是 | 修改时间 |

默认不预置数据，用户可以自定义添加品牌。

## 4. Size 尺寸

尺寸值根据一级品类动态确定。

### ApparelSize 服装码

适用于上装、下装。

- XS
- S
- M
- L
- XL
- XXL

### ShoeSize 鞋码

适用于鞋履。

- 35
- 36
- 37
- 38
- 39
- 40
- 41
- 42
- 43
- 44
- 45

## 5. Color 颜色

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| id | String | 是 | 颜色唯一标识 |
| name | String | 是 | 颜色名称 |
| hex | String | 是 | 颜色 HEX 值 |

以下是默认的颜色数据，用户暂不能自定义添加颜色。

| id | 名称 | HEX |
|---|---|---|
| white | 白色 | #FFFFFF |
| cream | 米白色 | #F6EDDB |
| black | 黑色 | #000000 |
| gray | 灰色 | #A0A0A0 |
| red | 红色 | #FF0000 |
| orange | 橙色 | #FFA500 |
| yellow | 黄色 | #FFFF00 |
| green | 绿色 | #00CC66 |
| cyan | 青色 | #26C6DA |
| blue | 蓝色 | #3399FF |
| purple | 紫色 | #9933FF |
| pink | 粉色 | #FF99CC |
| khaki | 卡其色 | #D6C3B2 |
| brown | 棕色 | #4B2C23 |
| navy | 藏青色 | #1A2747 |
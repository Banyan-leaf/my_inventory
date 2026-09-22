/// 模块：app / pages / onboarding
/// 职责：新手指引的内容数据。
/// 约束：
///   1. 只承载数据，不含渲染逻辑。
///   2. Block 是 sealed class，各子类对应不同的视觉样式。
library;

import 'package:flutter/material.dart';

/// 单页数据。
class OnboardingStep {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<Block> blocks;

  const OnboardingStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.blocks,
  });
}

// ---------- Block 类型 ----------

sealed class Block {
  const Block();
}

/// 小标题（带左侧竖条）。
class HeadingBlock extends Block {
  final String text;
  const HeadingBlock(this.text);
}

/// 段落。
class ParagraphBlock extends Block {
  final String text;
  const ParagraphBlock(this.text);
}

/// 无序列表。
class BulletsBlock extends Block {
  final List<String> items;
  const BulletsBlock(this.items);
}

/// 表格。第一行作为表头。
class TableBlock extends Block {
  final List<List<String>> rows;
  const TableBlock(this.rows);
}

/// 引用/示例框（等宽字体，灰底）。
class QuoteBlock extends Block {
  final String text;
  const QuoteBlock(this.text);
}

/// 提示框（黄底）。
class TipBlock extends Block {
  final String text;
  const TipBlock(this.text);
}

/// 动手试试（绿底，带编号步骤）。
class ActionBlock extends Block {
  final String title;
  final List<String> steps;
  const ActionBlock({required this.title, required this.steps});
}

// ---------- 15 页数据 ----------

const List<OnboardingStep> onboardingSteps = [
  // ==================== 1. 欢迎 ====================
  OnboardingStep(
    icon: Icons.waving_hand_outlined,
    color: Colors.teal,
    title: '欢迎使用',
    subtitle: '一个完全离线的物品管家',
    blocks: [
      ParagraphBlock('本软件帮你把家里的物品数字化：找得到、记得住、录得快。所有数据都存在本机，不联网、不上传、不泄露。'),
      HeadingBlock('数据存在哪'),
      TableBlock([
        ['内容', '位置'],
        ['数据库', 'Documents\\inventory.db'],
        ['附件图片', 'Documents\\my_inventory_photos\\'],
        ['备份文件', '由你选择导出路径'],
      ]),
      HeadingBlock('5 个页面'),
      TableBlock([
        ['页面', '用途'],
        ['物品', '查看和管理所有已录入物品'],
        ['位置', '按物理位置组织物品（树形结构）'],
        ['联想', '快速录入：输入关键词从词库选词创建'],
        ['统计', '图表查看分类、价值、到期等全貌'],
        ['设置', '主题、皮肤、分类/标签/状态管理、导入导出'],
      ]),
      ActionBlock(
        title: '动手试试',
        steps: [
          '点底部 5 个 tab，每个都点一下',
          '感受一下每个页面大致是什么',
        ],
      ),
    ],
  ),

  // ==================== 2. 四维度 ====================
  OnboardingStep(
    icon: Icons.category_outlined,
    color: Colors.indigo,
    title: '一个物品 = 4 个维度',
    subtitle: '理解这 4 点，就理解了整个软件',
    blocks: [
      ParagraphBlock('每个物品都可以用 4 个独立维度描述。它们各自独立，可以自由组合。'),
      TableBlock([
        ['维度', '数量关系'],
        ['位置', '一个物品只在一个位置'],
        ['分类', '一个物品只属于一个分类'],
        ['标签', '一个物品可以挂多个'],
        ['别名', '一个物品可以有多个别名'],
      ]),
      HeadingBlock('各自的角色'),
      BulletsBlock([
        '位置：管"在哪"，树形结构（家 / 书房 / 书柜A）',
        '分类：管"是什么"，比如电子、工具、日用',
        '标签：管"怎么用"，比如贵重、常用、闲置',
        '别名：管"怎么搜"，比如台灯可以叫"夜灯、照明灯"',
      ]),
      HeadingBlock('一个例子'),
      QuoteBlock('名称：台灯\n位置：家 / 书房 / 书桌\n分类：电子\n标签：贵重、常用\n别名：床头灯, 夜灯'),
      ActionBlock(
        title: '动手试试',
        steps: [
          '打开"物品" tab',
          '点右下角 + 号，看表单',
          '观察：只有"名称"是必填',
          '随便填个名字，保存',
        ],
      ),
    ],
  ),

  // ==================== 3. 手动录入 ====================
  OnboardingStep(
    icon: Icons.edit_note_outlined,
    color: Colors.orange,
    title: '手动录入详解',
    subtitle: '适合有明确信息、需要记录价格/日期的场景',
    blocks: [
      ParagraphBlock('从"物品" tab 点 + 进入表单，字段依次如下：'),
      HeadingBlock('1. 名称（必填）'),
      ParagraphBlock('写清楚物品叫什么。同名物品在后面靠分类/标签区分。'),
      HeadingBlock('2. 别名（可选）'),
      ParagraphBlock('逗号分隔，如"照明灯,夜灯"。搜索"夜灯"也能找到它。'),
      HeadingBlock('3. 数量 / 单位'),
      ParagraphBlock('默认"1 件"。可改成 5 支 / 2 盒 / 3 个。批量物品填数量如 5、单位如"双"。'),
      HeadingBlock('4. 分类'),
      ParagraphBlock('下拉选已有分类。右侧有 + 号，可以直接新建分类，建完自动选中。'),
      HeadingBlock('5. 位置'),
      ParagraphBlock('下拉选位置树中任意节点。位置是树形的，可以选到任意层级。'),
      HeadingBlock('6. 状态'),
      ParagraphBlock('默认"在库"。可选：借出 / 维修 / 丢失 / 丢弃 / 耗尽。状态决定了统计图表。'),
      HeadingBlock('7. 价格'),
      ParagraphBlock('填数字，用于统计总价值。'),
      HeadingBlock('8. 日期'),
      BulletsBlock([
        '购买日期：影响价值趋势图',
        '保修到期：会出现在"即将到期"预警',
        '过期日期：适用于药品、食品',
      ]),
      HeadingBlock('9. 标签'),
      ParagraphBlock('显示为 chip，点一下切换选中。上方有 + 新建标签按钮，可现场加。一个物品可以挂任意多个。'),
      HeadingBlock('10. 备注'),
      ParagraphBlock('自由文本，随便写。'),
      ActionBlock(
        title: '动手试试',
        steps: [
          '新建物品"测试电钻"',
          '分类 → 点 + → 输入"工具" → 自动选中',
          '价格填 199，购买日期选今天',
          '保存 → 回列表看效果',
        ],
      ),
    ],
  ),

  // ==================== 4. 位置树 ====================
  OnboardingStep(
    icon: Icons.account_tree_outlined,
    color: Colors.blueGrey,
    title: '位置树详解',
    subtitle: '树形结构，可以无限嵌套',
    blocks: [
      ParagraphBlock('位置是树形结构，像文件夹一样，可以无限层级：'),
      QuoteBlock('家\n├── 书房\n│   ├── 书柜A\n│   │   ├── 第二层\n│   │   └── 第三层\n│   └── 书桌\n├── 厨房\n└── 客厅'),
      HeadingBlock('徽章上的数字'),
      ParagraphBlock('每个位置右侧显示"5 件 · 本层 1"：'),
      BulletsBlock([
        '左边数字（5 件）= 该位置 + 所有子位置的物品总数',
        '右边小字（本层 1）= 直接挂在该位置的物品数',
      ]),
      HeadingBlock('常见操作'),
      BulletsBlock([
        '点击徽章：打开物品清单（显示本层/子层/孙层）',
        '点击位置行：新增子位置',
        '长按位置：重命名 / 删除 / 查看物品',
        '右上角 ⇅：手动排序，用 ↑↓ 调整同级顺序',
        '右上角 ☑：多选模式，批量移动或删除',
      ]),
      HeadingBlock('未分类节点'),
      ParagraphBlock('位置树底部有虚拟节点"未分类"，显示所有没指定位置的物品。点它可以查看、多选、批量移动到某个位置。'),
      ActionBlock(
        title: '动手试试',
        steps: [
          '"位置" tab → 点右下角 + → 输入"家"',
          '点"家"一行 → 输入"书房" → 确定',
          '点"书房" → 输入"书柜A" → 确定',
          '点"家"右侧的徽章 → 看物品清单',
        ],
      ),
    ],
  ),

  // ==================== 5. 分类管理 ====================
  OnboardingStep(
    icon: Icons.folder_outlined,
    color: Colors.amber,
    title: '分类管理',
    subtitle: '一个物品只属于一个分类',
    blocks: [
      HeadingBlock('分类的特点'),
      BulletsBlock([
        '一个物品只能选一个分类',
        '分类可以嵌套（父分类 / 子分类）',
        '主要用途：粗粒度归档',
        '典型分类：电子、工具、日用、文具',
      ]),
      HeadingBlock('入口'),
      ParagraphBlock('设置 → 分类管理'),
      HeadingBlock('操作'),
      BulletsBlock([
        '右下角 + ：新建分类，可选父分类',
        '每项右侧 ✏️ ：重命名',
        '每项右侧 🗑 ：删除（物品变成"未分类"）',
      ]),
      HeadingBlock('在物品列表'),
      ParagraphBlock('物品会按分类分组显示，每个分类一个 section，可以点击 header 折叠。'),
      ActionBlock(
        title: '动手试试',
        steps: [
          '设置 → 分类管理 → 点 + → 输入"电子"',
          '再建一个"工具"',
          '回物品 tab → 观察列表按分类分组',
          '点物品 → 改分类 → 保存 → 看分组变化',
        ],
      ),
    ],
  ),

  // ==================== 6. 标签管理 ====================
  OnboardingStep(
    icon: Icons.local_offer_outlined,
    color: Colors.pink,
    title: '标签管理',
    subtitle: '一个物品可以挂多个标签',
    blocks: [
      HeadingBlock('标签的特点'),
      BulletsBlock([
        '一个物品可以挂多个标签',
        '标签没有层级（扁平）',
        '每个标签可以有一个颜色',
        '主要用途：灵活标记',
      ]),
      HeadingBlock('分类 vs 标签的典型用法'),
      TableBlock([
        ['场景', '用哪个'],
        ['归档', '分类：电子/工具/日用'],
        ['价值', '标签：贵重/普通/淘汰'],
        ['使用频率', '标签：常用/偶尔用/闲置'],
        ['归属', '标签：我的/家人的/办公'],
      ]),
      HeadingBlock('入口'),
      ParagraphBlock('设置 → 标签管理'),
      HeadingBlock('操作'),
      BulletsBlock([
        '右下角 + ：新建标签，选颜色',
        '每项右侧 ✏️ ：改名字和颜色',
        '每项右侧 🗑 ：删除（物品会失去这个标签）',
        '副标题显示"关联 N 个物品"',
      ]),
      ActionBlock(
        title: '动手试试',
        steps: [
          '设置 → 标签管理 → + → 输入"贵重" → 选红色',
          '再建"常用" → 蓝色',
          '回物品 tab → 点某物品 → 勾选这两个标签',
          '保存 → 列表下方出现两个彩色 chip',
        ],
      ),
    ],
  ),

  // ==================== 7. 状态管理 ====================
  OnboardingStep(
    icon: Icons.flag_outlined,
    color: Colors.red,
    title: '状态管理',
    subtitle: '物品的当前处境',
    blocks: [
      HeadingBlock('6 个系统状态'),
      TableBlock([
        ['默认名', '含义'],
        ['在库', '正常存放（新建默认）'],
        ['借出', '借给别人了'],
        ['维修', '送去修理'],
        ['丢失', '找不到了'],
        ['丢弃', '已扔掉'],
        ['耗尽', '用完了'],
      ]),
      TipBlock('系统状态不可删除，但可以改名和改色。"在库"是新建物品的默认状态，删了会影响新建流程。'),
      HeadingBlock('用户新增状态'),
      ParagraphBlock('可以自由增删。删除时如果有物品正在用，会弹窗让你选择迁移到哪个状态，物品自动跟着变。'),
      HeadingBlock('批量改状态'),
      BulletsBlock([
        '物品页多选 → 右上角 🚩 改状态',
        '位置弹窗多选 → 底部 🚩 改状态',
        '未分类弹窗多选 → 底部 🚩 改状态',
      ]),
      ActionBlock(
        title: '动手试试',
        steps: [
          '设置 → 状态管理 → 看到 6 个系统状态',
          '点"在库"的 ✏️ → 改名"库存" → 保存',
          '新建物品时状态默认显示"库存"',
          '点 + 新增一个"已赠送"自定义状态',
        ],
      ),
    ],
  ),

  // ==================== 8. 联想录入 ====================
  OnboardingStep(
    icon: Icons.auto_awesome_outlined,
    color: Colors.deepPurple,
    title: '联想录入',
    subtitle: '少打字，快录入',
    blocks: [
      ParagraphBlock('不想从空表单开始？联想录入让你从词库候选一键创建物品。'),
      HeadingBlock('流程'),
      BulletsBlock([
        '输入关键词（如"灯"）',
        '出现两类结果：已有物品 + 词库候选',
        '点未录入候选（橙色竖条）→ 直接创建',
        '点已录入候选（绿色 ✓）→ 弹菜单',
      ]),
      HeadingBlock('同名不同类'),
      ParagraphBlock('词库里可能有多个同名条目，用橙色大类徽章区分：'),
      QuoteBlock('○ 苹果   [水果]\n○ 苹果   [电子]'),
      HeadingBlock('搜不到怎么办'),
      BulletsBlock([
        '词库里没这个词 → 底部出现"创建「XXX」"按钮',
        '物品表里已有同名 → 弹窗问是否把它加入词库',
        '两边都没有 → 进入新建物品页，名称预填',
      ]),
      ActionBlock(
        title: '动手试试',
        steps: [
          '联想 tab → 输入"灯"',
          '观察词库候选的橙色大类徽章',
          '点一个未录入的（如"壁灯"）→ 直接创建',
          '观察它变成绿色 ✓ 已录入',
        ],
      ),
    ],
  ),  // ==================== 9. 学习机制 ====================
  OnboardingStep(
    icon: Icons.school_outlined,
    color: Colors.green,
    title: '学习机制',
    subtitle: '软件会"学"你录的东西',
    blocks: [
      ParagraphBlock('保存新物品后，弹窗问你是否加入词库。这样下次输入相似关键词时它能排更靠前。'),
      HeadingBlock('场景 A：词库里没有这个词'),
      QuoteBlock('把「测试电钻」加入联想词库？\n归入大类：[其他 ▼]'),
      ParagraphBlock('选一个大类 → 点"加入并关联" → 完成。'),
      HeadingBlock('场景 B：词库里已有同名词条'),
      QuoteBlock('词库中已有「台灯」\n你录入的「台灯」和哪个指代相同？\n◉ 台灯  [日用]  权重 5\n○ 台灯  [家具]  权重 1\n○ 都不是，创建新词条'),
      BulletsBlock([
        '选已有的 → 权重 +1，排更靠前',
        '选"都不是" → 进入创建流程，可以新增大类',
      ]),
      TipBlock('觉得烦？可以在"设置 → 学习提醒"里关闭。词库用得越多越贴合你的习惯。'),
      ActionBlock(
        title: '动手试试',
        steps: [
          '新建物品"测试台灯" → 保存',
          '弹窗"加入词库" → 大类选"日用" → 加入并关联',
          '打开"联想" tab → 输入"测试"',
          '观察：测试台灯出现在词库候选里',
        ],
      ),
    ],
  ),

  // ==================== 10. 搜索与批量操作 ====================
  OnboardingStep(
    icon: Icons.checklist_outlined,
    color: Colors.cyan,
    title: '多选 + 批量处理',
    subtitle: '一次改一批',
    blocks: [
      ParagraphBlock('物品页、位置弹窗、未分类弹窗，右上角都有 ☑ 多选图标。'),
      HeadingBlock('进入多选后'),
      BulletsBlock([
        '每个物品左边出现 Checkbox',
        '顶部显示"已选 N / 总数"',
        '旁边有"全选 / 取消全选"',
        '底部或右上角出现操作栏',
      ]),
      HeadingBlock('支持的操作'),
      TableBlock([
        ['操作', '用途'],
        ['🚩 改状态', '批量改为借出/维修/丢失…'],
        ['📁 移动', '批量移到其他位置'],
        ['🗑 删除', '批量软删除'],
        ['✕ 退出', '取消多选模式'],
      ]),
      HeadingBlock('搜索栏'),
      ParagraphBlock('物品页顶部有搜索框，输入名称或别名立即过滤，右侧 ✕ 清空。'),
      ActionBlock(
        title: '动手试试',
        steps: [
          '物品 tab → 右上角 ☑ 进入多选',
          '点几个物品 → 底部出现操作栏',
          '点 🚩 改状态 → 选"维修"',
          '观察这些物品状态变成"维修"',
        ],
      ),
    ],
  ),

  // ==================== 11. 统计仪表盘 ====================
  OnboardingStep(
    icon: Icons.bar_chart_outlined,
    color: Colors.purple,
    title: '统计仪表盘',
    subtitle: '一眼看清全貌',
    blocks: [
      HeadingBlock('7 个可视化区块'),
      TableBlock([
        ['区块', '内容'],
        ['总览卡片', '物品总数、总价值、借出中、即将到期'],
        ['分类分布', '环形图，每类占比'],
        ['状态分布', '环形图，在库/借出/维修…'],
        ['价值趋势', '按购买日期累积的折线'],
        ['位置分布', '每个位置有多少物品'],
        ['标签分布', '每个标签挂了多少物品'],
        ['到期预警', '保修、过期日期临近的清单'],
      ]),
      TipBlock('统计只算未删除的物品。软删除的物品不参与统计。价值趋势只算有"购买日期"和"价格"的物品。'),
      HeadingBlock('不自动刷新'),
      ParagraphBlock('切换 tab 或点右上角 🔄 才更新。数据变动后想立刻看到，需要手动刷新。'),
      ActionBlock(
        title: '动手试试',
        steps: [
          '统计 tab → 点右上角 🔄 刷新',
          '观察图表（物品少时大多是空的，正常）',
          '回物品 tab 多建几个带价格日期的物品',
          '回统计 tab → 再刷新 → 看数据变化',
        ],
      ),
    ],
  ),

  // ==================== 12. 外观与皮肤 ====================
  OnboardingStep(
    icon: Icons.palette_outlined,
    color: Colors.deepOrange,
    title: '外观与皮肤',
    subtitle: '外观管明暗，皮肤管色调',
    blocks: [
      HeadingBlock('两个独立设置'),
      TableBlock([
        ['设置', '作用'],
        ['外观', '浅色 / 深色 / 跟随系统'],
        ['皮肤', '默认青 / 灵梦红 / 早苗绿 / 莎莎黄 / 姆Q紫 / 小伞蓝'],
      ]),
      ParagraphBlock('两者独立：切外观时皮肤保持，切皮肤时外观保持。'),
      HeadingBlock('智能适配'),
      ParagraphBlock('同一个皮肤在浅色和深色下自动生成不同亮度的配色。灵梦红在浅色模式是鲜红，在深色模式是柔和暗红，不需要单独配置。'),
      HeadingBlock('影响范围'),
      BulletsBlock([
        '底部导航栏、按钮、图标',
        '位置徽章、排序箭头、选中高亮',
        '不影响：标签颜色、状态颜色（各自独立定义）',
      ]),
      ActionBlock(
        title: '动手试试',
        steps: [
          '设置 → 外观 → 选"深色"，界面变暗',
          '设置 → 皮肤 → 选"灵梦红"，变红色调',
          '切回"浅色" → 红色保持，背景变亮',
        ],
      ),
    ],
  ),

  // ==================== 13. 数据安全 ====================
  OnboardingStep(
    icon: Icons.backup_outlined,
    color: Colors.brown,
    title: '数据安全与备份',
    subtitle: '数据在你手里，你要负责',
    blocks: [
      HeadingBlock('数据位置'),
      TableBlock([
        ['内容', '路径'],
        ['数据库', 'Documents\\inventory.db'],
        ['附件图片', 'Documents\\my_inventory_photos\\'],
      ]),
      HeadingBlock('导出'),
      BulletsBlock([
        '入口：设置 → 导出到 JSON',
        '生成一个 .json 文件，包含所有表的数据',
        '不含附件图片',
        '文件名自动带时间戳',
      ]),
      HeadingBlock('恢复'),
      BulletsBlock([
        '入口：设置 → 从 JSON 恢复',
        '会清空当前所有数据',
        '附件图片不会恢复（JSON 里只有元数据）',
      ]),
      HeadingBlock('换电脑迁移'),
      BulletsBlock([
        '旧电脑：导出 JSON + 手动拷贝 my_inventory_photos\\ 目录',
        '新电脑：装好软件，把文件放到 Documents',
        '设置 → 从 JSON 恢复（填 JSON 路径）',
      ]),
      TipBlock('建议每周导出一次，大操作前先导出。'),
      ActionBlock(
        title: '动手试试',
        steps: [
          '设置 → 导出到 JSON',
          '打开文件资源管理器 → Documents',
          '找到刚生成的 JSON 文件',
          '用记事本打开看一眼内容',
        ],
      ),
    ],
  ),

  // ==================== 14. 分享给别人 ====================
  OnboardingStep(
    icon: Icons.share_outlined,
    color: Colors.lightBlue,
    title: '分享给别人',
    subtitle: '只给可执行文件，不给源码',
    blocks: [
      HeadingBlock('编译发布版'),
      QuoteBlock('cd C:\\dev\\projects\\my_inventory\nflutter build windows --release'),
      HeadingBlock('输出目录'),
      QuoteBlock('build\\windows\\x64\\runner\\Release\\\n├── my_inventory.exe\n├── flutter_windows.dll\n└── data\\'),
      HeadingBlock('打包方式'),
      ParagraphBlock('整个 Release 目录压缩成 ZIP 发给朋友。'),
      HeadingBlock('朋友使用'),
      BulletsBlock([
        '解压到任意目录',
        '双击 my_inventory.exe',
        '数据存在朋友自己的 Documents\\inventory.db',
        '不需要装 Flutter / VS 等任何东西',
      ]),
      TipBlock('不会泄露你的数据：数据库在 Documents，不在 exe 里。词库是编译进 exe 的，不含你添加的自定义词。'),
      ActionBlock(
        title: '动手试试',
        steps: [
          '跑 flutter build windows --release',
          '打开 Release 目录',
          '看文件清单（只有 exe + dll + data\\）',
        ],
      ),
    ],
  ),

  // ==================== 15. FAQ ====================
  OnboardingStep(
    icon: Icons.help_outline,
    color: Colors.blueGrey,
    title: '常见问题',
    subtitle: '新手最容易踩的坑',
    blocks: [
      HeadingBlock('Q1：物品 ID 为什么跳跃？'),
      ParagraphBlock('ID 是内部编号，删除过的号不复用，避免数据错乱。看到"物品 #5"不代表你有 5 个物品。'),
      HeadingBlock('Q2：统计总数和最高 ID 不一样？'),
      ParagraphBlock('统计的是真实存在的物品数，已删除的不算。'),
      HeadingBlock('Q3：删除物品能恢复吗？'),
      ParagraphBlock('当前 UI 不提供恢复入口。软删除的行还在数据库里，但界面上看不到。'),
      HeadingBlock('Q4：搜"布鞋"显示没有找到？'),
      ParagraphBlock('如果词库和物品里都没有精确匹配，底部会出现"创建"按钮。只匹配到"帆布鞋"是子串匹配，不是精确匹配。'),
      HeadingBlock('Q5：同名不同类的词是什么意思？'),
      ParagraphBlock('比如"苹果"可能是水果也可能是电子品牌。系统允许同名不同大类共存，用橙色大类徽章区分。'),
      HeadingBlock('Q6：切换皮肤会改数据吗？'),
      ParagraphBlock('不会。皮肤只影响界面颜色，跟数据无关。'),
      HeadingBlock('Q7：软件联网吗？'),
      ParagraphBlock('不联网。所有数据本地处理，没有任何网络请求。'),
      HeadingBlock('Q8：数据会越来越大吗？'),
      ParagraphBlock('会，但增长很慢。几千物品 + 事件通常几百 KB。附件图片才是占空间大头。'),
      ActionBlock(
        title: '动手试试',
        steps: [
          '遇到问题时，回"设置 → 新手指引"重看对应章节',
          '如果还有疑问，先尝试操作一遍再问',
        ],
      ),
    ],
  ),
];
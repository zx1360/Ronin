import 'package:torrid/models/common/message.dart';
import 'package:torrid/models/essay/essay.dart';
import 'package:torrid/models/essay/label.dart';
import 'package:torrid/models/essay/year_summary.dart';
import 'package:torrid/util/util.dart';

// 示例数据
class EssaySampleData {
  // 示例标签
  static List<Label> sampleLabels = [
    Label(id: Util.generateId(), name: "日常", essayCount: 12),
    Label(id: Util.generateId(), name: "思考", essayCount: 8),
    Label(id: Util.generateId(), name: "旅行", essayCount: 5),
    Label(id: Util.generateId(), name: "阅读", essayCount: 6),
    Label(id: Util.generateId(), name: "灵感", essayCount: 9),
  ];

  // 示例留言
  static List<Message> _createSampleMessages() {
    return [
      Message(
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        content: "现在回看这段文字，依然很有感触。",
      ),
      Message(
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        content: "当时的想法后来有了新的发展...",
      ),
    ];
  }

  // 示例随笔
  static List<Essay> sampleEssays = [
    Essay(
      id: Util.generateId(),
      date: DateTime.now().subtract(const Duration(days: 1)),
      wordCount: 356,
      content: "今天天气格外晴朗，适合外出散步。午后的阳光透过树叶的缝隙洒在地上，形成斑驳的光影。走在熟悉的街道上，看着周围的人和事，忽然有种时光静止的感觉。\n\n有时候，我们需要放慢脚步，感受生活中的小确幸。一杯热茶，一本好书，一次愉快的交谈，都是构成幸福的元素。不需要追求太多，简单即是美好。\n\n最近在读一本关于心理学的书，让我对人性有了更深的理解。每个人都有自己的故事和难处，多一份理解，少一份苛责，世界会变得更温暖。",
      imgs: [
        "https://picsum.photos/id/1000/800/600",
      ],
      labels: [sampleLabels[0].id, sampleLabels[1].id],
      messages: _createSampleMessages(),
    ),
    Essay(
      id: Util.generateId(),
      date: DateTime.now().subtract(const Duration(days: 3)),
      wordCount: 289,
      content: "终于完成了那个困扰我许久的项目，虽然过程充满挑战，但结果令人满意。这让我明白，只要坚持下去，再困难的事情也能找到解决的办法。\n\n期间得到了很多朋友的帮助，真心感谢他们。人与人之间的互助，让这个世界变得更加美好。晚上奖励自己看了一部电影，放松一下紧绷的神经。",
      imgs: [],
      labels: [sampleLabels[1].id],
      messages: [],
    ),
    Essay(
      id: Util.generateId(),
      date: DateTime.now().subtract(const Duration(days: 7)),
      wordCount: 421,
      content: "今天去了郊外的公园，远离城市的喧嚣，心情格外舒畅。大自然的治愈力总是让人惊叹，清新的空气，翠绿的草地，盛开的花朵，构成了一幅美丽的画卷。\n\n坐在湖边的长椅上，看着远处的鸟儿飞过水面，激起一圈圈涟漪。那一刻，所有的烦恼都烟消云散。有时候，我们需要暂时逃离日常生活，去寻找内心的平静。\n\n傍晚时分，天空出现了绚丽的晚霞，红色、橙色、紫色交织在一起，美得让人窒息。赶紧用手机记录下这瞬间的美好。",
      imgs: [
        "https://picsum.photos/id/1015/800/600",
        "https://picsum.photos/id/1016/800/600",
      ],
      labels: [sampleLabels[0].id, sampleLabels[2].id],
      messages: [
        Message(
          timestamp: DateTime.now().subtract(const Duration(days: 5)),
          content: "这地方真美，下次也想去看看！",
        ),
      ],
    ),
    Essay(
      id: Util.generateId(),
      date: DateTime.now().subtract(const Duration(days: 10)),
      wordCount: 512,
      content: "读完了《人类简史》，这本书给了我很多启发。作者从全新的角度解读了人类的发展历程，让我对历史有了不同的认识。\n\n书中提到的认知革命、农业革命和科学革命，每一个阶段都深刻地改变了人类的命运。最让我印象深刻的是关于金钱和宗教的论述，它们作为虚构的概念，却对人类社会产生了如此巨大的影响。\n\n阅读不仅能增长知识，更能开阔视野。以后要坚持保持阅读的习惯，探索更多未知的领域。",
      imgs: [
        "https://picsum.photos/id/24/800/600",
      ],
      labels: [sampleLabels[3].id, sampleLabels[1].id],
      messages: [],
    ),
    Essay(
      id: Util.generateId(),
      date: DateTime.now().subtract(const Duration(days: 15)),
      wordCount: 278,
      content: "突然有了一个新的想法，关于如何改进我们目前的工作流程。记录下来，免得以后忘记：\n\n1. 建立更清晰的任务分配机制\n2. 增加每日简短例会，及时解决问题\n3. 引入自动化工具，减少重复劳动\n4. 定期回顾总结，不断优化流程\n\n希望这个想法能有所帮助，下周可以和团队讨论一下。",
      imgs: [],
      labels: [sampleLabels[4].id],
      messages: [
        Message(
          timestamp: DateTime.now().subtract(const Duration(days: 12)),
          content: "和团队讨论过了，大家都很认可这些建议！",
        ),
        Message(
          timestamp: DateTime.now().subtract(const Duration(days: 8)),
          content: "已经开始实施，效果不错！",
        ),
      ],
    ),
  ];

  // 示例年度总结
  static List<YearSummary> sampleYearSummaries = [
    YearSummary(
      year: DateTime.now().year.toString(),
      essayCount: sampleEssays.length,
      wordCount: sampleEssays.fold(0, (sum, essay) => sum + essay.wordCount),
      monthSummaries: [
        MonthSummary(month: DateTime.now().month.toString(), essayCount: sampleEssays.length, wordCount: sampleEssays.fold(0, (sum, essay) => sum + essay.wordCount)),
        MonthSummary(month: (DateTime.now().month - 1).toString(), essayCount: 4, wordCount: 1250),
        MonthSummary(month: (DateTime.now().month - 2).toString(), essayCount: 6, wordCount: 1870),
      ],
    ),
    YearSummary(
      year: (DateTime.now().year - 1).toString(),
      essayCount: 56,
      wordCount: 24560,
      monthSummaries: List.generate(12, (index) => 
        MonthSummary(
          month: (index + 1).toString(), 
          essayCount: 4 + index % 3, 
          wordCount: 1500 + index * 120
        )
      ),
    ),
  ];

  // 根据ID获取标签名称
  static String getLabelName(String labelId) {
    final label = sampleLabels.firstWhere((l) => l.id == labelId, orElse: () => Label(id: '', name: '', essayCount: 0));
    return label.name;
  }
}

import 'package:torrid/features/read/models/random_media_models.dart';

// ────────────────────────────────────────────
// 图片 API 源
// ────────────────────────────────────────────

const kImageGroups = <MediaApiGroup>[
  // ── czl.net ──
  MediaApiGroup(
    id: 'czl',
    name: 'czl 随机',
    sources: [
      RandomMediaSource(
        label: '全部图片',
        apiUrl: 'https://random-api.czl.net/pic/all',
        responseType: ApiResponseType.redirect302,
      ),
      RandomMediaSource(
        label: '普通图片',
        apiUrl: 'https://random-api.czl.net/pic/normal',
        responseType: ApiResponseType.redirect302,
      ),
      RandomMediaSource(
        label: 'AI 图片',
        apiUrl: 'https://random-api.czl.net/pic/ai',
        responseType: ApiResponseType.redirect302,
      ),
      RandomMediaSource(
        label: '二次元',
        apiUrl: 'https://random-api.czl.net/pic/ecy',
        responseType: ApiResponseType.redirect302,
      ),
      RandomMediaSource(
        label: '加载图',
        apiUrl: 'https://random-api.czl.net/pic/loading',
        responseType: ApiResponseType.redirect302,
      ),
      RandomMediaSource(
        label: '背景图',
        apiUrl: 'https://random-api.czl.net/pic/czlwb',
        responseType: ApiResponseType.redirect302,
      ),
      RandomMediaSource(
        label: '风景',
        apiUrl: 'https://random-api.czl.net/pic/fj',
        responseType: ApiResponseType.redirect302,
      ),
      RandomMediaSource(
        label: '美女',
        apiUrl: 'https://random-api.czl.net/pic/truegirl',
        responseType: ApiResponseType.redirect302,
      ),
    ],
  ),

  // ── xxapi.cn ──
  MediaApiGroup(
    id: 'xxapi',
    name: 'xxapi 4K 壁纸',
    sources: [
      RandomMediaSource(
        label: '4K 壁纸',
        apiUrl: 'https://v2.xxapi.cn/api/random4kPic?return=json',
        responseType: ApiResponseType.json,
        jsonUrlKey: 'data',
        params: [
          ApiParam(
            key: 'type',
            label: '类型',
            defaultValue: 'acg',
            options: [
              ApiParamOption('acg', '二次元'),
              ApiParamOption('wallpaper', '风景壁纸'),
            ],
          ),
        ],
      ),
    ],
  ),

  // ── ZiChen ACG ──
  MediaApiGroup(
    id: 'zichen',
    name: 'ZiChen ACG',
    sources: [
      RandomMediaSource(
        label: 'ACG 二次元',
        apiUrl: 'https://app.zichen.zone/api/acg/api.php',
        responseType: ApiResponseType.redirect302,
      ),
    ],
  ),

  // ── Lolicon Pixiv ──
  MediaApiGroup(
    id: 'lolicon',
    name: 'Lolicon Pixiv',
    sources: [
      RandomMediaSource(
        label: 'Pixiv 随机',
        apiUrl: 'https://api.lolicon.app/setu/v2?r18=0&num=1',
        responseType: ApiResponseType.json,
        jsonUrlPath: ['data', '0', 'urls', '{size}'],
        params: [
          ApiParam(
            key: 'size',
            label: '图片规格',
            defaultValue: 'regular',
            options: [
              ApiParamOption('original', '原图'),
              ApiParamOption('regular', '常规'),
              ApiParamOption('small', '小图'),
            ],
          ),
          ApiParam(
            key: 'excludeAI',
            label: '排除 AI',
            defaultValue: 'false',
            options: [
              ApiParamOption('false', '不排除'),
              ApiParamOption('true', '排除'),
            ],
          ),
          ApiParam(key: 'tag', label: '标签', hint: '可选，如: 风景|壁纸'),
        ],
      ),
    ],
  ),

  // ── Tmini 随机图片（apidata?id=18）──
  MediaApiGroup(
    id: 'tmini',
    name: 'Tmini 随机',
    sources: [
      RandomMediaSource(
        label: '随机表情图',
        apiUrl: 'https://tmini.net/api/emojis',
        responseType: ApiResponseType.json,
        jsonUrlPath: ['data', '0', 'url'],
        params: [
          ApiParam(
            key: 'id',
            label: '分类',
            defaultValue: '2',
            options: [
              ApiParamOption('1', '热门'),
              ApiParamOption('2', '精选'),
              ApiParamOption('3', '熊猫表情'),
              ApiParamOption('4', '模板'),
              ApiParamOption('5', '卡通'),
              ApiParamOption('158', '天线宝宝'),
              ApiParamOption('514', '上班狗专用'),
            ],
          ),
          ApiParam(
            key: 'json',
            label: '返回条数',
            defaultValue: '1',
            options: [
              ApiParamOption('1', '1 条'),
              ApiParamOption('2', '2 条'),
              ApiParamOption('3', '3 条'),
              ApiParamOption('5', '5 条'),
            ],
          ),
        ],
      ),
    ],
  ),
];

// ────────────────────────────────────────────
// 视频 API 源
// ────────────────────────────────────────────

const kVideoGroups = <MediaApiGroup>[
  MediaApiGroup(
    id: 'czl',
    name: 'czl 随机',
    sources: [
      RandomMediaSource(
        label: '抖音艺术',
        apiUrl: 'https://random-api.czl.net/video/dy-art',
        responseType: ApiResponseType.redirect302,
      ),
    ],
  ),
  MediaApiGroup(
    id: 'tmini',
    name: 'Tmini 随机',
    sources: [
      RandomMediaSource(
        label: '随机小姐姐',
        apiUrl: 'https://tmini.net/api/meinv?mp4=json',
        responseType: ApiResponseType.json,
        jsonUrlKey: 'url',
      ),
    ],
  ),
];

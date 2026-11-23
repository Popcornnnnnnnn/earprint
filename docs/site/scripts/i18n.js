/* Earprint Bilingual Dictionary & Controller (English <-> Simplified Chinese) */

const STORAGE_KEY = 'earprint.lang';

export const MESSAGES = {
  en: {
    'meta.title': 'Earprint — 3D Headphone Archive & Acoustic Rings',
    'nav.cards': '3D Cards',
    'nav.rings': 'Rings Lab',
    'nav.dossier': 'Dossier',
    'nav.widgets': 'Widgets',
    'nav.support': 'Support',
    'nav.privacy': 'Privacy',
    'nav.cta': 'App Store',
    'controls.langToggle': '中文',
    'controls.langAria': '中文 · Switch language to Simplified Chinese',
    'controls.themeLight': 'Ceramic',
    'controls.themeDark': 'Obsidian',
    'controls.themeLightAria': 'Ceramic · Switch to Light Museum appearance',
    'controls.themeDarkAria': 'Obsidian · Switch to Dark Studio appearance',

    'hero.eyebrow': '01 / ACOUSTIC ARCHIVE · READ-ONLY HEALTHKIT',
    'hero.title': 'Every hour in your headphones, cast in metal.',
    'hero.lead': 'Turn read-only Apple Health Headphone Audio Levels into 6-tier 3D foil cards, a PSA-style Device Dossier, 28-day Earprint Rings, and Home & Lock Screen widgets — 100% on your iPhone.',
    'hero.ctaPrimary': 'Download on App Store · Free',
    'hero.ctaSecondary': 'View Source on GitHub',
    'hero.spec1Val': '06 FOIL TIERS',
    'hero.spec1Lbl': '0h Bronze Slate → 2,000h+ Liquid Holo',
    'hero.spec2Val': '34 MODEL PIDS',
    'hero.spec2Lbl': 'Bluetooth 0x2002–0x2036 Lookup',
    'hero.spec3Val': '0 BYTES SENT',
    'hero.spec3Lbl': 'Read-Only HealthKit · No Tracking',

    'hero.flipFront': 'Inspect Rear Provenance',
    'hero.flipBack': 'Return to Front Slab',
    'hero.hoursLabel': 'Lifetime Listening Hours',
    'hero.tierQuickLabel': 'Jump to Collector Tier',
    'hero.dragHint': 'Drag or tilt card to inspect specular grain',

    'showcase.eyebrow': '02 / REALITYKIT MOTION & METALLURGY',
    'showcase.title': 'Sculpted in RealityKit. Tempered by hours.',
    'showcase.lead': 'Every pair renders in real-time 3D above an anodized collector plate — drag with momentum, pinch to zoom, long-press to twirl, and level across 6 curated foil finishes.',
    'showcase.video1Title': 'DARK STUDIO · AIRPODS PRO 2',
    'showcase.video2Title': 'MUSEUM LIGHT · AIRPODS MAX',
    'showcase.pauseVideos': 'Pause 3D Loops',
    'showcase.playVideos': 'Play 3D Loops',
    'showcase.binderHeading': 'Collector Binder · 6 Rarity Thresholds',

    'rings.eyebrow': '03 / ACOUSTIC CHRONOMETER · WHO / ITU H.870',
    'rings.title': '28 days × 24 hours, plotted by loudness.',
    'rings.lead': 'Concentric rings map the past four weeks by local hour, energy-averaged loudness (Leq in dB(A)), listening persona, and your weekly safe-listening budget.',
    'rings.deviceFilterLabel': 'Filter Listening History',
    'rings.personaFilterLabel': 'Explore Listening Personas',
    'rings.deviceAll': 'All Pairs',
    'rings.personaNight': 'Night Owl',
    'rings.personaCommute': 'Commute',
    'rings.personaEarly': 'Early Bird',
    'rings.personaAllDay': 'All-Day',
    'rings.readoutIdle': 'Hover, tap, or arrow across the dial to inspect any hour sector.',
    'rings.scaleQuiet': '<60 dB(A) Glacier Mint',
    'rings.scaleMod': '70 dB(A) Champagne Gold',
    'rings.scaleLoud': '82+ dB(A) Rose Crimson',
    'rings.whoHeading': 'WHO / ITU H.870 Weekly Sound Budget',
    'rings.whoFormula': 'Reference ceiling: 80 dB(A) for 40 hours/week, halving every +3 dB.',
    'rings.whoDbLabel': 'Weekly Average Loudness (Leq)',
    'rings.whoHoursLabel': 'Weekly Listening Duration',
    'rings.whoPctLbl': 'Budget Used',
    'rings.whoAllowLbl': 'Safe Weekly Ceiling',
    'rings.whoExposedLbl': 'Exposed Time',
    'rings.whoRemainLbl': 'Remaining Budget',
    'rings.posterHeading': '3:4 & 9:16 Share Poster Preview',

    'dossier.eyebrow': '04 / PSA-STYLE DEVICE DOSSIER · EAR GRADE',
    'dossier.title': 'Each pair, acoustically graded.',
    'dossier.lead': 'Behind every collectible sits a transparent Ear Grade (1.0–10.0), 30-day loudness trend, 24-hour Day Clock, monthly ledger, milestones, and guilloché provenance certificate.',
    'dossier.simHeading': 'Simulate Ear Grade Formula',
    'dossier.simLead': 'Live mirror of DeviceDossier.swift: starts at 10.0 and deducts four transparent acoustic penalties.',
    'dossier.dbLabel': '30-Day Avg Loudness',
    'dossier.doseLabel': 'Weekly WHO Dose',
    'dossier.loudLabel': 'Sessions ≥ 80 dB(A)',
    'dossier.nightLabel': 'Late-Night Share (00–05h)',
    'dossier.slabFlipFront': 'Inspect Guilloché Certificate',
    'dossier.slabFlipBack': 'Show Grading Front',
    'dossier.galleryTitle': 'App Exhibition · Dark Studio & Museum Light',
    'dossier.tabDark': 'Dark Studio',
    'dossier.tabLight': 'Museum Light',

    'widgets.eyebrow': '05 / WIDGETKIT · DYNAMIC ISLAND · 41 ICONS',
    'widgets.title': 'Ambient across Home & Lock Screen.',
    'widgets.lead': 'Interactive Today card cycler, 3-slot Card Shelf deep links, Large 28-day Earprint Ring widget, Lock Screen WHO gauges, Live Activity ear-break timer, and 41 custom App Icons.',
    'widgets.studioEyebrow': 'App Icon Studio · 1 Emblem + 10 Finishes × 4 Surfaces = 41 Icons',
    'widgets.studioTitle': 'Pair your Home Screen with your hardware.',
    'widgets.bgLabel': 'Surface Backing',
    'widgets.finishLabel': 'AirPods Max Finish (USB-C & Lightning)',
    'widgets.defaultEmblemBtn': 'Earprint Studio Emblem (Default)',

    'privacy.eyebrow': '06 / ON-DEVICE ARCHITECTURE · CC-BY 4.0',
    'privacy.title': 'Read-only HealthKit. Zero servers.',
    'privacy.lead': 'Your listening history never leaves your iPhone. Release builds request strictly read-only Headphone Audio Levels (toShare: []) under Apple Data Not Collected.',
    'privacy.card1Kicker': 'SINGLE HK TYPE',
    'privacy.card1Title': 'Headphone Audio Levels Only',
    'privacy.card1Body': 'Reads only HKQuantityType(.headphoneAudioExposure) with toShare: []. Never accesses heart rate, sleep, mic, location, or track titles.',
    'privacy.card2Kicker': 'ENCRYPTED SANDBOX',
    'privacy.card2Title': 'Local Cache & App Group',
    'privacy.card2Body': 'Incremental HKAnchoredObjectQueryDescriptor writes aggregates to listening-aggregate.json under iOS file protection and group.com.popcornnn.earprint.',
    'privacy.card3Kicker': 'ZERO TELEMETRY',
    'privacy.card3Title': 'No Accounts, Servers, or SDKs',
    'privacy.card3Body': 'Zero analytics, zero crash reporting SDKs, zero ad frameworks. Exported posters leave iPhone only via your explicit iOS Share Sheet choice.',
    'privacy.card4Kicker': 'OPEN SOURCE',
    'privacy.card4Title': 'Inspect Every Line on GitHub',
    'privacy.card4Body': 'Full SwiftUI, RealityKit, HealthKit, WidgetKit, and test suite source code is auditable publicly on GitHub.',
    'privacy.policyLink': 'Read Full Bilingual Privacy Policy →',
    'privacy.supportLink': 'Open Complete Support & FAQ →',

    'faq.heading': 'Quick Answers',
    'faq.q1': 'Why are no headphones showing up yet?',
    'faq.a1': 'Ensure Settings → Privacy & Security → Health → Earprint has Headphone Audio Levels enabled. Note iOS records samples only while audio actively plays — silent ANC does not generate Health samples.',
    'faq.q2': 'Which headphones receive interactive 3D cards?',
    'faq.a2': 'AirPods (1st–4th gen, ANC & standard), AirPods Pro (1–3), and AirPods Max (Lightning & USB-C) receive matched collectible artwork and 3D models. Beats and third-party Bluetooth headphones still count toward Rings and totals.',
    'faq.q3': 'How do the 6 collector tiers unlock?',
    'faq.a3': 'Cards upgrade automatically by lifetime listening hours: Bronze Slate (0h+), Silver Aluminum (25h+), Fjord Teal (120h+), Deep Purple (400h+), Midnight Carbon (1,000h+), and Liquid Holo (2,000h+).',
    'faq.q4': 'Is Earprint affiliated with Apple or a medical device?',
    'faq.a4': 'No. Earprint is an independent app by Weizhi Wang and is not affiliated with, sponsored by, or endorsed by Apple Inc. Acoustic metrics and WHO budgets are informational only and not a medical device.',

    'credits.caption': 'Bundled 3D Model Attributions (CC-BY 4.0)',
    'finale.title': 'Cast your listening history.',
    'finale.body': 'Free on iOS 18+. Strictly read-only Apple Health integration, 6 foil tiers, 28-day acoustic rings, PSA Device Dossier, and 41 custom app icons.',
    'finale.cta': 'Get Earprint on the App Store',
    'finale.meta': 'Bundle ID: com.popcornnn.earprint · Developer: Weizhi Wang · wmax43906@gmail.com',

    'footer.disclaimer1': 'Earprint is an independent app developed by Weizhi Wang and is not affiliated with, sponsored by, or endorsed by Apple Inc. Apple, Apple Health, AirPods, AirPods Pro, AirPods Max, and Beats are trademarks of Apple Inc.',
    'footer.disclaimer2': 'Earprint visualizations, WHO / ITU H.870 weekly budget estimates, and Ear Grade scores are for personal informational and collectible purposes only and are not a medical device.',
    'footer.showcase': 'Showcase',

    'tiers.bronze.name': 'Bronze Slate',
    'tiers.bronze.finish': 'Anodized Matte',
    'tiers.silver.name': 'Silver Aluminum',
    'tiers.silver.finish': 'Beaded Alloy',
    'tiers.sapphire.name': 'Fjord Teal',
    'tiers.sapphire.finish': 'Brushed Slate',
    'tiers.platinum.name': 'Deep Purple',
    'tiers.platinum.finish': 'Frosted Plum',
    'tiers.obsidian.name': 'Midnight Carbon',
    'tiers.obsidian.finish': 'DLC Coating',
    'tiers.holo.name': 'Liquid Holo',
    'tiers.holo.finish': 'Prism Oxide',

    'back.avgDb': 'Avg Leq',
    'back.longest': 'Longest',
    'back.active': 'Active',
    'back.sessions': 'Sessions',
    'rings.sumTotal': '28-Day Total',
    'rings.sumLeq': 'Energy Avg Leq',
    'rings.sumSessions': 'Sessions',
    'poster.dark': 'Dark',
    'poster.light': 'Light',
    'icon.bgAuto': 'Auto',
    'icon.bgLight': 'Light',
    'icon.bgDark': 'Dark',
    'icon.bgHolo': 'Holo',
    'table.model': 'Model',
    'table.work': 'Source Work',
    'table.creator': 'Creator',
    'table.license': 'License',

    'sub.backHome': '← Back to Earprint Showcase',
    'sub.privacyTitle': 'Privacy Policy · 隐私政策 — Earprint',
    'sub.supportTitle': 'Support & FAQ · 使用帮助 — Earprint'
  },

  'zh-Hans': {
    'meta.title': 'Earprint — 3D 耳机收藏图鉴与声学聆听环',
    'nav.cards': '3D 闪卡',
    'nav.rings': '声纹环',
    'nav.dossier': '设备档案',
    'nav.widgets': '小组件',
    'nav.support': '使用帮助',
    'nav.privacy': '隐私政策',
    'nav.cta': 'App Store',
    'controls.langToggle': 'EN',
    'controls.langAria': 'EN · Switch language to English',
    'controls.themeLight': '陶瓷浅色',
    'controls.themeDark': '曜石深色',
    'controls.themeLightAria': '陶瓷浅色 · 切换至博物馆浅色外观',
    'controls.themeDarkAria': '曜石深色 · 切换至曜石工作室深色外观',

    'hero.eyebrow': '01 / 声学收藏档案馆 · 严格只读 APPLE 健康',
    'hero.title': '戴上耳机的每一小时，铸成声学收藏卡。',
    'hero.lead': '将 Apple“健康”中的只读耳机音量记录，铸造为 6 阶 3D 金属闪卡、PSA 级设备档案、28 天声纹环与桌面小组件——全流程 100% 在 iPhone 本地完成。',
    'hero.ctaPrimary': '在 App Store 免费下载',
    'hero.ctaSecondary': '查看 GitHub 源码',
    'hero.spec1Val': '06 阶工艺卡面',
    'hero.spec1Lbl': '0h–2,000h+ 六阶材质',
    'hero.spec2Val': '34 组硬件 PID',
    'hero.spec2Lbl': '蓝牙 0x2002–0x2036 识别',
    'hero.spec3Val': '0 字节外传',
    'hero.spec3Lbl': '只读健康 · 零数据收集',

    'hero.flipFront': '翻转查看背面溯源',
    'hero.flipBack': '返回卡面正面',
    'hero.hoursLabel': '模拟累计聆听时长',
    'hero.tierQuickLabel': '快速切换稀有度阶级',
    'hero.dragHint': '拖动或倾斜卡片，实时观察金属光泽与视差',

    'showcase.eyebrow': '02 / REALITYKIT 实时 3D 与六阶金属工艺',
    'showcase.title': 'RealityKit 立体塑形，随时间淬炼晋级。',
    'showcase.lead': '每副耳机在实时 3D 阳极金属底板上悬浮呈现——惯性拨转、双指缩放、长按触感飞旋，并随时长跨越 6 个工艺阶级。',
    'showcase.video1Title': '曜石深色 · AIRPODS PRO 2',
    'showcase.video2Title': '陶瓷浅色 · AIRPODS MAX',
    'showcase.pauseVideos': '暂停 3D 演示循环',
    'showcase.playVideos': '播放 3D 演示循环',
    'showcase.binderHeading': '收藏图鉴册 · 6 阶解锁门槛',

    'rings.eyebrow': '03 / 28 天声学计时盘 · WHO / ITU H.870',
    'rings.title': '28 天 × 24 小时，按能量响度精准刻画。',
    'rings.lead': '同心圆环依本地时间记录最近四周每一小时的佩戴分布与能量平均响度 Leq (dB(A))，生成专属听歌画像并追踪每周安全听力预算。',
    'rings.deviceFilterLabel': '按耳机筛选',
    'rings.personaFilterLabel': '切换听歌画像预设',
    'rings.deviceAll': '全部耳机',
    'rings.personaNight': '夜猫子',
    'rings.personaCommute': '通勤声景师',
    'rings.personaEarly': '早起鸟',
    'rings.personaAllDay': '全天候听众',
    'rings.readoutIdle': '悬停、点按或使用方向键移动声纹扇区，查看精确时段与分贝值。',
    'rings.scaleQuiet': '<60 dB(A) 冰川薄荷',
    'rings.scaleMod': '70 dB(A) 香槟金',
    'rings.scaleLoud': '82+ dB(A) 玫瑰绯红',
    'rings.whoHeading': 'WHO / ITU H.870 每周听力安全预算',
    'rings.whoFormula': '参考基准：80 dB(A) 下每周 40 小时为 100%，每升高 3 dB 允许时长减半。',
    'rings.whoDbLabel': '周能量平均响度 (Leq)',
    'rings.whoHoursLabel': '本周聆听总时长',
    'rings.whoPctLbl': '已消耗预算',
    'rings.whoAllowLbl': '当前响度每周上限',
    'rings.whoExposedLbl': '本周暴露时长',
    'rings.whoRemainLbl': '剩余安全余量',
    'rings.posterHeading': '3:4 与 9:16 分享海报实时预览',

    'dossier.eyebrow': '04 / PSA 级设备档案 · 聆听评分 EAR GRADE',
    'dossier.title': '为每一副耳机，出具声学评级报告。',
    'dossier.lead': '每张卡面背后都封存着透明可验证的 1.0–10.0 聆听评分、30 天分贝柱状趋势、24 小时放射钟盘、月度账本、里程碑与扭索纹硬件溯源证书。',
    'dossier.simHeading': '实时推演聆听评分公式',
    'dossier.simLead': '1:1 同步 DeviceDossier.swift 算法：满分 10.0 起扣，涵盖四项透明声学扣分项。',
    'dossier.dbLabel': '30 天平均响度',
    'dossier.doseLabel': 'WHO 周剂量占比',
    'dossier.loudLabel': '≥80 dB(A) 高音量占比',
    'dossier.nightLabel': '深夜时段占比 (00–05h)',
    'dossier.slabFlipFront': '翻转查看扭索纹证书',
    'dossier.slabFlipBack': '返回评级封装正面',
    'dossier.galleryTitle': 'App 双色实机画廊 · 曜石深色与陶瓷浅色',
    'dossier.tabDark': '曜石深色',
    'dossier.tabLight': '陶瓷浅色',

    'widgets.eyebrow': '05 / 原生小组件 · 灵动岛 · 41 款图标工作室',
    'widgets.title': '主屏幕、锁屏与灵动岛，无声陪伴。',
    'widgets.lead': '小号今日卡片切换器、中号直达陈列架、大号 28 天聆听环、锁屏 WHO 仪表盘、实时活动护耳倒计时，以及 41 款可换桌面图标。',
    'widgets.studioEyebrow': '图标工作室 · 1 款默认徽标 + 10 款金属配色 × 4 种底板 = 41 款图标',
    'widgets.studioTitle': '让桌面图标与你的耳机同色。',
    'widgets.bgLabel': '图标底板材质',
    'widgets.finishLabel': 'AirPods Max 官方配色 (USB-C 与 Lightning)',
    'widgets.defaultEmblemBtn': 'Earprint 默认声纹徽标',

    'privacy.eyebrow': '06 / 100% 本地架构 · CC-BY 4.0 模型致谢',
    'privacy.title': '严格只读 Apple 健康，零服务器外传。',
    'privacy.lead': '你的听歌轨迹只属于你的 iPhone。正式版仅申请耳机音量只读权限（toShare: []），App Store 隐私分类为“不收集数据”。',
    'privacy.card1Kicker': '单一数据类型',
    'privacy.card1Title': '仅读取耳机音量曝光',
    'privacy.card1Body': '只读取 HKQuantityType(.headphoneAudioExposure)（toShare: []），绝不访问心率、睡眠、麦克风、定位或播放歌名。',
    'privacy.card2Kicker': '沙盒加密存储',
    'privacy.card2Title': '本地汇总与小组件容器',
    'privacy.card2Body': '通过 HKAnchoredObjectQueryDescriptor 后台增量聚合至受保护的 listening-aggregate.json 与 group.com.popcornnn.earprint。',
    'privacy.card3Kicker': '零追踪零广告',
    'privacy.card3Title': '无账号、无后台、无 SDK',
    'privacy.card3Body': '不含任何统计或广告 SDK。导出的分享海报仅在你主动调用系统分享面板时离开本机。',
    'privacy.card4Kicker': '开源可审计',
    'privacy.card4Title': 'GitHub 公开全部源码',
    'privacy.card4Body': '完整 SwiftUI、RealityKit、HealthKit 与 WidgetKit 工程均可在 GitHub 公开审阅。',
    'privacy.policyLink': '阅读完整双语隐私政策 →',
    'privacy.supportLink': '查看完整使用帮助与 FAQ →',

    'faq.heading': '常见问答',
    'faq.q1': '为什么 App 里还没有显示耳机卡片？',
    'faq.a1': '请打开 iPhone 设置 → 隐私与安全性 → 健康 → Earprint，确认已开启“耳机音量”。iOS 仅在耳机播放音频时记录音量；纯开启降噪不播放声音不会写入记录。',
    'faq.q2': '哪些耳机支持生成 3D 收藏卡片？',
    'faq.a2': 'AirPods（1–4 代含降噪版）、AirPods Pro（1–3 代）与 AirPods Max（Lightning 及 USB-C）均配对专属卡片与 3D 模型；Beats 及其他蓝牙耳机同样完整计入声纹环与总时长。',
    'faq.q3': '6 个稀有度等级是多少小时解锁？',
    'faq.a3': '随累计聆听小时自动晋级：青铜岩（0h+）、银灰铝（25h+）、峡湾青（120h+）、深紫（400h+）、午夜碳纤（1,000h+）、流光全息（2,000h+）。',
    'faq.q4': 'Earprint 与 Apple 有关联吗？属于医疗应用吗？',
    'faq.a4': 'Earprint 为独立开发者 Weizhi Wang 的作品，与 Apple Inc. 无任何关联或官方背书；所有声纹环、WHO 预算与评分仅供个人参考，不构成医疗器械。',

    'credits.caption': '内置 3D 模型开源致谢 (CC-BY 4.0)',
    'finale.title': '为你的耳机聆听史，留下一份实体档案。',
    'finale.body': '支持 iOS 18+ 免费下载。严格只读 Apple“健康”、6 阶金属闪卡、28 天声纹环、PSA 设备档案与 41 款定制图标。',
    'finale.cta': '前往 App Store 免费下载',
    'finale.meta': 'Bundle ID: com.popcornnn.earprint · 开发者: Weizhi Wang · wmax43906@gmail.com',

    'footer.disclaimer1': 'Earprint 为独立开发者 Weizhi Wang 的作品，与 Apple Inc. 无任何关联、赞助或官方背书。Apple、Apple Health、AirPods、AirPods Pro、AirPods Max 与 Beats 为 Apple Inc. 注册商标。',
    'footer.disclaimer2': '本应用中的声纹环、WHO / ITU H.870 每周听力预算与聆听评分仅供个人兴趣参考与展示，不构成医疗器械或临床建议。',
    'footer.showcase': '主展馆',

    'tiers.bronze.name': '青铜岩',
    'tiers.bronze.finish': '哑光阳极铜',
    'tiers.silver.name': '银灰铝',
    'tiers.silver.finish': '微珠喷砂铝',
    'tiers.sapphire.name': '峡湾青',
    'tiers.sapphire.finish': '拉丝石青绿',
    'tiers.platinum.name': '深紫',
    'tiers.platinum.finish': '哑光深紫釉',
    'tiers.obsidian.name': '午夜碳纤',
    'tiers.obsidian.finish': '类钻碳涂层',
    'tiers.holo.name': '流光全息',
    'tiers.holo.finish': '液态全息镀膜',

    'back.avgDb': '平均响度',
    'back.longest': '最长单次',
    'back.active': '活跃起止',
    'back.sessions': '佩戴次数',
    'rings.sumTotal': '28 天累计',
    'rings.sumLeq': '能量平均 Leq',
    'rings.sumSessions': '累计佩戴',
    'poster.dark': '深色',
    'poster.light': '浅色',
    'icon.bgAuto': '双拼',
    'icon.bgLight': '浅色',
    'icon.bgDark': '深色',
    'icon.bgHolo': '全息',
    'table.model': '模型资产',
    'table.work': '原始作品',
    'table.creator': '创作者',
    'table.license': '开源协议',

    'sub.backHome': '← 返回 Earprint 主展馆',
    'sub.privacyTitle': 'Privacy Policy · 隐私政策 — Earprint',
    'sub.supportTitle': 'Support & FAQ · 使用帮助 — Earprint'
  }
};

let activeLang = 'en';

export function resolveInitialLang() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved === 'en' || saved === 'zh-Hans') return saved;
  } catch {
    // Ignore restricted storage environments
  }
  const docLang = document.documentElement.lang;
  if (docLang === 'zh-Hans' || docLang.toLowerCase().startsWith('zh')) return 'zh-Hans';
  const navLang = (navigator.language || '').toLowerCase();
  if (navLang.startsWith('zh')) return 'zh-Hans';
  return 'en';
}

export function getLang() {
  return activeLang;
}

export function t(key) {
  return MESSAGES[activeLang]?.[key] ?? MESSAGES.en[key] ?? key;
}

export function applyTranslations(lang) {
  const normalized = lang === 'zh-Hans' ? 'zh-Hans' : 'en';
  activeLang = normalized;
  document.documentElement.lang = normalized;

  const pageTitleKey = document.body?.dataset?.titleKey || 'meta.title';
  const nextTitle = MESSAGES[normalized]?.[pageTitleKey];
  if (nextTitle) {
    document.title = nextTitle;
  }

  for (const el of document.querySelectorAll('[data-i18n]')) {
    const key = el.getAttribute('data-i18n');
    const val = MESSAGES[normalized]?.[key];
    if (val !== undefined) {
      el.textContent = val;
    }
  }

  for (const el of document.querySelectorAll('[data-i18n-html]')) {
    const key = el.getAttribute('data-i18n-html');
    const val = MESSAGES[normalized]?.[key];
    if (val !== undefined) {
      el.innerHTML = val;
    }
  }

  for (const el of document.querySelectorAll('[data-i18n-aria]')) {
    const key = el.getAttribute('data-i18n-aria');
    const val = MESSAGES[normalized]?.[key];
    if (val !== undefined) {
      el.setAttribute('aria-label', val);
    }
  }

  const toggleBtn = document.querySelector('[data-lang-toggle]');
  if (toggleBtn) {
    const nextLangIsZh = normalized === 'en';
    toggleBtn.setAttribute('aria-pressed', String(!nextLangIsZh));
  }
}

export function setLang(lang, { persist = true, emit = true } = {}) {
  const normalized = lang === 'zh-Hans' ? 'zh-Hans' : 'en';
  if (persist) {
    try {
      localStorage.setItem(STORAGE_KEY, normalized);
    } catch {
      // Ignore restricted storage environments
    }
  }
  applyTranslations(normalized);
  if (emit) {
    document.dispatchEvent(
      new CustomEvent('earprint:langchange', {
        bubbles: true,
        detail: { lang: normalized }
      })
    );
  }
}

export function toggleLang() {
  setLang(activeLang === 'en' ? 'zh-Hans' : 'en');
}

export function initI18n() {
  const initial = resolveInitialLang();
  applyTranslations(initial);

  document.addEventListener('click', (event) => {
    const btn = event.target.closest('[data-lang-toggle]');
    if (!btn) return;
    toggleLang();
  });

  window.addEventListener('storage', (event) => {
    if (event.key === STORAGE_KEY && (event.newValue === 'en' || event.newValue === 'zh-Hans')) {
      setLang(event.newValue, { persist: false, emit: true });
    }
  });

  return initial;
}

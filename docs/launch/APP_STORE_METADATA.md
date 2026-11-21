# App Store Connect Metadata — Earprint (v1.0.0)

Ready-to-paste bilingual (**English `en-US`** + **Simplified Chinese `zh-Hans`**) App Store Connect metadata, Review Notes, and 6-frame Screenshot Storyboard grounded in the current `Earprint` codebase (`com.popcornnn.earprint`).

> **Note on character limits:** Apple App Store Connect enforces strict per-field character limits (`30` for Name/Subtitle, `170` for Promotional Text, `100` for Keywords, `4,000` for Description). Every field below is verified under limit.

---

## 1. Naming & Trademark Positioning ("Earprint")

- **Primary recommendation — Keep the App Name clean:** Use **`Earprint`** (`8 / 30`) in English (or **`Earprint · 耳机听歌图鉴`**, `17 / 30`, in Simplified Chinese) and keep `"AirPods"` / `"Apple Health"` **out** of the App Name and Subtitle.
- **Why:** Apple App Review routinely flags titles or subtitles containing Apple trademarks (`AirPods`, `Apple Health`, `Beats`) under **Guideline 5.2.1** (Intellectual Property / false affiliation) or **Guideline 4.1** / **2.3.8**.
- **Nominative reference rule:** Mention AirPods and Beats strictly as compatible logged hardware inside the Full Description alongside the non-affiliation disclaimer at the bottom.
- **Default Icon:** Primary App Icon uses the original concentric **Earprint Rings Emblem** (`AppIcon`), with alternate headphone icons optional in Settings.

---

## 2. English (`en-US`) Metadata

### App Name (`<= 30 chars`)
```text
Earprint
```
- Character count: **`8 / 30`**

### Subtitle (`<= 30 chars`)
```text
3D Audio Cards & WHO Rings
```
- Character count: **`26 / 30`**

### Promotional Text (`<= 170 chars`)
*Editable in App Store Connect without submitting a new binary.*
```text
Turn headphone history from Apple Health into 6-tier 3D foil cards, a PSA-style Device Dossier, 28-day acoustic rings, and widgets — 100% private on iPhone.
```
- Character count: **`156 / 170`**

### Keywords (`<= 100 chars`, comma-separated, no spaces)
*Does not duplicate `Earprint`, `3d`, `audio`, `cards`, `who`, `rings` from Name/Subtitle.*
- **Standard set:**
  ```text
  airpods,headphone,listening,tracker,decibel,hearing,health,widget,collectible,stats,music,foil,psa
  ```
  - Character count: **`98 / 100`**
- **Trademark-safe fallback (without `"airpods"`):**
  ```text
  headphone,earbuds,listening,tracker,decibel,hearing,health,widget,collectible,stats,music,foil,db
  ```
  - Character count: **`97 / 100`**

### Full Description (`<= 4,000 chars`)
```text
Every hour in your headphones has a story. Earprint turns your Apple Health Headphone Audio Levels into interactive 3D collectible trading cards, a collector-grade Device Dossier, 28-day acoustic Earprint Rings, and native widgets — processed 100% on your iPhone.

INTERACTIVE 3D COLLECTIBLE CARDS
• Real-time 3D RealityKit models float above custom foil surfaces: drag to spin with momentum, pinch to zoom, long-press to twirl with haptics, and tilt your iPhone for prismatic foil shimmer and parallax.
• Tap or swipe to flip any card for lifetime hours, sessions, average loudness (dB(A)), and tier progress.
• Automatic Bluetooth product ID matching for Apple and Beats hardware, retail finish customization for AirPods Max and Beats models, Light/Dark/System themes, and custom App Icons in Settings.

6 COLLECTOR RARITY TIERS (0H → 2,000H)
Your cards evolve automatically as your lifetime listening hours grow, with a clean multi-device Collector Binder showing when each tier unlocked:
• 0h+ — BRONZE SLATE (Matte Anodized Foil)
• 25h+ — SILVER ALUMINUM (Brushed Alloy)
• 120h+ — FJORD TEAL (Brushed Slate)
• 400h+ — DEEP PURPLE (Satin Glaze)
• 1,000h+ — MIDNIGHT CARBON (Machined Carbon Weave)
• 2,000h+ — LIQUID HOLO (Prismatic Alloy)

PSA-STYLE DEVICE DOSSIER & SHARE POSTERS
• Flip any card and open its Device Dossier — styled as an acrylic grading slab with a transparent Ear Grade (1.0–10.0) scored from loudness, weekly WHO dose, loud-session share, and late-night listening.
• Explore Week / Month / Year / All views, a scrubbable 30-day trend chart, a 24-hour radial Day Clock, a Habits & Hearing bento, monthly career ledger, milestone timeline with ETA, and a guilloché hardware provenance certificate.
• Export high-res Light or Dark PNG posters via Share Dossier in Simple (1-page) or Long (4-page carousel) 3:4 feed layouts, plus 3:4 and 9:16 Earprint Rings share posters.

28-DAY EARPRINT RINGS & WHO HEARING BUDGET
• See the last 28 days × 24 hours plotted as a concentric acoustic dial colored by energy-averaged loudness (Leq), alongside your listening persona (Night Owl, Commute Soundtracker, Early Bird, or All-Day Listener).
• Compare all pairs together or filter by individual headphones, and track your weekly safe-listening budget based on WHO / ITU H.870 guidelines (80 dB(A) for 40 hours/week, halving every +3 dB).

HOME & LOCK SCREEN WIDGETS
• Home Screen widgets: Today (interactive card cycler), Card Shelf (up to 3 cards with deep links), and Large Earprint Ring + 28-day heatmap + WHO budget.
• Lock Screen gauges: Circular WHO Budget, Rectangular Today Summary, and Inline status.

100% PRIVATE ON YOUR IPHONE
• Read-only Apple Health access (Headphone Audio Levels only).
• Zero accounts, zero backend servers, zero analytics or ad SDKs. All processing stays encrypted on your device.

Note: Earprint is an independent app and is not affiliated with, sponsored by, or endorsed by Apple Inc. Apple, Apple Health, AirPods, AirPods Pro, AirPods Max, and Beats are trademarks of Apple Inc. Earprint is for informational and entertainment purposes only and is not a medical device.
```
- Character count: **`3,118 / 4,000`**

---

## 3. Simplified Chinese (`zh-Hans`) Metadata

### App Name (`<= 30 chars`)
```text
Earprint · 耳机听歌图鉴
```
- Character count: **`17 / 30`**

### Subtitle (`<= 30 chars`)
```text
3D 收藏闪卡与声学聆听环
```
- Character count: **`13 / 30`**

### Promotional Text (`<= 170 chars`)
```text
把 Apple 健康里的耳机听歌记录变成 6 阶 3D 立体闪卡、PSA 级设备档案与 28 天声学聆听环。支持浅色/深色外观、3:4 海报导出与桌面小组件，100% 本地隐私。
```
- Character count: **`89 / 170`**

### Keywords (`<= 100 chars`, comma-separated, no spaces)
- **Standard set:**
  ```text
  AirPods,Apple健康,音量,分贝,听力保护,护耳,听歌时长,小组件,档案,统计,蓝牙,稀有度,年报,音频,噪音,音乐,健康数据,耳机时长,周报,深色模式
  ```
  - Character count: **`81 / 100`**
- **Trademark-safe fallback (without `"AirPods"` / `"Apple"`):**
  ```text
  耳机,健康,音量,分贝,听力保护,护耳,听歌时长,小组件,设备档案,统计,蓝牙,稀有度,年报,音频,噪音,音乐,健康数据,周报,深色模式,卡片
  ```
  - Character count: **`71 / 100`**

### Full Description (`<= 4,000 chars`)
```text
戴上耳机的每一小时，都值得被收藏。Earprint 读取你在 Apple“健康”中的耳机音量曝光记录，将日常听歌时间铸成可交互的 3D 立体闪卡、PSA 级设备档案、28 天声学聆听环与原生桌面小组件——全部计算 100% 在 iPhone 本地完成。

可交互 3D 耳机收藏闪卡
• 实时 RealityKit 3D 模型悬浮于金属卡面之上：拖动自由旋转并带惯性回弹、双指缩放、长按触发触感飞旋；倾斜手机即可欣赏随角度流动的棱镜光泽与视差层次。
• 轻点即可翻转卡片，查看该副耳机的累计聆听时长、佩戴次数、能量平均响度（Leq / dB(A)）与升级进度；左右滑动流畅切换卡片。
• 自动识别 Apple 与 Beats 蓝牙产品型号 ID；支持为 AirPods Max 及 Beats 系列切换硬件配色，支持全局浅色/深色外观、多款 App 图标与中英双语切换。

6 阶稀有度进化体系（0 小时 → 2,000 小时）
随着耳机陪伴时间累积，卡片会自动解锁更高工艺卡面，并在「收藏图鉴册」记录多副设备的真实达成月份：
• 0 小时起 — 青铜岩板（哑光阳极青铜，BRONZE SLATE）
• 25 小时起 — 银铝（微珠喷砂铝合金，SILVER ALUMINUM）
• 120 小时起 — 峡湾青（拉丝石青绿，FJORD TEAL）
• 400 小时起 — 深紫釉（缎面深紫釉，DEEP PURPLE）
• 1,000 小时起 — 午夜碳纤（精雕碳纤维纹，MIDNIGHT CARBON）
• 2,000 小时起 — 液态全息（流光全息幻彩，LIQUID HOLO）

PSA 级设备档案（Device Dossier）与海报导出
• 翻转卡片即可进入真实健康数据驱动的设备档案：以透明亚克力评级封装壳呈现，依据日常平均音量、WHO 每周安全预算占比、≥80 分贝高音量比例与深夜聆听占比，计算出 1.0–10.0 分的「聆听评分（EAR GRADE）」。
• 支持按 周 / 月 / 年 / 全部 切换查看：可跟手滑动的 30 天趋势柱状图、24 小时放射状时间钟盘、习惯与听力看板、月度生涯账本、带达成时间预测的里程碑时间线，以及扭索纹硬件溯源证书。
• 支持浅色/深色高清 PNG 导出：极简 1 页总览与 4 页 3:4 档案轮播海报，以及 3:4 / 9:16 声纹环分享长卡，适配小红书等社交平台分享。

28 天声学聆听环与 WHO 听力预算
• 将最近 28 天 × 24 小时的声音足迹刻画为同心圆精密表盘，按能量平均响度着色，并生成专属听歌画像（夜猫子、通勤声景师、早起鸟或全天候听众）。
• 基于世界卫生组织（WHO / ITU H.870）安全聆听标准（80 dB(A) 下每周 40 小时为 100%，每升高 3 dB 允许时长减半），实时追踪本周听力安全预算。

桌面与锁屏小组件
• 主屏幕小组件：小号「今日聆听」（支持点击切换卡片）、中号「卡片陈列架」（最多展示 3 张卡片并支持点击直达）、大号「28 天聆听环与热力图 + WHO 预算」。
• 锁屏组件：环形安全预算表盘、矩形今日摘要与行内状态组件。

100% 本地处理 · 零数据上传
• 仅以严格只读方式访问 Apple“健康”中的「耳机音量」数据。
• 无账号注册、无后台服务器、无任何第三方统计或广告 SDK，所有记录均加密保留在你的 iPhone 上。

声明：Earprint 为独立开发者作品，与 Apple Inc. 无任何关联、赞助或官方背书关系。Apple、Apple Health、AirPods、AirPods Pro、AirPods Max 与 Beats 均为 Apple Inc. 的注册商标。本应用仅供个人信息记录与展示参考，不构成医疗器械或临床听力诊断。
```
- Character count: **`1,594 / 4,000`**

---

## 4. App Review Notes (Copy into App Store Connect → App Review Information)

```text
Thank you for reviewing Earprint.

1. HEALTHKIT ACCESS & PRIVACY (READ-ONLY)
- Earprint requests read-only HealthKit access for a single data type: HKQuantityType(.headphoneAudioExposure) ("Headphone Audio Levels").
- Release builds do not request HealthKit write access (NSHealthUpdateUsageDescription is omitted from the Release Info.plist).
- No account or sign-in is required. All HealthKit aggregation stays 100% on-device inside Application Support and the private App Group container (group.com.popcornnn.earprint) for widgets. Zero servers or third-party analytics SDKs are used.

2. TESTING ON A CLEAN REVIEW DEVICE (ZERO SAMPLES / PERMISSION DENIED)
- On first launch, Earprint presents a pre-permission Welcome screen explaining why it reads Headphone Audio Levels, followed by the system Apple Health permission prompt.
- Because Apple Health treats denied read access identically to having 0 samples, a clean test iPhone with no prior headphone exposure samples shows a consistent zero-data state across both tabs:
  - Collection tab: shows a clean empty state ("No supported headphones yet") with a "Sync Apple Health" action and permission path guidance (Settings > Health > Data Access > Earprint).
  - Rings tab: shows a clean empty state ("No listening data yet") explaining that iOS logs headphone audio levels while audio is playing (not silent ANC) with a "Sync Apple Health" button — zero placeholder sample metrics appear in Release builds.
  - Settings (gear icon in Collection): reviewers can browse Appearance (System/Light/Dark), Model Gallery (supported headphone hardware catalog), Card Tiers (all 6 tiers from Bronze Slate to Liquid Holo), App Icon Studio, Language (System / English / Simplified Chinese), Apple Health Privacy, and Credits & Attributions (CC-BY 4.0 3D asset credits + non-affiliation notice).

3. GENERATING REAL HEALTHKIT SAMPLES ON A TEST DEVICE
- Note: Manually adding entries inside Apple Health attributes samples to the host iPhone (HKDevice.local()), which Earprint intentionally excludes so phone speakers never appear as headphones.
- To test card and Dossier generation with live hardware: connect AirPods or Bluetooth headphones to the test iPhone, play audio for 1–2 minutes until iOS writes a Headphone Audio Levels sample, then tap "Sync Apple Health" in Earprint.
- An unedited screen recording from a physical iPhone is attached showing the live Apple Health sync, 3D card interaction (spin/zoom/flip/swipe), real HealthKit Device Dossier, Light/Dark themes, 3:4 PNG export, and Home/Lock Screen widgets.

4. NON-AFFILIATION & NON-MEDICAL DISCLAIMER
- Earprint is an independent app by Weizhi Wang and is not affiliated with, sponsored by, or endorsed by Apple Inc.
- Earprint visualizes Apple Health listening hours and WHO/ITU H.870 safe-listening budgets for informational purposes only and is not a medical device.
```

---

## 5. 6-Frame App Store Screenshot Storyboard

### Target Display Sizes (App Store Connect)
| Display Slot | Required Resolution (Portrait) | Primary Capture Device |
| --- | --- | --- |
| **iPhone 6.9" Display** (Required) | `1320 × 2868 px` (or `1290 × 2796 px`) | iPhone 17 Pro Max simulator or physical 6.9" Pro Max |
| **iPhone 6.5" Display** (Optional / Scaled) | `1284 × 2778 px` | iPhone 14 Plus / iPhone XS Max simulator, or crisp downscale from 6.9" |

### Capture Hygiene Rules
- **No Debug-only chrome:** Do not capture `"Sample data · Simulator"` banners in App Store screenshots.
- **Status bar:** Use `xcrun simctl status_bar <UDID> override --time "9:41" --batteryState charged --batteryLevel 100 --cellularMode active --wifiBars 3`.

### Frame-by-Frame Plan

| Frame | Screen & Capture State | EN Headline & Subhead | ZH-Hans Headline & Subhead |
| --- | --- | --- | --- |
| **1. Hero 3D Collectible Card** | `CardDetail` open on a `FJORD TEAL` / `LIQUID HOLO` AirPods Pro 3D card (Dark Mode) | **Headline:** Your Listening History, in 3D<br>**Subhead:** Interactive foil cards forged from Apple Health hours | **主标题：** 把听歌记录铸成 3D 闪卡<br>**副标题：** 连接 Apple 健康，解锁专属立体耳机收藏卡 |
| **2. 6-Tier Collector Binder** | `CardTiersView` showing the 2×3 binder with multi-pair unlock dates (Light Mode showcase!) | **Headline:** 6 Foil Tiers to 2,000 Hours<br>**Subhead:** Clean multi-device binder tracking every milestone | **主标题：** 6 阶稀有度进化图鉴<br>**副标题：** 自动记录每副耳机的解锁月份与进阶历程 |
| **3. PSA-Style Device Dossier** | `DeviceDossierView` acrylic grading slab (`EAR GRADE` `GEM MINT`) + `DayClock` | **Headline:** Collector-Grade Device Dossier<br>**Subhead:** Acrylic grading slab, Ear Grade &amp; 30-day trends | **主标题：** PSA 级设备档案与聆听评分<br>**副标题：** 亚克力封装评级、30 天趋势与 24 小时钟盘 |
| **4. 28-Day Earprint Rings & WHO** | `HomeView` (`Rings` tab) chronometer dial + WHO weekly budget + pair switcher | **Headline:** 28-Day Earprint &amp; WHO Budget<br>**Subhead:** Spot late-night habits within 80 dB(A) safe limits | **主标题：** 28 天声纹环与安全预算<br>**副标题：** 清晰掌握昼夜听歌节律与 WHO 护耳余量 |
| **5. Light/Dark & 3:4 Share Posters** | `ShareSheet` 3:4 poster preview alongside Light/Dark App Appearance &amp; finish swatches | **Headline:** Light, Dark &amp; 3:4 Share Posters<br>**Subhead:** Built for seamless sharing and everyday comfort | **主标题：** 浅色/深色外观与 3:4 海报<br>**副标题：** 一键生成高清分享卡片，优雅适配每日视觉 |
| **6. Widgets & 100% On-Device** | Home Screen &amp; Lock Screen widgets + **100% On-Device** privacy callout | **Headline:** Live Widgets, 100% On-Device<br>**Subhead:** Home &amp; Lock Screen trackers with zero servers | **主标题：** 原生小组件 · 100% 本地隐私<br>**副标题：** 主屏与锁屏实时陪伴，数据绝不离开 iPhone |

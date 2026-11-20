# App Store Connect Metadata — Earprint (v1.0.0)

Ready-to-paste bilingual (**English `en-US`** + **Simplified Chinese `zh-Hans`**) App Store Connect metadata, Review Notes, and 6-frame Screenshot Storyboard grounded in the current `Earprint` codebase (`com.popcornnn.earprint`).

> **Note on character limits:** Apple App Store Connect enforces strict per-field character limits (`30` for Name/Subtitle, `170` for Promotional Text, `100` for Keywords, `4,000` for Description). Every field below includes its verified `len()` count.
>
> **Note on Live Activity copy:** `ListeningLiveActivity` UI is implemented in `EarprintWidgets`, while `LiveActivityController.start(...)` is currently triggered only from Debug Developer Tools / `-startLiveActivity` (see [APP_STORE_CHECKLIST.md](APP_STORE_CHECKLIST.md)). Ensure the user-facing foreground trigger or App Intent lands before publishing the Live Activity bullet below, or remove that line at submission time.

---

## 1. Naming & Trademark Positioning ("Earprint")

- **Primary recommendation — Keep the App Name clean:** Use **`Earprint`** (`8 / 30`) in English (or **`Earprint · 耳机听歌图鉴`**, `17 / 30`, in Simplified Chinese) and keep `"AirPods"` / `"Apple Health"` **out** of the App Name and Subtitle.
- **Why:** Apple App Review routinely rejects titles or subtitles that place Apple product trademarks (`AirPods`, `Apple Health`, `Beats`) in the primary app title/subtitle under **Guideline 5.2.1** (Intellectual Property / false affiliation) or **Guideline 4.1** / **2.3.8**.
- **Nominative reference rule:** Refer to AirPods and Beats strictly in a descriptive, compatible-hardware context in the Full Description (`"Works with AirPods and Bluetooth headphones logged in Apple Health"`), paired with an explicit non-affiliation notice at the bottom.
- **Pre-lock check:** Before locking `v1.0.0` in App Store Connect, verify `"Earprint"` name availability inside App Store Connect (`App Information → Name`) across all target storefronts and check USPTO / CNIPA trademark registries.

---

## 2. English (`en-US`) Metadata

### App Name (`<= 30 chars`)
- **Recommended (Clean Brand):**
  ```text
  Earprint
  ```
  - Character count: **`8 / 30`**
- **Descriptive Alternative (if ASO keyword boost in title is desired):**
  ```text
  Earprint: Headphone Cards
  ```
  - Character count: **`25 / 30`**

### Subtitle (`<= 30 chars`)
- **For `Earprint`:**
  ```text
  3D Audio Cards & WHO Rings
  ```
  - Character count: **`26 / 30`**
- **For `Earprint: Headphone Cards` (avoids repeating "Cards"):**
  ```text
  3D Audio Rings & WHO Stats
  ```
  - Character count: **`26 / 30`**

### Promotional Text (`<= 170 chars`)
*Editable in App Store Connect without submitting a new binary.*
```text
Turn headphone history from Apple Health into 3D foil cards, a PSA-style Device Dossier, 28-day acoustic rings, and Live Widgets—100% private on iPhone.
```
- Character count: **`152 / 170`**

### Keywords (`<= 100 chars`, comma-separated, no spaces)
*Does not duplicate `Earprint`, `3d`, `audio`, `cards`, `who`, `rings` from Name/Subtitle.*
- **Standard set:**
  ```text
  airpods,headphone,listening,tracker,decibel,hearing,health,widget,collectible,stats,music,foil,psa
  ```
  - Character count: **`98 / 100`**
- **Trademark-safe fallback (if Review flags `"airpods"` in keywords):**
  ```text
  headphone,earbuds,listening,tracker,decibel,hearing,health,widget,collectible,stats,music,foil,db
  ```
  - Character count: **`97 / 100`**

### Full Description (`<= 4,000 chars`)
```text
Every hour in your headphones has a story. Earprint turns your Apple Health Headphone Audio Levels into interactive 3D collectible trading cards, a collector-grade Device Dossier, 28-day acoustic Earprint Rings, and native widgets—processed 100% on your iPhone.

INTERACTIVE 3D COLLECTIBLE CARDS
• Real-time 3D RealityKit models float above custom foil surfaces: drag to spin with momentum, pinch to zoom, long-press to twirl with haptics, and tilt your iPhone for prismatic foil shimmer and parallax.
• Tap or swipe to flip any card for lifetime hours, sessions, average loudness (dB(A)), and tier progress.
• Automatic Bluetooth product ID matching for Apple and Beats hardware, plus retail finish customization for AirPods Max and Beats models and 40 custom App Icons in Settings.

10 COLLECTOR RARITY TIERS (0H → 2,000H)
Your cards evolve automatically as your lifetime listening hours grow:
• 0h+ — BRONZE
• 10h+ — SILVER · UNCOMMON
• 35h+ — GOLD · RARE
• 80h+ — EMERALD · VIVID
• 160h+ — SAPPHIRE · COBALT
• 300h+ — AMETHYST · MYSTIC
• 550h+ — PLATINUM · MASTER
• 900h+ — DIAMOND · PRISM
• 1,400h+ — OBSIDIAN · PRESTIGE
• 2,000h+ — HOLO · LEGENDARY

PSA-STYLE DEVICE DOSSIER & SHARE EXPORT
• Flip any card and open its Device Dossier—styled as an acrylic grading slab with a transparent Ear Grade (0.0–10.0) scored from average loudness, weekly WHO dose, loud-session share, and late-night listening.
• Explore Week / Month / Year / All views, a scrubbable 30-day trend chart, a 24-hour radial Day Clock, a 6-tile Habits & Hearing bento, monthly career ledger, milestone timeline with ETA, and a guilloché hardware provenance certificate.
• Export crisp high-res PNG posters via Share Dossier in Simple (1-page summary) or Long (4-page carousel: Cover, Rhythm, Habits, Certificate), plus a 9:16 Earprint Rings share card.

28-DAY EARPRINT RINGS & WHO HEARING BUDGET
• See the last 28 days × 24 hours plotted as a concentric acoustic dial colored by energy-averaged loudness (Leq), alongside your listening persona (Night Owl, Commute Soundtracker, Early Bird, or All-Day Listener).
• Track your weekly safe-listening budget based on WHO / ITU H.870 guidelines (80 dB(A) for 40 hours/week, halving every +3 dB).

WIDGETS & LIVE ACTIVITY
• Home Screen widgets: Today (interactive card cycler), Card Shelf (up to 3 cards with deep links), and Large Earprint Ring + 28-day heatmap + WHO budget.
• Lock Screen gauges (Circular WHO Budget, Rectangular Today Summary, Inline) and Live Activity / Dynamic Island with live elapsed timer, loudness band, and ear-break countdown.

100% PRIVATE ON YOUR IPHONE
• Read-only Apple Health access (Headphone Audio Levels only).
• Zero accounts, zero backend servers, zero analytics or ad SDKs. All processing stays encrypted on your device.

Note: Earprint is an independent app and is not affiliated with, sponsored by, or endorsed by Apple Inc. Apple, Apple Health, AirPods, AirPods Pro, AirPods Max, and Beats are trademarks of Apple Inc. Earprint is for informational and entertainment purposes only and is not a medical device.
```
- Character count: **`3,071 / 4,000`**

---

## 3. Simplified Chinese (`zh-Hans`) Metadata

### App Name (`<= 30 chars`)
- **Recommended (Brand + Chinese Search Clarity):**
  ```text
  Earprint · 耳机听歌图鉴
  ```
  - Character count: **`17 / 30`**
- **Clean Alternative:**
  ```text
  Earprint
  ```
  - Character count: **`8 / 30`**

### Subtitle (`<= 30 chars`)
```text
3D 收藏闪卡与声学聆听环
```
- Character count: **`13 / 30`**

### Promotional Text (`<= 170 chars`)
```text
把 Apple 健康里的耳机听歌记录变成 3D 立体闪卡、PSA 级设备档案与 28 天声学聆听环。10 阶稀有度自动升级，桌面小组件与灵动岛实时陪伴，100% 本地隐私。
```
- Character count: **`86 / 170`**

### Keywords (`<= 100 chars`, comma-separated, no spaces)
*Does not duplicate `Earprint`, `耳机`, `听歌`, `图鉴`, `3D`, `收藏`, `闪卡`, `声学`, `聆听`, `环` already present in primary Name + Subtitle.*
- **Standard set:**
  ```text
  AirPods,Apple健康,音量,分贝,听力保护,护耳,听歌时长,小组件,灵动岛,档案,统计,蓝牙,稀有度,年报,音频,噪音,音乐,健康数据,耳机时长,周报,评测
  ```
  - Character count: **`83 / 100`**
- **Trademark-safe fallback (without `"AirPods"` / `"Apple"`):**
  ```text
  耳机,健康,音量,分贝,听力保护,护耳,听歌时长,小组件,灵动岛,设备档案,统计,蓝牙,稀有度,年报,音频,噪音,音乐,健康数据,周报,评测,卡片
  ```
  - Character count: **`73 / 100`**

### Full Description (`<= 4,000 chars`)
```text
戴上耳机的每一小时，都值得被收藏。Earprint 读取你在 Apple“健康”中的耳机音量曝光记录，将日常听歌时间铸成可交互的 3D 立体闪卡、PSA 级设备档案、28 天声学聆听环与原生桌面小组件——全部计算 100% 在 iPhone 本地完成。

可交互 3D 耳机收藏闪卡
• 实时 RealityKit 3D 模型悬浮于金属卡面之上：拖动自由旋转并带惯性回弹、双指缩放、长按触发触感飞旋；倾斜手机即可欣赏随角度流动的棱镜光泽与视差层次。
• 轻点或滑动翻转卡片，查看该副耳机的累计聆听时长、佩戴次数、能量平均响度（Leq / dB(A)）与升级进度。
• 自动识别 Apple 与 Beats 蓝牙产品型号 ID；支持为 AirPods Max 及 Beats 系列切换多款官方硬件配色，并在设置中提供 40 种 App 图标组合与英文/简体中文双语切换。

10 阶稀有度进化阶梯（0 小时 → 2,000 小时）
随着耳机陪伴时间累积，你的卡片会自动进阶解锁更高工艺卡面：
• 0 小时起 — 铜卡（BRONZE）
• 10 小时起 — 白银 · 进阶（SILVER）
• 35 小时起 — 黄金 · 稀有（GOLD）
• 80 小时起 — 祖母绿 · 灵动（EMERALD）
• 160 小时起 — 蓝宝石 · 深海（SAPPHIRE）
• 300 小时起 — 紫水晶 · 秘境（AMETHYST）
• 550 小时起 — 铂金 · 大师（PLATINUM）
• 900 小时起 — 钻石 · 棱镜（DIAMOND）
• 1,400 小时起 — 黑曜 · 臻享（OBSIDIAN）
• 2,000 小时起 — 幻彩 · 传奇（HOLO）

PSA 级设备档案（Device Dossier）与海报导出
• 翻转卡片即可进入专属设备档案：以透明亚克力评级封装壳呈现，依据日常平均音量、WHO 每周安全预算占比、≥80 分贝高音量比例与深夜聆听占比，透明计算出 0.0–10.0 分的「聆听评分（EAR GRADE）」。
• 支持按 周 / 月 / 年 / 全部 切换查看：可跟手滑动的 30 天趋势柱状图、24 小时放射状时间钟盘、6 宫格习惯与听力看板、月度生涯账本、带达成时间预测（ETA）的里程碑时间线，以及防伪扭索纹硬件溯源证书。
• 内置高清 PNG 分享导出：支持「极简 1 页总览」与「长图 4 页轮播（封面 / 节奏 / 习惯 / 证书）」两种档案海报，也可导出 9:16 声学聆听环长卡，方便分享至社交平台。

28 天声学聆听环与 WHO 听力预算
• 将最近 28 天 × 24 小时的声音足迹刻画为同心圆精密表盘，按能量平均响度着色，并生成你的专属听歌画像（夜猫子、通勤声景师、早起鸟或全天候听众）。
• 基于世界卫生组织（WHO / ITU H.870）安全聆听标准（80 dB(A) 下每周 40 小时为 100%，每升高 3 dB 允许时长减半），实时追踪本周听力安全预算。

桌面小组件与灵动岛实时活动
• 主屏幕小组件：小号「今日聆听」（支持点击切换展示卡片）、中号「卡片陈列架」（最多展示 3 张卡片并支持点击直达）、大号「28 天聆听环与热力图 + WHO 预算」。
• 锁屏组件（环形预算表盘、矩形今日摘要、行内状态）与灵动岛 / 锁屏实时活动，呈现当前计时、响度区间与护耳休息倒计时。

100% 本地处理 · 零数据上传
• 仅以严格只读方式访问 Apple“健康”中的「耳机音量」数据。
• 无账号注册、无后台服务器、无任何第三方统计或广告 SDK，所有记录均加密保留在你的 iPhone 上。

声明：Earprint 为独立开发者作品，与 Apple Inc. 无任何关联、赞助或官方背书关系。Apple、Apple Health、AirPods、AirPods Pro、AirPods Max 与 Beats 均为 Apple Inc. 的注册商标。本应用仅供个人信息记录与展示参考，不构成医疗器械或临床听力诊断。
```
- Character count: **`1,691 / 4,000`**

---

## 4. App Review Notes (Copy into App Store Connect → App Review Information)

> **Pre-submit sync check:** Update item (2) below once the Release empty/sample-preview behavior in `HeadphoneLibrary.swift` and `DeviceDossierView` real-session wiring are finalized (see [APP_STORE_CHECKLIST.md](APP_STORE_CHECKLIST.md) Phase 3).

```text
Thank you for reviewing Earprint.

1. HEALTHKIT ACCESS & PRIVACY (READ-ONLY)
- Earprint requests read-only HealthKit access for a single data type: HKQuantityType(.headphoneAudioExposure) ("Headphone Audio Levels").
- Release builds do not request HealthKit write access (NSHealthUpdateUsageDescription is omitted from the Release Info.plist).
- No account or sign-in is required. All HealthKit aggregation stays 100% on-device inside Application Support and the private App Group container (group.com.popcornnn.earprint) for widgets. Zero servers or third-party analytics SDKs are used.

2. TESTING ON A CLEAN REVIEW DEVICE (ZERO SAMPLES / PERMISSION DENIED)
- On first launch, Earprint presents the standard Apple Health permission sheet.
- Because Apple Health intentionally treats denied read permission identically to having 0 samples, a fresh test iPhone with no prior AirPods/headphone audio exposure logs will initially return 0 samples:
  - Collection tab: displays an empty state explaining that collectible cards unlock once supported headphone audio exposure samples exist in Apple Health, plus a "Sync Apple Health" button and Settings guidance (Settings > Health > Data Access > Earprint).
  - Settings (gear icon in Collection): you can browse **Model Gallery** (supported headphone models and hardware catalog), **Card Tiers** (all 10 rarity foil finishes from 0h Bronze to 2,000h Holo Legendary), **App Icon** (40 finish + background combinations), **Language** (English / Simplified Chinese), and **Credits** (CC-BY 4.0 3D asset attributions).
  - [Note before submitting: confirm here whether the Rings tab displays a clean zero-data onboarding state or an explicit opt-in "Preview Sample Data" toggle.]

3. GENERATING REAL HEALTHKIT SAMPLES ON A TEST DEVICE
- Note: Manually tapping "Add Data" inside the Apple Health app attributes samples to the host iPhone (HKDevice.local()), which Earprint intentionally filters out so phone-speaker entries do not appear as headphones.
- To test real headphone card generation: pair AirPods or Bluetooth headphones to the test iPhone and play audio for 1–2 minutes until iOS writes a Headphone Audio Levels sample, then return to Earprint and tap "Sync Apple Health" (or open the Collection tab).
- We have also attached a short unedited screen recording from a physical iPhone showing live Apple Health sync, 3D card interaction (drag/zoom/tilt/flip), Device Dossier inspection, 1-page / 4-page PNG export, and Home/Lock Screen widgets.

4. NON-AFFILIATION & NON-MEDICAL DISCLAIMER
- Earprint is an independent app and is not affiliated with, sponsored by, or endorsed by Apple Inc.
- Earprint visualizes Apple Health listening hours and WHO/ITU H.870 safe-listening budgets for informational purposes only and is not a medical device.
```

---

## 5. 6-Frame App Store Screenshot Storyboard

### Target Display Sizes (App Store Connect)
| Display Slot | Required Resolution (Portrait) | Primary Capture Device |
| --- | --- | --- |
| **iPhone 6.9" Display** (Required) | `1320 × 2868 px` (or `1290 × 2796 px`) | iPhone 17 Pro Max (`-destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`) or physical 6.9" Pro Max |
| **iPhone 6.5" Display** (Optional if scaled from 6.9", or native upload) | `1284 × 2778 px` (or `1242 × 2688 px`) | iPhone 14 Plus / iPhone XS Max simulator, or crisp downscale in Figma/Screenshot pipeline |

### Capture Hygiene Rules
- **No Debug-only chrome:** Do not capture `"Sample data · Simulator"` banners in App Store screenshots. Capture from a clean Release-styled demo build (or real device with realistic clean nicknames/data) after Rings UI polish locks.
- **Status bar:** Use `xcrun simctl status_bar <UDID> override --time "9:41" --batteryState charged --batteryLevel 100 --cellularMode active --wifiBars 3` for consistent `9:41` full-battery captures.
- **Keep frame captions concise:** 1 short headline (`<= 6` words EN / `<= 12` chars ZH) + 1 short subtitle line.

### Frame-by-Frame Plan

| Frame | Screen & Capture State | Launch Arg / Route | EN Headline & Subhead | ZH-Hans Headline & Subhead |
| --- | --- | --- | --- | --- |
| **1. Hero 3D Collectible Card** | `CardDetail` open on a `HOLO · LEGENDARY` (`2,000h+`) or `GOLD` AirPods Pro / AirPods Max card tilted slightly so RealityKit 3D model + prismatic foil sheen pop | `-demo -demoIndex 0` / `-cardDetail` (with AirPods Pro / Max 3D model rotated ~20°) | **Headline:** Your AirPods History, in 3D<br>**Subhead:** Interactive foil cards forged from Apple Health listening hours | **主标题：** 把听歌记录铸成 3D 闪卡<br>**副标题：** 连接 Apple 健康，解锁专属立体耳机收藏卡 |
| **2. 10-Tier Rarity Ladder** | Split/collage or `CardTiersView` + `CollectionView` stack showing progression from `0h Bronze` through `Emerald`, `Amethyst`, `Diamond`, `Obsidian`, up to `2,000h Holo Legendary` | `Collection` tab + `Settings → Card Tiers` | **Headline:** 10 Foil Tiers to 2,000 Hours<br>**Subhead:** Cards upgrade automatically from Bronze to Holo Legendary | **主标题：** 10 阶稀有度进化至 2000 小时<br>**副标题：** 从铜卡一路升级至钻石、黑曜与幻彩传奇 |
| **3. PSA-Style Device Dossier** | `DeviceDossierView` showing top acrylic grading slab (`EAR GRADE` 9.x `GEM MINT`), `HoloSeal`, and `01 Airtime` / `02 Rhythm` trend & 24h `DayClock` | `-dossier -demoIndex 0` (`-dossierPeriod month`) | **Headline:** Collector-Grade Device Dossier<br>**Subhead:** Acrylic grading slab, Ear Grade, 30-day trends & 24h clock | **主标题：** PSA 级设备档案与聆听评分<br>**副标题：** 亚克力封装评级、30 天趋势与 24 小时钟盘 |
| **4. 28-Day Earprint Rings & WHO** | Redesigned `HomeView` (`Rings` tab) hero centerpiece showing the 28-day concentric chronometer dial, active pair pill, persona badge, and WHO weekly hearing budget | `-tab rings` (capture **only after** `@rings-ui` polish locks) | **Headline:** 28-Day Earprint & WHO Budget<br>**Subhead:** Spot late-night habits and stay within 80 dB(A) safe limits | **主标题：** 28 天声学聆听环与安全预算<br>**副标题：** 一眼看清昼夜听歌节律与 WHO 护耳余量 |
| **5. Poster Export & Color Studio** | `DossierShareSheet` (`Long · 4 pages` fanned preview) alongside AirPods Max finish swatches / `AppIconPickerView` (10 finishes × 4 backgrounds) | `Dossier → Share` + `CardDetail` color switcher | **Headline:** Shareable Dossier Posters & Finishes<br>**Subhead:** Export 1- or 4-page PNG carousels & match your hardware finish | **主标题：** 一键导出长图海报与硬件配色<br>**副标题：** 极简单页与 4 页档案海报，匹配你的设备外观 |
| **6. Widgets, Island & Privacy** | iOS Home Screen / Lock Screen composite featuring `EarprintToday` (Small), `EarprintCardShelf` (Medium), `EarprintRing` (Large), `EarprintBudget` circular gauge, and **100% On-Device** badge | `docs/widgets/` renders or real device Home Screen + Lock Screen | **Headline:** Live Widgets, 100% On-Device<br>**Subhead:** Home & Lock Screen trackers with zero servers or tracking | **主标题：** 桌面小组件与 100% 本地隐私<br>**副标题：** 主屏/锁屏实时陪伴，数据绝不离开你的 iPhone |

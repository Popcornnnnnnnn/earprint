# Earprint Multi-Platform Launch Kit (`v1.1.0`)

Complete, platform-tailored launch playbook for **`Earprint - Headphone Archive`** (`v1.1.0`, iOS 18+):

- **App Store Name:** `Earprint - Headphone Archive` (search keyword: `Earprint` · `ID: 6837883616`)
- **App Store URL (LIVE — v1.0.0 approved 2026-11-23):** `https://apps.apple.com/app/id6837883616`
- **Landing Page:** `https://popcornnnnnnnn.github.io/earprint/`
- **Support FAQ:** `https://popcornnnnnnnn.github.io/earprint/support.html`
- **Privacy Policy:** `https://popcornnnnnnnn.github.io/earprint/privacy.html`
- **Public GitHub Repo (Open Source):** `https://github.com/Popcornnnnnnnn/earprint`
- **Price / Business Model:** Free core forever · Optional one-time Earprint Pro unlock (no subscription), zero accounts, zero servers, zero analytics/ads (`Data Not Collected`)

---

## 1. Truthful Product Spec Sheet (Verify Before Posting)

Use these exact verified numbers and labels from `Shared/Rarity.swift`, `HeadphoneModelCatalog.swift`, `DossierShareView.swift`, and `project.yml` so posts stay accurate and code-consistent:

### 1.1 Six Collector Foil Tiers (`Shared/Rarity.swift`)
Cards evolve automatically as lifetime HealthKit hours accumulate, and the `2×3` **Collector Binder** (`CardTiersView`) records the exact month each tier unlocked across your headphones:

| Tier | Hours | English Title (`Finish`) | 简体中文名称 | Max Holo Sheen |
| --- | --- | --- | --- | --- |
| 01 | `0h+` | **BRONZE SLATE** (`Anodized Matte`) | 青铜岩 / 青铜岩板 | `0.00` |
| 02 | `25h+` | **SILVER ALUMINUM** (`Beaded Alloy`) | 银铝 | `0.00` |
| 03 | `120h+` | **FJORD TEAL** (`Brushed Slate`) | 峡湾青 | `0.26` |
| 04 | `400h+` | **DEEP PURPLE** (`Frosted Plum`) | 深紫 / 深紫釉 | `0.42` |
| 05 | `1,000h+` | **MIDNIGHT CARBON** (`DLC Coating`) | 午夜碳纤 | `0.62` |
| 06 | `2,000h+` | **LIQUID HOLO · LEGENDARY** (`Prism Oxide`) | 液态全息 | `0.90` |

### 1.2 Hardware, Customization & Exports
- **Bluetooth Product IDs:** `34` Apple/Beats Bluetooth PIDs (`0x2002`–`0x2036`) mapped in `HeadphoneModelCatalog.swift` (AirPods 1–5, AirPods 4 & ANC, AirPods Pro 1–3, AirPods Max Lightning / USB-C / 2, Beats & Powerbeats), plus third-party over-ear/in-ear fallback; host iPhone/Watch (`HKDevice.local()`) samples are excluded so phone speakers never appear as headphones.
- **3D Models & Retail Colors:** Real-time RealityKit `.usdz` models (`AirPods4.usdz`, `AirPodsPro.usdz`, `AirPodsMax.usdz` + `HeadphoneGeneric.usdz` in Model Gallery & procedural fallback), with **10 official AirPods Max colors** (5 USB-C 2024 + 5 Lightning 2020) and Beats retail finishes.
- **App Appearance & Icons:** Full **Light / Dark / System** appearance across every view, Dossier slab, exported PNG, and widget; bilingual **English & 简体中文** matching system language automatically; custom concentric **Earprint Rings Emblem** primary icon + `40` alternate icons (**`41` total**).
- **PSA Device Dossier (`DeviceDossierView`):** Transparent acrylic grading slab with **`EAR GRADE` (`1.0–10.0`)** (`PRISTINE` / `GEM MINT` / etc.), `Week / Month / Year / All` ranges, scrubbable 30-day bar chart, 24-hour radial Day Clock, Habits & Hearing bento, monthly Career Ledger, milestone ETAs, and guilloché provenance certificate.
- **Customizable Share PNG Exports:**
  - **Dossier Share Sheet:** `Simple` (1 page) or `Long` (1–4 customizable pages: Cover, Rhythm, Habits & Hearing, Certificate) at `420×560 pt @3x` = **`1260 × 1680 px`** (`3:4` portrait), toggleable sections, Light or Dark theme.
  - **Rings Share Card:** `3:4` (`1080 × 1440 px`) or `9:16` (`1080 × 1920 px`), Light or Dark theme.
- **28-Day Earprint Rings & WHO Weekly Budget:** Concentric `28 × 24` local-time chronometer dial colored by energy-averaged loudness (`Leq` in `dB(A)`), listening personas (`Night Owl`, `Commute Soundtracker`, `Early Bird`, `All-Day Listener`), and **WHO / ITU H.870** budget (`80 dB(A)` × `40h/week` = `100%`, equal-energy `+3.01 dB` halving rule).
- **Widgets (No Live Activity in `v1.0.0`):** Home Screen `Today` (interactive card cycler), `Card Shelf` (up to 3 cards with `earprint://card/<id>` deep links), and `Large Earprint Ring + Heatmap + WHO Budget`, plus Lock Screen Circular, Rectangular, and Inline accessories.
- **Verifiable Privacy:** Zero networking code, zero servers, zero accounts, zero tracking/ad SDKs. Calls `HKHealthStore.requestAuthorization(toShare: [], read:)` strictly read-only for `headphoneAudioExposure` (`NSHealthUpdateUsageDescription` is declared in `Info.plist` solely to satisfy Apple static check `ITMS-90683`, while zero HealthKit write/save symbols exist in the Release binary).

---

## 2. Rollout Strategy: Live Global Launch (`READY_FOR_SALE`)

`v1.0.0` was approved on `2026-11-23` and is **LIVE (`READY_FOR_SALE`)** in **US, EU (`de`), UK (`gb`), Japan (`jp`), Hong Kong (`hk`), and Taiwan (`tw`)**.

| Timing | Where to Post | Purpose | Link / CTA |
| --- | --- | --- | --- |
| **Live Now (Global Storefronts)** | X Launch Thread, `r/iosapps`, `r/airpods`, TikTok, **即刻 / V2EX (for HK/TW/US Apple IDs)** | Launch across live regions right away using direct links while App Store search indexing completes (typically 12–24h) | Always use direct link `https://apps.apple.com/app/id6837883616` until `Earprint` ranks in App Store search |
| **Product Hunt / HN (`00:01 PT` / `16:01` Beijing)** | Product Hunt + Hacker News (`Show HN`) + `r/swift` | Start the 24-hour Product Hunt voting window at `00:01 PT` and technical HN wave together | Landing page (`popcornnnnnnnn.github.io/earprint/`) + App Store (`apps.apple.com/app/id6837883616`) + GitHub source |
| **After China Mainland (`cn`) Goes Live** | 小红书 Post 1 + 抖音 Video 1 + 少数派 | Hold China Mainland download posts until `cn` storefront (`https://apps.apple.com/cn/app/id6837883616`, currently `404`) is verified in App Store Connect | Direct search `App Store 搜「Earprint」` once `cn` is live & indexed |
| **Day 2–7** | 小红书 Post 2/3/4, 抖音 Video 2/3, TikTok Reels, `r/Apple` (Promo Sunday only!) | Sustain discovery with 6-tier showcase, PSA Ear Grade challenge, AirPods Max 10 colors, and Light/Dark craft | Encourage comment comparisons (`段位 / Ear Grade`) |

> **Important (2026-11-23 Status):**
> - **Use direct link globally:** Apple Search API indexing for newly released apps can take **12–24 hours**, so phone keyword search for `Earprint` may not surface it immediately even where it is live. Always include `https://apps.apple.com/app/id6837883616` in global posts.
> - **China Mainland (`cn`) check pending:** `https://apps.apple.com/cn/app/id6837883616` currently returns `404` (likely awaiting ICP / China territory verification in App Store Connect). Do **not** tell China Mainland users to search the CN App Store until confirmed.
> - **Monitor runtime:** `appstore-review-monitor` runs as an Antigravity sidecar (`App Store Review Monitor`) with per-channel delivery retries for iMessage, macOS notifications, and Antigravity briefings.

---

## 3. Compliance & Platform Safety Rules (All Channels)

1. **Mandatory Apple Non-Affiliation Notice:** Always state (in bio, footer, or pinned comment) that Earprint is an **independent app not affiliated with, sponsored by, or endorsed by Apple Inc.**
2. **No Medical Claims:** Frame as personal informational visualization and WHO/ITU H.870 awareness — **never** call it a medical device or hearing-loss diagnostic tool.
3. **Silent ANC Reality Check:** Remind new users in pinned comments that iOS only writes `Headphone Audio Levels` while audio is actively playing (not silent ANC), and that App Store apps cannot distinguish denied Health permission from zero samples (point to `Settings > Health > Data Access > Earprint`).
4. **Douyin / Rednote Anti-Ban Rules:** Never write `加微信 / WX / 私信领链接 / 扫码`, raw URLs in Rednote bio or Douyin comments, or夸张极限词 (`最强 / 天花板 / 绝对安全`). Guide users to **search `Earprint` in the App Store** (`App Store 搜索英文名 Earprint`).

---

## 4. 抖音 (Douyin) — 3 Ready Scripts (`9:16` Vertical, `15–22s`)

> **Asset ready to post:** `/Users/forge/.gemini/antigravity/brain/86907472-1f5c-45c9-88c5-a1dab54d1c23/promo-kit/videos/earprint-reel-zh-9x16.mp4` (`1080×1920`, H.264, `0` white flash frames).

### 抖音 Script 1：纯视觉 3D 炫技流（19s，强推荐首发）
- **核心视觉：** 深色背景 3D AirPods 卡片陀螺仪斜向镭射反光 → 单指旋转/翻面统计 → 浅色模式 PSA 设备档案与 30 天柱状图 → 深色 28 天声纹指环。
- **视频配乐：** 节拍清晰的轻节奏电子 / Synthwave，无口播，保留原生动效节奏。
- **发布标题文案：**
  ```text
  给我的 AirPods 做了一套会反光的 3D 收藏卡，翻开 Apple 健康才发现已经戴了一百多小时。纯本地只读不联网、免费无广，已开源。#独立开发 #AirPods #iOS技巧 #数码好物 #Apple健康
  ```
- **置顶评论：**
  ```text
  App Store 直接搜索英文名「Earprint」（全名 Earprint - Headphone Archive，iOS 18+ 可用）。纯本地读取 Apple 健康耳机音量，没有服务器、不用注册登录，项目代码也在 GitHub 开源啦～ 如果打开没有数据，记得去「设置 - 健康 - 数据访问」确认已允许读取（另外苹果系统只有放声音时才会记时长，纯开降噪不记）。（独立开发者作品，非 Apple 官方应用）
  ```

### 抖音 Script 2：悬念揭晓流（22–25s，实拍+录屏）
- **拍摄节奏：**
  - `0–3s` 手拿微旧 AirPods 充电盒特写：`这副 AirPods 在健康里偷偷攒了多少小时？`
  - `3–8s` 切 App 首页：`188h 22m` + 6 阶稀有度（`0h 青铜岩 → 25h 银铝 → 120h 峡湾青 → 400h 深紫 → 1000h 午夜碳纤 → 2000h 液态全息`）
  - `8–16s` 翻转进入 **PSA 亚克力评级档案**：展示 `EAR GRADE` 评分（如 `9.5 GEM MINT`）、`周/月/年/全部` 切换与 `24 小时钟盘`
  - `16–22s` 滑到桌面上小号/中号 3 卡架/大号 28 天耳纹小组件
- **口播参考：** “你知道 iPhone 里的健康 App，默默记了好几年你戴 AirPods 的总时间吗？我写了这个免费开源工具，一秒把你的历史数据变成 3D 收藏卡，还能给佩戴习惯做 PSA 评级，全程纯本地不联网。快看你的耳机现在排第几阶？”
- **发布文案：**
  ```text
  翻出 iPhone 健康里存了好几年的耳机记录，给每副 AirPods 都发了张带编号的 3D 收藏卡 + PSA 评级档案。你是第几阶？#AirPodsPro #AirPodsMax #iPhone #独立开发者 #宝藏App
  ```

### 抖音 Script 3：强迫症踩点换色（18s）
- **核心卖点：** AirPods Max `10` 款官方配色实时切换（USB-C 5 色 + Lightning 5 色）+ `41` 款桌面自定义图标 + 浅色/深色双主题对比。
- **发布文案：**
  ```text
  强迫症把 AirPods Max 的 10 种官方配色和 41 款桌面图标全塞进一个免费 App 里了 🎨 浅色/深色主题无缝切换。#AirPodsMax #桌面美学 #iOS小组件 #独立开发 #极简设计
  ```

---

## 5. TikTok (Global) — 3 Ready English Scripts (`9:16` Vertical, `15–22s`)

> **Assets ready to post:**
> - Captioned Reel: `.../promo-kit/videos/earprint-reel-en-9x16.mp4` (`1080×1920`, H.264)
> - Raw Clean Cut (add native TikTok text/sounds): `.../promo-kit/videos/earprint-raw-en.mp4` (`1080×1920`, H.264)

### TikTok 1 — Curiosity Reveal Hook (Top Performer Format)
- **On-screen hook (`0–2.5s`):** `Your iPhone has been tracking EVERY hour you wore your AirPods 👀`
- **Voiceover / Captions:**
  - `Apple Health quietly stores years of your headphone listening history.`
  - `I built a free, 100% offline iOS app that turns it into 3D collectible foil cards.`
  - `6 tiers from Bronze Slate up to Liquid Holo at 2,000 hours — plus a PSA-style Ear Grade slab & 28-day Earprint Rings.`
  - `No login. Zero servers. Open source on GitHub.`
- **Caption:**
  ```text
  Turns out Apple Health kept receipts on every single hour in my AirPods 💀 Built a free, 100% offline + open-source iOS app called Earprint to turn that history into 3D foil cards & a PSA-style Ear Grade slab. Search "Earprint" on the App Store (iOS 18+). #airpods #iphone #iosapp #applehealth #indiedev #tech #opensource
  ```
- **Pinned Comment:**
  ```text
  App is "Earprint - Headphone Archive" (free, zero ads/accounts). Note: Apple Health only logs while audio is actively playing (not silent ANC). Independent app, not affiliated with Apple Inc.
  ```

### TikTok 2 — "PSA Grading My AirPods" Challenge
- **On-screen hook:** `Grading my daily-driver AirPods like a PSA Pokémon card 💎`
- **Beats:** Card flip → Light-mode Acrylic Grading Slab (`EAR GRADE 9.5 · GEM MINT`) → WHO Weekly Hearing Budget (`80 dB(A) for 40h/wk`) → Export customizable 4-page carousel PNGs.
- **Caption:**
  ```text
  My AirPods Pro graded 9.5 GEM MINT based on decibels, WHO safe listening limits, and late-night hours 😂 Search "Earprint" on iOS (free & offline). What grade would yours get? #airpodspro #tech #edc #ios #apple #earprint
  ```

### TikTok 3 — "Zero Servers, Audit the Code Yourself"
- **On-screen hook:** `A Health data app that actually sends 0 bytes to the internet 🔓`
- **Caption:**
  ```text
  Most health/tracker apps want an account & cloud sync. Earprint asks read-only Apple Health access, makes 0 network calls, and the Swift code is public on GitHub. #privacy #iosdev #swiftui #realitykit #opensource #airpods
  ```

---

## 6. 小红书 (Rednote) — 4 Carousel Posts (`3:4`, Zero Shadowban)

> **Assets ready to post:** `/Users/forge/.gemini/antigravity/brain/86907472-1f5c-45c9-88c5-a1dab54d1c23/promo-kit/rednote-zh/` (`01`–`06`, `1200 × 1600 px` exact `3:4`).
> **Bio 建议（已过审可用）：**
> ```text
> 独立开发者｜做了一款免费开源的 AirPods 3D 收藏卡 App 🎧
> App Store 搜「Earprint」｜iOS 18+ 免费无广
> 只读 Apple 健康 · 100% 本地不联网 · 非 Apple 官方应用
> ```

### 小红书 Post 1：正式上线主推（直接使用 `rednote-zh/01..06`）
- **标题备选：**
  1. `给陪伴你几百小时的 AirPods，发一张会反光的 3D 收藏卡`
  2. `翻开 Apple 健康才发现我戴了 188 小时耳机，顺手做了这个免费开源 App`
  3. `把 iPhone 健康里的耳机记录变成 PSA 评级闪卡（纯本地零上传）`
- **正文：**
  ```text
  之前突然发现，只要 iPhone 开着「耳机音量」记录，Apple 健康其实默默攒了好几年的 AirPods 听歌数据——只是原生的柱状图太枯燥了，很少有人点进去看。

  花了几周用 SwiftUI + RealityKit 写了一个核心功能永久免费、不联网的小工具，叫 **Earprint**（提供可选一次性 Pro 解锁、无订阅）：

  🔸 **实时 3D 耳机收藏卡**：自动读取本机健康里的历史（不用从零攒起），每副 AirPods / Beats 都会生成带首次佩戴日期与编号的立体卡片。拖动旋转、双指放大、长按飞旋、倾斜手机看镭射反光，轻点翻面查看近 4 周听歌环形图。
  🔸 **6 阶稀有度收藏图鉴（0h → 2,000h）**：0h 青铜岩 → 25h 银铝 → 120h 峡湾青 → 400h 深紫 → 1,000h 午夜碳纤 → 2,000h 液态全息，记录每副耳机达成高阶的月份。
  🔸 **PSA 级设备档案 & 自定义导出**：透明亚克力评级卡套 + 1.0–10.0「聆听评分」，含 30 天趋势、24 小时钟盘、习惯看板和硬件溯源证书；内置浅色/深色高清长图导出（简图 1 页或自由勾选 1–4 页 3:4 组图，直接用来发笔记都不用再 P 图）。
  🔸 **28 天声学聆听环 & WHO 护耳预算**：一眼看清自己是「夜猫子」还是「通勤声景师」，对照 WHO 每周安全额度（80 dB(A) 下每周 40 小时）。
  🔸 **桌面/锁屏小组件 + 41 款图标 + AirPods Max 10 色切换**，浅色/深色主题随意切。

  **最重要的是：** 零登录、零服务器、零广告和统计 SDK，所有健康计算加密留在你的 iPhone 上，源码也已在 GitHub 公开（同名搜 `Popcornnnnnnnn/earprint`）欢迎检查。

  App Store 直接搜英文名 **`Earprint`** 就能免费下载体验核心功能（iOS 18+，支持中英文随系统切换；可选一次性买断 Earprint Pro，无订阅）。快去看看你的主力耳机攒了多少小时、拿了几分 Ear Grade，评论区蹲一波最高段位 👀

  （注：独立开发者个人作品，与 Apple Inc. 无任何关联；不构成医疗诊断设备。）
  ```
- **Tags：** `#Earprint` `#AirPods` `#宝藏App` `#iOS应用推荐` `#独立开发` `#苹果健康` `#开源项目` `#极简桌面`
- **置顶评论：**
  ```text
  上手小贴士：① 打开授权时记得允许只读「耳机音量」，如果以前关过权限可在「设置 → 健康 → 数据访问 → Earprint」重新打开；② Apple 健康只会在主动播放音频时记录，纯戴耳机开降噪不放歌系统不生成数据哦～
  ```

### 小红书 Post 2：6 阶进化 + AirPods Max 10 色 + 41 款桌面图标专场
- **配图：** `app-store-screenshots/zh-Hans/` 中的 `02-card-tiers.png`、`07-airpods-max-finishes.png`、`05-collection-themes.png` + `rednote-zh/05-max-colors-themes.png`。
- **标题：** `从 0h 青铜岩到 2,000h 液态全息：测测你的 AirPods 第几阶？`
- **互动问题：** `大家目前主力 AirPods 在哪个段位？达到 1,000h 午夜碳纤或 2,000h 液态全息的大佬请现身`

### 小红书 Post 3：直接展示 App 一键导出的 `3:4` 档案长图（“用自己写的 App 出图发小红书”）
- **操作：** 直接在手机实机用 **设备档案 → 分享档案 → 长图（4 页 `1260×1680` `3:4` PNG）** 导出你真实耳机的数据图 + 1 页浅色卡套特写发组图！真实个人数据天然比 Demo 数据转化率高很多。
- **标题：** `为了发小红书省事，我直接在 App 里做了浅/深色 4 页 3:4 档案导出`

### 小红书 Post 4：夜猫子听歌图谱 + 28 天声纹环 & 小组件
- **标题：** `把最近 28 天戴耳机的节奏画成一圈彩色指环，才发现自己半夜两点最爱听歌`
- **配图：** `rednote-zh/04-28day-rings-who.png` + 实机摆放小组件桌拍图 + `ShareCardView` 导出图。

---

## 7. X (Twitter) — Thread & Standalone Posts

> **Assets ready to post:**
> - Single-post / Thread #1 Hero Banner: `.../promo-kit/global-en/00-hero-banner-16x9.png` (`1600×900`)
> - Video post: `.../promo-kit/videos/earprint-raw-en.mp4` or `earprint-reel-en-9x16.mp4`
> - 4-image grid option: `.../promo-kit/global-en/01..04-*.png` (`1200×1500`)

### X Launch Thread (5 Posts)
- **Tweet 1/5 (Attach `earprint-raw-en.mp4` or `00-hero-banner-16x9.png`):**
  ```text
  Apple Health has been silently logging every hour you wore your AirPods for years.

  So I built Earprint — a free, open-source, 100% offline iOS app that turns your headphone history into interactive 3D foil cards, a PSA-style Device Dossier & 28-day acoustic rings.

  Just shipped on the App Store 🧵👇
  https://apps.apple.com/app/id6837883616
  ```
- **Tweet 2/5 (Attach `02-card-tiers-4x5.png`):**
  ```text
  Cards automatically level up across 6 metallic foil tiers from your real Apple Health lifetime hours:

  0h+ Bronze Slate
  25h+ Silver Aluminum
  120h+ Fjord Teal
  400h+ Deep Purple
  1,000h+ Midnight Carbon
  2,000h+ Liquid Holo · Legendary

  Flip any card for 4-week stats or tap Dossier for its Ear Grade slab.
  ```
- **Tweet 3/5 (Attach `03-psa-dossier-4x5.png`):**
  ```text
  Built a collector-grade Device Dossier in Light & Dark mode:

  • Transparent acrylic slab + EAR GRADE (1.0–10.0) scored from loudness, late-night habits & WHO weekly limits
  • Scrubbable 30-day bar chart & 24h radial Day Clock
  • Customizable 1-page & 4-page 3:4 PNG poster exports
  • 34 Apple/Beats Bluetooth PIDs + 10 AirPods Max finishes + 41 app icons
  ```
- **Tweet 4/5 (Attach `04-rings-privacy-4x5.png`):**
  ```text
  Everything runs locally in SwiftUI + RealityKit:

  • Strictly read-only HealthKit (headphoneAudioExposure only)
  • Zero servers, zero accounts, zero analytics/ad SDKs
  • Home & Lock Screen widgets included
  • Excludes host iPhone speakers automatically

  Inspect the full Swift source on GitHub:
  https://github.com/Popcornnnnnnnn/earprint
  ```
- **Tweet 5/5:**
  ```text
  Grab Earprint for free (iOS 18+, English & 简体中文):
  App Store: https://apps.apple.com/app/id6837883616
  Site & FAQ: https://popcornnnnnnnn.github.io/earprint/

  Curious what Ear Grade & tier your daily-driver AirPods hit — drop a screenshot below 👇

  (Independent app, not affiliated with Apple Inc.)
  ```

### X Build-in-Public / Dev Craft Tweet
```text
Fun SwiftUI + HealthKit edge cases solved while shipping Earprint:
1. Equal-energy Leq & WHO ITU H.870 dose (10*log10(2) ≈ 3.01 dB exchange) over UTC 15-min slots so DST transitions stay aligned
2. Stripping "-tacl" from HKDevice.localIdentifier so renamed AirPods don't split cards
3. Static ITMS-90683 HealthKit purpose-string quirks even with toShare: []

All open source: https://github.com/Popcornnnnnnnn/earprint
```

---

## 8. Reddit Strategy & Subreddit Drafts (Strict Anti-Spam Etiquette)

> **Reddit Rule:** Post genuine, story-first text with specs & open-source link; reply to every comment; check `r/Apple` Self-Promotion Sunday rule before posting there (`r/iosapps`, `r/airpods`, `r/swift`, `r/SideProject` allow launch posts any day following their flair/disclosure rules).

### `r/iosapps` (`[Free · Open Source]`)
- **Title:** `[iOS 18+] [Free] [Open Source] Earprint – Turns your Apple Health AirPods history into 3D collectible cards, PSA Device Dossier & 28-day rings (100% offline)`
- **Body (Attach `00-hero-banner-16x9.png` + `01..04` or video):**
  ```text
  Hey r/iosapps! Apple Health quietly logs every hour you listen through headphones (`headphoneAudioExposure`), usually buried inside a tiny chart. I built **Earprint** to turn that existing multi-year history into something tactile and fun.

  **What it does:**
  - **Interactive 3D Collectible Cards:** Real-time RealityKit AirPods 4 / Pro / Max cards with gyroscope tilt foil shimmer, drag-to-spin physics, pinch zoom, long-press twirl haptics, 10 official AirPods Max finishes, and flip-to-stats backs.
  - **6 Collector Foil Tiers (0h → 2,000h):** Bronze Slate → Silver Aluminum → Fjord Teal → Deep Purple → Midnight Carbon → Liquid Holo Legendary, tracked in a multi-device Collector Binder.
  - **PSA-Style Device Dossier:** Acrylic grading slab with an Ear Grade (1.0–10.0) scored from loudness, loud-session share, late-night habits, and WHO weekly budgets (`80 dB(A)` × `40h/week`), plus 30-day scrub charts, 24h Day Clock, hardware ID (`0x2024`), and customizable 1-to-4-page 3:4 PNG exports.
  - **28-Day Earprint Rings & Widgets:** Concentric 28×24 chronometer dial + listening persona + Home & Lock Screen widgets.
  - **Light / Dark / System** themes, **41** app icons, and **English + 简体中文**.

  **Privacy & Cost:**
  - **Free core forever** · Optional one-time Earprint Pro unlock (no subscriptions), no ads, no accounts.
  - **100% offline & open source:** Zero network code, read-only HealthKit access (`toShare: []`), excludes `HKDevice.local()` iPhone speakers.

  - App Store: https://apps.apple.com/app/id6837883616
  - GitHub (full Swift source): https://github.com/Popcornnnnnnnn/earprint
  - Landing Page / FAQ: https://popcornnnnnnnn.github.io/earprint/

  *(Quick tip: Apple iOS only logs `Headphone Audio Levels` while audio is playing — silent ANC wear generates no samples.)*
  ```

### `r/airpods`
- **Title:** `I built a free, offline iOS app that turns years of your Apple Health AirPods listening history into 3D collectible cards (no account, open source)`
- **Tone:** Lead with the relatable AirPods nostalgia hook + `34` mapped Apple/Beats Bluetooth PIDs + `10` AirPods Max colors + quick tip about `HKDevice.local()` / silent ANC, plus clear non-affiliation disclaimer.

### `r/swift` & `r/iOSProgramming`
- **Title:** `Open-sourced Earprint (SwiftUI + RealityKit + HealthKit): incremental anchored audio-exposure aggregation, 6-tier foil shaders, and App Group widgets`
- **Focus:** Technical architecture (`ListeningAggregate` v2, UTC 15-min slots preserving midnight-crossing sessions & DST shifts, `Energy = 10^(dB/10) * t`, `HKDevice.localIdentifier` `-tacl` merging, SwiftUI `ImageRenderer` PDF/PNG sharing sheets, and `75` XCTest cases).

### `r/Apple` (Promo Sunday Only!)
- Keep strictly compliant with r/Apple's Self-Promotion Sunday rule: clear free/open-source/no-ads disclosure, technical value, responsive in comments.

---

## 9. Product Hunt Launch Package

- **Name:** `Earprint - Headphone Archive`
- **Tagline (`49 / 60 chars`):** `Turn Apple Health headphone history into 3D cards`
- **Topics:** `iPhone`, `Health & Fitness`, `Open Source`, `Audio`, `Design Tools`
- **Pricing:** `Freemium` (`Free core forever · Optional one-time Pro unlock`)
- **Gallery Order (`5` slides + Video):**
  1. `earprint-reel-en-9x16.mp4` (or YouTube mirror of `earprint-raw-en.mp4`)
  2. `00-hero-banner-16x9.png` — *"6-Tier 3D Foil Cards, PSA Device Dossier & 28-Day Rings"*
  3. `app-store-screenshots/en-US/02-card-tiers.png` — *"Evolve from Bronze Slate (0h) to Liquid Holo (2,000h)"*
  4. `app-store-screenshots/en-US/03-device-dossier.png` — *"Collector-Grade Acrylic Dossier, Ear Grade & 3:4 PNG Export"*
  5. `app-store-screenshots/en-US/04-earprint-rings.png` — *"28-Day Acoustic Chronometer & WHO Weekly Budget (Zero Servers)"*
- **Maker First Comment (Copy & Paste):**
  ```text
  Hey Product Hunt! 👋

  I noticed Apple Health quietly stores years of `Headphone Audio Levels` on your iPhone — how many hours you listened, which AirPods pair you wore, and how loud it was — buried inside static bar charts.

  So I built **Earprint** to turn that private local history into tactile collector cards you actually enjoy revisiting:
  • **Interactive 3D Foil Cards** powered by RealityKit + gyroscope tilt parallax (AirPods 4, Pro, Max + Beats finishes)
  • **6 Evolving Tiers (0h → 2,000h)** tracked in a multi-device Collector Binder
  • **PSA-Style Device Dossier** with an Ear Grade (1.0–10.0), 30-day scrub charts, 24h Day Clock, WHO/ITU H.870 safe-listening score, and customizable 1-to-4-page 3:4 PNG share posters
  • **28-Day Earprint Rings + Native Home & Lock Screen Widgets**
  • **Free core forever · Optional one-time Earprint Pro unlock** (zero subscriptions, zero accounts, zero servers, zero tracking SDKs, `toShare: []` read-only HealthKit).

  Source code & architecture docs: https://github.com/Popcornnnnnnnn/earprint
  App Store (iOS 18+, EN & 简体中文): https://apps.apple.com/app/id6837883616

  *(Tip: Apple only logs headphone audio levels while audio is actively playing, not during silent ANC.)*
  I'd love to hear your thoughts, feedback, or what Ear Grade your main headphones landed on!
  ```

---

## 10. Hacker News (`Show HN`)

- **Title (`74 chars`):** `Show HN: Earprint – Open-source iOS app turning HealthKit audio into 3D cards`
- **URL:** `https://github.com/Popcornnnnnnnn/earprint` (HN strongly prefers direct GitHub / technical writeup over App Store redirects, with App Store link in README & top comment!)
- **First Comment:**
  ```text
  Hi HN, I built Earprint (`com.popcornnn.earprint`), a free, open-source SwiftUI + RealityKit iOS 18+ app that visualizes Apple Health `HKQuantityType(.headphoneAudioExposure)` history without touching a network socket.

  A few interesting implementation notes in case you're building with HealthKit audio data:
  1. **True energy-averaged Leq & WHO dose:** Apple's individual exposure samples are weighted cleanly via `E = 10^(dB/10) * duration`, computing weekly budget share against WHO/ITU H.870 (`80 dB(A)` × 40h/week, halving every `10*log10(2) ≈ 3.01 dB`).
  2. **Time-zone-invariant bucketing:** Recent samples are quantized into UTC 15-minute buckets (`epoch / 900`) and projected into local calendar hours at render time, handling midnight crossings and DST shifts cleanly (verified across 75 unit tests).
  3. **Device identity merging & speaker filtering:** Stripping `-tacl` from `HKDevice.localIdentifier` merges cards seamlessly when a user renames Bluetooth headphones; samples matching `HKDevice.local()` (host iPhone/Watch) are excluded so speaker playback never generates headphone cards.
  4. **ITMS-90683 quirk:** Even when calling `requestAuthorization(toShare: [], read:)` strictly read-only with zero HealthKit save/write symbols in the Release binary, App Store Connect requires `NSHealthUpdateUsageDescription` statically if that selector is linked.

  GitHub: https://github.com/Popcornnnnnnnn/earprint
  App Store: https://apps.apple.com/app/id6837883616
  ```

---

## 11. 即刻 (Jike) / V2EX / 少数派 (SSPai)

### 11.1 即刻（发「独立开发者 / App 推荐 / AirPods」圈子）
```text
做了个免费开源的 iOS 小工具「Earprint」🎧

把 Apple 健康里躺了好几年的 AirPods 耳机音量历史，直接变成可转动的 3D 收藏闪卡（0h 青铜岩 → 2000h 液态全息 6 阶进化）、带 EAR GRADE 的 PSA 评级档案和 28 天声纹指环，顺手把小组件、浅/深色主题和 41 款图标也补齐了。

零账号、零服务器、不联网，GitHub 已全量开源，App Store 直接搜 `Earprint` 就能装～
（个人独立作品，非 Apple 官方 App）

GitHub：https://github.com/Popcornnnnnnnn/earprint
App Store：https://apps.apple.com/app/id6837883616
```

### 11.2 V2EX（`/go/apple` 或 `/go/share` 节点）
- **标题：** `[开源免费 / iOS] Earprint：把 Apple 健康里的 AirPods 历史变成 3D 收藏卡、PSA 档案与 28 天声纹环（纯本地不联网）`
- **要点：** 简洁技术风：说明用 `HKAnchoredObjectQueryDescriptor` 增量只读 `headphoneAudioExposure`、按 `-tacl` 合并改名设备、排除 `HKDevice.local()`、Leq 能量加权 + WHO ITU H.870 剂量算法、支持中英文与深浅主题、开源地址 + App Store 链接 + 免责声明。

### 11.3 少数派 (SSPai) — App+1 / Matrix 投稿结构
- **切入点：** 「为什么你的 AirPods 值得一张实体感数字档案？」—— 从系统“健康”里被埋没的 `headphoneAudioExposure` 讲起 → 设计理念（实体球星卡 foil 金属光学质感 + PSA 亚克力评级隐喻 + 克制的 WHO 听力剂量提醒）→ 隐私架构透明性（开源无网络权限审计）。配 `promo-kit/rednote-zh/` 与 App 原生导出的 4 张 `1260×1680` 长图效果极佳。

---

## 12. Third-Party CC-BY 4.0 Attribution & Non-Affiliation Reference

- **AirPods 4:** Falah3D (`3dFalah`), *"AirPods 4"*, `https://sketchfab.com/3d-models/airpods-4-e44730974131402eb496352cab19c82e` (CC-BY 4.0)
- **AirPods Max:** polyman Studio (`Polyman_3D`), *"Airpods max sky blue"*, `https://sketchfab.com/3d-models/airpods-max-sky-blue-3d0643db08fc4ef89bda55a74077ece4` (CC-BY 4.0)
- **AirPods Pro:** polyman Studio (`Polyman_3D`), *"Airpods Pro With Magsafe Charging Case Ios15"*, `https://sketchfab.com/3d-models/airpods-pro-with-magsafe-charging-case-ios15-52e5f28b37f94f05b6c0768773137689` (CC-BY 4.0)
- **Generic Headphones:** crow (`crow.bite`), *"Studio Headphones"*, `https://sketchfab.com/3d-models/studio-headphones-2f04830fbf884632a89445db0d170ba8` (CC-BY 4.0)
- **Disclaimer:** Earprint is an independent app by Weizhi Wang and is not affiliated with, sponsored by, or endorsed by Apple Inc. Informational only, not a medical device.

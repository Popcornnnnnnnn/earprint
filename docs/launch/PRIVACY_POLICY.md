# Privacy Policy — Earprint / 隐私政策

**Effective Date / 生效日期:** `[YYYY-MM-DD — set before publishing]`  
**App:** Earprint (`com.popcornnn.earprint`)  
**Developer / Contact / 开发者联系方式:** `[Developer or Entity Name]` · `[support@example.com]`

> **Plain-language summary:** Earprint works **100% on your iPhone**. It reads your Apple Health Headphone Audio Levels in read-only mode to render your 3D headphone cards, Device Dossier, 28-day Earprint Rings, and widgets. Earprint has no user accounts, no backend servers, no analytics or advertising SDKs, and never sends your listening or Health data off your device.
>
> **一句话说明：** Earprint **100% 在你的 iPhone 本地运行**。App 仅以只读方式读取 Apple“健康”中的耳机音量曝光数据，用于生成 3D 耳机卡片、设备档案、28 天声学聆听环和桌面小组件。我们不设账号系统、没有后台服务器、不含任何第三方统计或广告 SDK，也不会将你的任何健康或听歌数据上传或离开你的设备。

---

## English

### 1. Overview

Earprint is an independent iOS utility that visualizes your headphone listening history stored in Apple Health. Protecting your privacy is built directly into the app's architecture: **Earprint does not collect, transmit, store on external servers, sell, or share any personal or Health data.**

For Apple App Store Privacy ("Privacy Nutrition Label") purposes, Earprint operates under **Data Not Collected**.

### 2. Apple Health (HealthKit) Data Accessed

With your explicit permission in the iOS Health Access prompt, Earprint requests **read-only** access to a single HealthKit data type:

- **Headphone Audio Levels** (`HKQuantityType(.headphoneAudioExposure)`)

Specifically, Earprint reads the following properties locally on your iPhone:
- Sample timestamps (`startDate`, `endDate`) and A-weighted sound level (`dB(A)`)
- Associated audio accessory metadata (`HKDevice` fields such as headphone Bluetooth nickname, manufacturer, Bluetooth product ID, hardware/firmware version, and accessory local identifier, plus recording `HKSource` name/bundle ID)

Earprint does **not**:
- Request write access to Apple Health in App Store / Release builds (`NSHealthUpdateUsageDescription` is not included in Release builds).
- Access any other Apple Health categories (such as heart rate, workouts, sleep, or medical records).
- Access your microphone, camera, contacts, location, or raw audio playback streams.

### 3. How Your Data Is Processed & Stored On-Device

All processing happens locally on your iPhone:

1. **On-Device Aggregation Cache:** Earprint processes HealthKit samples off the main thread and stores compact derived totals and an Apple Health sync anchor locally inside the app's sandboxed Application Support directory (`listening-aggregate.json`), encrypted at rest using iOS file protection (`NSFileProtectionCompleteUntilFirstUserAuthentication`).
2. **App Group Snapshot for Widgets & Live Activities:** To display your listening summary on iOS Home Screen widgets, Lock Screen widgets, and Live Activities (`EarprintWidgets`), the app writes a compact derived summary file (`widget-snapshot.json`) and widget display preference (such as the currently featured card index) into the app's private App Group container (`group.com.popcornnn.earprint`). This container stays strictly on your iPhone and is shared only between the Earprint app and its embedded `EarprintWidgets` extension.
3. **Optional User-Initiated Image Exports:** When you export a 1-page or 4-page Dossier poster or a Rings share card, the PNG image is rendered locally on your iPhone and is only shared if and where you choose using the standard iOS Share Sheet.

### 4. Zero Servers, Zero Analytics, Zero Third-Party Tracking

- **No backend servers:** Earprint does not operate servers to collect or sync your data.
- **No accounts or sign-in:** No name, email address, phone number, or account registration is required.
- **No analytics, ad, or crash SDKs:** Earprint contains zero third-party analytics, telemetry, advertising, or behavioral tracking libraries.
- **HealthKit Compliance:** Consistent with Apple's App Review Guidelines (Section 5.1.3), data accessed via HealthKit is never used for advertising, marketing, or data brokerage, and is never disclosed to third parties.

### 5. Managing Permissions & Deleting Local Data

You remain in full control of your data at all times:

- **Revoke HealthKit Permission:** Open **Settings → Privacy & Security → Health → Earprint** (or open the **Apple Health** app → tap your profile picture → **Apps → Earprint**) and turn off **Headphone Audio Levels**.
- **Delete Local App Cache:** Uninstalling Earprint from your iPhone permanently removes the app's local aggregate cache and the App Group snapshot container (`group.com.popcornnn.earprint`). Your underlying listening history in Apple Health is never modified or deleted by Earprint.

### 6. Informational Purpose & Non-Affiliation

- **Not a Medical Device:** Earprint's listening rings, WHO weekly budget indicators, and Ear Grade scores are for personal informational and collectible entertainment purposes only. They are not medical advice and are not intended to diagnose, treat, or prevent hearing loss or any medical condition.
- **Independent App:** Earprint is an independent product and is not affiliated with, sponsored by, or endorsed by Apple Inc. Apple, Apple Health, AirPods, AirPods Pro, AirPods Max, and Beats are trademarks of Apple Inc.

### 7. Children's Privacy

Earprint does not collect personal information from anyone, including children under 13 (or the applicable age in your jurisdiction).

### 8. Changes & Contact

If this Privacy Policy is updated for a future version (for example, if optional iCloud sync or new features are ever introduced), the updated policy will be published at this URL with a revised Effective Date before those changes take effect.

Questions or privacy inquiries: **[support@example.com]**  
Support page: **[https://your-domain-or-github-pages-url]**

---

## 简体中文

### 一、概述

Earprint 是一款独立开发的 iOS 应用，用于将存储在 Apple“健康”中的耳机聆听记录可视化为 3D 耳机卡片、设备档案与声学聆听环。隐私保护从一开始就内建于应用架构中：**Earprint 不会收集、上传、向外部服务器存储、出售或向任何第三方共享你的个人数据或健康数据。**

在 App Store“App 隐私”标签下，Earprint 属于 **“不收集数据”（Data Not Collected）**。

### 二、访问的 Apple“健康”（HealthKit）数据范围

仅在获得你通过 iOS 系统弹窗授予的明确授权后，Earprint 会以**严格只读**的方式访问以下**唯一一项**健康数据类型：

- **耳机音量（Headphone Audio Levels）**（`HKQuantityType(.headphoneAudioExposure)`）

具体仅在本地读取以下字段：
- 采样时间段（起止时间）及 A 计权分贝数值（`dB(A)`）
- 关联耳机设备的系统元信息（`HKDevice`：耳机蓝牙名称、制造商、蓝牙产品型号 ID、硬件/固件版本、设备本地标识符及写入来源 `HKSource`）

Earprint **不会**：
- 在 App Store 正式发布版本中请求 Apple“健康”的写入权限（Release 版本不包含 `NSHealthUpdateUsageDescription`）。
- 读取心率、体能训练、睡眠、医疗记录等其他任何健康数据类别。
- 访问麦克风、相机、通讯录、定位信息或你正在播放的具体音频/歌单内容。

### 三、数据如何在本地处理与存储

所有计算与存储全部在你的 iPhone 本地完成：

1. **本地加密聚合缓存：** Earprint 在后台队列将健康采样聚合为统计结果，并将统计缓存与增量同步锚点保存在应用沙盒的 `Application Support` 目录（`listening-aggregate.json`）中，启用 iOS 系统文件级加密保护（`NSFileProtectionCompleteUntilFirstUserAuthentication`）。
2. **桌面小组件与灵动岛本地共享容器：** 为了在主屏幕小组件、锁屏小组件与实时活动/灵动岛（`EarprintWidgets`）中显示统计结果，主应用仅将精简后的衍生汇总数据（`widget-snapshot.json`）及小组件展示偏好（如当前展示卡片索引）写入本地 iOS App Group 容器（`group.com.popcornnn.earprint`）。该容器仅在 Earprint 主应用及其内置小组件扩展之间本地访问，不会离开你的设备。
3. **主动导出的分享图片：** 当你使用“分享档案”或分享“声学聆听环”海报时，PNG 图片在设备本地渲染生成，仅在你主动点击系统分享面板（Share Sheet）选择发送目标时才由你自行分享。

### 四、无服务器、无埋点统计、无第三方追踪

- **无后台服务器：** Earprint 不运营任何用于收集、同步或备份用户数据的服务器。
- **无需账号登录：** 不要求填写姓名、手机号、邮箱或注册账号。
- **零第三方分析与广告 SDK：** 应用内不包含任何第三方埋点分析、崩溃上报、广告归因或行为追踪 SDK。
- **HealthKit 合规承诺：** 严格遵守 Apple《App 审核指南》第 5.1.3 条，从 Apple“健康”读取的任何数据绝不用于广告、营销或数据交易，也不会向任何第三方披露。

### 五、管理权限与删除本地数据

你对自己的数据拥有完全控制权：

- **随时撤销健康权限：** 打开 iPhone **设置 → 隐私与安全性 → 健康 → Earprint**（或打开 **健康 App → 右上角个人头像 → App → Earprint**），关闭 **“耳机音量”** 读取开关即可。
- **清除本地缓存数据：** 从 iPhone 卸载 Earprint 即可永久删除本地统计缓存及 App Group 容器（`group.com.popcornnn.earprint`）中的全部衍生数据；你在 Apple“健康”中的原始记录不受任何影响。

### 六、非医疗声明与独立声明

- **非医疗器械：** Earprint 展示的聆听环、世界卫生组织（WHO）每周听力预算参考与聆听评分（Ear Grade）仅用于个人兴趣展示与健康意识参考，不构成医疗建议，亦不用于诊断、治疗或预防任何听力疾病。
- **独立开发者声明：** Earprint 为独立开发作品，与 Apple Inc. 无任何关联、赞助或官方背书关系。Apple、Apple Health、AirPods、AirPods Pro、AirPods Max 与 Beats 均为 Apple Inc. 的注册商标。

### 七、未成年人隐私

Earprint 不向任何用户（包括未满 13 周岁或所在司法辖区适用法定年龄的未成年人）收集个人信息。

### 八、政策更新与联系我们

如未来版本因新增功能（例如用户主动开启的 iCloud 同步等）而需调整本隐私政策，我们将在更新生效前于本页面公布修订内容并更新生效日期。

隐私相关咨询或问题反馈：**[support@example.com]**  
技术支持页面：**[https://your-domain-or-github-pages-url]**

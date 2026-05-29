# NeonSaga — 产品定义

> 🌐 **Languages**: 中文（当前文件）· [English docs/PRODUCT.md](PRODUCT.md)

> **产品定位的真相来源。** 代码、计划和设计决策均以本文件为准。
> 最后更新日期：2026-05-27。

---

## 1. 愿景

NeonSaga 将生活变成一款开放世界 RPG。参考框架：*Earth Online*（将生活视为 MMORPG 认真对待）+ *塞尔达传说：旷野之息*（玩家自主，并行子系统）+ *Cyberpunk 2077*（视觉框架）。玩家的真实世界行为——进食、健身、旅行、消费、阅读——流入实时 RPG character sheet。stats 上升，quests 完成，character 升级。AI 是支撑基础设施；玩家才是主角。

## 2. 受众与身份目标

**用户**：已经玩游戏、想提升现实生活水平、不会被充满内疚感的自我提升应用打动的人。拥有 iPhone。使用英语作为操作语言。

**身份转变**：使用 NeonSaga 六个月后，用户成为更自律、以成长为导向的自己——不是因为应用在说教，而是因为他们在玩一款以生活为内容的游戏。RPG LV 是自律能力的代理指标。AI 是副驾驶，不是教练。

## 3. 驱动循环

NeonSaga 利用现有的游戏多巴胺连线，而非建立新的自律习惯。机制：RPG 机制让现实世界行为产生成就感。Habitica 使用连续打卡内疚感；Apple Health 没有钩子。NeonSaga 的钩子就是 RPG 本身——看着 character 的 LV / sub-stats / quest 进度上升，会让你想去完成现实世界的行为。

**四个多巴胺钩子（全部 MVP）：**

1. **Level-up 全屏接管** — 任何 sub-stat 跨越 LV 阈值时触发全屏接管（Cyberpunk HUD + 0.8 秒动画 + 触觉反馈 + 音效）。30 天留存所必需。
2. **里程碑 Toast** — sub-stat 首次达到 10 / 25 / 50 / 75 / 100 时显示明确 toast（不需要完整的成就画廊）。
3. **每日连续计数器** — 在 character sheet 顶部显示：连续开启天数。
4. **Quest 完成动画** — quest 卡片消散 + XP 滚动。不是打勾。

## 4. 定位

### NeonSaga 是
- 多 sub-stat **RPG character sheet** — 带 RPG 框架的个性化生活统计仪表盘
- **跨域推理引擎** — 一条日志条目自动更新多个 stats（核心差异化优势）
- **每月用户驱动的 quest 系统** — 主 quest + 支线 quest，AI 作为平衡执行者
- **Cyberpunk 2077** 视觉风格 + **英语优先** UI

### NeonSaga 不是（定位反转，2026-05-22 锁定）
- ❌ 数据仪表盘（不是 Apple Health / 财务应用 / Habitica 的克隆）
- ❌ 拟人化 AI 人格（命名助手、"先生，……"、第一人称口吻、跨 session 记忆、用户画像构建）
- ❌ 强制性生活教练（第二人称命令式口吻 ——"你必须练 X / 吃 Y / Z 点前睡"）。保留玩家自主的"建议式条件句"被允许（例如，"若 STRENGTH quest 活跃，今日适合做"）
- ❌ 社交 / 排行榜 / 多人 PvP（单人游戏）

### 差异化

| 竞争对手 | 他们做什么 | NeonSaga 如何不同 |
|---|---|---|
| **Apple Health** | 被动数据展示；跨来源聚合，无叙事 | 数据 → RPG stat → 活跃 quest；不重建 Apple Health 可视化 |
| **Habitica** | 手动待办 + RPG 皮肤；自我汇报完成情况 | 自动感知 + 跨域推理取代手动打卡；Habitica 需要自律才能记录，NeonSaga 数据自动到达 |
| **Whoop** | 仅健康（恢复/负荷）；订阅 + 教练语气 | 多域（HEALTH/WEALTH/GROWTH）+ 玩家自主（不是教练） |
| **Notion + 生活模板** | 通用 DB；用户必须自建系统 | 开箱即用设置 + 多模态 AI + iOS 原生 |
| **Cal AI** | 照片 → 营养；单一用途工具 | 照片营养是 NeonSaga 中的一个 AI 切入点，不是产品本身；直接反馈到 stat 链条 |
| **Looki L1** | 多模态可穿戴硬件 + 自动 vlog | 不需要新硬件；vlog/回顾推迟到 2.0+ |

## 5. 核心原则

1. **单应用 AI 集成** — AI 客户端在 iOS 应用进程内运行，并能看到跨所有域的原始数据。这是跨域推理的前提条件。与原则 7 不冲突。
2. **跨域推理是核心优势** — 一条餐饮消费记录 → 四个 sub-stats 更新。这是 NeonSaga 区别于所有竞争对手的地方。
3. **玩家自主 > AI 主动** — quest 由用户接受（AI 执行平衡）；AI 不分配任务。
4. **RPG 机制，Apple 工艺** — 视觉风格为完整 Cyberpunk；工程为 iOS 原生 SwiftUI + SwiftData，达到 Apple 质量标准。
5. **英语优先 UI** — 系统语言英语，新加坡地区，附带英语练习。
6. **Compute full, UI compressed** — AI 摄入完整快照；UI 界面是 character sheet + 一屏 quest 日志。NeonSagaCore/NeonSaga 拆分 + HealthDataSource/AIProvider 协议见 `docs/TOOLCHAIN.md`（待添加）/ `CLAUDE.md`。
7. **本地优先，明确云边界** — SwiftData 是唯一的真相来源，完全在设备上。云仅在两种情况下看到数据：
   - **(a) 多模态图像** — 食物照片直接作为单张原始图像发送到 Claude/OpenAI 视觉端点；不缓存，不批处理，不构建用户图谱。
   - **(b) 文本推理快照** — 仅当前调用所需的派生特征快照（例如，"过去 7 天 STRENGTH stat = [...]，活跃 quests = [...]"）；绝不是原始交易列表或原始 HealthKit 样本。
   - **绝不**：原始交易历史 / 原始 HK 样本流 / 用户身份 / 长期用户档案。
8. **无需用户教育** — 单人游戏应用；无引导文案。

## 6. MVP 范围：3 根支柱

### 1. RPG character sheet（多 sub-stat）

| Stat 组 | 顶层 0–100 | Sub-stats |
|---|---|---|
| **HEALTH** | avg(HUNGER, FATIGUE, STRENGTH) | HUNGER / FATIGUE / STRENGTH — 各自 0–100，各有独立 LV |
| **WEALTH** | 见 §7 公式 | 无 sub-stats — 单一来源来自 `Transaction` 聚合器 |
| **GROWTH** | avg(INTELLECT, COMPANIONSHIP, TRAVEL) | INTELLECT / COMPANIONSHIP / TRAVEL — 可扩展技能树形状 |

### 2. 跨域推理引擎

一条日志条目 → AI 提取字段 + 用户填写少量内容 → N 个 stats 更新。规则表（可扩展）：

| 触发器 | 上线版本 | 用户提供 | 自动提取 | 涉及的 stats |
|---|---|---|---|---|
| 餐饮消费（无照片） | v0.3 | 用餐人数 | 地点 / 时间 / 金额 / 商家 | WEALTH−X · COMPANIONSHIP+X（如人数 > 1）· TRAVEL+1（如不在家） |
| 餐饮消费 + 食物照片 | v0.3 | 用餐人数 | 同上 + 多模态 AI 提取食物条目 / 份量 / 营养 | WEALTH−X · HUNGER+X（按营养）· COMPANIONSHIP+X · TRAVEL+1 |
| 健身房会员购买 | v0.3 | — | 商家 / 金额 | WEALTH−X · 建议"STRENGTH 每月 quest"（用户必须接受） |
| Apple Watch 锻炼 (*) | v0.1（stats）/ v0.2（quest 进度） | — | 类型 / 时长 / 心率 / 卡路里 | STRENGTH+X（v0.1 via `HealthSnapshot`）· 活跃 STRENGTH quest 进度（v0.2 via Stage 2 Quest 层）—— 锻炼**不**喂 FATIGUE;FATIGUE 由 HRV 驱动（§9，ADR-002） |
| 航班 | v0.3 | 同行人数 | 出发地 / 目的地（自动地理编码；按 `ROADMAP.md` §4 L2 Stage 3 Plan B 回退为手动输入）/ 金额 | WEALTH−X · TRAVEL+地图解锁 · COMPANIONSHIP+X |
| 阅读 / OJ / 论文日志 | v1.1 | 标题 / 时长 | （未来 AI 分类） | INTELLECT+X |
| Apple Maps 重要地点 | **v1.0 public** | — | 城市 / 国家 / 频率 | TRAVEL+1（新城市）· 新地图节点 — iOS CLLocation 访问监控 |

**(\*) HKWorkout 路由说明**：Apple Watch 锻炼通过 `HealthSnapshot`（Stage 1）流转，**不**经过此跨域推理引擎 — 避免与引擎的 `InferenceLog` 重复计数。表中列出仅为逻辑 sub-stat → 触发器映射的完整性。详见 `ROADMAP.md` §4 跨域接线说明。

**每版本计数**：v0.3 ship **4 个引擎触发器**（餐饮无照 / 餐饮带照 / 健身房 / 航班）。v1.0 public 增加**第 5 个**（Apple Maps 重要地点 auto-TRAVEL+1）。v1.1 候选加入阅读 / OJ / 论文日志。Apple Watch 锻炼不计入"5+ 规则" public-v1.0 promise，因为它不经过引擎。

引擎是声明式且由表驱动的。当没有规则匹配时，引擎返回空的无信号结果（不是 nil — `InferenceResult` 是非可选的，因此调用者仍可记录处理输入的 `ruleVersion`）。不匹配时不调用 AI。未来的 AI 回退使用已就位的 prompt-schema / budget / cache 管道，一旦规则集稳定就会注入。每次规则扩展都需要单元测试。规则有版本控制。

### 3. Quest 系统

- **每月节奏**：Quest Design Day 在每月 1 日 — 用户 + AI 共同设计当月的主 quest 和支线 quest。
- **主 quests**：长期目标（例如，"今年发表一篇论文"），分解为每月步骤。
- **支线 quests**：每月目标（例如，"读一本书"，"跑 8 次"）。
- **AI 角色**：平衡执行者 — 防止用户仅选择偏好的域（旅行/游戏），强制 sub-stat 覆盖。
- **进度追踪**：自动（通过相同跨域推理的数据触发）+ 手动打勾。
- **奖励**：完成 = stat XP 获取 + 解锁 quest 链中的下一个节点。

## 7. 计算字段与公式

| 字段 | 公式 | 注意 |
|---|---|---|
| **每 sub-stat LV** | `LV = floor((current_value / 100) × 99) + 1` → 范围 LV 1–100 | current_value 可超过 100；LV 上限为 100 |
| **每顶层 stat LV** | `LV = floor(贡献 sub-stat LV 的平均值)` | WEALTH 无 sub-stats → 直接使用 WEALTH 0–100 → LV |
| **Total LV** | `LV = floor(avg(HEALTH_LV, WEALTH_LV, GROWTH_LV))` | v1 等权重 |
| **WEALTH 0–100** | `clamp((rolling_30d_net / monthly_target) × 50 + 50, 0, 100)` | `rolling_30d_net = sum(Transaction.amountCents) / 100` — `amountCents` 符号：正数 = 收入，负数 = 支出；除以 100 将分 → 人民币后计算比率。`monthly_target` 是 Settings 中设置的正整数人民币；如果为 nil 或零，WEALTH 默认回退值 = 50。 |
| **CLASS** | 前 2 个 sub-stat-LV 对 → 查找表（例如，STRENGTH+FATIGUE → "Athlete"；INTELLECT+TRAVEL → "Explorer-Scholar"；INTELLECT+COMPANIONSHIP → "Mentor"） | 使用 SubStat 枚举原始名称；自动确定，不由用户选择；变化时显示 toast |
| **ALIGNMENT** | v1 静态 = "Neutral"（残留 RPG 风味，无功能） | 未来行为推理的占位符 |
| **DAY** | 自首次记录 stat 以来的天数（非安装日期） | 显示"我已坚持 X 天" |
| **CREDITS** | 累计 `Quest.status == .completed` 数量 × 100 + 奖励（待定） | 装饰性 RPG 货币；消费机制推迟（见开放问题） |
| **EXPERIENCE bar** | `fraction = total_LV_continuous − floor(total_LV_continuous)`，其中 `total_LV_continuous = avg(HEALTH_LV, WEALTH_LV, GROWTH_LV)`（不取整） | 进度条显示在 total LV 旁 |

## 8. AI 集成角色

| AI 角色 | 触发器 | 输入 | 输出 |
|---|---|---|---|
| 跨域推理 | 任意日志提交 | 日志条目 + 用户提供的字段 | Stat 增量列表 |
| 多模态营养视觉 | 食物照片拍摄 | 照片 | 食物条目 / 份量 / 营养分解 |
| Quest 平衡执行者 | Quest Design Day | 用户草稿 + 过去 30 天的 stats | 调整建议 + 平衡警告（**不是**强制性任务分配 — 见 §4 不是教练规则） |
| Time-aware brief | 每日 AM/PM 窗口 | 前一晚恢复情况 + 今日活跃 quests，或当日 deltas + 已完成/闲置 contracts | Morning Brief 或 Evening Recap 行 |
| Oracle Q&A | 用户打开 Oracle / 提问一轮 | 锁定快照（跨域）+ 当前问题 | butler-tone 叙事化回答（第三人称客观 或 建议式条件句口吻），并引用快照字段。无人格，无跨快照记忆，无命令式。见 ADR-001 + Stage 4 Oracle CONTRACT。 |

## 9. Sub-stat 数据来源

| Sub-stat | 来源 | 模式 |
|---|---|---|
| HUNGER | 照片 → 应用内 AI 营养提取 | 半手动（用户拍照）+ AI |
| FATIGUE | Apple Health 的 HRV（HKHealthDataSource） | 全自动 |
| STRENGTH | Apple Watch 锻炼类型（HKWorkout） | 全自动 |
| INTELLECT | 阅读 / OJ / 论文日志 | 手动日志（未来 AI 分类） |
| COMPANIONSHIP | 消费反向推理 + 用户提供的用餐人数 | 跨域推理 |
| TRAVEL | iOS CLLocationManager + Significant Location Change + Visit Monitoring | 全自动（后台）；需要 `NSLocationAlwaysAndWhenInUseUsageDescription` |
| WEALTH | Transaction 模型 | 手动 |

> **Sub-stat 动态（ADR-002）。** HEALTH sub-stat 值是**累积的**（EWMA + 时间感知缓慢衰减），非每个 snapshot 的瞬时读数 —— STRENGTH 随持续训练上升、休息日缓降,FATIGUE 是缓慢的 HRV-恢复趋势（与每日的 Recovery 英雄分相区分）。这是上表来源**如何**映射到所存 stat,不改变来源本身。

## 10. First-eye view 与视觉方向

**first-eye view**：启动默认屏幕是 `Core`：压缩后的 RPG character sheet，用来回答"今天我要去挑战什么 -> 我的 character 准备好了吗？" 这不是漫画，不是统计仪表盘，也不是聊天框。

**标签页 IA**：五个标签页 — CORE / INGEST / ORACLE / CONTRACTS / ARCHIVE。
- **CORE**：已打磨的 first-eye character sheet — LV/EXP header、domain LV meta strip、0-100 stat bars + 趋势、Morning Brief、Active Contracts 预览和 CONFIG gear。
- **INGEST**：手动和感知数据输入界面。Stage 3 ship LOG MEAL / LOG TRANSACTION / LOG ACTIVITY（见 `ROADMAP.md` §4）。
- **ORACLE**：同快照多轮 Q&A 界面 + butler-tone 叙事。无人格 / 无跨快照记忆 / 无强制性生活口吻。Stage 4 ship（见 `ROADMAP.md` §5 和 ADR-001 的警戒线）。
- **CONTRACTS**：quest/mission 系统，包括 active/completed contracts 与 Quest Design Day。Stage 4 redesign 为与 CORE 对齐的 Cyberpunk HUD。
- **ARCHIVE**：历史 journal 和事件 timeline + 未来事件视图。Stage 2 从被动过去时间线扩展。

**视觉风格（Locked 2026-05-22）**：
- 黑色背景 + 霓虹青色 / 品红色 / 黄色点缀
- HUD 框架 + 机甲面板 + 半透明 holographic 层
- SF Mono 主字体；Cyberpunk 友好替代：Orbitron / Rajdhani
- 升级时的细微 glitch 艺术效果

**Avatar 方向**：Cyberpunk 插画 character 半身像（半身，不是 Memoji / 不是油画）。Stage 1 ship 打包的插画 bust 资产并保留程序化 fallback。未来 tier/class avatar 演进推迟。

**语言**：纯英语 UI。

**当前视觉参考**：TBD — Stage 1 交付物。

## 11. MVP 1.0 范围外

推迟到 2.0+：

- 每日漫画回顾（AI 图像生成 vlog）
- 世界地图（路径可视化）
- 背包（装备 / 消耗品 / 药水系统）
- 成就画廊（徽章 / 事件 / 里程碑系统）
- Avatar 自定义深度（性别 / 服装 / 武器 / 种族选择）
- 升级音效自定义
- 多设备可穿戴设备（Whoop / Oura / Looki L1；HealthDataSource 协议已实现，但无硬件适配器）
- 社交感知层（家庭 / 朋友标记和互动）
- BOSS 机制作为独立系统（MVP：boss = 增强版 quest）

完整 anti-goal 列表见 `ROADMAP.md` §7（含 Stage 4 特定的可砍项，本 PRODUCT 不需重复列出）。

---

## 开放问题

已搁置的决策，不阻塞 MVP 范围锁定：

- **Quest 链结构** — 线性 / 分支 / 主 + 支线依赖图？在 Quest Design Day 实现时决定。
- **CLASS 映射完整性** — 哪些前 2 个 sub-stat-LV 对映射到哪个 class 名称的完整表。v1 映射表是占位符；完整表是后续交付物。
- **跨设备同步** — CloudKit 切换时机。受阻于付费 Apple Developer 账户准备情况（当前账户是免费 Personal Team；自定义 CloudKit 容器配置在此不可靠）。
- **CREDITS 消费** — 背包商店是否真的会建成？取决于背包里程碑。CREDITS 现在累积；消费机制推迟。

## 来源与历史

- NeonSaga PRODUCT.zh.md v1 于 2026-05-27 发布。
- 视觉参考：TBD（Stage 1 交付物）。
- UI 规格：在 `docs/ui/` 下 Stage 1+ ship 时落地。

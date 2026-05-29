# NeonSaga — 4-Stage Roadmap（中文版,locked,2026-05-27）

> 🌐 **Languages**: 中文（当前文件,便于 owner review）· [English ROADMAP.md](ROADMAP.md)
>
> **EN 版是 roadmap 的 source of truth。** 本中文版用于 owner self-review,
> 应与 EN 同步更新;翻译歧义以 EN 为准。

> **Status:** 经 7 轮 Codex review 后锁定(详见 §9 changelog)。Living document
> in `docs/ROADMAP.md`(EN source-of-truth);本文件为 ZH mirror。
> **权威:** ROADMAP 定义 stage 范围和顺序。PRODUCT.md 定义产品身份。
> CONTRACT.md(工作树内)定义每个 slice 的精确实现。
> 规格层级见 `CLAUDE.md` §1.8。

---

## 0. 项目前提

NeonSaga 是一个为期 8 周的严格规范 build,目标是个人完整可用的
`v1.0-personal` iOS 版本。下面的 4-stage 节奏先 front-load HEALTH,
然后在 Stage 3 解锁跨域 killer-edge,然后在 Stage 4 把剩余 placeholder
关掉,合成一个完整 5-tab 产品。

`CLAUDE.md` §1 中的严格规范是为了让 autonomous-agent 执行保持一致 ——
摩擦是有意为之。每个 stage 都以 iPhone dev-build 装机 + git tag 收尾;
如果 owner 不能在真实设备上使用该 build,该 stage 不算关闭。

---

## 1. 版本号与里程碑

| 版本 | Stage 后 | 形态 | 价值承诺 | 显式非承诺 |
|---|---|---|---|---|
| v0.1 | Stage 1 | owner iPhone 上的 Xcode dev build | HEALTH detail 主观上对标 Whoop/Oura;AI Recovery brief 解释今日数字;HEALTH sub-stat 越过阈值触发 Level-up 全屏接管 | 跨域推理不可见;WEALTH/GROWTH 无 real 界面;Archive 未变 |
| v0.2 | Stage 2 | owner iPhone 上的 Xcode dev build | Archive 呈现过去 + 未来 timeline;Quest Design Day 流程端到端可跑通;quest 完成仪式动画播放 | 仍无跨域验证;INGEST/ORACLE/WEALTH 占位仍在 |
| v0.3 | Stage 3 | owner iPhone 上的 Xcode dev build | 杀手边可见——一条 Transaction log → 多个 stats 触发(含 meal-photo → HUNGER 多模态 AI);WEALTH detail real;Ingest tab 可用 | 只 wire 4 个推理 trigger(meal-no-photo / meal-with-photo / gym / flight);reading/location trigger 推迟;Oracle/Contracts redesign 推迟 |
| **v1.0-personal** | Stage 4 | TestFlight build(若 Apple Developer 就绪)否则 dev build | 5 个 tab 全 real(Oracle 以同快照多轮 Q&A + butler-tone 叙事 ship,见 ADR-001);Contracts 视觉对齐;多巴胺循环接通(quest 完成仪式 + Level-up 全屏接管 + 里程碑 toast);GROWTH detail | 还不是 **public** `v1.0` —— 跨域规则仍 ≤4;没有一周日常使用验证 |
| v1.0(public) | Stage 4 后的打磨 | TestFlight | ≥5 条跨域规则集(v0.3 的 4 个引擎 trigger + Apple Maps Significant Location auto-TRAVEL+1 作为第 5 个,在 Stage 4 后加入);owner 已把 NeonSaga 作为日常 app 使用 ≥7 天,未回到其他追踪器 | — |

**硬规则:** 每个 stage 退出要求 owner 在真实 iPhone 上装该版本,并使用对应时长:
- Stage 1(v0.1):≥1 天
- Stage 2(v0.2):≥1 天
- Stage 3(v0.3):≥3 天(killer-edge dwell 测试)
- Stage 4(v1.0-personal):≥1 天,必须跑通 5-tab happy-path smoke flow
  (CORE → INGEST log → ORACLE 问 → CONTRACTS 查 → ARCHIVE scrub)
- v1.0(public):≥7 天日常使用

如 dev build 在 iPhone 上跑不起来,该 stage 不算关闭,git tag 也不打。

周粒度日期与关键 DDL 见 `docs/SCHEDULE.md`。

---

## 2. Stage 1 — HEALTH 对标 Whoop/Oura + AI(3 周硬截止,目标 ~2026-06-17)

**目标:** HEALTH detail 页主观上对标 Whoop/Oura,AI Recovery brief 解释当日数字。
HEALTH 任一 sub-stat 越过 LV 阈值时 Level-up 全屏接管触发。

**时间框架:** 3 周是**硬截止**,不是固定 scope 保证。
若 Day 18 仍有装机阻塞核心受险,从下面 Plan B 列表底部砍 ——
**不要**滑期。

### 已承诺范围(按 load-bearing 顺序)

1. **可装机的 HEALTH detail 界面** —— Cyberpunk HUD 卡片栈(3–4 张)。
   *不可砍。*
2. **Recovery score** —— HRV(rMSSD)在 28 天滚动窗口上 baseline-normalized,
   与 resting HR 和 sleep efficiency 混合。输出:0–100 + 3 段分类
   (RED / YELLOW / GREEN)。*不可砍。*
3. **Level-up 全屏接管** —— 任何 HEALTH sub-stat(HUNGER / FATIGUE / STRENGTH)
   的阈值越过检测;全屏 0.8s 动画 + 触觉反馈。*不可砍* —— 这是阈值反馈回路。
4. **Strain score** —— HR-zone × time 积分;0–21 Whoop 约定标尺。
5. **Sleep 结构** —— Deep / REM / Light 分钟数、time-in-bed vs asleep、wake events 次数;
   来自 HealthKit sleep samples。
6. **AI Recovery brief** —— Claude 调用(app 打开时;当日缓存);输出 ~300 tokens,
   用 2–3 句解释"为什么今天 Recovery 是 X"。
7. **视觉主观对齐** —— 最后的视觉打磨,对齐 Whoop/Oura 感觉(字体、间距、动效)。
8. **每日连续计数器(PRODUCT §3.3 多巴胺钩子)** —— 显示在 CORE first-eye
   header。通过 daily presence model + scene-active 时的 presence recorder
   service + streak source service,追踪连续 app-open 天数。
9. **HealthSnapshot service(Stage 3 跨域前置)** —— 把 HealthKit 数据
   (HRV、HR、sleep、workouts)桥接到 HEALTH sub-stats:**HRV → FATIGUE / Recovery;
   HKWorkout → STRENGTH;sleep → 仅 Recovery**(FATIGUE 仅由 HRV 驱动,
   按 PRODUCT §9 —— workout/sleep 不喂 FATIGUE;ADR-002)。HEALTH sub-stat 值
   是**累积的(EWMA,时间感知缓慢衰减),非每个 snapshot 瞬时值** —— 累积模型
   (slice **S6b**)在 **Level-up 全屏接管(项 3)之前**落地,使 LV 跨越有意义、
   而非每日 0↔100 抖动(ADR-002)。**Stage 3 的跨域
   引擎刻意绕过 `HealthSnapshot`(避免通过 `InferenceLog` 双重计数)** ——
   见 §4 跨域 wire 澄清。Recovery(项 2)和 Strain(项 4)都消费 `HealthSnapshot`;
   `NeonSagaCoreTests/main.swift` 中的测试验证 `HealthSnapshot.derive(...)` 映射。

### Plan B 砍单顺序(如 Day 18 进度受险)

从底部砍:
- L4:Level-up 全屏接管的音效精修(保留占位)
- L3:wake events + time-in-bed 精度(仅保留 Deep/REM/Light)
- L2:精确的 HR-zone strain 数学(保留简单的 HR×duration 近似)
- L1:AI brief 文案调优(用模板短语 ship,推迟 LLM 调优)
- **永不砍:** 可装机的 HEALTH detail 界面、Recovery 0–100、Level-up 全屏接管
  阈值触发、**每日连续计数器(PRODUCT §3.3 多巴胺钩子)**、**HealthSnapshot
  wire(Stage 3 前置 —— Recovery 和 Strain 已依赖)**。这五项是 v0.1 的存在理由。

### Killer-edge spike(条件性、off-main、debug-only)

1 天的 spike,在 Stage 3 承诺 user-visible 之前端到端验证跨域推理。
严格警戒线:

- **Day-13 go/no-go gate(2026-06-10)** —— Stage 1 Day 13 时,lead review
  **全部 5 项"永不砍"项**(可装机 HEALTH detail + Recovery + Level-up
  全屏接管 + 每日连续计数器 + HealthSnapshot wire)是否能在 **Stage 1 deadline
  (2026-06-17,Day 20 —— SCHEDULE.md 拥有此日期权威)** 前到位。
  如 5 项中任一受险 → 跳过 spike;验证移到 Stage 3 Day 0。
  如 5 项全部 on track → Day 14(2026-06-11)跑 spike。
- **Off-main 工作树** —— spike 代码在独立 worktree,不在通往 v0.1 的 feature branch。
- **Debug-only 入口** —— 不动 production UI 界面。
- **1 天硬停** —— Day 14 EOD(2026-06-11)前,把 spike 输出(无论成功失败)
  写入 `docs/spikes/stage-1-killer-edge-spike.md`(已 commit,持久 ——
  CONTRACT.md 是工作树本地的,清理时会丢失工件),然后删 spike 代码。
  不延期。
- **示例形态**:健身房会员购买 → STRENGTH+5 + monthly-quest 建议
  (3 行规则代码 + 1 个 debug 按钮)。单条规则,无 UI。

### 范围外(Stage 1)

- WEALTH 和 GROWTH detail 真页面(占位保留)。
- Production 级跨域推理 wire(Stage 3)。
- Archive 增强(Stage 2)。
- Contracts 重设计(Stage 4)。

### 退出准则(usage 先于 tag)

- `make test-core` 绿;`make test` 绿;**`make verify-full` clean**
  (commit 中报告数字,per `CLAUDE.md` §1.9 验证矩阵)。
- HEALTH detail 截图 side-by-side Whoop/Oura → owner 主观通过。
- 如 spike 跑了,输出捕获在 `docs/spikes/stage-1-killer-edge-spike.md`
  (或 Day 13 gate 跳过则记"spike-skipped, deferred to Stage 3 Day 0")。
- **每日连续计数器**在 CORE header 可见;在模拟日期边界上 app open 时递增
  (通过 debug time-warp 或 iPhone 装机使用窗口内的真实日切换验证)。
- **HealthSnapshot wire** 测试绿;owner iPhone 使用窗口内,sub-stat 值
  从真实 HealthKit samples 派生(HRV → FATIGUE,HKWorkout → STRENGTH 可见)。
- Owner 在 iPhone 装;使用 ≥1 天;汇报。
- Owner 确认使用顺利后,**才**打 `v0.1` git tag。

### 风险

- 前 28 天 HRV baseline 数学不稳定。缓解:HRV samples <14 天时显示 "Calibrating" banner。
- AI brief token 预算 —— 通过 `AIBudget` pattern 限制每天 1 调用。
- 主观对齐不可测量 —— 以 owner 判断为最终。

---

## 3. Stage 2 — ARCHIVE + 事件计划(1.5 周硬截止,目标 ~2026-06-28)

**目标:** Archive 从被动过去 timeline 扩展为统一的过去 / 今天 / 未来视图。
Quest Design Day 流程端到端可跑通。**Quest 完成仪式 ship**。

### 已承诺范围

1. **Archive 三段滚动** —— 过去 / 今天 / 未来,带 scrubber 和 filter
   (日期 scrub + 域 filter chip)。
2. **未来段内容** —— 活跃 Quest 截止日;Quest Design Day(每月 1 号);
   user-confirmed 日程事件。
3. **Quest Design Day 流程** —— 每月 1 号 app 打开触发。AI 从过去一月 stat
   趋势给主 quest + 支线 quest 建议 → user 挑选 / 编辑 → 保存。
   使用 Quest balance enforcer service(建议,不分配)。
4. **Quest 完成仪式** —— 任何 quest 的 status 翻成 `.completed` 时
   (手动 check-off 或 threshold 触发),dissolve + XP scroll 动画触发
   (per PRODUCT §3.4 多巴胺钩子)。
5. **Archive ↔ Detail 跳转** —— 未来 Quest → Quest 编辑器;过去 brief
   → brief detail。

### 范围外(Stage 2)

- 用户自定义自由日历事件(v1.x)。
- Contracts 视觉重设计(Stage 4)。
- 跨域推理 wire(Stage 3)。

### 退出准则(usage 先于 tag)

- 全部测试绿;**`make verify-full` clean**(per `CLAUDE.md` §1.4 + §1.9)。
- Archive 在 "30 天前" 和 "30 天后" 之间流畅滚动。
- Owner 在 iPhone 上通过 debug-menu 强制入口完整跑通 Quest Design Day 流程。
- Owner 至少看到一次 quest 完成仪式端到端触发(debug 菜单手动 check-off 即可)。
- Owner 使用 ≥1 天 iPhone。
- Owner 确认使用顺利后,**才**打 `v0.2` git tag。

### 风险

- "未来"段对新用户偏稀疏(只有 Quest 截止日 + Design Day)。
  个人使用可接受;v1.0 时重新评估。
- Quest Design Day AI 建议可能漂移成"教练"口吻 —— 保持"建议"基调,
  不是 assignment(PRODUCT §5.3 玩家自主)。

---

## 4. Stage 3 — INGEST + 记账(跨域杀手边可见)(2 周硬截止,目标 ~2026-07-12)

**目标:** Ingest tab 作为统一数据输入界面 ship。Transaction 模型 + 记账 UI。
WEALTH detail real。跨域推理 v1(**4 个 trigger**,含 meal-photo 多模态 AI flow)
可见触发 —— **这是杀手边的验证 stage**。

### 已承诺范围

1. **Transaction `@Model`** —— `amountCents`, `merchant`, `category`, `date`,
   optional `partySize`, optional `location`。符号:正数 = 收入。
2. **Ingest tab** —— 三个主要入口:LOG MEAL, LOG TRANSACTION, LOG ACTIVITY。
3. **LOG TRANSACTION sheet** —— 手工:金额 / 商家 / 类别 / 用餐人数 / 日期。
   位置从 `CLLocationManager` 自动填充。
4. **LOG MEAL sheet** —— 照片 + 金额 + 用餐人数;走 meal vision 管道。
5. **WEALTH detail view** —— 30 天滚动净值、月目标进度、最近交易(最新优先,
   无限滚动)。
6. **跨域推理 v1(4 个 trigger,wire 且 user-visible):**
   - **餐饮消费(无照片)**:WEALTH−X · COMPANIONSHIP+X(人数 >1)· TRAVEL+1(远离家时)
   - **餐饮消费 + 食物照片(多模态 AI 杀手 demo)**:WEALTH−X · HUNGER+X(按 AI 提取的营养)· COMPANIONSHIP+X · TRAVEL+1
   - **健身房会员购买**:WEALTH−X · 提示"接受 STRENGTH 月度 quest"
   - **航班**:WEALTH−X · TRAVEL+地图解锁 · COMPANIONSHIP+X(同行者)
   - 规则在 `NeonSagaCore` 中表驱动。
7. **InferenceLog 可见性** —— 每次触发在 Archive 过去段产生一行,
   可点开看推理解释 sheet。

### Plan B 砍单顺序(Stage 3 时间线受险时)

所有 4 个跨域 trigger 本身**不可砍**(v0.3 承诺 4 个 trigger 可见触发)。
Plan B **降级**(不是砍)以下项目,如时间线受险:

- L2:航班 trigger 的**自动地理编码(origin/destination)**→ 降级为手动
  城市/国家输入(user 手输代替 `CLLocationManager` 反向地理编码),
  如位置 plumbing 拖到 Stage 3 Day 12。**航班 trigger 仍然触发;
  WEALTH−X · TRAVEL+地图解锁 · COMPANIONSHIP+X 都仍生效;只有城市/国家
  自动提取被手动输入替代。** `PRODUCT.md` §6.2 航班行明确注明这个 Plan B
  fallback。
- L1:健身房会员 trigger 的 quest-suggestion **模态弹窗样式**→ 降级为
  被动 banner + Archive InferenceLog 行"STRENGTH quest 已建议 — 见
  CONTRACTS",如弹窗 UX 打磨拖过 Stage 3 Day 10。**规则仍触发;quest 仍
  通过 Stage 2 的 Quest model 创建;只有模态打断式 UX 降级**(永不砍 v0.3
  4-trigger promise)。
- L0:InferenceLog 解释 sheet **富布局**→ 降级为更简单的 sheet,仍显示
  规则名 + stat 差量 + "为什么"文字 + (对 meal-photo)AI 提取的食物条目列表,
  如富 sheet 视觉打磨拖过 Stage 3 Day 11。**只有照片缩略图渲染 / 多 pane
  媒体样式 / 花式过渡可推到 v1.1;解释数据本身在 v0.3 保持可见**
  (永不砍 v0.3 "InferenceLog 可见 + 可点"承诺)。

**永不砍:** 全部 4 个跨域 trigger wire 到 InferenceLog(触发本身保留 ——
只有 follow-on UX 可能降级)、Transaction model、LOG TRANSACTION sheet、
WEALTH detail real、**meal-photo → HUNGER trigger**(杀手多模态 AI demo;
v0.3 价值承诺 + 退出准则依赖它)。

### 跨域 wire 澄清

- **HKWorkout → STRENGTH 更新走 `HealthSnapshot`,不是 `InferenceLog`。**
  这是硬不变式(避免双重计数)。Stage 1 已 wire。
  Stage 3 **不**让 HKWorkout 走跨域规则引擎。(FATIGUE 由 HRV 驱动,
  非 workout 驱动 —— ADR-002。)
- **HKWorkout → 活跃 STRENGTH quest 进度** wire 在 Stage 2 的 quest 层
  (不在 Stage 3 的跨域引擎)。

### 范围外(Stage 3)

- 未匹配规则的 AI fallback(规则路径必须先稳定)。
- HKWorkout-routed 推理(上文不变式)。
- 阅读 / OJ / 论文 log(INTELLECT trigger;v1.x)。
- 位置 significant-change 自动 trigger(Stage 4 后 → **v1.0 public
  第 5 条跨域规则**);TRAVEL+1 在 v0.3 → v1.0-personal 期间仍通过
  LOG TRANSACTION + LOG MEAL 位置字段手动触发。

### 退出准则(usage 先于 tag)

- 全部测试绿;**`make verify-full` clean**(per `CLAUDE.md` §1.4 + §1.9)。
- Owner 在 iPhone 上真实记一笔 party=2 餐费 → WEALTH 和 COMPANIONSHIP
  都实时更新;Archive 显示 InferenceLog 行。
- Owner 通过 LOG MEAL 拍一张真实食物照片 → HUNGER 从 AI 营养提取更新;
  Archive 显示带 AI 提取食物条目的多模态 InferenceLog 行。
- WEALTH detail 显示真实数据。
- Owner 使用 ≥3 天 iPhone(killer-edge dwell 测试)。
- 在 ≥3 天 dwell 测试期间记录 p50 / p95 tokenized 快照大小(HEALTH + WEALTH + GROWTH + 活跃 quests + 近期 Archive InferenceLog)。这些测量锚定 Stage 4 Oracle 每快照预算上限(ADR-001)。**测量缺失的 fallback**(per Codex round 3 IMPORTANT #2 —— 主动 gate,非被动):Stage 4 Oracle CONTRACT 在以下**任一**条件满足前,不得 lead-approve:(a) lead 对代表性 Stage 3 快照跑 token-count dry-run,从该数据设定上限;或 (b) lead 设定一个刻意保守的临时上限(例如,3 轮 / 3000 输入 tokens),并配套一个 owner 显式批准的校准任务,排程在 Stage 4 实现的前 7 天内(带硬编码复查日期)。被动"等 owner 抱怨"被禁止 —— 成本边界必须在 Stage 4 Oracle 实现开始**之前**存在。
- Owner 确认 dwell 测试顺利后,**才**打 `v0.3` git tag。

### 风险

- **Load-bearing stage。** 如果"一条 log 触发多个 stat"感觉像噱头而不是魔法,
  产品失去 hook。缓解:坚持 InferenceExplanation 界面,让 user 总能看到每个
  stat 为什么动。
- Vision API 集成(meal-photo)是复杂度最高的项。缓解:通过 Stage 1 Day-14
  killer-edge spike 验证(如跑了;per §2);若 vision API 在 production 不可靠,
  ship 时同时给 photo input 提供手工营养输入 fallback,但 meal-photo trigger
  本身永不砍。

---

## 5. Stage 4 — v1.0-personal(1.5 周硬截止,目标 ~2026-07-22)

**目标:** 关闭所有 5-tab 占位。锁定多巴胺循环。如果可能 ship TestFlight。
Owner 看到一个**完整的个人用产品**。

**命名:** 这是 `v1.0-personal`,不是 `v1.0-alpha` 也不是 `v1.0`。
"Personal" 承认:5 个 tab 都 real,多巴胺循环接通,owner 可作为日常 app 使用。
"还不是 public v1.0" 因为 (a) 引擎的跨域规则集只 wire 了 **4 个**
(第 5 个 —— Apple Maps Significant Location auto-TRAVEL+1 —— 在 Stage 4
后落地),且 (b) 7 天日常使用验证还没发生。

### 范围,按优先级(如需从底部砍)

1. **发布 / 装机稳定性** —— `make verify-full` 在干净 checkout 上绿;
   iPhone 装机可重现;reset/recover 路径可用。*不可砍。*
2. **Contracts 视觉重设计 + quest 完成仪式打磨** —— 与 CORE 对齐的
   Cyberpunk HUD。替换语义重命名的 quest tab。与 Stage 2 的 quest 完成
   overlay 配对,形成统一的 Contracts 体验。
3. **Oracle tab —— 同快照多轮 Q&A + butler-tone 叙事(见 ADR-001)。** *不可砍* —— `v1.0-personal` 不能带着 Oracle 占位关闭。
   - **打开时锁快照**:跨域 HEALTH + WEALTH + GROWTH + 活跃 quests + 近期 Archive InferenceLog 行。
   - **重锁触发**:Oracle tab 关闭 / app 后台 >30 分钟 / Oracle 前台空闲 >30 分钟 / 用户显式刷新。
   - **重锁 UX**:可见快照时间戳 chip;重锁时 transcript 分割 + 新隔离 context;前一快照的轮次**不**送回模型。
   - **口吻**:第三人称客观 或 建议式条件句。**不**第一人称,**不**第二人称命令式,**不**命名人格,**不**跨快照记忆。
   - **每快照预算上限**:锚定 Stage 3 经验样本快照(TBD,由 Stage 4 CONTRACT 设定,不在本 ROADMAP)。
   - **回答 contract**:用户用文本输入提问;每个 Oracle 回答必须引用其使用的具体快照字段(例如,"Recovery 62 [from HRV 32 ms · RHR 58 · sleep eff 89 %]")。引用数据不可砍 —— 无可追溯来源的回答被禁止。
   - **Archive 集成**:"Ask about <day>" 在点击时预填 Oracle。
4. **里程碑 toast** —— sub-stat 首次达到 10 / 25 / 50 / 75 / 100 时显示 toast
   (PRODUCT §3.2)。与 Stage 1 Level-up 全屏接管配对。
5. **GROWTH detail view** —— INTELLECT / COMPANIONSHIP / TRAVEL 三栏,
   与 HEALTH detail 形态平行。
6. **TestFlight build** —— 如 owner 有付费 Apple Developer 账户,推 v1.0-personal
   到 TestFlight;否则继续 dev build 装机。
7. **Demo 视频** —— 90 秒走查(post-feature artifact,不是 feature)。

### Stage 4 反漂移约束

- **Oracle 允许同快照多轮 Q&A(见 ADR-001)。** 禁止清单:Jarvis 人格、跨快照记忆、强制性生活命令式口吻。Stage 4 Oracle CONTRACT 必须包含 `docs/templates/CONTRACT.md` §AI prompt guardrails 的 prompt-guardrails checklist + lint 失败模式。
- **Contracts 重设计保留玩家自主** —— quest 由用户接受,不是分配;
  AI 是平衡执行者,不是教练(PRODUCT §5.3)。

### 范围外(Stage 4 → v1.x)

- 阅读 / 论文 log 推理 trigger(v1.1)。
- 位置自动 TRAVEL+1(Stage 4 后 → v1.0 public 第 5 条跨域规则)。
- 未匹配规则的 AI fallback(v1.1)。
- 世界地图 / 背包 / 成就画廊 / 每日漫画(v2.0+)。
- CloudKit 同步(受阻于付费 Apple Developer;v1.x)。
- Apple Health 以外的可穿戴(v2.0+)。

### 退出准则(usage 先于 tag)

- 全部测试绿;`make verify-full` 在干净 checkout 上 clean。
- Plan B:若 Oracle 多轮实现吃掉 >+3 天,Demo 视频可推到 v1.0-personal 之后。需要 owner 显式同意推延。
- Demo 视频已录制。
- 如 Apple Developer access 存在则 TestFlight build 可用;否则 dev build 在
  owner iPhone 上已验证。
- **Owner 装机并至少在真实使用中完成一次 5-tab happy-path smoke flow:**
  CORE → INGEST 记点东西 → ORACLE 问个问题 → CONTRACTS 看活跃 quest →
  ARCHIVE scrub 一个过去日。≥1 天使用。
- Owner 确认 5-tab smoke flow 顺利后,**才**打 `v1.0-personal` git tag。
- (public `v1.0`,Stage 4 后)Owner 把 NeonSaga 作日常 app 使用 ≥7 天,
  不回到其他追踪器;跨域规则达到 ≥5。

---

## 6. 严格规范(通过 `CLAUDE.md` 强制)

8 周交付期内不可妥协。本节镜像 `CLAUDE.md` §1 —— CLAUDE.md 是操作权威;
本节仅供叙述性 review。

### 6.1 Spec-first CONTRACT 闸口
见 `CLAUDE.md` §1.1。没经过 Codex 审 + lead 批准的 CONTRACT,worker subagent
不得写 production 代码。

### 6.2 TDD red + green 纪律(PR-level 强制,非 pre-commit ancestry hook)
见 `CLAUDE.md` §1.2。pre-commit ancestry hook 软化,以 `git log` 前缀 grep
在 PR review 时验证。

### 6.3 范围冻结 + ADR
见 `CLAUDE.md` §1.3。ROADMAP 之外的 feature 需要 ADR。

### 6.4 每 stage 退出仪式
见 `CLAUDE.md` §1.4。用 "tag the stage version" (而非具体 "v0.X")。

### 6.5 外部代码引入纪律 + Source references
见 `CLAUDE.md` §1.5。引入外部代码的每个 CONTRACT 在 CONTRACT 中声明 source
references —— 无孤儿 imports。

### 6.6 Autonomous agent 就绪度
见 `CLAUDE.md` §1.6。任务 done-criterion 走验证矩阵 §1.9,不用单一 `make verify`。

### 6.7 Wiring 完整性 —— 无孤立层
见 `CLAUDE.md` §1.7。Stage exit checklist 强制无死路、无 shipped 界面的占位、
所有 schemas + 测试注册都到位。

### 6.8 规格层级优先级
见 `CLAUDE.md` §1.8 authoritative 表。简短版:
**PRODUCT > ROADMAP > SCHEDULE(日期权威)> CONTRACT > UI docs**。
ADR(★ override)通过显式决策 + Codex review 覆盖以上任意。冲突需 ADR。

### 6.9 验证矩阵
见 `CLAUDE.md` §1.9。`test-core` / `test` / `verify-full` 矩阵替代
autonomous-agent done-claim 的单一 `make verify`。

---

## 7. 反目标(显式拒绝列表)

以下显式推到 v1.0-personal 之后,保持 8 周交付聚焦:

| 项 | 理由 | 最早目标 |
|---|---|---|
| 跨域推理完整(5+ 规则集) | Stage 3 ship 4;其余排队 | v1.0(public,Stage 4 后) |
| 跨设备同步(CloudKit) | 需付费 Apple Developer | 账户升级后 |
| 世界地图 / 背包 / 成就画廊 / 每日漫画 | MVP 外 per PRODUCT §11 | v2.0+ |
| Apple Health 外可穿戴(Whoop / Oura / Looki) | 协议存在,无集成 | v2.0+ |
| **Avatar 自定义深度**(性别 / 服装 / 武器 / 种族) | PRODUCT §11 | v2.0+ |
| **Level-up 音效自定义** | PRODUCT §11 | v2.0+ |
| **BOSS 作为独立系统** | MVP 把 boss 视为增强 quest | v2.0+ |
| **多人 / 排行榜 / PvP** | **BANNED** per PRODUCT §4 IS NOT(单人游戏) | 永不 |
| 社交感知层(家庭 / 朋友标记 —— 非多人) | 推迟,不 ban | v2.0+ |
| 用户引导 / 教程 | 单人,无教育 per PRODUCT §5.8 | 永不 |
| 阅读 / OJ / 论文 log 推理 | Stage 4 砍单候选 | v1.1 |
| 位置自动 TRAVEL+1 | Public-v1.0 的第 5 条跨域规则 | v1.0 public |
| AI 推理 fallback(未匹配规则) | 规则路径必须先稳定 | v1.1 |
| 拟人化 AI 人格(命名助手 / "先生,……" / 跨 session 记忆) | **BANNED** per PRODUCT §4 IS NOT | 永不 |
| 强制性生活命令式口吻("你今天必须 X") | **BANNED** per PRODUCT §4 IS NOT | 永不 |

---

## 8. Stage 到 PRODUCT.md 多巴胺钩子覆盖

验证 PRODUCT.md §3 的 4 个多巴胺钩子在 v1.0-personal 都落地:

| PRODUCT §3 钩子 | 落在 |
|---|---|
| Level-up 全屏接管(全屏 + 触觉 + 音效) | Stage 1 |
| 里程碑 toast(10/25/50/75/100) | Stage 4 |
| 每日连续计数器 | Stage 1(scope 项 8) |
| Quest 完成动画(dissolve + XP scroll) | Stage 2 |

4 个都在 8 周交付期内 ship。

---

## 9. Codex review 决策(changelog)

供追溯;非 load-bearing。

### v1 → v2(10 findings,全部应用)

- #1 Stage 价值/非价值框架 → §1 versioning 表加双栏。
- #2 Stage 1 deadline 框架 → §2 称 3 周为 deadline + Plan B 砍单顺序。
- #3 Killer-edge spike → §2 dev-only spike(v3 加约束)。
- #4 Stage 1 滑期风险 → §2 Plan B 砍单顺序成文,"永不砍" 列表。
- #5 Stage 4 优先级重排 → §5 重排(v3 再调)。
- #6 Source references 清单 → CONTRACT 模板 + §6.5。
- #7 Pre-commit hook 软化 → §6.2 PR-level。
- #8 Quest 完成动画 → §3 Stage 2 scope + §8 钩子。
- #9 反目标扩充 → §7 涵盖 avatar、音效、BOSS、多人 ban、Jarvis ban。
- #10 版本号改名 → 最终在 v3 改为 `v1.0-personal`。

### v2 → v3(10 findings,全部应用)

详见 EN 版 §9。要点:Stage 4 Oracle 移到 #3 + "无 chat" 警戒线 inlined;
spike 收紧到 Day-13 go/no-go gate + 1 天硬停;验证矩阵;规格层级;
wiring 完整性 checklist;quest 完成仪式移到 Stage 2;v1.0 保留给 Stage 4 后
public release。

### v3 → v3+15-fix(Codex review #3,15 findings,REJECT)

- BLOCKING #1 Day-13 日期改为 2026-06-10。
- BLOCKING #2 meal-photo → HUNGER 移到 "never cut"。
- BLOCKING #3 spike 输出目的地改到 `docs/spikes/`(已 commit)。
- IMPORTANT #4-13 与 NIT #14-15 全部应用。

### v3+15-fix → v4(Codex review #4,4 findings,REJECT)

- **BLOCKING #1** Stage 3 Plan B "degrade-not-cut" —— 4 个 trigger 永不砍,
  只降级 follow-on UX。Risk note 同步更新。
- **IMPORTANT #2** `CLAUDE.md` §1.7 句子澄清(NeonSaga-native 文件无需分类)。
- **IMPORTANT #3** `docs/ROADMAP.md` §6.8 规格层级与 `CLAUDE.md` §1.8 对齐
  (SCHEDULE rank 2.5 + ADR ★ override)。
- **NIT #4** `docs/legacy-disposition.md` "git tag v0.X" → "git tag <stage
  version>"。(该文件后续删除,严格规范简化 —— CLAUDE.md §1.7 wiring
  完整性 + CONTRACT 模板的 source references 覆盖了 legacy disposition
  追踪的范围。)

### v5 / v6 / v7(Codex reviews #5–#7,精炼合并)

三轮额外 review(分别 9 + 4 + 5 findings)精炼了:(a) Plan B "degrade-not-cut"
模式贯彻 Stage 3 全部 3 个 L-tier(L0/L1/L2 都是 presentation-only ——
rule + effect 总是触发);(b) v1.0 public 第 5 条跨域规则具体化 = Apple
Maps Significant Location auto-TRAVEL+1(Stage 4 后);(c) HealthSnapshot
service 作为显式 Stage 1 scope 项 9(Stage 3 跨域前置);(d) 每日连续计数器
提升为 Never cut + exit criteria;(e) System-capability 维度加入 wiring
完整性 checklist(HealthKit / camera / location / CloudKit + Info.plist
usage strings + permission flow 测试);(f) `make verify-full` 加入所有
stage exit criteria(原仅通过 §1.4 隐式);(g) Day-13 spike gate 检查全部
5 个 Never-cut 项(不是原 3 个);(h) PRODUCT Apple Watch 行拆分 = v0.1
stats via `HealthSnapshot` + v0.2 quest 进度 via Stage 2 Quest 层;(i)
PRODUCT Flight 行注明 Plan B 手动输入 fallback;(j) Day-21 → Day-20 日期
算术修正;(k) `§1.7b` 孤儿引用 → `§1.7`;(l) SCHEDULE legacy-disposition
孤儿 checklist 项替换为 wiring + source-refs gate;(m) 全部公开 docs 清理
为 Praxis-free(项目改名)。

**最终 verdict(v7):APPROVE WITH CHANGES → 5 项 v7 findings 全部应用 =
locked 当前状态。** 这是 owner 在 `git init` 前批准的规范集。

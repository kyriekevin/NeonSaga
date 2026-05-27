# SCHEDULE — NeonSaga 8 周交付（中文）

> 🌐 **Languages**: 中文（当前文件）· [English SCHEDULE.md](SCHEDULE.md)

> 日期与 DDL 的真相来源。由 `ROADMAP.md` §1 版本表 + §2–§5 各 stage 目标派生。
> 每个 stage 退出时更新。硬规则见 `CLAUDE.md` §1.4 per-stage exit ritual。

---

## 日历总览

| 周 | 日期范围 | Stage | 里程碑 | 状态 |
|---|---|---|---|---|
| 0 | 2026-05-27 → 2026-05-28 | Genesis（起步） | 规范文档锁定 + git init + Makefile/project.yml 接通 + skill 移植 + skeleton 构建绿 | 进行中 |
| 1 | 2026-05-29 → 2026-06-04 | Stage 1 W1 | Stage 1 CONTRACT + RED 测试；HealthDataSource + HealthSnapshot 骨架；Recovery 骨架 | 待办 |
| 2 | 2026-06-05 → 2026-06-11 | Stage 1 W2 | Strain + Sleep 结构；AI Recovery brief 接通；**Day-13 spike go/no-go 决策** | 待办 |
| 3 | 2026-06-12 → 2026-06-17 | Stage 1 W3（收口） | 视觉打磨；Level-up 全屏接管；**v0.1 出版** | 待办 |
| 4 | 2026-06-18 → 2026-06-24 | Stage 2 W1 | Stage 2 CONTRACT；Archive 三段滚动 + Quest Design Day 流程 | 待办 |
| 5 | 2026-06-25 → 2026-06-28 | Stage 2 W2（半周收口） | Quest 完成仪式动画；**v0.2 出版** | 待办 |
| 6 | 2026-06-29 → 2026-07-05 | Stage 3 W1 | Stage 3 CONTRACT；Transaction model + Ingest tab + LOG TRANSACTION sheet | 待办 |
| 7 | 2026-07-06 → 2026-07-12 | Stage 3 W2（收口） | LOG MEAL + WEALTH detail + 4 个跨域 trigger；**v0.3 出版** | 待办 |
| 8 | 2026-07-13 → 2026-07-22 | Stage 4（1.5 周） | 稳定性 + Contracts + Oracle + Milestones + GROWTH + TestFlight；**v1.0-personal 出版** | 待办 |
| 9+ | 2026-07-23+ | Stage 4 后 | 7 天日常使用验证；第 5 条跨域规则；**v1.0 public** | 待办 |

---

## 关键 DDL

| DDL | 内容 | 错过会怎样 |
|---|---|---|
| **2026-06-04**（Stage 1 W1 末） | Recovery score 骨架 in（哪怕占位数学） | Stage 1 slip 风险真实化；Plan B 开始从底部砍 |
| **2026-06-10**（Stage 1 Day 13） | Killer-edge spike go/no-go gate | spike 跳过 → killer-edge 验证推到 Stage 3 Day 0 |
| **2026-06-17**（Stage 1 deadline） | v0.1 git tag 打出 | Stage 2-4 时间线级联；Stage 4 有滑入 8 月风险 |
| **2026-06-28**（Stage 2 deadline） | v0.2 git tag 打出 | quest 系统未完成进入 Stage 3 |
| **2026-07-12**（Stage 3 deadline） | v0.3 git tag 打出 | 跨域"杀手边"未验证就进入 Stage 4 |
| **2026-07-22**（Stage 4 deadline） | v1.0-personal git tag 打出 | 8 周交付未达成；v1.0 public 时间线坍塌 |
| **2026-07-29**（v1.0-personal 后 1 周） | 日常使用验证窗口结束（若 Day 1 开始） | v1.0 public 没有 7 天使用验证就不可达 |

---

## 每 stage 退出 checklist（per `CLAUDE.md` §1.4）

每个 stage 退出时，以下六项必须全部为真：

1. [ ] `make verify-full` 绿
2. [ ] `docs/screenshots/` 中已更新对应可视界面的截图
3. [ ] Owner 在 iPhone 上装机；使用窗口达到 `ROADMAP.md` §1 硬规则规定的时长
4. [ ] `docs/STATUS.md` 已更新
5. [ ] Wiring 完整性全部为绿（CLAUDE §1.7）；CONTRACT "Source references"（§1.5）已填写所有外部 import
6. [ ] `git tag <stage 版本>` + push

---

## Buffer 策略

- **无 buffer 周。** 每个 stage 的 Plan B 砍单顺序吸收滑期。
- 如果**连续两个 stage** 都错过 deadline，lead **必须**在 Stage 4 开始前写一份
  "scope reduction ADR"，按如下顺序砍 Stage 4 范围：
  Demo 视频 → TestFlight build（dev build 可接受，TestFlight 本就是 post-feature）
  → GROWTH detail → Contracts 视觉重设计的精修（基本 Contracts 都能用）。
- **Stage 4 永不砍：** Oracle（5-tab promise per `ROADMAP.md` §5）、Milestone toasts
  （PRODUCT §3.2 多巴胺钩子）、Quest 完成仪式（PRODUCT §3.4 多巴胺钩子，
  Stage 2 ship 但 Stage 4 polish 时再提一次）。
- v1.0-personal deadline 只能通过 owner ADR 延后到 **2026-07-29**（1 周延期）；
  agent 不可自主延期。

---

## 跟踪约定

状态列取值：`待办` / `进行中` / `完成` / `已砍（ADR-NNN）` / `滑到 <日期>`。

Lead 在以下时点更新本表：
- 每周一上午（周开始）—— 刷新当周状态
- 每 stage 退出 —— 将该里程碑翻成 `完成`，下一 stage 推进到 `进行中`

---

## 来源与历史

- v3 于 2026-05-27 与 `ROADMAP.md` v3 同步发布；中文版 2026-05-27 翻译
- 日历精度为周（per `ROADMAP.md` §1 versioning）
- 关键 DDL 派生自 `ROADMAP.md` §2–§5 目标 + Codex v2 #2 Day-13 gate
- Buffer policy 来自 `ROADMAP.md` §0 + lead 自主裁量

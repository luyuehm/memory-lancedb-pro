# Dreaming 兼容设计说明

> 更新时间：2026-04-09  
> 相关实现：`src/dreaming.ts`、`index.ts`、`openclaw.plugin.json`、`test/dreaming-compatibility.test.mjs`

---

## 1. 背景

原始 `memory-lancedb-pro` 可以承担长期记忆插件职责，但不支持 OpenClaw Dreaming 页的配置和状态展示。

宿主报错的直接原因是：

- 当前 memory slot 指向 `memory-lancedb-pro`
- Control UI 会检查 `plugins.entries.<pluginId>.config` 的 schema 中是否存在 `dreaming`
- 原插件 schema 没有 `dreaming`
- 因此 UI 会认为“所选 memory 插件不支持 Dreaming settings”

这份增强版的目标不是替换 `memory-core`，而是在继续使用 `memory-lancedb-pro` 作为主记忆插件的前提下，补齐 Dreaming 兼容层。

---

## 2. 兼容目标

要让 OpenClaw 的 Dreaming UI 可用，至少需要满足两类契约：

### 2.1 配置契约

插件 schema 必须声明：

- `dreaming.enabled`
- `dreaming.frequency`
- `dreaming.timezone`
- `dreaming.storage.*`
- `dreaming.phases.light|deep|rem`

### 2.2 产物契约

宿主会读取以下产物：

- `memory/.dreams/short-term-recall.json`
- `memory/.dreams/phase-signals.json`
- `DREAMS.md` 或 `dreams.md`

因此只补 UI schema 不够，必须真正写出 Dreaming 兼容文件。

---

## 3. 本项目中的实现位置

### 3.1 `src/dreaming.ts`

这是 Dreaming 兼容层的核心模块，负责：

- `dreaming` 配置解析
- 五段 cron 字符串频率匹配
- Dreaming 候选记忆筛选与评分
- 生成 session corpus 文件
- 写入 short-term store
- 写入 phase signal store
- 维护 `DREAMS.md`
- 可选写出 `memory/dreaming/<phase>/YYYY-MM-DD.md`

### 3.2 `index.ts`

插件入口负责把 Dreaming 接入运行时：

- 在 `PluginConfig` 中加入 `dreaming`
- 在 `parsePluginConfig()` 中解析 `dreaming`
- 在 service `start()` 中注册启动后与定时 sweep
- 在 memory reflection 写入后补一次 Dreaming sweep

### 3.3 `openclaw.plugin.json`

清单层负责：

- 声明 `dreaming` 的 config schema
- 声明对应 `uiHints`

### 3.4 `test/dreaming-compatibility.test.mjs`

回归测试覆盖：

- Dreaming 配置解析
- 频率匹配
- `.dreams` / `DREAMS.md` 产物写入

---

## 4. 运行流程

Dreaming 兼容主链可以简化为下面这条：

```text
OpenClaw config
  -> parsePluginConfig()
  -> service.start()
  -> runDreamingSweep()
  -> collect memories from LanceDB
  -> score / filter / group candidates
  -> write session corpus
  -> write short-term-recall.json
  -> write phase-signals.json
  -> write DREAMS.md
  -> optional phase reports
```

除此之外，当 memory reflection 在 `/new` 或 `/reset` 前生成新反思文件时，也会触发一轮补充 sweep。

---

## 5. 产物说明

### 5.1 `memory/.dreams/short-term-recall.json`

这是 Dreaming 状态页最关键的数据文件之一，用来表达：

- 当前短期条目
- 被提升的条目
- 每条内容的范围、摘要、召回次数、提升时间等

本项目里写入的关键字段包括：

- `key`
- `path`
- `startLine`
- `endLine`
- `source`
- `snippet`
- `recallCount`
- `dailyCount`
- `groundedCount`
- `totalScore`
- `maxScore`
- `firstRecalledAt`
- `lastRecalledAt`
- `recallDays`
- `conceptTags`
- `promotedAt`

### 5.2 `memory/.dreams/phase-signals.json`

这个文件表达阶段信号，当前重点写：

- `lightHits`
- `remHits`

宿主会基于它统计：

- `phaseSignalCount`
- `lightPhaseHitCount`
- `remPhaseHitCount`

### 5.3 `DREAMS.md`

Dreaming Diary 的人类可读入口。

本项目遵循宿主已有的 diary marker 约定：

- `<!-- openclaw:dreaming:diary:start -->`
- `<!-- openclaw:dreaming:diary:end -->`

因此 Dreaming 页可以直接读到这份 diary。

### 5.4 `memory/.dreams/session-corpus/YYYY-MM-DD.md`

这是本项目为了把短期条目映射到可读文件范围而生成的中间产物。

它的作用是：

- 给 short-term 条目提供稳定的 `path + line range`
- 让宿主统计页能指向真实文件位置

---

## 6. 配置模型

当前支持的配置结构如下：

```json
{
  "dreaming": {
    "enabled": true,
    "frequency": "0 3 * * *",
    "timezone": "Asia/Shanghai",
    "verboseLogging": false,
    "storage": {
      "mode": "inline",
      "separateReports": false
    },
    "phases": {
      "light": {
        "enabled": true,
        "lookbackDays": 7,
        "limit": 12
      },
      "deep": {
        "enabled": true,
        "limit": 8,
        "minScore": 0.6,
        "minRecallCount": 2,
        "minUniqueQueries": 1,
        "recencyHalfLifeDays": 14,
        "maxAgeDays": 30
      },
      "rem": {
        "enabled": true,
        "lookbackDays": 14,
        "limit": 8,
        "minPatternStrength": 0.45
      }
    }
  }
}
```

其中最小可用配置只有两项：

```json
{
  "dreaming": {
    "enabled": true,
    "frequency": "0 3 * * *"
  }
}
```

---

## 7. 兼容策略

### 7.1 为什么不是直接复用 `memory-core`

因为需求是“两者都要”：

- 继续使用 `memory-lancedb-pro` 作为主记忆插件
- 同时打开 Dreaming

如果简单切回 `memory-core`，Dreaming 确实能开，但 `memory-lancedb-pro` 就不再是当前 memory slot。

### 7.2 为什么采用“兼容输出”而不是“完全复刻”

因为 Control UI 和 server 侧最稳定的契约是：

- schema 中有 `dreaming`
- 工作区里有固定 Dreaming 产物文件

只要稳定产出这些文件，Dreaming 页就能工作；没有必要把 `memory-core` 的所有实现全部复制一遍。

---

## 8. 验证方法

### 8.1 自动化测试

```bash
node --test test/dreaming-compatibility.test.mjs
```

### 8.2 宿主验证

```bash
openclaw plugins info memory-lancedb-pro
openclaw config get plugins.entries.memory-lancedb-pro.config.dreaming
```

期望：

- 插件已加载
- `dreaming` 配置可读

### 8.3 文件验证

检查以下文件：

```bash
test -f ~/.openclaw/workspace/DREAMS.md
test -f ~/.openclaw/workspace/memory/.dreams/short-term-recall.json
test -f ~/.openclaw/workspace/memory/.dreams/phase-signals.json
```

---

## 9. 已知边界

当前 Dreaming 兼容层有几个明确边界：

- 不会生成 `memory-core` 风格的受管 cron 元数据
- `managedCronPresent` / `nextRunAtMs` 这类状态不一定完整
- 当前 diary 叙述是兼容输出，不依赖 `memory-core` 的 narrative subagent
- 初次启用后如果还没有历史产物，可能需要手动执行一次 bootstrap 生成

这些边界不会阻止 Dreaming 页使用，但需要在维护文档里写清楚。

---

## 10. 建议的下一步演进

如果后续要把 Dreaming 从“可用兼容版”继续做深，建议按下面顺序推进：

1. 增加手动 CLI：
   - 例如 `openclaw memory-pro dreaming run`
2. 增加更细粒度的事件日志与失败日志
3. 增加 phase report 的回归样本
4. 视需要补充 narrative 生成能力
5. 如果要与宿主更深联动，再评估是否补齐受管 cron 语义

当前这份实现已经能满足：

- `memory-lancedb-pro` 继续做主记忆插件
- Dreaming 设置页可打开
- Dreaming 状态与 diary 有真实产物支撑

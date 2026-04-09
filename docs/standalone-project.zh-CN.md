# memory-lancedb-pro 独立项目说明

> 更新时间：2026-04-09  
> 适用版本：当前工作区中的 `memory-lancedb-pro` 独立增强版  
> 项目定位：一个可以单独维护、单独发布、单独接入 OpenClaw 的长期记忆插件项目，而不是零散补丁集合。

---

## 1. 项目定位

这份项目是以 `memory-lancedb-pro` 为基础整理出来的独立项目版，目标不是只“修一个 Dreaming 开关”，而是形成一套可持续维护的 OpenClaw 记忆插件工程：

- 保留原有的 LanceDB 长期记忆、混合检索、生命周期维护、工具链与 CLI
- 增补 Dreaming 兼容能力，让 `memory-lancedb-pro` 在保持主记忆插件身份的同时，能输出 OpenClaw Dreaming UI 所需的产物
- 补齐安装、配置、运行、验证、排障文档，降低后续移交和维护成本

如果你把这个目录单独放进一个 Git 仓库，它已经具备独立项目的基本结构：

- 入口与运行时：`index.ts`
- 插件清单与配置 schema：`openclaw.plugin.json`
- CLI：`cli.ts`
- 核心模块：`src/`
- 测试：`test/`
- 文档：`README*`、`docs/`
- 包定义：`package.json`

---

## 2. 核心能力边界

### 2.1 本项目负责什么

- OpenClaw memory slot 插件注册与加载
- 对话自动捕捉、结构化记忆写入、混合检索与自动回忆
- 生命周期衰减、Tier 演化、管理工具与运维 CLI
- 反思记忆注入与反思持久化
- Dreaming 兼容输出：
  - `memory/.dreams/short-term-recall.json`
  - `memory/.dreams/phase-signals.json`
  - `DREAMS.md`
  - 可选 `memory/dreaming/<phase>/YYYY-MM-DD.md`

### 2.2 本项目不直接负责什么

- OpenClaw 宿主的 Dreaming UI 渲染逻辑
- `memory-core` 插件的受管 cron 任务管理
- OpenClaw Gateway 本身的部署、认证和多端通道
- 外部 Embedding / LLM provider 的 SLA

也就是说，这个项目的职责是“成为一个 Dreaming-compatible memory plugin”，不是复刻整个 `memory-core`。

---

## 3. 项目结构

```text
memory-lancedb-pro/
├── index.ts
├── cli.ts
├── openclaw.plugin.json
├── package.json
├── src/
│   ├── store.ts
│   ├── retriever.ts
│   ├── smart-extractor.ts
│   ├── decay-engine.ts
│   ├── tier-manager.ts
│   ├── reflection-*.ts
│   ├── dreaming.ts
│   └── ...
├── test/
│   ├── dreaming-compatibility.test.mjs
│   └── ...
├── docs/
│   ├── standalone-project.zh-CN.md
│   ├── dreaming-compatibility.zh-CN.md
│   ├── memory_architecture_analysis.md
│   └── openclaw-integration-playbook.zh-CN.md
└── README_CN.md
```

建议把这个目录作为独立仓库时，继续保持下面这条规则：

- `src/` 只放运行时代码
- `test/` 只放自动化验证
- `docs/` 放架构、集成、Dreaming、运维说明

---

## 4. 运行依赖

### 4.1 必要依赖

- OpenClaw 宿主环境
- Node.js
- LanceDB 运行时依赖
- 至少一个 Embedding provider

### 4.2 常见安装方式

独立使用这个项目时，推荐两种方式：

1. 作为独立仓库克隆后运行 `npm install`
2. 被 OpenClaw 通过 `plugins.load.paths` 以绝对路径加载

如果当前目录来自已有插件目录复制，请确认：

- 本目录下存在可用的 `node_modules`
- 或者你已在本目录重新执行过 `npm install`

否则插件在宿主加载时可能会报 `Cannot find module 'openai'` 一类错误。

---

## 5. OpenClaw 接入方式

最小接入步骤如下：

1. 将项目放到一个稳定路径，例如：

```bash
/path/to/memory-lancedb-pro
```

2. 在 `openclaw.json` 中设置：

```json
{
  "plugins": {
    "load": {
      "paths": [
        "/path/to/memory-lancedb-pro"
      ]
    },
    "slots": {
      "memory": "memory-lancedb-pro"
    },
    "entries": {
      "memory-lancedb-pro": {
        "enabled": true,
        "config": {
          "embedding": {
            "provider": "openai-compatible",
            "apiKey": "${OPENAI_API_KEY}",
            "model": "text-embedding-3-small"
          },
          "autoCapture": true,
          "autoRecall": true,
          "smartExtraction": true,
          "dreaming": {
            "enabled": true,
            "frequency": "0 3 * * *"
          }
        }
      }
    }
  }
}
```

3. 验证配置并重启：

```bash
openclaw config validate
openclaw gateway restart
openclaw plugins info memory-lancedb-pro
```

---

## 6. 独立项目的推荐文档入口

如果你要把它交给别人维护，建议先读这 4 份：

- [README_CN.md](../README_CN.md)
- [Dreaming 兼容设计说明](./dreaming-compatibility.zh-CN.md)
- [记忆架构分析](./memory_architecture_analysis.md)
- [OpenClaw 集成与迭代手册](./openclaw-integration-playbook.zh-CN.md)

阅读顺序建议：

1. 先看 `README_CN.md` 了解项目能力和安装路径
2. 再看 Dreaming 文档理解新增能力的边界
3. 再看架构分析理解写入、检索、生命周期主链
4. 最后看集成手册处理真实接入和回归

---

## 7. 验证标准

把它当独立项目时，至少应满足以下验收条件：

### 7.1 插件加载

- `openclaw plugins info memory-lancedb-pro` 显示 `Status: loaded`
- 日志中出现 `plugin registered`

### 7.2 记忆主链

- 能写入长期记忆
- 能执行搜索与自动回忆
- `memory-pro` CLI 正常可用

### 7.3 Dreaming 兼容主链

- 插件 schema 含有 `dreaming`
- 宿主允许配置 `plugins.entries.memory-lancedb-pro.config.dreaming`
- 产物文件存在：
  - `workspace/DREAMS.md`
  - `workspace/memory/.dreams/short-term-recall.json`
  - `workspace/memory/.dreams/phase-signals.json`

### 7.4 自动化验证

建议至少跑下面这些测试：

```bash
node --test test/dreaming-compatibility.test.mjs
node --test test/config-session-strategy-migration.test.mjs
node test/plugin-manifest-regression.mjs
```

---

## 8. 当前实现上的已知边界

这份独立项目版当前已经可用，但有几个边界需要写清楚：

- Dreaming 是“兼容实现”，不是完整复刻 `memory-core`
- 当前不会创建 `memory-core` 那种受管 cron 标记，因此 UI 中的 cron 托管状态不一定完整
- Dreaming 产物以本插件的记忆与反思数据为基础生成，不依赖 `memory-core`
- 若首次启用后工作区里还没有历史产物，可以手动执行一次 bootstrap 生成

这些边界不是缺陷隐藏点，而是维护时必须明确写在项目文档里的真实约束。

---

## 9. 适合如何继续演进

后续如果要把它进一步产品化，建议优先做这几类演进：

- 增加 Dreaming 手动触发 CLI
- 增加 Dreaming 独立回归测试覆盖更多真实数据样本
- 把 Dreaming 日志和阶段报告做成更稳定的运维输出
- 视需要补齐更完整的多语言文档

如果你只是要“能用、能交接、能独立维护”，当前这套结构已经足够形成一个独立项目。

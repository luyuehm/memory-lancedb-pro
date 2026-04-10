# 自愈 Skill（memory-lancedb-pro）V1

> 目标：当插件出现回归、链路异常或发布前不确定状态时，快速“发现 → 定位 → 修复 → 证据化验证 → 沉淀经验”。

---

## 1. 触发条件（什么时候启用自愈）

满足任一条件即触发：

1. 新改动后测试失败（单测/全量/宿主链路）
2. 关键能力退化（如反射注入为空、搜索命中异常、导入导出失败）
3. 发布前状态不确定（版本一致性、配置漂移、迁移风险）
4. 用户反馈“偶发问题、难复现”

---

## 2. 自愈流程（标准 6 步）

### Step A｜快速复现
- 最小复现优先：
  - `node --test test/<target>.mjs`
- 全链路复现：
  - `npm test`
  - `npm run test:openclaw-host`

### Step B｜症状归因
优先判断是哪一层：
1. **逻辑缺失/条件错误**（函数缺失、分支未命中）
2. **时序/时间窗脆弱性**（固定时间戳导致过期）
3. **配置/数据格式不匹配**（CLI 入参格式、schema 漂移）
4. **宿主集成问题**（OpenClaw 命令链某环失败）

### Step C｜最小修复
- 只改必要点，不扩大改动面
- 先修生产逻辑，再修测试脆弱性
- 典型策略：
  - 补齐缺失 helper / 防御分支
  - 固定时间改为 `Date.now()`（避免时间窗导致 flaky）
  - 导入/导出样例严格对齐 CLI schema

### Step D｜分层验证（必须有证据）
1. 目标用例通过
2. 全量测试通过
3. 宿主功能测试通过（import/list/search/stats/export/delete/migrate）
4. 发布前脚本通过：
   - `FAST=1 bash scripts/release-readiness-check.sh`
   - `bash scripts/release-readiness-check.sh`

### Step E｜提交与发布
- 提交信息需可审计：`fix(...)` / `chore(release)...`
- 推送后附“证据链”摘要（命令 + 通过信号）

### Step F｜经验沉淀
- 把本次故障写入可复用规则：
  - 测试时间窗规范
  - 导入格式规范
  - 发布验收脚本化

---

## 3. 本项目已验证的自愈案例（可复用模板）

### 案例：reflection hook 注入回归
- **症状**：`test/reflection-bypass-hook.test.mjs` 4 个用例失败，`prependContext` 为空
- **根因**：
  1) `index.ts` 缺失 `isReflectionMetadataType` / `isOwnedByAgent`
  2) 测试 `runAt` 用历史时间，被 derived 时间窗过滤
- **修复**：
  - 补齐 helper
  - `runAt` 改为 `Date.now()`
- **验证**：
  - 目标测试通过
  - `npm test` 全量通过
  - `npm run test:openclaw-host` 通过

---

## 4. 自愈检查清单（上线前）

1. `package.json` 与 `openclaw.plugin.json` 版本一致
2. 插件可发现：`openclaw plugins info memory-lancedb-pro`
3. 管理命令可用：`openclaw memory-pro version`
4. 导入/检索/导出链路可跑通
5. 删除操作幂等
6. （可选）迁移 run/verify 通过
7. `npm pack --dry-run` 正常

> 已脚本化：`scripts/release-readiness-check.sh`

---

## 5. 反脆弱规则（避免重复踩坑）

1. **时间相关测试禁止硬编码历史时间**（除非显式测试过期逻辑）
2. **功能修复必须包含宿主链路验证，不只看单测**
3. **发布前检查必须脚本化，不依赖人工记忆**
4. **新增 helper/分支要有对应 regression test**

---

## 6. 推荐执行顺序（现场应急）

```bash
# 1) 先定位
node --test test/reflection-bypass-hook.test.mjs

# 2) 再确认全局影响
npm test
npm run test:openclaw-host

# 3) 最后发布前总验
bash scripts/release-readiness-check.sh
```

---

## 7. 输出模板（对外同步）

- 症状：
- 根因：
- 修复点：
- 验证命令：
- 结果：
- 风险边界：
- 后续预防：

> 要求：每次自愈都要形成“可复现证据链”，而不是口头结论。

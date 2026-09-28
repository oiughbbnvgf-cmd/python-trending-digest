---
name: pydigest
description: 抓取 GitHub Trending 的 Python 月榜 Top 10，逐个深挖并生成「一句话价值 + 技术栈拆解 + 爆火归因 + 可落地性」四维中文摘要，同时输出 Markdown 报告与自包含 HTML 可视化。当用户要求看 Python 月榜热门项目、分析 Python 生态趋势、解读某个项目为什么突然火了、评估这些项目值不值得上手，或要求生成 GitHub Trending 简报/报告时使用。
---

# Python 月榜 Top 10 深度摘要

固定范围：**GitHub Trending 的 Python 月榜（`?since=monthly`）前 10 名**。不查日榜周榜，不查其他语言，不超过 10 个。

输出两件事，缺一不可：

1. `reports/digest_YYYY-MM-DD.md` — 四维摘要正文
2. `reports/digest_YYYY-MM-DD.html` — 自包含可视化

另有两份**只读不写、除了追加什么都不做**的状态文件：

- `data/history.jsonl` — 每期一行，抓到的榜单原始数据。**只用于下期做 diff**，见步骤 4 / 4b
- `PREFERENCES.md` — 用户维护的口味配置，每次运行第一步读它，见步骤 0

本 skill 基于 [wahahaazhe/KnowGT](https://github.com/wahahaazhe/KnowGT)（MIT）的 `knowgtzh` 改造。原版只做「通俗解释 + 趋势对比」，且**明确禁止读取仓库 README**；本版因为要做技术栈拆解和可落地性评估，**该禁令已解除** —— 见下方步骤 3。

---

## 步骤 0：读取偏好（每次运行第一步）

读项目根目录的 **`PREFERENCES.md`**，把里面所有条目当硬约束执行——它优先于本文档的通用描述。

那个文件是给用户自己改的口味配置。用户没提过就只按本文档走；提了就按 `PREFERENCES.md` 走。两者冲突时以 `PREFERENCES.md` 为准。

---

## 步骤 1：抓榜单

```
WebFetch https://github.com/trending/python?since=monthly
```

提示词：`List the first 10 repositories in order, with full repo path (owner/name), description, language, total stars, stars gained this month, and forks.`

逐项提取：

| 字段 | 说明 |
|---|---|
| `repo` | `owner/name` |
| `desc` | 英文原始描述，**只作素材，不直接进正文** |
| `lang` | 主语言 |
| `stars` | 总 star |
| `gained` | 本月新增 star |
| `forks` | 总 fork |

**只取前 10**，按页面顺序。

抓不到时：先用 `https://github.com/trending/python/monthly` 重试；仍失败则 WebSearch「GitHub trending python monthly」找镜像站，并在报告开头注明用了什么数据源。**不要凭记忆编数据。**

## 步骤 2：算两个派生指标

这两个指标是后面所有判断的量化基础，先算出来。

**新项目指数** = `gained / stars`（本月新增占总 star 的比例）

| 区间 | 含义 |
|---|---|
| > 60% | 全新项目，本月首次出圈 |
| 25%–60% | 上升期项目 |
| < 25% | 老项目回潮，或本来就很大、增速自然 |

算出来后在报告里显式给出这个百分比，不要只写「新增很多」。

**增速倍数** = `gained / (stars - gained)`（本月新增相对此前存量的倍数）

> 3.6k star 的项目本月 +2.9k → 倍数 4.5，说明几乎是一夜之间被发现的。
> 33.9k 的项目本月 +5.7k → 倍数 0.20，属于稳定自然增长。

⚠️ **统计栏用中位数，不要用均值。** 增速倍数分布极度右偏——2026-09-28 那期 microduck_rl 是 94.8×，把均值从 1.2 拉到 12.1，中位数才反映典型项目。报告里要同时写明「中位数 X×，均值 Y×（被 Z 项目拉高）」。

## 步骤 3：逐个深挖（关键步骤，不可跳过）

对步骤 1 拿到的**每一个** repo，WebFetch 其仓库主页：

```
WebFetch https://github.com/{owner}/{repo}
```

提示词：`Extract: the README's stated purpose, installation/setup requirements, hardware or API-key requirements, primary frameworks and dependencies, whether there is a hosted/demo version, the latest release or commit date, and any stated roadmap or limitations.`

需要从 README 里挖出的四类信息：

1. **技术栈** — 主要依赖（框架、模型、SDK）、语言构成、是否有预训练权重、代码规模
2. **可落地性** — 硬件门槛（显存/磁盘）、是否需要 API key、本地能否跑通、有没有官方 demo/托管版
3. **限制与风险** — README 里明说的 limitation；没有明说就从依赖和形态推断（如「需从零训练」「权重需另行下载」）
4. **成熟度信号** — star/fork 比、issue 数量、最后提交时间、是否有 release

⛔ **不采集、不讨论 License、授权协议或商用风险。** 这条线不在本报告范围内，即使 README 显著标注了授权条款也跳过。用户要看的是「这东西好不好用、能不能跑起来」，不是法务问题。

**抓取失败或 README 为空**：不要跳过该项目，在对应字段写「README 信息不足，未能核实」并说明。这比编造有价值。

**不要调用 GitHub REST API**（`api.github.com/repos/...`）。未认证时限额只有 60 次/小时且极易耗尽，仓库主页 WebFetch 已能拿到全部所需信息，且无此限制。

## 步骤 4：对比历史

**用 `data/history.jsonl` 做精确 diff，不要靠读散文猜。**

该文件每期一行 JSON（格式见步骤 4b）。读**倒数第二行**作为上期基线，与本期步骤 1 的结果对比，得出：

| 指标 | 算法 |
|---|---|
| 新上榜 | 本期有、上期没有的 repo |
| 掉出 | 上期有、本期没有的 repo（附上期排名） |
| 排名升降 | 两期都在的 repo，`本期 rank - 上期 rank`（负数 = 上升） |
| star 轨迹 | 两期都在的 repo，`本期 stars - 上期 stars` 及涨幅 % |

「持续在榜」的判定标准是：**在 `history.jsonl` 里连续出现 ≥2 期**。不要用「上一份 md 里出现过」来判，那个不准。

`reports/` 里的 md 只用于补充文字背景（上一期对该项目的解读），**不要拿它算数字**。

没有历史（文件为空，或只有本期这一行）就在报告里写「首期，暂无对比基准」。

## 步骤 4b：追写历史

**在写报告之前**，把本期数据追加到 `data/history.jsonl`（一行，UTF-8 无 BOM，逗号紧凑分隔）：

```json
{"date":"YYYY-MM-DD","source":"github.com/trending/python?since=monthly","repos":[{"rank":1,"repo":"owner/name","stars":3599,"gained":2945,"forks":294}]}
```

字段就这几个，不要加别的。同一天重跑要**覆盖那一行而不是追加两条**。

写完验证能解析：

```bash
python -c "import json;print(len([json.loads(l) for l in open('data/history.jsonl',encoding='utf-8') if l.strip()]))"
```

**这一步不能省**——省了下期就没法对比。

## 步骤 5：写 Markdown 报告

### 5.1 头部

```markdown
# Python 月榜 Top 10 深度摘要 — YYYY-MM-DD

> 数据来源：github.com/trending/python?since=monthly
> 抓取时间：YYYY-MM-DD HH:MM
> 对比基准：<上期日期，取自 data/history.jsonl 倒数第二行；首期写「无」>
> 生成工具：pydigest
```

### 5.2 榜单速览表

紧凑表格，10 行。`一句话价值` 硬约束 **30 字以内**。

| # | 项目 | 总 Star | 本月新增 | 新项目指数 | 一句话价值 |
|---|---|---|---|---|---|
| 1 | `owner/repo` | 3.6k | +2.9k | **82%** | 给 AI Agent 用的模型路由器 |
| 2 | `owner/repo` | 40.6k | +27.3k | **67%** | 本地开源的 ElevenLabs 替代品，做配音和语音克隆 |

### 5.3 逐个深挖（10 个项目，顺序按榜单排名）

每个项目**严格四段**，顺序固定：

```markdown
## 1. owner/repo

**总 Star** 3,599 · **本月新增** +2,945 · **新项目指数** 82% · **增速倍数** 4.6
`Python` · 最后提交 2026-09-20

**① 一句话价值 + 适合谁**

<30 字以内讲清「它替代/解决什么、谁该关注」，不要复述英文描述>

**适合谁**：<具体到角色和处境，不要「所有人」>
**不适谁**：<明确劝退对象>

**② 技术栈与实现**

| 维度 | 内容 |
|---|---|
| 核心依赖 | <框架/SDK/模型，逐个列> |
| 形态 | <库 / CLI / 服务 / 权重 / 应用> |
| 代码规模 | <文件数、LOC 量级，或「无法核实」> |

<2-3 句讲清实现思路上的关键取舍，不要复述依赖列表。>

**③ 为什么突然火**

- **数据证据**：<用步骤 2 的两个指标说，不要只写「涨很多」>
- **时机因素**：<发布时间、是否踩中当前热点、作者/组织背景>
- **传播路径**：<Product Hunt / 社交媒体 / 论文 / 大厂背书，能核实就写，核实不了就写「未查到明确来源」>

**④ 可落地性与风险**

- **本地门槛**：<显存 / 磁盘 / API key / 无>
- **上手成本**：<预估分钟数或难度>
- **成熟度**：<star/fork 比、issue 情况、最近提交>
- **风险**：<依赖过重、权重需另行下载、停更迹象、接口不稳定、README 未提的坑 —— 只谈工程和使用层面的坑，不谈授权>
- **给结论**：⭐⭐⭐ / ⭐⭐ / ⭐ —— <一句话明确推荐或劝退>
```

### 5.4 可落地性排序

按「值不值得投入」重排一次，给明确的行动建议。这是本报告最有决策价值的部分。

| 项目 | 门槛 | 上手成本 | 结论 |
|---|---|---|---|
| `owner/repo` | 无，纯 Python 库 | 5 分钟 | ⭐⭐⭐ 今天就能试 |
| `owner/repo` | 需 24G 显存 | 几天调参 | ⭐ 有专门团队再做 |

### 5.5 生态趋势

2–4 个主题，每个主题必须引用**具体项目名 + 排名 + 新增 star** 作为证据。没有足够证据就少写一节，不要硬凑。

最后一句话总结这期 Python 生态说明了什么。

### 5.6 完整数据表

| # | 项目 | 语言 | 总 Star | Fork | 本月新增 | 新项目指数 |
|---|---|---|---|---|---|---|

---

## 步骤 6：生成 HTML

读本 skill 目录下的 `reference/digest-template.html`，**沿用它的 `<style>` 全部 CSS 和 `switchTab()` 函数**，DOM 结构保持一致，只填数据：

- **Hero**：标题改中文，meta-chip 填 `Python` / `monthly` / 抓取时间 / 对比基准
- **Stats**：`项目总数 10` / `新项目指数>60% 的数量` / **`增速倍数中位数`** / `零门槛可跑的数量`（严格标准：既不需 API key 也不需 GPU）
- **速览页签**：榜单速览表、爆火归因表、可落地性排序表、趋势解读段落、完整数据表。删掉所有 `.empty-row` 占位行
- **深拆页签**：对每个项目渲染完整 `.project-card`，body 内依次是 `.proj-what-is-it`（①）、`.proj-tech`（②，新增）、`.proj-why-hot`（③，新增）、`.proj-verdict`（④，新增）。历史报告中已有的项目用 `style="opacity:0.7"` 的精简卡片并注明首次出现日期

要求：

- **完全自包含** —— CSS 全在 `<style>` 内，JS 全在 `<script>` 内，零外部请求、零 CDN
- 中文字体栈保留模板里的 `Noto Sans SC` / `PingFang SC` / `Microsoft YaHei`
- 写完后自动打开（不要问用户用什么系统）。**注意 Claude Code 的 Bash 工具在 Windows 上跑的是 Git Bash，不是 PowerShell**——`Start-Process` 和 `start` 都会失败。可靠写法：
  - 跨平台（推荐，已实测可用）：
    ```bash
    python -c "import webbrowser,pathlib;print(webbrowser.open(pathlib.Path('reports/digest_YYYY-MM-DD.html').resolve().as_uri()))"
    ```
  - macOS：`open reports/digest_YYYY-MM-DD.html`
  - Linux：`xdg-open reports/digest_YYYY-MM-DD.html`

## 步骤 7：自检

写完逐条核对，不过关就改：

- [ ] 榜单是 Python **月榜**且**恰好 10 个**？
- [ ] `data/history.jsonl` 已追写本期，且能 `json.loads` 解析？同一天有没有写出重复行？
- [ ] 有历史的话，「新上榜 / 掉出 / 排名升降」是从 jsonl 算的，不是从 md 猜的？
- [ ] 读过 `PREFERENCES.md` 并遵守了？里面「不感兴趣的维度」有没有漏进报告？
- [ ] 每个项目四段齐全、顺序一致？
- [ ] 每句「一句话价值」都 **≤30 字**？
- [ ] 「为什么突然火」引用了**具体数字**而不是「增长迅速」？
- [ ] 「可落地性」给出**明确结论**而不是「视情况而定」？
- [ ] 全文有没有混进 License / 授权 / 商用风险？有就删掉
- [ ] 有没有哪个字段是我编的？有就改成「未能核实」
- [ ] HTML 打开过、两个页签都能切换、样式没崩？

---

## 写作规范

- **不写 License、不写授权协议、不写商用风险。** 不设授权相关栏目，不在「风险」里塞授权条款，也不用它影响推荐结论
- 中文正文，技术专有名词（LLM、RAG、Agent、TTS、RL、Embedding、OCR、Markdown）保留英文，不要幼稚化翻译
- 禁用空洞词：赋能、抓手、闭环、生态位、护城河、颠覆
- 不复述 GitHub 英文原始描述，要「翻译」成中文并补上「给谁用」
- 不堆功能清单。「多语言/多说话人/多框架」不是价值陈述
- 判断要有依据。**该说「不建议上手」就直说**，不要为了礼貌含糊其辞
- 抓不到的数据就写「未能核实」。**宁可留空，不要编造** —— 这份报告的价值完全建立在数据真实之上

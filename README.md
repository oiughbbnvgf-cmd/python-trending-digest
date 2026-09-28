# pydigest — GitHub Python 月榜 Top 10 深度摘要

抓 [GitHub Trending Python 月榜](https://github.com/trending/python?since=monthly)前 10 名，对每个项目做**四维拆解**，输出 Markdown 报告 + 自包含 HTML 可视化。

## 四个维度

| 维度 | 回答的问题 | 依据 |
|---|---|---|
| ① 一句话价值 + 适合谁 | 这东西替代/解决什么？谁该关注、谁该绕开？ | Trending 描述 + README 首段 |
| ② 技术栈与实现 | 依赖什么、什么形态、多大规模、什么协议？ | README + 仓库元信息 |
| ③ 为什么突然火 | 是真爆火还是自然增长？踩中什么时机？ | **新项目指数**、增速倍数、发布时间 |
| ④ 可落地性与风险 | 门槛多高、要多久、有什么坑、值不值得投入？ | README 安装/限制章节 + 成熟度信号 |

## 两个派生指标

报告里所有「爆火」判断都建立在这两个数上，不是形容词：

```
新项目指数 = 本月新增 ÷ 总 Star          增速倍数 = 本月新增 ÷ 此前存量 Star
```

> 例：`3,599 star` 本月 `+2,945` → 指数 **82%**、倍数 **4.6×**，是一夜之间被发现的新项目。
> 例：`33,871 star` 本月 `+5,681` → 指数 **17%**、倍数 **0.20**，属于大项目自然增长。

## 用法

```
① cd 到本目录，打开 Claude Code
② 输入 /pydigest
```

就这样。`/pydigest` 不是程序也不是插件，就是 `.claude/skills/pydigest/SKILL.md` 这个文件——Claude Code 在会话启动时扫描 `.claude/skills/` 并把它注册成斜杠命令，调用时把内容读进上下文。没有 npm 包、没有后台进程、不需要 install。

产物落在 `reports/`：

```
reports/digest_2026-09-28.md
reports/digest_2026-09-28.html
```

**第二次起会自动对比历史**，标出新上榜 / 掉出 / 排名升降 / star 轨迹。首期没有对比基准，报告里会注明。

## 改口味

编辑 **`PREFERENCES.md`**，不用碰 `SKILL.md`。里面是不感兴趣的维度、评价侧重、写作口味、硬约束。每次 `/pydigest` 都会读它，冲突时以它为准。

比如「不关注 License 和商用风险」这条就写在那里——改口味是改一个文件，不是每次口头交代。

## 结构

```
month/
├── PREFERENCES.md                    # ← 你的口味配置，改这个
├── data/
│   └── history.jsonl                 # 每期一行榜单数据，只用于下期 diff
├── reports/                          # 生成的 md + html
└── .claude/skills/pydigest/
    ├── SKILL.md                      # 抓取流程 + 四维摘要规范 + 自检清单
    └── reference/
        └── digest-template.html      # HTML 模板（自包含，零外部请求）
```

## 与上游 KnowGT 的差异

基于 [wahahaazhe/KnowGT](https://github.com/wahahaazhe/KnowGT)（MIT）的 `knowgtzh` skill 改造。改动有三处，其中一处是**方向性反转**：

1. **范围收窄**：从「daily/weekly 全语言榜」固定为「Python 月榜 Top 10」
2. **维度扩充**：从「通俗解释 + 趋势对比」扩为四维深度拆解，且趋势对比从 daily 改为按报告期累积
3. **解除 README 禁令** ⚠️ — 上游 `knowgtzh` 明确禁止读取仓库 README（原文：「不要去 WebFetch 仓库 README」），因为它只要一句话通俗解释。本项目要做技术栈拆解和可落地性评估，**必须读 README**，否则门槛和风险全是猜测。该禁令已在本版明确废除

HTML 模板沿用上游的 CSS 与 `switchTab()`，新增 `.proj-tech` / `.proj-why-hot` / `.proj-verdict` 三组样式，中文化。

## 已知限制

- **没有爬虫脚本**。抓取走 WebFetch，靠模型自己解析页面。这换来了免维护、不受 GitHub API 60 次/小时限流，但也意味着没有缓存、没有定时任务保证
- **历史只在你自己跑过的地方存在**。GitHub 不提供历史 trending API，所以「连续上榜 N 期」完全靠 `data/history.jsonl` 累积。**这个文件删了就断档**，git 没初始化的话也没有备份
- **`history.jsonl` 越跑越对不上**。GitHub 的月榜是滚动窗口，隔两期以上再看，star 涨幅已经不能代表「这一个月涨了多少」了——指标含义会漂
- **单次抓取失败即该字段留空**。不重试到成功，宁可写「未能核实」也不编数据

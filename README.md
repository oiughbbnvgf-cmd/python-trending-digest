# pydigest

每月把 [GitHub Trending 的 Python 月榜](https://github.com/trending/python?since=monthly)前十名抓下来，逐个读完 README，写成一份能直接拿去判断「这玩意儿值不值得我投入时间」的中文报告。

榜单本身只告诉你谁涨了多少 star，不告诉你它是什么东西、要多少显卡、有没有坑。这个项目补的就是这段。

## 报告里有什么

每个项目四段：一句话说清它替代什么、适合谁；技术栈和实现形态；为什么这一个月突然涨起来；以及本地能不能跑通、要多少成本、有什么坑。最后按「值不值得投入」重排一次。

涨星这事会区分两种：一个月内被集中发现的爆火，和大项目本身的自然增长。报告用新增占总 star 的比例来分，不靠形容词。

## 怎么用

```
cd 到本目录
claude
/pydigest
```

产物在 `reports/`，一份 Markdown 一份 HTML。HTML 是自包含的单文件，双击就能看。

没有爬虫、没有依赖、不需要装东西。`/pydigest` 就是 `.claude/skills/pydigest/SKILL.md` 这个文件，Claude Code 启动时扫到它就注册成命令，调用时把内容读进上下文。数据靠 WebFetch 现抓现解析。

跑第二期开始会自动和上一期对比，标出新上榜、掉出、排名升降和 star 增量。历史存在 `data/history.jsonl` 里，一期一行。

## 想改口味

编辑 `PREFERENCES.md`。不感兴趣的维度、评价侧重、写作口味、硬约束都写在里面，每次运行第一步读它，冲突时以它为准。比如「不关注 License 和商用风险」就是记在那儿的——改口味是改一个文件，不用每次口头交代。

## 几点说明

没有定时任务，也不会自己跑。想更新就手动执行一次。

GitHub 不提供 trending 的历史接口，所以「连续上榜 N 期」完全靠本地那个 jsonl 累积。文件删了历史就断。另外月榜是滚动窗口，间隔久了再看，涨幅已经不能代表「这一个月涨了多少」。

抓不到的数据报告里会写「未能核实」，不填不猜。

---

改造自 [wahahaazhe/KnowGT](https://github.com/wahahaazhe/KnowGT)（MIT）的 `knowgtzh` skill。原版禁止读仓库 README，这里解除了——不读 README 就没法做技术栈和门槛的判断。

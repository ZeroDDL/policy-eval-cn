# 政策评估助手（policy-eval-cn）

「政策评估实证方法系列」收官篇配套开源工具包：一张"数据特征 → 方法选择"决策地图 + 一个 Claude Code skill + 8 个可一键复现的 Stata 案例。

装上这个 skill 后，没有计量背景的读者也可以：用自然语言描述研究问题（或直接丢给它一份数据），由 AI 判断适用的政策评估方法（DID / PSM / RDD / SCM / PSM-DID / 多期 DID / 交错 DID 稳健估计量 / 强度 DID），自动调用本机 Stata 完成实证，并用白话解读结果、给出论文结果部分的报告清单。

## 决策地图

| 数据/问题特征 | 适用方法 | 核心命令 | 案例 |
| --- | --- | --- | --- |
| 只有一个处理对象 + 未处理供体 + 长面板 | SCM 合成控制 | `synth` | cases/SCM案例-08-17 |
| 连续驱动变量 + 明确门槛 | RDD 断点回归 | `rdrobust` | cases/RDD案例-08-16 |
| 截面 + 两组特征差异大 + 协变量丰富 | PSM 倾向值匹配 | `psmatch2` | cases/PSM案例-08-15 |
| 面板 + 统一处理时点 | DID 双重差分 | `reghdfe` | cases/DID案例-08-14 |
| 面板 + 基线特征不可比 | PSM-DID | `psmatch2`+`reghdfe` | cases/PSMDID案例-08-18 |
| 面板 + 政策分批落地 | 多期 DID + Bacon 诊断 | `bacondecomp` | cases/多期DID案例-08-19 |
| 交错处理 + 效应异质 | 稳健估计量（CS/SA/BJS） | `csdid` 等 | cases/交错DID案例-08-20 |
| 处理为连续强度 | 强度 DID（CGBS） | 强度DID/分档 | cases/强度DID案例-08-21 |

交错处理的平行趋势敏感性分析（honestdid）参考 cases/稳健DID案例-08-22。

## 安装（三步）

1. 安装 [Claude Code](https://claude.com/claude-code)（Anthropic 官方命令行 AI 助手）；
2. 下载本仓库（Code → Download ZIP，或 `git clone`）并解压；
3. 把 `skill/policy-eval-cn` 文件夹复制到 skills 目录：
   - Windows：`C:\Users\你的用户名\.claude\skills\`
   - macOS/Linux：`~/.claude/skills/`

`cases/` 文件夹放在任意位置即可。

## 使用

1. 在 Claude Code 中随便说一句，例如：
   - "帮我看看这份数据适合用什么政策评估方法：xxx.dta"
   - "我想评估低碳城市试点对企业创新的影响，该用什么模型？"
2. 首次使用，助手会询问你的 **Stata 安装路径**（右键 Stata 图标 → 属性可查看）和 **cases 案例包的存放位置**，自动写入 `skill/policy-eval-cn/config.txt`，以后不用再问；
3. 之后按提示确认变量对应关系即可，剩下的判方法、跑 Stata、解读结果都由助手完成。

也可以直接把 `cases/` 里任意案例的 do 文件拖进 Stata 手动运行（Ctrl+A 全选 → Ctrl+D），输出文件保存在当前工作目录。

## 目录结构

```
policy-eval-cn/
├── README.md
├── skill/policy-eval-cn/        # Claude Code skill（复制到 ~/.claude/skills/ 使用）
│   ├── SKILL.md                 # 工作流主文件
│   ├── references/              # 决策树 / 数据体检 / 案例索引 / Stata批处理
│   ├── scripts/数据体检.do       # 数据结构探针
│   └── config.示例.txt           # 首次使用时由助手自动生成 config.txt
└── cases/                       # 8+1 个配套案例（do 模板 + 模拟数据 + 输出示例）
```

## 注意事项

- 需要本机安装 Stata（版本不限）；案例所需社区命令由 do 文件自动从 SSC 安装，首次运行需联网；
- skill 是助手不是替身：识别假设（平行趋势、驱动变量不可操纵等）需结合政策背景自行论证；
- 自动执行的结果请打开输出文件夹中的 log 与图表复核。

## 配套推文

「政策评估实证方法系列」（公众号：梁老师讲AI金融），2026-08-13 至 2026-08-22 共十篇，每篇对应一个案例文件夹。

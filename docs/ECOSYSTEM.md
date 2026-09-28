# Ecosystem comparison / 选题边界

核查日期：2026-09-28。本文区分“查询没有命中”与“证明不存在”，不承诺初审结果，不声称全生态唯一或已有外部用户。

## 本项目是什么

MoonCassowary 是 Kiwi/Cassowary 求解核心的 MoonBit 移植：以稀疏 tableau 保存状态，支持运行中增删线性等式/不等式、设置软强度、注册编辑变量并用 dual simplex 更新建议值。上游关系、固定版本及许可证见 [THIRD_PARTY_NOTICES](../THIRD_PARTY_NOTICES.md)。求解不转发给现成运行时。

真实使用边界是交互式几何关系：窗口或拖动建议变化后，保持硬边界、跨变量关系并平衡偏好。可运行例 `examples/split_pane`、`examples/recovery` 分别展示连续编辑和冲突后恢复。示例证明可调用和工作边界，**不是第三方采用或性能优势的证据**。

## 最近似的已有 MoonBit 项目

| 项目 / 查询版本 | 已有能力（必须承认） | 与本项目的具体区别 |
|---|---|---|
| [Milky2018/chicle 0.6.1](https://mooncakes.io/docs/Milky2018/chicle@0.6.1) | Taffy-inspired UI 布局，树节点、Flex/Grid、JSON/YAML 输入与交互演示 | 不是通用的任意变量线性关系＋软强度＋edit-variable 求解接口；本项目也不实现其 CSS 样式与布局树 |
| [mizchi/crater-layout 0.19.0](https://mooncakes.io/docs/mizchi/crater-layout@0.19.0) | CSS 布局内核及增量缓存 | “布局缓存”与维护线性方程组基并增删约束不同；本项目不替代其布局引擎 |
| [Freon793/moonopt 0.1.2](https://mooncakes.io/docs/Freon793/moonopt@0.1.2) | 纯 MoonBit LP/MIP、稀疏修正单纯形、对偶热启动、MPS/LP、证书 | **确有算法与数学问题重叠**，且能表达等价优化问题。这里的交付边界是持续 add/remove、软约束 marker 管理、edit 建议和可直接移植的 Kiwi 行为，而不是宣称第一次在 MoonBit 实现线性优化 |
| [mjfmjf879/moonbit_constraint 0.1.0](https://mooncakes.io/docs/mjfmjf879/moonbit_constraint@0.1.0) | 有限整数域、约束传播、启发式搜索、排班与配置模型 | 不是连续浮点变量上的加权线性布局求解；本项目不做其整数枚举和领域模型 |

一般 LP 可以表示加权软约束，因此差异不是数学不可替代性，而是**实际移植的增量求解数据结构、在线操作语义、跨后端可复用 API 和对应行为测试**。本项目不靠添加报告格式或 CLI 宣称新算法。

## 查重方法和盲区

- 本机 `moon search <keyword> --limit 60 --json`：cassowary、kiwi、layout、simplex、solver、linear、autolayout；前两项未命中。宽泛词有命中，以上近邻已阅读功能说明，不能把它们忽略。
- GitHub 仓库检索 `cassowary MoonBit`、`kiwi MoonBit`、`simplex MoonBit`；代码检索 `cassowary extension:mbt`、`addEditVariable extension:mbt`、`suggest_value extension:mbt` 未命中。`kiwi` 代码命中主要是词表中的水果名，不等于求解器。
- Exa 补充检索并阅读版本文档。搜索索引、未发布/私有代码、不同命名或内部子模块仍是盲区；正式提交前应刷新查询。
- 暂未找到直接要求 MoonBit Cassowary 的用户工单，未取得外部采用反馈。不能把这个缺口写成“已有社区用户急需”。

此类算法在其他生态确有实际用途，例如 [Ratatui 的布局代码](https://github.com/ratatui/ratatui/blob/main/ratatui-core/src/layout/layout.rs)使用相关约束求解器。但这只证明应用方式成立，不等同于 MoonBit 生态采用。

## 与旧参赛项目的区别

MoonCheck 是 JSON Schema 校验的 CLI/CI 前端；MoonCassowary 是实数变量约束的求解核心，两者输入模型、核心算法、公共 API 与运行场景不同。旧仓库保持独立，不搬迁其校验实现，不把旧提交/测试数量计为新成果。

参赛者已提供三次 MoonCheck 驳回通知：早期通知明确提及 Betterlol/moon_zod 及实现边界，随后再次指出 JSON Schema 重叠与扩展声明不足，最新通知指出方向成熟、增量价值有限并建议换题。新项目因此采用独立选题并明确声明移植来源，不把修改声明本身当作新增价值。

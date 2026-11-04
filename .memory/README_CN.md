---
name: memory-readme-zh-cn
description: 记忆系统索引的简体中文译文。规则以 README.md 为准；本文与英文版不一致时，以英文版为准。
---

# 记忆索引

[English](README.md) | [简体中文](README_CN.md)

> `README.md` 是记忆系统规则的唯一规范来源。本文仅作为翻译参考；如有任何内容与英文版不一致，以英文版为准。

> 此目录是系统的持久记忆。通过本索引定位相关记忆，无需默认加载所有文件。

## 保留规则

| 存放内容 | 文件 | 何时清理 |
| --- | --- | --- |
| 当前任务 | [focus.md](focus.md) | 任务切换时重写整份文件。 |
| 跨任务仍然成立的事实和规则 | [user.md](user.md)、[relationships.md](relationships.md)、[goals.md](goals.md) | 有新的说法取代旧条目时，替换该条目。 |
| 已经发生的经过 | [experiences.md](experiences.md) | 不改写旧条目。教训变成长期规则时，把规则移入 `user.md`，此处只留指向。 |

## 记忆区域

| 文件 | 用途 | 读取时机 |
| --- | --- | --- |
| [user.md](user.md) | 身份、沟通方式、工作偏好、原则和安全边界。 | 需要个性化、做判断或触及安全边界时。 |
| [focus.md](focus.md) | 当前任务、阶段、下一步和阻塞项。 | 继续或恢复当前任务时。 |
| [goals.md](goals.md) | 目标、优先级、状态、完成标准，以及可选的截止日期。 | 规划工作或判断轻重时。 |
| [relationships.md](relationships.md) | 人物、团队、组织及其协作方式。 | 任务涉及已知人物、角色或协作时。 |
| [experiences.md](experiences.md) | 已经发生的事件及其结果。 | 以前出现过类似情况时。 |

## 运行规则

1. 本索引位于 `.memory/README.md`。其中的相对路径都相对于 `.memory/` 目录解析。
2. 恢复工作时读取 `user.md` 和 `focus.md`。只有当 `goals.md`、`relationships.md` 或 `experiences.md` 的用途适用时才读取它们。
3. 将记忆视为上下文，而不是绝对正确的事实；准确性重要时应进行验证。
4. 保存可长期留用的信息，不保存对话记录，也不得保存密码、访问令牌、私钥或其他秘密信息。
5. 项目实现笔记和仓库约定留在仓库里，不要复制到本目录。
6. 在 `user.md`、`relationships.md` 和 `goals.md` 中替换已有条目，不要另起一条重复内容。
7. 当前任务变化时，完整重写 `focus.md`，并且只保留该文件里的字段。下一步只写在这里。
8. 在 `goals.md` 中记录状态、优先级、完成标准，以及可选的 `Due` 日期。目标完成后移入 Completed。
9. 向 `experiences.md` 追加条目，不改写更早的条目。教训变成长期规则时，把规则写入 `user.md`，并在该条目中留下指向。
10. 不要创建上表以外的记忆文件。

## 记忆元数据

`user.md`、`relationships.md`、`goals.md` 和 `experiences.md` 中的条目应包含：

- `Updated`：条目最近一次确认或修改的日期，格式为 `YYYY-MM-DD`。
- `Source`：信息来源，例如 `User`、文件路径或 URL。
- `Confidence`：仅使用 `Confirmed`、`Inferred` 或 `Unverified`。

明确陈述或经过独立验证的信息使用 `Confirmed`，合理推断使用 `Inferred`，仍需核实的信息使用 `Unverified`。

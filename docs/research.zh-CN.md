# DST Skin Research 路线 A：阶段技术证据

记录日期：2026-10-27。目标是诊断正常使用的自有皮肤及原创外观，不扩展为官方权益绕过。

## 证据来源及可复现范围

本次主要依据用户机器中正版安装目录的 `version.txt` 与 `data/databundles/scripts.zip`。版本记录为 **760178**；这仅说明本机安装状态，不证明已是 Steam 最新发行版本。

脚本包 SHA-256：`fab1cab00a0d043e49917bf18adbe8199caf60f1523dcc2e998785f44037893a`。7 个文件的逐文件哈希与行号见 `evidence/source_manifest.json`，该文件不复制游戏代码。脚本只在 `.local-source/` 中供本机可选测试使用，不进入仓库、ZIP 或 Bundle。

旧会话的压缩包和 Git Bundle 均不可访问；读取引用会话最近 3 轮后，附件列表为空。因此没有旧 MOD、测试或 Actions 文件可供完整审计。下列与旧实现有关的判断仅针对会话里可见片段：早期示例在 modmain 顶层访问 `TheWorld.ismastersim`，有初始化时机风险；而 `GetClothing().base` 在当前实际源码中成立，不应误报为 API 使用错误。旧回复中的“Lua 5.4 通过”不能替代本次 Lua 5.1 检查。

## 权限和状态链路

| 环节 | 本机文件与一基行号 | 本次确认 |
|---|---|---|
| 本地外观选择 | `playerprofile.lua:202–212, 264–299` | 服装列表使用本地 `CheckOwnership`；读取角色选择会执行本地校验 |
| 本地选择校验 | `skinsutils.lua:1504–1519` | 对选择项查询本地拥有权；非基础项检查服装类型 |
| 发出生成请求 | `mainfunctions.lua:2026–2055` | 选择结果交给 `TheNet:SendSpawnRequestToServer`，进入原生边界 |
| 服务端生成校验 | `networking.lua:194–246` | 基础皮肤、服装、角色列表分别处理 |
| 生成后应用 | `networking.lua:250–260, 276–284` | 从 sim 回调应用 Skinner 状态 |
| 主模拟初始化 | `prefabs/player_common.lua:2611–2615, 2834` | 客户端提前返回；后续主模拟路径加入 Skinner |
| 基础数据载入 | `components/skinner.lua:577–612` | 皮肤 prefab 数据转换为模式 build；关联胡须有独立拥有权查询 |
| 动画与网络提交 | `components/skinner.lua:459–483` | 先应用动画，再回调，再提交五项网络皮肤标识 |
| 原生动画入口 | `components/skinner.lua:11–45` | `SetSkinsOnAnim` 在非 `NO_BASE` 模式调用 `AnimState:SetSkin` |
| 复制外观 | `components/skinner.lua:682–706` | 调用 `AssignItemSkins` 时包含来源 userid，随后应用动画 |
| 存档恢复 | `components/skinner.lua:822–872` | 游戏中加载与快照恢复的检查条件不同 |

以上行号对应本次哈希，更新游戏后须重新生成。

实际可见链路是：

```text
Profile / UI 本地选择和校验
  → TheNet:SendSpawnRequestToServer [原生实现未知]
  … ValidateSpawnPrefabRequest [Lua 入参/返回值已审查]
  … SpawnNewPlayerOnServerFromSim [Lua 回调已审查]
  → Skinner:SetClothing / SetSkinName / SetSkinMode
     → SetSkinsOnAnim → AnimState:SetSkin [原生实现未知]
     → base_change_cb（如有）
     → Network:SetPlayerSkin [原生实现未知]
        … 远端状态接受和最终渲染 [本次未执行]
```

实线表示源码内直接调用；省略号表示中间经过原生实现，本次没有追踪其运行或证明内部调用顺序。不能把两个 Lua 入口的存在自动当成完整网络调用证据。

## 生成入口的精确边界

`ValidateSpawnPrefabRequest` 对正常角色的默认 `<prefab>_none` 分支直接接受基础外观，不发起该项库存查询；这不表示已验证付费角色 entitlement。其他基础皮肤必须先通过 `CheckClientOwnership(user_id, skin_base)`，再出现在该角色的 `PREFAB_SKINS` 中。拥有其他角色的皮肤不满足此处的归属检查。

四个服装参数独立经过非空、拥有权和 `IsClothingItem` 检查。此入口没有逐参数验证服装必须属于对应槽位；后续 `Skinner:SetClothing` 使用服装元数据决定槽位。这个细节不能扩张为未授权服装可用。MOD 角色在此不使用官方基础皮肤分支；无效角色有列表回退。当前版本还检查 seamless swap 角色的允许条件。

`SetSkinName`、`SetClothing` 是状态应用方法，不能独立作为外部不可信请求的授权边界。本工程没有暴露接受任意皮肤名的 RPC，也没有调用这些方法修改外观。它依赖正常游戏入口选择已经拥有的外观，再观察结果。

## SetSkin 和 SetPlayerSkin 的参数并不等价

`SetSkinName` 保存逻辑皮肤标识，并从对应 prefab 的 `skins` 表读取不同模式的动画 build。`SetSkinMode` 在普通、幽灵等模式中选择 build；`SetSkinsOnAnim` 最终把 build 与 fallback 交给 `AnimState:SetSkin`。

之后 `Network:SetPlayerSkin` 收到的是基础皮肤标识、body、hand、legs、feet 五个字符串。它没有在这个 Lua 调用位置显式接收 userid。不能据此断言引擎缺乏身份绑定——身份可能关联于实体或网络对象，本次未确认。五个参数也没有在该调用点直接携带全部动画模式、符号覆盖和 build 选择，不能假设这是完整的线上传输协议。

`CopySkinsFromPlayer` 则把来源 userid 交给 `AnimState:AssignItemSkins`，其源码注释称这一过程用于与 AnimState 验证。可以确认此关联信息存在；没有 C++ 源码或执行证据，不能声称已经知道内部权益判定和缓存规则。

在已扫描脚本中，`Network:SetPlayerSkin` 的直接调用位于 Skinner；相关接口的 C++ 实现不在本次读取的 Lua 包内。这里的结论是证据不足，而不是引擎已经允许或已经拒绝某个未执行场景。

## OnLoad 的场景差异

游戏进行中，存在 userid 时，服装会逐项查询拥有权，未拥有项清空；非默认基础皮肤也需拥有权通过，否则回退默认。快照恢复阶段 `InGamePlay()` 为假时，源码刻意延后库存验证，因为此时玩家未实际登录。

另一个细节是：游戏进行中但缺少 userid，基础皮肤会回退，而服装库存校验分支不执行。本次使用合成输入确认了该 Lua 分支，不能据此认定真实登录流程能进入任何指定状态，更不能将暂存值解释为已获授权。世界快照恢复、玩家重连和角色重新创建必须分别取证。

## 客户端边界和原创资源

本地选择 UI 的拥有权查询、服务端对玩家拥有权的判断、原生动画的接受行为、远端观察者的最终显示是四类证据。读取服务端 Skinner 的值只说明一份服务器状态；即便日志显示 `owned`，也不能证明某个远端客户端已经呈现该外观。

玩家 B 观察玩家 A 的合法皮肤，与 B 自己能否装备该皮肤是不同问题。实际测试应让 A 正常选择其拥有的皮肤，B 仅观察，不向 B 注入装备请求。不能用观察者本地库存代替发送玩家的权益检查。

原创外观必须具有独立资源来源和命名，避免覆盖官方库存或复用官方受限资源实现授权规避。对于新增动画资源，客户端需要获得相应资源是工程上的预期，不能将“服务器注册了新 build 名称”当作原版客户端能够显示的证据。本阶段尚未创建原创动画包，也未确认任何自定义资源分发路径。

## 诊断工程审计

| 项目 | 当前实现 | 局限 |
|---|---|---|
| 初始化 | 玩家回调内检查世界和主模拟 | 未在真实加载流程验证 |
| 采样 | 10 秒周期、仅状态变化输出 | 中间瞬时状态可能漏采 |
| 方法跟踪 | 默认关；可选在实例方法完成后采样 | 仅证明 Lua 方法返回，不是原生 API trace；其他 MOD 后续覆盖方法时不保证仍能观测 |
| 错误与返回值 | 原方法错误继续抛出；保留 nil 返回槽位；日志异常隔离 | 不承诺与所有其他 MOD 组合兼容 |
| 权益查询 | 调用原库存接口，不替换结果；异常单列 | 不推断引擎缓存、刷新时序或交易最终状态 |
| 日志 | 临时标签、特殊字符编码、无 userid 输出 | 分片/重启/重连需人工关联；时间戳依赖服务器日志外层 |
| 生命周期 | 实体移除时取消周期任务 | 需实机确认游戏调度行为 |
| CI | 只读 token、固定 checkout 提交、Lua 5.1、无游戏资产 | 普通 CI 不执行原始源码测试，更不是游戏联机测试 |

模拟测试固定了接口契约；源码分支测试运行的是本机提取的原函数，使用合成库存与 native stub。因此二者互补，但都不能证明引擎和网络行为。曾出现的源码测试 Lua pattern 错误已修复并重新通过；没有将首次失败记为通过。

## 外部资料的证据等级

Klei 论坛中，2016 年 [Random Characters Only?](https://kleiforums.com/forums/topic/70716-random-characters-only/) 的开发者讨论描述生成请求经过 C 层回到 Lua 校验。它是历史作者观察，仅用于解释为什么两个 Lua 回调间存在不可见部分，不是版本 760178 的原生执行证据。

2023 年 [NPC 外观讨论](https://kleiforums.com/forums/topic/147418-help-how-to-use-checkclientownership-to-get-my-npcs-to-look-like-dlc-characters/) 报告需要配合 `AssignItemSkins` 和 `SetSkinsOnAnim`，也出现显示及重载问题。它支持进一步实验的必要性，不证明现代版本的通用同步效果。本工程不移植其中临时改变玩家外观的实验代码。

Lua 环境语义参照 [Lua 5.1 官方手册](https://www.lua.org/manual/5.1/manual.html)。可选运行器来自 [Lupa 2.6](https://pypi.org/project/lupa/2.6/)，本次显式验证 `_VERSION == 'Lua 5.1'`。CI 的 checkout SHA 已由 [actions/checkout v4.2.2 标签](https://github.com/actions/checkout/tree/v4.2.2) 查询核实。远程 CI 的实际结果另行记录，不能以已配置 workflow 代替已运行。

## 下一步与停止条件

下一步是独立测试世界中的默认外观、自有官方皮肤、衣柜正常换装、重连、世界重启和地洞迁移；每项需要服务器日志及观察客户端画面。完整表见 `live-test-plan.zh-CN.md`。未拥有的皮肤只在合成库存测试中作为拒绝输入，不在真实账号上尝试装备。

如果服务器状态、原生调用与观察者画面不一致，先记录版本、场景和原始证据，不通过移除拥有权检查来修复。如果新增资源未正常分发，先按正常 MOD 资源机制处理，不尝试把任意新名称当作官方皮肤标识发送。当前没有足以判定原生接口内部行为的证据，不编造其实现。

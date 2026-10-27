# DST Skin Research · 路线 A

研究合法、自有皮肤与原创外观的服务器诊断及同步边界。保留游戏原有授权流程，不提供解锁、库存伪造、权益替换或官方付费资源提取功能。

本工程是 **2026-10-27 新建的 0.2.0 工程**。旧会话中的 `/mnt/data/dst-skin-research.zip` 和 `.bundle` 在当前 Windows 会话不可访问，引用会话也没有可恢复附件。本工程不包含旧提交历史，不宣称已经审计旧压缩包。

目前已核对本机安装版本 **760178** 的 7 个 Lua 文件。Lua 5.1 语法检查通过，诊断 MOD 的 12 项模拟测试和原始 Lua 函数的 12 项分支测试通过。它们均不是真实 DST 服务端或客户端测试。原生动画接口、网络传输和远端渲染尚未执行验证。

用户最初要求私有仓库；发现同名公开空仓库后暂停上传。用户随后明确回复“允许公开提交”，因此允许提交本工程的原创代码及不含游戏源码的研究记录。未修改 DST-changqing。

## 交付结构

| 路径 | 内容 |
|---|---|
| `mod/` | 只读诊断 MOD；默认每 10 秒采样，仅输出变化 |
| `tests/mock_runtime.lua` | MOD 环境、异常隔离、返回值和生命周期测试 |
| `tests/source_boundary.lua` | 使用本机原始 Lua 函数的可选分支测试 |
| `tools/audit_local.py` | 从自有安装读取脚本，生成哈希与行号；提取内容忽略提交 |
| `tools/run_checks.py` | 可选 Lupa Lua 5.1 测试入口 |
| `.github/workflows/ci.yml` | Lua 5.1 语法、模拟测试及静态回归检查 |
| `evidence/source_manifest.json` | 本次源码版本、SHA-256 和调用位置，不含游戏代码 |
| `docs/research.zh-CN.md` | 技术结论、证据层级与原生接口未知边界 |
| `docs/live-test-plan.zh-CN.md` | 尚未执行的双客户端实验及验收表 |

## 本地检查

从工程根目录运行，原生 Lua 5.1 路径：

```sh
lua5.1 tests/mock_runtime.lua
python tools/check_guardrails.py
```

也可安装 PyPI 的 `lupa==2.6`，明确选择其 `lua51` 后端：

```sh
python -m pip install lupa==2.6
python tools/run_checks.py
```

可选：在持有正版游戏脚本的机器上，提取到被忽略的目录并核对原始分支：

```sh
python tools/audit_local.py "<DST 安装目录>"
python tools/run_checks.py --local-source
```

普通 GitHub CI 不包含或下载游戏脚本，因而不运行这 12 项本机源码测试。不要将 `.local-source/` 上传。`check_guardrails.py` 只是针对常见错误的正则回归检查，不是安全证明。

## 诊断 MOD 的使用

将 `mod/` 的内容放入独立测试安装的 `mods/dst_skin_probe/` 并在测试世界启用。不要覆盖已有 MOD。使用本地 MOD 的专用服务器须在对应世界的 `modoverrides.lua` 中启用 `dst_skin_probe`；保留其他配置。此步骤尚未在游戏内验证。

默认不要求普通客户端安装；仅在主模拟实例的玩家回调中工作。配置 `trace_methods` 默认关闭，开启后会对玩家实例的四个 Skinner 方法增加完成日志。它不拦截原生 AnimState/Network 接口，也不记录网络包。

日志以 `[DST-Skin-Probe]` 开头，后接制表符分隔的 `key=value`。特殊字符采用 `%XX` 编码。`p1` 等是本次 MOD 实例内的临时标签，不是用户账号；重连、分片和重启后不保证标签连续。MOD 不输出 userid，也不发送遥测。人工对照表仍需区分地面、洞穴与观测客户端。

权益状态包括 `owned`、`not_owned`、`error`、`unknown`、`unavailable`、`no_user`、`empty` 和 `default_not_queried`。默认基础外观不查询库存，不代表付费角色权益已验证。查询失败不能解释为未拥有；状态快照也不能证明客户端已正确显示。

## 研究边界

本机脚本显示：生成入口检查非默认基础皮肤的拥有权和角色归属；服装有独立检查；存档加载按场景重新验证；Skinner 会依次调用动画和网络接口。但这些 Lua 调用不能证明引擎内部的授权、网络接受或最终渲染结果。

原创资源应采用独立命名并正常分发给需要加载它们的客户端；仅向服务器加入任意新 build 名称，不能据此认为原版客户端已经具有资源。本阶段没有制作原创动画资源包，也没有完成任何联机显示测试。

查看 [研究报告](docs/research.zh-CN.md) 和 [实际测试计划](docs/live-test-plan.zh-CN.md)。

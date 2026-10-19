# singbox-easytier（单仓）

**一个仓、一条流水线**：sing-box（reF1nd 线）里把 EasyTier 组网内核以 wazero **内嵌为 `easytier` 出站**，
与 SFA（sing-box Android 客户端）合在同一仓，CI 直接产出**已签名的 APK**——
这样一个 `VpnService` 同时承担代理与组网，EasyTier 官方安卓 App 可以退役。

```
sing-box/     sing-box（含内嵌 EasyTier 出站，构建 tag with_easytier）
sfa/          SFA Android 客户端（吃 sing-box/ 构出的 libbox.aar）
scripts/      sync-upstream.sh（三条上游的同步入口）
.github/      regression / apk / release 三条工作流
```

## 上游与归属（重要）

| 目录 | 上游 | 跟踪分支 | 同步方式 |
|---|---|---|---|
| `sing-box/` | [reF1nd/sing-box](https://github.com/reF1nd/sing-box) | `reF1nd-testing` | `git subtree pull`（源码合并） |
| `sfa/` | [reF1nd/sing-box-for-android](https://github.com/reF1nd/sing-box-for-android) | `dev` | `git subtree pull`（源码合并） |
| （无目录） | [EasyTier/easytier](https://github.com/EasyTier/easytier) | `main` / release tag | **依赖 bump**：`go.mod` 里的 `github.com/easytier/easytier/easytier-go`；预编译内核 `easytier-go/internal/artifact/easytier_core.wasm` 随模块交付，故本仓不需要 Rust 工具链 |

上游版权归各上游项目所有，两边均为 Apache-2.0（见 `sing-box/LICENSE`、`sfa/LICENSE`），我们不改许可证。
本仓不是 GitHub 意义上的 fork（原 fork 关系在可见性变更时被平台剥离），因此同步只能走 `scripts/sync-upstream.sh`。

## 用法

```bash
scripts/sync-upstream.sh status     # 只读：三条上游各落后多少 + EasyTier pin 对比
scripts/sync-upstream.sh singbox    # subtree pull reF1nd/sing-box:reF1nd-testing（冲突即停，不自动解）
scripts/sync-upstream.sh sfa        # subtree pull …-for-android:dev
scripts/sync-upstream.sh easytier   # 报告当前 pin 与上游差异，并打印要改的那一行（不自动改）
```

发布：

```bash
gh workflow run release.yml --repo AcccBa/singbox-easytier -f prerelease=true -f attest=true
```

回归门（push 到 `main` 且改了 `sing-box/` 时自动跑）：全 tag 构建 → 自检 `sing-box version` 必须含 `easytier` → `go vet` → `lazy`/`cache_runtime` 默认语义单测。

## 核对与验签（发布物）

```bash
sha256sum -c SHA256SUMS
apksigner verify --print-certs <apk>     # 证书指纹必须等于下面这行
```

签名证书 SHA-256：`b6f677491cc6e1ee0440afbc42568e9e114a6f963a2ee0a8780c7939e40e8012`（`CN=EasyTier Local Build`）。
签名在 CI 的 environment `sign-gate` 内完成，**指纹不符即拒发**；同一哈希另记在 CI 无写权限的仓库（home-mesh 文档）作独立核对。

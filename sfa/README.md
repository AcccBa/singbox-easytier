# SFA

Experimental Android client for sing-box, the universal proxy platform.
> **下游改造说明（fork）** — 本仓基于 [reF1nd/sing-box-for-android](https://github.com/reF1nd/sing-box-for-android) 的 `dev` 线；上游版权归 reF1nd 项目，Apache-2.0 许可证（见 `LICENSE`）保持不变。差别只有一个：`libbox.aar` 由 [AcccBa/easytier-sing-box](https://github.com/AcccBa/easytier-sing-box) 构建（含内嵌 `easytier` 出站，tag `with_easytier`），于是 **一个 VpnService 同时承担代理与组网**，EasyTier 安卓 App 可退役。
>
> 发布物在 Releases（预发布），每条说明附 `SHA256SUMS`。核对与验签：
>
> ```text
> sha256sum -c SHA256SUMS
> apksigner verify --print-certs <apk>    # 证书指纹必须等于下面这行
> ```
>
> 签名证书 SHA-256：`b6f677491cc6e1ee0440afbc42568e9e114a6f963a2ee0a8780c7939e40e8012`（`CN=EasyTier Local Build`）。签名在 CI 的 environment `sign-gate` 内完成，**指纹不符即拒发**。
>
> 注：与上游的 GitHub fork 关系因可见性变更被剥离，同步上游走手工 `git fetch upstream && git merge upstream/dev`。

## Documentation

https://sing-box.sagernet.org/installation/clients/sfa/

## License

```
Copyright (C) 2022 by nekohasekai <contact-sagernet@sekai.icu>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.

In addition, no derivative work may use the name or imply association
with this application without prior consent.
```

Under the license, that forks of the app are not allowed to be listed on F-Droid or other app stores
under the original name.

# 映源 Surge 分流规则

为映源 iOS 的内置苹果 CMS 接口和实际 HLS/CDN 提供可远程引用的 Surge 规则。

最近验证：2026-08-10（UTC+8）

> 适用前提：iPhone 位于中国大陆，`DIRECT` 确实使用大陆网络出口，同时你的代理策略组提供境外出口。人在海外时，`DIRECT` 仍然是海外出口，无法修复只允许大陆 IP 的媒体 403/404。

这些规则只解决网络出口选择，不会修复已失效的播放地址、网页播放器线路或 CMS 数据错误。

## 在 Surge 中引用

把下面两条 `RULE-SET` 规则放在 Surge 配置已有的 `[Rule]` 中，并置于宽泛的代理、`GEOIP`、`FINAL` 规则之前。只有新建配置时才添加一次 `[Rule]` 标题：

```ini
[Rule]
RULE-SET,https://raw.githubusercontent.com/Ricadre/yingyuan-surge-rules/main/ruleset/yingyuan-direct.list,DIRECT
RULE-SET,https://raw.githubusercontent.com/Ricadre/yingyuan-surge-rules/main/ruleset/yingyuan-proxy.list,你的代理策略组名称
```

第二行最后一项必须换成你自己的 Surge 代理节点或策略组名称。`PROXY` 不是 Surge 内建策略，不能在所有配置里通用。

- [DIRECT 规则原始文件](https://raw.githubusercontent.com/Ricadre/yingyuan-surge-rules/main/ruleset/yingyuan-direct.list)
- [代理规则原始文件](https://raw.githubusercontent.com/Ricadre/yingyuan-surge-rules/main/ruleset/yingyuan-proxy.list)
- [仅包含 DIRECT 规则的 Module](https://raw.githubusercontent.com/Ricadre/yingyuan-surge-rules/main/modules/yingyuan-direct.sgmodule)

也可以复制下面的地址到 Safari 打开，安装仅包含 DIRECT 规则的 Module：

```text
surge:///install-module?url=https%3A%2F%2Fraw.githubusercontent.com%2FRicadre%2Fyingyuan-surge-rules%2Fmain%2Fmodules%2Fyingyuan-direct.sgmodule
```

Surge 官方限制 Module 中的 Rule 只能使用 `DIRECT`、`REJECT` 和 `REJECT-TINYGIF`，不能引用用户自定义代理或策略组。因此 Module 只能完成媒体直连，三个 CMS API 的代理规则仍需手动加入主配置。

## 为什么必须拆成两个规则集

苹果 CMS 搜索/详情请求与视频播放请求会访问不同主机，两者可能要求相反的出口。不能把一个“源”整体粗暴地设为直连或代理。

| API 路由 | 当前抽样媒体路由 | 内置源 |
| --- | --- | --- |
| 自动 | **DIRECT** | 量子资源、U酷资源、最大资源、电影天堂资源、暴风资源、无尽资源 |
| **代理** | **DIRECT** | 优质资源站 |
| **代理** | 自动 | iKun资源、魔都资源 |
| 自动 | 自动 | 红牛资源、光速资源、虎牙资源、豪华资源、速播资源、新浪资源、金鹰资源、360资源、西瓜资源、非凡资源、爱奇艺影视、猫眼资源、如意资源、极速资源 |

“自动”表示本轮没有证据要求强制改变出口，让请求继续使用你原有 Surge 配置的匹配结果。表中的 DIRECT 只代表当前已验证且已经列入规则的媒体域名；同一来源轮换到新域名时，未命中的请求仍按你的原配置处理。

最典型的是优质资源站：`api.yzzy-api.com` 在两批大陆三网探针上均连接失败、美国正常，所以 API 需要代理；它返回的部分媒体 CDN 在大陆正常、境外返回 403，所以播放反而必须直连。

## 多地区验证证据

大陆使用中国电信、联通、移动的 eyeball 探针；境外使用美国数据中心探针，关键 403/404 又由本机美国出口复现。测试使用 HTTP GET 并检查响应是 JSON 或 `#EXTM3U`，没有使用可能返回不同结果的 HEAD 请求。

| 内置源 / 请求 | 测试主机 | 大陆 | 美国 | 结论 |
| --- | --- | --- | --- | --- |
| 量子媒体 | `lzcdn33v1.com` | 三网 200 HLS | 404 | DIRECT |
| U酷媒体 | `ukzy.ukubf3.com` | 三网 200 HLS | 403 | DIRECT |
| 最大媒体 | `v2.zuidazym3u8.com` | 三网 200 HLS | 403 | DIRECT |
| 优质媒体 | `cdn.yzzyvip-29.com` | 三网 200 HLS | 403 | DIRECT |
| 优质历史轮换媒体 | `cdn.yzzy31-play.com` | 上海 200，清单与首分片有效 | 美国、日本、新加坡 403 | DIRECT |
| 电影天堂媒体 | `play.phimgood.com` | 三网 200 HLS | 403 | DIRECT |
| 暴风媒体 | `v.fengbao11.com` | 三网 200 HLS | 404 | DIRECT |
| 无尽媒体 | `v10.ppqrrs.com` | 三网 200 HLS | 403 | DIRECT |
| iKun API（第二批复测） | `ikunzy.net` | 三网均 reset | 200 JSON | 代理 |
| 魔都 API（第二批复测） | `moduzy.com` | 三网均 reset | 200 JSON | 代理 |
| 优质 API（第二批复测） | `api.yzzy-api.com` | 三网均 timeout | 200 JSON | 代理 |
| 西瓜媒体重定向终点 | `vip20.jimxtc.com` | 三网 200 HLS | 200 HLS | 自动 |

美国的 404 不能据此认定链接失效：表中同一路径在同一时刻经大陆探针返回有效 HLS，这是服务端按出口地域伪装失败的表现。

## 尚未强制路由的候选域名

以下域名在美国出口出现 403、404 或超时，但尚缺同一路径的大陆三网对照，因此不会凭单侧结果加入规则：

- `ukzyvod3.ukubf5.com`
- `yzzy.play-cdn17.com`
- `vip.dytt-film.com`
- `svip.xgplay3.com`
- `vip.lzcdn2.com`
- `p.bvvvvvvvvv1f.com`
- `v.gsuus.com`
- `play.hhuus.com`

## 范围与更新

- 规则只收录有大陆/境外对照证据的主机，并使用最窄的精确域名或服务商专用后缀；不会使用过宽的 `DOMAIN-KEYWORD` 或易漂移、可能共享的 CDN IP。
- `DOMAIN-SUFFIX` 是为同一媒体服务商的子域轮换预留的有限外推，不代表同名品牌的所有其他注册域都会被自动覆盖。
- CMS 会按影片或剧集轮换媒体域名。新域名不会自动被旧规则命中，需要重新做大陆/境外对照后再加入。
- `main` 链接会滚动更新；需要固定复现某次规则时，可把 URL 中的 `main` 换成 release tag 或 commit SHA。
- DIRECT 会绕过代理并向第三方暴露你的真实出口 IP；不希望这样做时不要启用 DIRECT 列表。
- 极速资源当前抽样地址网络可达，但返回的是 HTML 播放页而不是 HLS。这属于播放器解析兼容性问题，切换出口不会修复。
- 规则更新后，请在 Surge 的外部资源/规则集页面手动刷新，或重新载入配置。

Surge 格式依据：[官方《理解 Surge 原理》](https://manual.nssurge.com/book/understanding-surge/cn/)。

## 许可证

MIT License。网络状态与第三方域名可能随时变化，请自行复核后使用。

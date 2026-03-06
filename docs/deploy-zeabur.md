# Zeabur 部署指南

## 前置准备

开始之前，确认你已准备好以下内容：

- **Zeabur 账号**：已注册并可正常使用
- **管理密码**：想好一个复杂的管理密码（用于登录管理面板）
- **美国住宅代理**（如需使用 Codex / Claude）：准备好代理地址，格式如 `socks5://user:pass@host:port`

### 为什么需要美国住宅代理？

Codex（OpenAI）和 Claude（Anthropic）的 API 会检测请求来源 IP。如果请求来自云服务器的数据中心 IP 或非美国 IP，会被拒绝访问。这是 provider 自身的反滥用策略，不是本项目的限制。

需要代理的 provider：

- **Codex** — 需要美国住宅 IP
- **Claude** — 需要美国住宅 IP
- **Gemini / Vertex / OpenAI Compatibility** — 通常可直连，无需代理

代理协议支持 `socks5`、`http`、`https`。推荐使用美区住宅静态 IP 的 SOCKS5 代理。

---

## 第 1 步：创建服务

1. 进入你的 Zeabur Project
2. 点击 **Add Service** → 选择 **Prebuilt Image**
3. 镜像地址填写：`ghcr.io/dev-longshun/cliproxyapi:latest`
   - 如需固定版本：`ghcr.io/dev-longshun/cliproxyapi:vX.Y.Z`
4. 区域选择 **US West**（美西）
5. 点击创建

> 区域选择在 Zeabur 的资源/区域步骤中，不是在镜像输入框里。

---

## 第 2 步：配置存储挂载

在服务的 **Disks** 设置中，添加一个 Volume：

- 挂载路径：`/root/.cli-proxy-api`

可选：再挂一个日志目录 `/CLIProxyAPI/logs`

> **注意**：不要把 Volume 挂载到 `/CLIProxyAPI/config.yaml` 这个文件路径上，否则会把文件变成目录导致启动失败。

---

## 第 3 步：设置环境变量

在服务的 **Environment Variables** 中添加：

- `MANAGEMENT_PASSWORD` = `你的管理密码`

这个密码用于登录管理面板，建议使用独立的复杂密码。

---

## 第 4 步：设置启动命令

在服务的 **Start Command** 中填写：

```bash
sh -c '[ -f /root/.cli-proxy-api/config.yaml ] || cp /CLIProxyAPI/config.example.yaml /root/.cli-proxy-api/config.yaml; exec ./CLIProxyAPI -config /root/.cli-proxy-api/config.yaml'
```

这条命令的作用：

- 首次启动时，自动从模板生成配置文件到可写目录
- 后续启动直接使用已有配置，不会覆盖

---

## 第 5 步：配置网络

在服务的 **Networking** 设置中：

1. 开启 **Public Network**（公网访问）
2. 对外端口设为 `8317`
3. 使用 Zeabur 分配的域名，或绑定自己的域名

---

## 第 6 步：首次登录管理面板

1. 访问 `https://<你的域名>/management.html`
2. 输入第 3 步设置的管理密码登录
3. 登录后在配置页修改以下内容：
   - `api-keys`：设置你的 API 密钥
   - `remote-management.secret-key`：设置管理密钥（设置后可不再依赖环境变量）
   - 其他按需调整

---

## 第 7 步：导入账号并配置代理

### 7.1 导入 OAuth 账号

在管理面板中完成 OAuth 登录（Codex、Claude 等），导入后在 **Auth Files** 页面确认账号状态为 `active`。

### 7.2 配置代理（关键步骤）

项目支持两个层级的代理配置，优先级从高到低：

- **单账号代理**（`auth.proxy_url`）：针对单个账号生效，优先级最高
- **全局代理**（`config.proxy-url`）：对所有请求生效，优先级较低

推荐做法 — 在管理面板中按账号配置：

1. 打开 **Auth Files** 页面
2. 找到 `provider=codex` 的账号，编辑 `proxy_url` 字段，填入代理地址
3. 找到 `provider=claude` 的账号，同样填写 `proxy_url`
4. 保存

代理地址格式：

- `socks5://user:pass@host:port`
- `http://user:pass@host:port`

如果你希望所有请求都走同一个代理，也可以在管理面板的设置页面直接配置全局 `proxy-url`，这样就不用逐个账号设置了。

> 配置代理不需要修改代码或配置文件，不需要重启服务，在管理面板操作即时生效。

---

## 第 8 步：验证部署

依次检查以下项目：

1. 访问首页，能正常返回（不是 502）
2. 管理面板能正常加载登录页
3. `management.html#/quota` 页面中 Codex / Claude 额度能正常显示
4. 用配置的 API Key 请求一次接口，能正常返回结果
5. 重启服务后，账号和代理设置不丢失

---

## 附录 A：代理配置方式汇总

除了管理面板 GUI 操作外，项目还支持以下方式配置代理：

**通过管理 API 接口**

适合批量操作或自动化脚本：

- 设置全局代理：`PUT /v0/management/proxy-url`，body 为 `{"value": "socks5://user:pass@host:port"}`
- 修改单账号代理：`PATCH /v0/management/auth-files/fields`，body 为 `{"name": "账号名", "proxy_url": "socks5://..."}`

**通过 config.yaml 文件**

适合初始部署时就确定好代理的场景：

```yaml
# 全局代理
proxy-url: "socks5://user:pass@host:port"

# 或在具体 provider key 中配置
codex-api-key:
  - api-key: "sk-xxx"
    proxy-url: "socks5://user:pass@host:port"

claude-api-key:
  - api-key: "sk-xxx"
    proxy-url: "socks5://user:pass@host:port"
```

修改 config.yaml 后需要重启服务才能生效。

---

## 附录 B：常见问题与故障排查

### `read /CLIProxyAPI/config.yaml: is a directory`

原因：Volume 挂载到了文件路径 `/CLIProxyAPI/config.yaml`，导致该路径变成了目录。

处理：移除该挂载，改为挂载到 `/root/.cli-proxy-api` 目录，使用第 4 步的启动命令。

### `open /CLIProxyAPI/config.yaml: no such file or directory`

原因：使用了默认路径启动，但该路径没有配置文件。

处理：使用第 4 步的启动命令（带自动复制逻辑）。

### 管理面板改配置提示只读

原因：运行配置文件位于只读的 Config File 挂载中。

处理：改为使用 `/root/.cli-proxy-api/config.yaml` 作为运行配置。

### 额度获取失败 / 请求返回 403

优先检查：

- 该账号是否已配置代理（Codex / Claude 必须配置美国住宅代理）
- 代理地址是否正确，账号密码是否过期
- OAuth 凭证是否已失效（尝试重新登录）

### 代理配置了但仍然无法访问

排查步骤：

- 确认代理格式正确：`socks5://user:pass@host:port`（注意协议前缀不能省略）
- 确认代理是住宅 IP 而非数据中心 IP
- 确认代理 IP 在美国区域
- 在 Auth Files 中确认 `proxy_url` 字段已保存成功

---

## 附录 C：后续维护

### 更换代理线路

1. 进入管理面板 → **Auth Files**
2. 修改 Codex / Claude 账号的 `proxy_url` 为新地址
3. 保存
4. 在 **Quota** 页面刷新验证

### 更新镜像版本

在 Zeabur 服务设置中更新镜像 tag，或使用 `latest` 自动获取最新版本后重启服务。

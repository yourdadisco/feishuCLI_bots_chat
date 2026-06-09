# 三 Agent 协作系统 - Zeabur 部署

## 部署步骤

### 1. 推送到 GitHub

```bash
# 在 zeabur-bot-team 目录下
git init
git add .
git commit -m "init"
# 在 GitHub 创建仓库后
git remote add origin https://github.com/你的用户名/bot-team.git
git push -u origin main
```

### 2. 在 Zeabur 部署

1. 打开 [Zeabur](https://zeabur.com) → 新建项目
2. 导入 GitHub 仓库
3. Zeabur 自动识别 Node.js，部署

### 3. 配置环境变量

在 Zeabur 项目设置中添加：

| 变量名 | 值 |
|---|---|
| `DIRECTOR_APP_ID` | `cli_aaad7bd6d33a5bcf` |
| `DIRECTOR_APP_SECRET` | `XgwERkjh4KOfFd1pI6MydeSJOFpI0QGs` |
| `PM_APP_ID` | `cli_aaad306c77b91bc3` |
| `PM_APP_SECRET` | `34JhfWyRx1E7hZHjiABWrg7pao2Ri0J0` |
| `ENGINEER_APP_ID` | `cli_aaad323347a4dbc4` |
| `ENGINEER_APP_SECRET` | `UURsYT81a1bxNLq7uI6vfc72BdeKc0RB` |
| `CHAT_ID` | `oc_88cdd7c54cf79fca0b959644630f9b6d` |
| `DEEPSEEK_API_KEY` | `sk-8dc66b7474cf4c19b3e77fb9bcedc92d` |

### 4. 配置飞书事件订阅

部署后拿到 Zeabur 的 URL（如 `https://bot-team.zeabur.app`），然后：

1. 打开 [飞书开发者后台](https://open.feishu.cn/app)
2. 三个应用（Abot、Bbot、产品总监）都要配：
   - 进入「事件与回调」
   - **请求地址**填 `https://你的域名.zeabur.app`
   - 「添加事件」→ `im.message.receive_v1`
   - 飞书会发验证请求，通过后保存
   - 发布新版本上线

### 5. 使用

在群里 @张总 + 你的需求，三 Agent 自动讨论给出结论。

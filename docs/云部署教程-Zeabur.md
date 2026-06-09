# Zeabur 云部署

部署后，群里 @产品总监 发需求，三 Agent 自动讨论出结论。

---

## 部署

1. 把代码推送到 GitHub
2. 打开 [Zeabur](https://zeabur.com)，导入仓库
3. Zeabur 自动识别 Node.js 并部署
4. 在项目 **Environment** 添加环境变量：

| 变量 | 值 |
|:---|:---|
| `DIRECTOR_APP_ID` | 产品总监的 App ID |
| `DIRECTOR_APP_SECRET` | 产品总监的 App Secret |
| `PM_APP_ID` | 产品经理的 App ID |
| `PM_APP_SECRET` | 产品经理的 App Secret |
| `ENGINEER_APP_ID` | 研发工程师的 App ID |
| `ENGINEER_APP_SECRET` | 研发工程师的 App Secret |
| `CHAT_ID` | 群聊 ID |
| `DEEPSEEK_API_KEY` | DeepSeek API Key |

5. 拿到分配的域名（`xxx.zeabur.app`）

## 配置事件订阅

到飞书开发者后台，**三个应用都要做**：

1. 进入应用 → **「事件与回调」**
2. 请求地址填：`https://你的域名.zeabur.app`
3. 添加事件：`im.message.receive_v1`
4. 保存，发布新版本上线

## 使用

在群里 @产品总监 发需求即可，自动触发讨论。

# Zeabur 云部署教程

> 将 `server.js` 部署到 Zeabur，实现群里 @产品总监 自动响应，24小时在线。

---

## 前置条件

- 三个飞书应用已创建完毕（见 [`飞书机器人创建教程.md`](飞书机器人创建教程.md)）
- 三个应用的 **App ID** 和 **App Secret**
- 群聊 ID

---

## 第一步：推送到 GitHub

把项目代码推送到你的 GitHub 仓库。

```bash
git push origin main
```

## 第二步：Zeabur 导入部署

1. 打开 [Zeabur](https://zeabur.com)，用 GitHub 登录
2. 点击 **「New Project」** → **「Import from GitHub」**
3. 选择本项目的仓库
4. Zeabur 会自动识别 Node.js，开始部署

## 第三步：配置环境变量

部署完成后，进入项目 **「Environment」** 选项卡，添加以下变量：

| 变量名 | 值 |
|:---|:---|
| `DIRECTOR_APP_ID` | 产品总监的 App ID |
| `DIRECTOR_APP_SECRET` | 产品总监的 App Secret |
| `PM_APP_ID` | 产品经理的 App ID |
| `PM_APP_SECRET` | 产品经理的 App Secret |
| `ENGINEER_APP_ID` | 研发工程师的 App ID |
| `ENGINEER_APP_SECRET` | 研发工程师的 App Secret |
| `CHAT_ID` | 群聊 ID（`oc_xxx`） |
| `DEEPSEEK_API_KEY` | DeepSeek API Key |

## 第四步：拿到域名

部署成功后，Zeabur 会分配一个域名，类似：

```
https://你的项目名.zeabur.app
```

## 第五步：配置事件订阅

到飞书开发者后台，**三个应用都要做**：

1. 进入应用 → **「事件与回调」**
2. **「请求地址配置」** 填你的 Zeabur 域名：
   ```
   https://你的项目名.zeabur.app
   ```
3. **「添加事件」** → 搜索 `im.message.receive_v1` → 添加
4. 点击 **「完成」**（飞书会自动验证地址）
5. 保存 → **发布新版本上线**

## 第六步：使用

在群里 @产品总监 发需求，自动触发团队讨论：

```
@产品总监 我们想做AI客服，分析一下用户需求和可行性
```

> 如果 @产品总监 没反应，检查 Zeabur 是否正常运行，以及事件订阅是否配置正确。

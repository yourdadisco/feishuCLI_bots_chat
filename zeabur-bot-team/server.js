const express = require('express');
const app = express();
app.use(express.json());

// ======================== 配置 ========================
const CONFIG = {
  // 三个 Bot 的凭证（从环境变量读取）
  director: { appId: process.env.DIRECTOR_APP_ID, appSecret: process.env.DIRECTOR_APP_SECRET },
  pm:       { appId: process.env.PM_APP_ID,       appSecret: process.env.PM_APP_SECRET },
  engineer: { appId: process.env.ENGINEER_APP_ID,  appSecret: process.env.ENGINEER_APP_SECRET },
  // 群聊 ID
  chatId: process.env.CHAT_ID || 'oc_88cdd7c54cf79fca0b959644630f9b6d',
  // DeepSeek API Key
  apiKey: process.env.DEEPSEEK_API_KEY,
};

// 已处理消息去重
const processed = new Set();

// ======================== 飞书 API ========================
async function getToken(cfg) {
  const r = await fetch('https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ app_id: cfg.appId, app_secret: cfg.appSecret }),
  });
  const data = await r.json();
  return data.tenant_access_token;
}

async function sendMessage(cfg, text) {
  const token = await getToken(cfg);
  const safe = text.replace(/"/g, '\\"').replace(/\n/g, '\\n');
  await fetch(`https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=chat_id`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json; charset=utf-8',
    },
    body: JSON.stringify({
      receive_id: CONFIG.chatId,
      msg_type: 'text',
      content: JSON.stringify({ text }),
    }),
  });
}

// ======================== DeepSeek AI ========================
async function callDeepSeek(systemPrompt, context, name, task) {
  const userPrompt = `用户任务：${task}\n\n${context}\n\n现在${name}发言。针对任务直接给出专业分析，不要说需要更多信息。`;
  const r = await fetch('https://api.deepseek.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${CONFIG.apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'deepseek-chat',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      temperature: 0.85,
      max_tokens: 400,
    }),
  });
  const data = await r.json();
  return data.choices?.[0]?.message?.content?.trim() || '';
}

// ======================== 团队讨论 ========================
async function runTeamDiscussion(task) {
  if (processed.has(task)) { return; }
  processed.add(task);
  console.log(`[任务] ${task}`);

  const history = [];
  const ctx = () => history.slice(-20).join('\n');

  const directorSys = '你是张总，产品总监，团队决策者。工作：1)@阿博做产品分析 2)@阿布做技术评估 3)给用户总结。围绕用户具体任务。每条消息以@开头。';
  const pmSys = '你是阿博，热情的产品经理。以"@张总"开头。针对用户任务分析需求、目标用户、市场机会。用表情符号。';
  const engineerSys = '你是阿布，技术负责人。以"@张总"开头。针对用户任务评估可行性、成本、周期。不用表情。';

  const steps = [
    { cfg: 'director', sys: directorSys, name: '张总', fallback: '@阿博 你做产品分析，分析用户需求。' },
    { cfg: 'pm', sys: pmSys, name: '阿博', fallback: '@张总 我来分析用户需求🎯' },
    { cfg: 'director', sys: directorSys, name: '张总', fallback: '@阿布 你做技术评估。' },
    { cfg: 'engineer', sys: engineerSys, name: '阿布', fallback: '@张总 技术上可行。' },
    { cfg: 'director', sys: directorSys, name: '张总', fallback: '【总结】产品分析：... 技术评估：... 建议：...' },
  ];

  for (const step of steps) {
    const msg = await callDeepSeek(step.sys, ctx(), step.name, task) || step.fallback;
    await sendMessage(CONFIG[step.cfg], msg);
    history.push(`${step.name}: ${msg}`);
    console.log(`  ${step.name}: ${msg.substring(0, 50)}...`);
    // 等待几秒模拟思考
    await new Promise(r => setTimeout(r, 3000));
  }

  console.log(`[完成] ${task}`);
}

// ======================== Webhook ========================
app.post('/', async (req, res) => {
  const body = req.body;

  // 飞书 URL 验证挑战
  if (body.challenge) {
    return res.json({ challenge: body.challenge });
  }

  // 处理消息事件
  if (body.header?.event_type === 'im.message.receive_v1') {
    const event = body.event;
    // 只处理群聊中非 bot 的消息
    if (event.chat_type === 'group' && event.sender.sender_type !== 'app') {
      const msgId = event.message_id;
      let text = event.content;
      try { text = JSON.parse(text).text; } catch {}
      console.log(`[收到] ${text}`);
      // 异步处理，立即返回 200
      runTeamDiscussion(text).catch(e => console.error(e));
    }
  }

  res.status(200).end();
});

// ======================== 健康检查 ========================
app.get('/', (req, res) => res.send('Bot Team Webhook Running'));

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));

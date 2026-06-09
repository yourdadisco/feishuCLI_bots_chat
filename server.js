const http = require('http');
const https = require('https');

// ======================== 配置 ========================
const CFG = {
  director: { id: process.env.DIRECTOR_APP_ID, secret: process.env.DIRECTOR_APP_SECRET },
  pm:       { id: process.env.PM_APP_ID,       secret: process.env.PM_APP_SECRET },
  engineer: { id: process.env.ENGINEER_APP_ID,  secret: process.env.ENGINEER_APP_SECRET },
  chatId: process.env.CHAT_ID || 'oc_88cdd7c54cf79fca0b959644630f9b6d',
  apiKey: process.env.DEEPSEEK_API_KEY,
};

const processed = new Set();

// ======================== 飞书 API ========================
async function getToken(cfg) {
  const r = await fetch('https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ app_id: cfg.id, app_secret: cfg.secret }),
  });
  return (await r.json()).tenant_access_token;
}

async function sendMsg(cfg, text) {
  const token = await getToken(cfg);
  // 飞书消息有限制，超长时分段发送
  const MAX = 1000;
  const parts = [];
  for (let i = 0; i < text.length; i += MAX) {
    parts.push(text.substring(i, i + MAX));
  }
  for (const part of parts) {
    await fetch('https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=chat_id', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify({
        receive_id: CFG.chatId, msg_type: 'text',
        content: JSON.stringify({ text: part.replace(/"/g, '\\"') }),
      }),
    });
  }
}

// ======================== DeepSeek ========================
async function askAI(system, context, name, task) {
  const r = await fetch('https://api.deepseek.com/v1/chat/completions', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${CFG.apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: 'deepseek-chat',
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: `用户任务：${task}\n\n${context}\n\n现在${name}发言。针对任务直接给出专业分析。` },
      ],
      temperature: 0.85, max_tokens: 1200,
    }),
  });
  return (await r.json()).choices?.[0]?.message?.content?.trim() || '';
}

// ======================== 团队讨论 ========================
async function runTeam(task) {
  if (processed.has(task)) return;
  processed.add(task);
  console.log(`[任务] ${task}`);
  const h = [];
  const ctx = () => h.slice(-20).join('\n');
  const steps = [
    { k: 'director', s: '你是产品总监，产品总监。工作：1)@产品经理做产品分析 2)@研发做技术评估 3)给总结。', n: '产品总监', fb: '@产品经理 你做产品分析。' },
    { k: 'pm', s: '你是产品经理，产品经理。以@产品总监开头。分析需求、市场。用表情。', n: '产品经理', fb: '@产品总监 我来分析用户需求🎯' },
    { k: 'director', s: '你是产品总监，产品总监。工作：1)@产品经理做产品分析 2)@研发做技术评估 3)给总结。', n: '产品总监', fb: '@研发 你做技术评估。' },
    { k: 'engineer', s: '你是研发，技术负责人。以@产品总监开头。评估可行性、成本。不用表情。', n: '研发', fb: '@产品总监 技术上可行。' },
    { k: 'director', s: '你是产品总监，产品总监。工作：1)@产品经理做产品分析 2)@研发做技术评估 3)给总结。', n: '产品总监', fb: '【总结】产品分析结论+技术评估+建议。' },
  ];
  for (const s of steps) {
    const msg = await askAI(s.s, ctx(), s.n, task) || s.fb;
    await sendMsg(CFG[s.k], msg);
    h.push(`${s.n}: ${msg}`);
    console.log(`  ${s.n}: ${msg.substring(0, 50)}`);
    await new Promise(r => setTimeout(r, 3000));
  }
  console.log(`[完成] ${task}`);
}

// ======================== HTTP 服务 ========================
const server = http.createServer(async (req, res) => {
  // 统一响应头
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Access-Control-Allow-Origin', '*');

  // 收集 body
  let body = '';
  req.on('data', chunk => body += chunk);
  req.on('end', async () => {
    try {
      console.log(`[${req.method}] ${req.url}`);

      // GET - 健康检查
      if (req.method === 'GET') {
        res.writeHead(200);
        return res.end(JSON.stringify({ status: 'ok', message: 'Bot Team Webhook Running' }));
      }

      // POST - 处理事件
      if (req.method === 'POST') {
        let data;
        try { data = JSON.parse(body); } catch {
          res.writeHead(400);
          return res.end(JSON.stringify({ error: 'invalid json' }));
        }

        // 飞书 URL 验证挑战
        if (data.challenge) {
          console.log(`[验证] challenge: ${data.challenge}`);
          res.writeHead(200);
          return res.end(JSON.stringify({ challenge: data.challenge }));
        }

        // 消息事件
        if (data.header?.event_type === 'im.message.receive_v1') {
          const ev = data.event;
          console.log('[事件]', JSON.stringify(data).substring(0, 500));

          // 兼容两种事件格式: flat 和 {message: {...}}
          const chatType = ev.chat_type || ev.message?.chat_type;
          const senderType = ev.sender?.sender_type || ev.sender_type;
          const msgId = ev.message_id || ev.message?.message_id;
          let rawContent = ev.content || ev.message?.content || '';

          if (chatType === 'group' && senderType !== 'app') {
            let text = rawContent;
            try { text = JSON.parse(text).text; } catch {}
            console.log(`[收到@消息] ID=${msgId} 内容=${text}`);
            if (msgId && !processed.has(msgId)) {
              processed.add(msgId);
              runTeam(text).catch(e => console.error(e));
            }
          } else {
            console.log(`[跳过] chatType=${chatType} senderType=${senderType}`);
          }
        }

        res.writeHead(200);
        return res.end(JSON.stringify({ ok: true }));
      }

      // 其他方法
      res.writeHead(405);
      res.end(JSON.stringify({ error: 'method not allowed' }));

    } catch (e) {
      console.error('[错误]', e);
      res.writeHead(500);
      res.end(JSON.stringify({ error: e.message }));
    }
  });
});

const PORT = process.env.PORT || 8080;
server.listen(PORT, '0.0.0.0', () => console.log(`Server running on port ${PORT}`));

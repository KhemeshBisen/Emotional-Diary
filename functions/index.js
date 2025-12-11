const functions = require('firebase-functions');
const admin = require('firebase-admin');
const fetch = require('node-fetch');

admin.initializeApp();

const HF_API_KEY = process.env.HF_API_KEY;


// ----------------- Helpers -----------------
async function callHFModel(model, payload) {
  const url = `https://router.huggingface.co/hf-inference/models/${model}`;
  console.log('Calling HF URL:', url);

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${HF_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  const text = await res.text();
  console.log('HF status:', res.status, 'body:', text);

  let json;
  try {
    json = JSON.parse(text);
  } catch (e) {
    throw new Error(`HF non-JSON response (status ${res.status}): ${text}`);
  }

  if (!res.ok || (json.error && !Array.isArray(json))) {
    throw new Error(`HF error (${res.status}): ${JSON.stringify(json)}`);
  }

  return json;
}


// resp se first {label, score} safely nikaalne ka helper
function getLabelScore(resp) {
  // resp: [{label,score}] OR [[{label,score},...]]
  if (!Array.isArray(resp) || resp.length === 0) {
    return { label: null, score: 0 };
  }

  if (Array.isArray(resp[0])) {
    const inner = resp[0][0];
    if (inner && typeof inner === 'object') {
      return {
        label: inner.label || null,
        score: inner.score || 0,
      };
    }
  }

  if (resp[0] && typeof resp[0] === 'object') {
    return {
      label: resp[0].label || null,
      score: resp[0].score || 0,
    };
  }

  return { label: null, score: 0 };
}

function mapSentimentToRange(label, score) {
  if (!label) return 0;
  const l = label.toLowerCase();
  if (l.includes('neg')) return -score;
  if (l.includes('pos')) return score;
  return score >= 0.5 ? score : 0;
}

// ----------------- Main function -----------------

exports.processEntry = functions.https.onRequest(async (req, res) => {
  try {
    // CORS
    res.set('Access-Control-Allow-Origin', '*');
    if (req.method === 'OPTIONS') {
      res
        .set('Access-Control-Allow-Methods', 'POST')
        .set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
      return res.status(204).send('');
    }

    // Auth
    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ ok: false, error: 'missing_id_token' });
    }

    const idToken = authHeader.split('Bearer ')[1];
    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    const { text, audioUrl } = req.body || {};
    if (!text) {
      return res.status(400).json({ ok: false, error: 'missing_text' });
    }

   
    // 1) Sentiment
    const sentimentModel = 'distilbert/distilbert-base-uncased-finetuned-sst-2-english';
    const sResp = await callHFModel(sentimentModel, { inputs: text });
    const { label: sLabel, score: sScore } = getLabelScore(sResp);
    const sentiment = mapSentimentToRange(sLabel, sScore);

    // 2) Emotion
    const emotionModel = 'j-hartmann/emotion-english-distilroberta-base';
    const eResp = await callHFModel(emotionModel, { inputs: text });
    const { label: eLabelRaw, score: eScore } = getLabelScore(eResp);
    const eLabel = (eLabelRaw || 'neutral').toLowerCase();

    // 3) Summary
    const summaryModel = 'sshleifer/distilbart-cnn-12-6';
    let summary = '';
    try {
      const sumResp = await callHFModel(summaryModel, {
        inputs: text,
        parameters: { min_length: 10, max_length: 60 },
      });

      // summarization resp usually [{summary_text: "..."}] or [[{...}]]
      let sumObj = null;
      if (Array.isArray(sumResp) && sumResp.length > 0) {
        if (Array.isArray(sumResp[0]) && sumResp[0].length > 0) {
          sumObj = sumResp[0][0];
        } else {
          sumObj = sumResp[0];
        }
      }
      if (sumObj && typeof sumObj === 'object') {
        summary =
          sumObj.summary_text || sumObj.generated_text || '';
      }

      if (!summary) {
        summary =
          text.length > 200 ? text.substring(0, 200) + '...' : text;
      }
    } catch (e) {
      console.error('Summary model failed:', e);
      summary =
        text.length > 200 ? text.substring(0, 200) + '...' : text;
    }

    // 4) Stress score + suggestions
    const sNorm = 1 - (sentiment + 1) / 2; // 0..1 (higher = more negative)
    let stressScore = Math.round(
      sNorm * 6 +
        (['anxious', 'stressed', 'angry'].includes(eLabel) ? 3 : 0)
    );
    stressScore = Math.max(0, Math.min(10, stressScore));

    const suggestions = [];
    if (stressScore >= 7)
      suggestions.push('Try a 5-minute breathing exercise.');
    if (eLabel.includes('sad'))
      suggestions.push('Write one thing you are grateful for.');
    if (eLabel.includes('anxious'))
      suggestions.push('Try grounding: 5-4-3-2-1 exercise.');
    if (eLabel.includes('joy') || eLabel.includes('happy'))
      suggestions.push('Note what went well today.');

    const ai = {
      sentiment,
      emotion: eLabel,
      emotionScore: eScore,
      summary,
      stressScore,
      suggestions,
    };

    return res.json({ ok: true, uid, ai });
  } catch (err) {
    console.error('processEntry error:', err);
    return res
      .status(500)
      .json({ ok: false, error: err.message || String(err) });
  }
});

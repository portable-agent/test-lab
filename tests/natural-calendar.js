import http from 'k6/http';
import { check, fail, sleep } from 'k6';

const channelUrl = requiredUrl('CHANNEL_URL');
const actionUrl = requiredUrl('ACTION_URL');
const userToken = required('ACTION_TOKEN');
const maxSeconds = Number(__ENV.MODEL_TEST_MAX_SECONDS || 120);
const timeZone = 'Europe/Moscow';

export const options = {
  scenarios: {
    natural_calendar: {
      executor: 'shared-iterations',
      vus: 1,
      iterations: 1,
      maxDuration: `${maxSeconds}s`,
    },
  },
  thresholds: {
    checks: ['rate==1'],
    http_req_failed: ['rate==0'],
    http_req_duration: [`max<${maxSeconds * 1000}`],
  },
};

export default function () {
  const requestKey = `natural-calendar-${Date.now()}-${__VU}-${__ITER}`;
  const card = askAgent(requestKey);
  const action = getAction(card.actionId);
  const startAt = Date.parse(action.payload?.startAt);
  const endAt = Date.parse(action.payload?.endAt);

  check(action, {
    'action waits for approval': (item) => item.status === 'AWAITING_APPROVAL',
    'agent understands tomorrow at 19:00 Moscow time': () => startAt === expectedStart(),
    'agent understands half an hour': () => endAt - startAt === 30 * 60 * 1000,
    'agent keeps the trusted time zone': (item) => item.payload?.timeZone === timeZone,
    'agent keeps a useful title': (item) => /проект/i.test(item.payload?.title || ''),
  });

  cancelAction(card);
  check(waitForCancelled(card.actionId), {
    'test action is cancelled': (item) => item.status === 'CANCELLED',
  });
}

function askAgent(requestKey) {
  const response = http.post(
    `${channelUrl}/api/v1/conversations/messages`,
    JSON.stringify({
      requestKey,
      text: 'Поставь завтра в 19:00 созвон по проекту на полчаса',
      context: {
        locale: 'ru-RU',
        timeZone,
      },
    }),
    authHeaders(),
  );
  expectStatus(response, 200, 'agent did not return a confirmation');
  const card = response.json().reply?.card;
  if (card?.widget !== 'action_confirmation') {
    fail('agent returned no action confirmation');
  }
  return card;
}

function getAction(actionId) {
  const response = http.get(`${actionUrl}/api/v1/actions/${actionId}`, authHeaders());
  expectStatus(response, 200, 'action-service did not return the action');
  return response.json();
}

function cancelAction(card) {
  const response = http.post(
    `${channelUrl}/api/v1/actions/${card.actionId}/decisions`,
    JSON.stringify({ decision: 'CANCEL', payloadHash: card.payloadHash }),
    authHeaders(),
  );
  expectStatus(response, 202, 'action-service did not accept cancellation');
}

function waitForCancelled(actionId) {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const action = getAction(actionId);
    if (action.status === 'CANCELLED') {
      return action;
    }
    sleep(0.2);
  }
  fail('action was not cancelled');
}

function expectedStart() {
  const moscowNow = new Date(Date.now() + 3 * 60 * 60 * 1000);
  return Date.UTC(
    moscowNow.getUTCFullYear(),
    moscowNow.getUTCMonth(),
    moscowNow.getUTCDate() + 1,
    16,
    0,
    0,
  );
}

function authHeaders() {
  return {
    headers: {
      Authorization: `Bearer ${userToken}`,
      'Content-Type': 'application/json',
    },
  };
}

function expectStatus(response, expected, message) {
  if (response.status !== expected) {
    fail(`${message}: expected ${expected}, got ${response.status}`);
  }
}

function required(name) {
  const value = __ENV[name];
  if (!value) {
    throw new Error(`${name} is required`);
  }
  return value;
}

function requiredUrl(name) {
  return required(name).replace(/\/$/, '');
}

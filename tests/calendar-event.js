import http from 'k6/http';
import { check, fail, sleep } from 'k6';

const channelUrl = requiredUrl('CHANNEL_URL');
const actionUrl = requiredUrl('ACTION_URL');
const calendarTestUrl = requiredUrl('CALENDAR_TEST_URL');
const calendarTestKey = required('CALENDAR_TEST_API_KEY');
const userToken = required('ACTION_TOKEN');
const eventData = {
  title: 'Обсуждение проекта',
  startAt: '2030-09-08T12:00:00+03:00',
  endAt: '2030-09-08T12:30:00+03:00',
  timeZone: 'Europe/Moscow',
};

export const options = {
  scenarios: {
    calendar_event: {
      executor: 'shared-iterations',
      vus: 1,
      iterations: 1,
    },
  },
  thresholds: {
    checks: ['rate==1'],
    http_req_failed: ['rate==0'],
  },
};

export default function () {
  const requestKey = `calendar-test-${Date.now()}-${__VU}-${__ITER}`;
  const card = createConversation(requestKey);
  const action = getAction(card.actionId);

  check(action, {
    'action waits for approval': (item) => item.status === 'AWAITING_APPROVAL',
    'action keeps the exact event data': (item) =>
      item.payload.title === eventData.title &&
      item.payload.startAt === eventData.startAt &&
      item.payload.endAt === eventData.endAt &&
      item.payload.timeZone === eventData.timeZone,
  });
  check(findEvents(requestKey), {
    'calendar is empty before approval': (items) => items.length === 0,
  });

  confirmAction(card);
  const done = waitForDone(action.id);
  const events = findEvents(requestKey);

  check(done, {
    'action succeeds after approval': (item) => item.status === 'SUCCEEDED',
    'action returns event id': (item) => Boolean(item.result?.eventId),
  });
  check(events, {
    'calendar has one event': (items) => items.length === 1,
    'calendar keeps the exact title': (items) => items[0]?.title === eventData.title,
    'calendar keeps the start instant and offset': (items) =>
      sameDate(items[0]?.startAt, eventData.startAt),
    'calendar keeps the end instant and offset': (items) =>
      sameDate(items[0]?.endAt, eventData.endAt),
    'calendar keeps the exact time zone': (items) => items[0]?.timeZone === eventData.timeZone,
    'calendar event id matches action result': (items) => items[0]?.eventId === done.result?.eventId,
  });

  const repeated = createConversation(requestKey);
  check(repeated, {
    'repeated message returns the same action': (item) => item.actionId === action.id,
  });
  check(findEvents(requestKey), {
    'repeated request does not create a second event': (items) => items.length === 1,
  });
}

function createConversation(requestKey) {
  const response = http.post(
    `${channelUrl}/api/v1/conversations/messages`,
    JSON.stringify({
      requestKey,
      text: `Создай встречу "${eventData.title}" с ${eventData.startAt} до ${eventData.endAt}`,
      context: {
        locale: 'ru-RU',
        timeZone: eventData.timeZone,
      },
    }),
    authHeaders(),
  );
  expectStatus(response, 200, 'conversation route did not return a confirmation');
  const body = response.json();
  if (body.reply?.type !== 'confirmation') {
    fail('conversation route returned no confirmation reply');
  }
  const card = body.reply.card;
  if (card?.widget !== 'action_confirmation') {
    fail('conversation route returned an unsupported widget');
  }
  check(card, {
    'confirmation points to an action': (item) => Boolean(item.actionId),
    'confirmation protects the payload': (item) => /^[a-f0-9]{64}$/.test(item.payloadHash),
    'confirmation offers confirm and cancel': (item) =>
      item.actions?.some((action) => action.id === 'confirm') &&
      item.actions?.some((action) => action.id === 'cancel'),
  });
  return card;
}

function getAction(actionId) {
  const response = http.get(`${actionUrl}/api/v1/actions/${actionId}`, authHeaders());
  expectStatus(response, 200, 'action-service did not return the action');
  return response.json();
}

function confirmAction(card) {
  const response = http.post(
    `${actionUrl}/api/v1/actions/${card.actionId}/decisions`,
    JSON.stringify({ decision: 'CONFIRM', payloadHash: card.payloadHash }),
    authHeaders(),
  );
  expectStatus(response, 202, 'action-service did not accept confirmation');
}

function waitForDone(actionId) {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const action = getAction(actionId);
    if (action.status === 'SUCCEEDED' || action.status === 'FAILED') {
      return action;
    }
    sleep(0.5);
  }
  fail('action did not finish in 10 seconds');
}

function findEvents(requestKey) {
  const response = http.get(
    `${calendarTestUrl}/test/events?requestKey=${encodeURIComponent(requestKey)}`,
    { headers: { 'X-Test-Key': calendarTestKey } },
  );
  expectStatus(response, 200, 'fake-calendar test API is not available');
  return response.json().events;
}

function authHeaders() {
  return {
    headers: {
      Authorization: `Bearer ${userToken}`,
      'Content-Type': 'application/json',
    },
  };
}

function sameDate(actual, expected) {
  if (!actual || Date.parse(actual) !== Date.parse(expected)) {
    return false;
  }
  return timeOffset(actual) === timeOffset(expected);
}

function timeOffset(value) {
  const match = value.match(/(Z|[+-]\d{2}:\d{2})$/);
  return match ? match[1] : null;
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

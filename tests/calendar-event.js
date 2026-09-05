import http from 'k6/http';
import { check, fail, sleep } from 'k6';

const agentUrl = requiredUrl('AGENT_URL');
const actionUrl = requiredUrl('ACTION_URL');
const calendarTestUrl = requiredUrl('CALENDAR_TEST_URL');
const actionToken = required('ACTION_TOKEN');
const tenantId = required('TEST_TENANT_ID');
const actorId = required('TEST_ACTOR_ID');
const eventData = {
  title: 'Обсуждение проекта',
  startAt: '2026-09-08T12:00:00+03:00',
  endAt: '2026-09-08T12:30:00+03:00',
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
  const proposal = createProposal();
  const action = createAction(proposal, requestKey);

  check(action, {
    'action waits for approval': (item) => item.status === 'AWAITING_APPROVAL',
  });
  check(findEvents(requestKey), {
    'calendar is empty before approval': (items) => items.length === 0,
  });

  confirmAction(action);
  const done = waitForDone(action.id);
  const events = findEvents(requestKey);

  check(done, {
    'action succeeds after approval': (item) => item.status === 'SUCCEEDED',
    'action returns event id': (item) => Boolean(item.result?.eventId),
  });
  check(events, {
    'calendar has one event': (items) => items.length === 1,
    'calendar keeps the exact title': (items) => items[0]?.title === eventData.title,
    'calendar keeps the exact start': (items) => items[0]?.startAt === eventData.startAt,
    'calendar keeps the exact end': (items) => items[0]?.endAt === eventData.endAt,
    'calendar keeps the exact time zone': (items) => items[0]?.timeZone === eventData.timeZone,
    'calendar event id matches action result': (items) => items[0]?.eventId === done.result?.eventId,
  });

  const repeated = createAction(proposal, requestKey);
  check(repeated, {
    'repeated request returns the same action': (item) => item.id === action.id,
  });
  check(findEvents(requestKey), {
    'repeated request does not create a second event': (items) => items.length === 1,
  });
}

function createProposal() {
  const response = http.post(
    `${agentUrl}/api/v1/proposals`,
    JSON.stringify({
      utterance: `Создай встречу "${eventData.title}" с ${eventData.startAt} до ${eventData.endAt}`,
      context: {
        tenant_id: tenantId,
        actor_id: actorId,
        timezone: eventData.timeZone,
        available_connectors: ['fake-calendar'],
      },
    }),
    jsonHeaders(),
  );
  expectStatus(response, 200, 'agent-runtime did not create a proposal');
  const body = response.json();
  if (!body.proposal || body.clarification) {
    fail('agent-runtime returned no complete proposal');
  }
  check(body.proposal.payload, {
    'proposal keeps the exact event data': (payload) =>
      payload.title === eventData.title &&
      payload.startAt === eventData.startAt &&
      payload.endAt === eventData.endAt &&
      payload.timeZone === eventData.timeZone,
  });
  return body.proposal;
}

function createAction(proposal, requestKey) {
  const response = http.post(
    `${actionUrl}/api/v1/actions`,
    JSON.stringify({
      kind: proposal.kind,
      connector: proposal.connector,
      payload: proposal.payload,
      requestKey,
    }),
    authHeaders(),
  );
  expectStatus(response, 201, 'action-service did not create an action');
  return response.json();
}

function confirmAction(action) {
  const response = http.post(
    `${actionUrl}/api/v1/actions/${action.id}/decisions`,
    JSON.stringify({ decision: 'CONFIRM', payloadHash: action.payloadHash }),
    authHeaders(),
  );
  expectStatus(response, 202, 'action-service did not accept confirmation');
}

function waitForDone(actionId) {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const response = http.get(`${actionUrl}/api/v1/actions/${actionId}`, authHeaders());
    expectStatus(response, 200, 'action-service did not return the action');
    const action = response.json();
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
  );
  expectStatus(response, 200, 'fake-calendar test API is not available');
  return response.json().events;
}

function jsonHeaders() {
  return { headers: { 'Content-Type': 'application/json' } };
}

function authHeaders() {
  return {
    headers: {
      Authorization: `Bearer ${actionToken}`,
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

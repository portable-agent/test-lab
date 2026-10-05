import http from 'k6/http';
import { check, fail } from 'k6';

const channelUrl = requiredUrl('CHANNEL_URL');
const userToken = required('ACTION_TOKEN');

export const options = {
  scenarios: {
    connection_widget: {
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
  const requestKey = `connection-test-${Date.now()}-${__VU}-${__ITER}`;
  const first = sendMessage(requestKey);
  const second = sendMessage(requestKey);

  check(first, {
    'reply asks for a connection': (reply) => reply.type === 'connection',
    'widget uses the public schema': (reply) =>
      reply.card?.schemaVersion === 1 && reply.card?.widget === 'connection',
    'widget asks for Google Calendar': (reply) => reply.card?.provider === 'google-calendar',
    'button contains a Google HTTPS URL': (reply) =>
      reply.card?.button?.url?.startsWith('https://accounts.google.com/'),
    'button contains PKCE and state': (reply) =>
      hasQuery(reply.card?.button?.url, 'state') &&
      hasQuery(reply.card?.button?.url, 'code_challenge') &&
      reply.card?.button?.url?.includes('code_challenge_method=S256'),
    'button does not expose client secret': (reply) =>
      !reply.card?.button?.url?.includes('client_secret'),
  });
  check(second, {
    'repeated request keeps the connection widget': (reply) => reply.type === 'connection',
    'repeated request gets a fresh authorization URL': (reply) =>
      reply.card?.button?.url !== first.card?.button?.url,
  });
}

function sendMessage(requestKey) {
  const response = http.post(
    `${channelUrl}/api/v1/conversations/messages`,
    JSON.stringify({
      requestKey,
      text: 'Создай встречу "Проверка подключения" с 2030-09-08T12:00:00+03:00 до 2030-09-08T12:30:00+03:00',
      context: {
        locale: 'ru-RU',
        timeZone: 'Europe/Moscow',
      },
    }),
    {
      headers: {
        Authorization: `Bearer ${userToken}`,
        'Content-Type': 'application/json',
      },
    },
  );
  if (response.status !== 200) {
    fail(`conversation route did not return a connection widget: got ${response.status}`);
  }
  const reply = response.json().reply;
  if (reply?.type !== 'connection' || reply.card?.widget !== 'connection') {
    fail('conversation route returned no connection widget');
  }
  return reply;
}

function hasQuery(url, name) {
  return typeof url === 'string' && new RegExp(`[?&]${name}=[^&]+`).test(url);
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

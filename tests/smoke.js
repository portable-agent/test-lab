import http from 'k6/http';
import { check } from 'k6';

const target = __ENV.TARGET_URL;
if (!target) {
  throw new Error('TARGET_URL is required');
}

export const options = {
  vus: Number(__ENV.K6_USERS || 5),
  duration: __ENV.K6_TIME || '20s',
  thresholds: {
    http_req_failed: [`rate<${__ENV.K6_ERROR_RATE || '0.01'}`],
    http_req_duration: [`p(95)<${__ENV.K6_P95_MS || '300'}`],
    checks: ['rate>0.99'],
  },
};

export default function () {
  const response = http.get(`${target}/api/test`, { tags: { name: 'test' } });
  check(response, {
    'status is 200': (item) => item.status === 200,
    'response is json': (item) => item.headers['Content-Type']?.includes('application/json'),
  });
}


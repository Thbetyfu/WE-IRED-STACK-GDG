import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// Custom metrics for NFR-PERF-01 and NFR-PERF-02 tracking
const reportSuccessRate = new Rate('report_success_rate');
const reportLatency = new Trend('report_submission_latency');
const totalReportsSubmitted = new Counter('total_reports_submitted');

// Configuration: 300 reports/minute per RT across 50 RTs (15,000 reports/min = 250 RPS)
export const options = {
  scenarios: {
    emergency_reporting_surge: {
      executor: 'constant-arrival-rate',
      rate: 250, // 250 reports per second = 15,000 reports / minute
      timeUnit: '1s',
      duration: '1m', // 1 minute surge
      preAllocatedVUs: 50,
      maxVUs: 150,
    },
  },
  thresholds: {
    // NFR-PERF-01: API laporan harus merespons <= 500 ms (p95)
    'http_req_duration': ['p(95)<500', 'p(99)<1000'],
    'report_submission_latency': ['p(95)<500'],
    // Error rate must remain under 1%
    'http_req_failed': ['rate<0.01'],
    'report_success_rate': ['rate>0.99'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const INCIDENT_ID = __ENV.INCIDENT_ID || 'inc-surge-demo-01';
const AUTH_TOKEN = __ENV.AUTH_TOKEN || '';

export default function () {
  // Distribute across 50 RTs (RT 01 to RT 50) and 300 households per RT
  const rtNum = Math.floor(Math.random() * 50) + 1;
  const hhNum = Math.floor(Math.random() * 300) + 1;
  const rtId = `rt-${String(rtNum).padStart(2, '0')}`;
  const householdId = `hh-${rtId}-${String(hhNum).padStart(3, '0')}`;

  // Report status distribution: 15% kritis, 35% butuh_bantuan, 50% aman
  const randStatus = Math.random();
  let status = 3; // aman
  let urgency = 2; // biasa
  let needs = 0;

  if (randStatus < 0.15) {
    status = 1; // kritis
    urgency = 1; // kritis
    needs = 3; // evakuasi + medis
  } else if (randStatus < 0.50) {
    status = 2; // butuh_bantuan
    urgency = 2; // biasa
    needs = 1; // logistik
  }

  const payload = JSON.stringify({
    household_id: householdId,
    status: status,
    urgency: urgency,
    needs: needs,
    channel: 'aplikasi',
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      ...(AUTH_TOKEN ? { 'Authorization': `Bearer ${AUTH_TOKEN}` } : {}),
    },
    timeout: '5s',
  };

  const startTime = new Date();
  const res = http.post(`${BASE_URL}/incidents/${INCIDENT_ID}/reports`, payload, params);
  const duration = new Date() - startTime;

  reportLatency.add(duration);
  totalReportsSubmitted.add(1);

  const success = check(res, {
    'status is 201 or 200': (r) => r.status === 201 || r.status === 200,
    'response has action_taken': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.data && body.data.action_taken !== undefined;
      } catch (_) {
        return false;
      }
    },
  });

  reportSuccessRate.add(success);
}

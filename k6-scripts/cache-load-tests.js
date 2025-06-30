/**
 * k6 Load Test Script for Banking Redis Cache
 * Tests cache performance under various banking operation scenarios
 */

import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const cacheHitRate = new Rate('cache_hit_rate');
const accountBalanceLatency = new Trend('account_balance_latency');
const profileLoadLatency = new Trend('profile_load_latency');
const transactionHistoryLatency = new Trend('transaction_history_latency');

// Test configuration
export const options = {
    scenarios: {
        // Normal banking traffic
        normal_load: {
            executor: 'constant-vus',
            vus: 10,
            duration: '5m',
            tags: { scenario: 'normal' },
            exec: 'normalBankingTraffic'
        },
        
        // Morning rush (market open)
        morning_rush: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '30s', target: 50 },   // Ramp up
                { duration: '2m', target: 50 },    // Sustain
                { duration: '30s', target: 10 }    // Ramp down
            ],
            tags: { scenario: 'morning_rush' },
            exec: 'morningRushTraffic',
            startTime: '5m'
        },
        
        // Cache stampede test
        stampede_test: {
            executor: 'constant-arrival-rate',
            rate: 100,
            timeUnit: '1s',
            duration: '1m',
            preAllocatedVUs: 50,
            tags: { scenario: 'stampede' },
            exec: 'stampedeScenario',
            startTime: '10m'
        }
    },
    
    thresholds: {
        'http_req_duration': ['p(95)<500', 'p(99)<1000'],
        'cache_hit_rate': ['rate>0.8'],
        'account_balance_latency': ['p(95)<100'],
        'profile_load_latency': ['p(95)<200'],
        'transaction_history_latency': ['p(95)<300']
    }
};

// Test data
const accountIds = generateAccountIds(100);
const customerIds = generateCustomerIds(50);
const API_BASE = 'http://api-gateway:8080';

// Helper functions
function generateAccountIds(count) {
    const ids = [];
    for (let i = 0; i < count; i++) {
        ids.push(`ACC${100000 + i}`);
    }
    return ids;
}

function generateCustomerIds(count) {
    const ids = [];
    for (let i = 0; i < count; i++) {
        ids.push(`CUST${10000 + i}`);
    }
    return ids;
}

function getRandomElement(array) {
    return array[Math.floor(Math.random() * array.length)];
}

// Scenario: Normal Banking Traffic
export function normalBankingTraffic() {
    group('Normal Banking Operations', () => {
        // 40% - Account balance checks (should be cached)
        if (Math.random() < 0.4) {
            const accountId = getRandomElement(accountIds);
            const startTime = new Date();
            
            const response = http.get(`${API_BASE}/accounts/${accountId}/balance`, {
                headers: { 'X-Cache-Test': 'true' }
            });
            
            const latency = new Date() - startTime;
            accountBalanceLatency.add(latency);
            
            const success = check(response, {
                'balance check successful': (r) => r.status === 200,
                'response has balance': (r) => JSON.parse(r.body).balance !== undefined
            });
            
            // Check if it was a cache hit
            const cacheHit = response.headers['X-Cache-Hit'] === 'true';
            cacheHitRate.add(cacheHit);
        }
        
        // 20% - Customer profile views
        else if (Math.random() < 0.6) {
            const customerId = getRandomElement(customerIds);
            const startTime = new Date();
            
            const response = http.get(`${API_BASE}/customers/${customerId}/profile`);
            
            const latency = new Date() - startTime;
            profileLoadLatency.add(latency);
            
            check(response, {
                'profile load successful': (r) => r.status === 200
            });
        }
        
        // 25% - Transaction history
        else if (Math.random() < 0.85) {
            const accountId = getRandomElement(accountIds);
            const startTime = new Date();
            
            const response = http.get(`${API_BASE}/accounts/${accountId}/transactions?limit=10`);
            
            const latency = new Date() - startTime;
            transactionHistoryLatency.add(latency);
            
            check(response, {
                'transaction history successful': (r) => r.status === 200
            });
        }
        
        // 15% - Authentication/Session checks
        else {
            const sessionId = `SESSION_${Date.now()}_${Math.random()}`;
            const response = http.post(`${API_BASE}/auth/verify`, 
                JSON.stringify({ sessionId: sessionId }),
                { headers: { 'Content-Type': 'application/json' } }
            );
            
            check(response, {
                'session check successful': (r) => r.status === 200 || r.status === 401
            });
        }
    });
    
    sleep(Math.random() * 2 + 0.5); // Random sleep between 0.5-2.5 seconds
}

// Scenario: Morning Rush Traffic
export function morningRushTraffic() {
    group('Morning Rush - High Balance Checks', () => {
        // 90% balance checks during market open
        if (Math.random() < 0.9) {
            // Use top 20 accounts more frequently (hot accounts)
            const hotAccounts = accountIds.slice(0, 20);
            const accountId = Math.random() < 0.8 
                ? getRandomElement(hotAccounts) 
                : getRandomElement(accountIds);
            
            const response = http.get(`${API_BASE}/accounts/${accountId}/balance`, {
                headers: { 
                    'X-Cache-Test': 'true',
                    'X-Scenario': 'morning-rush'
                }
            });
            
            check(response, {
                'morning rush balance check': (r) => r.status === 200
            });
            
            const cacheHit = response.headers['X-Cache-Hit'] === 'true';
            cacheHitRate.add(cacheHit);
        }
        // 10% fraud score checks
        else {
            const accountId = getRandomElement(accountIds);
            const response = http.get(`${API_BASE}/fraud/score/${accountId}`);
            
            check(response, {
                'fraud check successful': (r) => r.status === 200
            });
        }
    });
    
    sleep(Math.random() * 0.5); // Faster requests during rush
}

// Scenario: Cache Stampede
export function stampedeScenario() {
    group('Cache Stampede Test', () => {
        // All VUs request the same popular account
        const popularAccountId = 'ACC100001';
        
        const response = http.get(`${API_BASE}/accounts/${popularAccountId}/balance`, {
            headers: { 
                'X-Cache-Test': 'true',
                'X-Scenario': 'stampede'
            }
        });
        
        check(response, {
            'stampede request successful': (r) => r.status === 200
        });
        
        // No sleep - maximum pressure
    });
}

// Cache invalidation scenario (for testing eviction)
export function cacheInvalidationTest() {
    group('Cache Invalidation Test', () => {
        const accountId = getRandomElement(accountIds);
        
        // First, ensure it's cached
        http.get(`${API_BASE}/accounts/${accountId}/balance`);
        
        // Make a transfer (should invalidate cache)
        const transferData = {
            fromAccount: accountId,
            toAccount: getRandomElement(accountIds),
            amount: Math.random() * 1000 + 10
        };
        
        const response = http.post(`${API_BASE}/transfer`, 
            JSON.stringify(transferData),
            { headers: { 'Content-Type': 'application/json' } }
        );
        
        check(response, {
            'transfer successful': (r) => r.status === 200 || r.status === 201
        });
        
        // Check if balance was invalidated
        sleep(0.5);
        const balanceResponse = http.get(`${API_BASE}/accounts/${accountId}/balance`);
        
        check(balanceResponse, {
            'cache invalidated': (r) => r.headers['X-Cache-Hit'] !== 'true'
        });
    });
    
    sleep(1);
}

// Main default function
export default function() {
    normalBankingTraffic();
}
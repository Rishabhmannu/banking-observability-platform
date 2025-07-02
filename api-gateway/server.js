const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const morgan = require('morgan');
const prometheus = require('prom-client');

const app = express();
const PORT = 8080;

// Prometheus setup
const register = new prometheus.Registry();
prometheus.collectDefaultMetrics({ register });

const httpRequestDurationMicroseconds = new prometheus.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'code'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10]
});
register.registerMetric(httpRequestDurationMicroseconds);

// Cache-proxy toggle
const CACHE_PROXY_URL   = process.env.CACHE_PROXY_URL   || 'http://cache-proxy-service:5020';
const USE_CACHE_PROXY   = process.env.USE_CACHE_PROXY === 'true';

console.log('=================================');
console.log('API Gateway Configuration:');
console.log(`Port: ${PORT}`);
console.log(`Cache Proxy: ${USE_CACHE_PROXY ? 'ENABLED' : 'DISABLED'}`);
if (USE_CACHE_PROXY) console.log(`Cache Proxy URL: ${CACHE_PROXY_URL}`);
console.log('=================================');

// Logging
app.use(morgan('combined'));

// Measure request durations
app.use((req, res, next) => {
  const end = httpRequestDurationMicroseconds.startTimer();
  res.on('finish', () => {
    end({ method: req.method, route: req.path, code: res.statusCode });
  });
  next();
});

// Expose metrics
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Helpers
function getTargetUrl(serviceUrl) {
  return USE_CACHE_PROXY ? CACHE_PROXY_URL : serviceUrl;
}

// Account Service
app.use('/accounts', createProxyMiddleware({
  target: getTargetUrl(process.env.ACCOUNT_SERVICE_URL || 'http://banking-account-service:8081'),
  changeOrigin: true,
  pathRewrite: {},  // FIXED: Stop rewriting paths
  onProxyReq: (proxyReq, req) => {
    console.log(`Routing ${req.method} /accounts${req.url}`);
  },
  onError: (err, req, res) => {
    console.error(`Proxy error for /accounts${req.url}:`, err.message);
    res.status(503).json({ error: 'Service unavailable' });
  }
}));

// Transaction Service
app.use('/transactions', createProxyMiddleware({
  target: getTargetUrl(process.env.TRANSACTION_SERVICE_URL || 'http://banking-transaction-service:8082'),
  changeOrigin: true,
  pathRewrite: {},  // FIXED: Stop rewriting paths
  onProxyReq: (proxyReq, req) => {
    console.log(`Routing ${req.method} /transactions${req.url}`);
  },
  onError: (err, req, res) => {
    console.error(`Proxy error for /transactions${req.url}:`, err.message);
    res.status(503).json({ error: 'Service unavailable' });
  }
}));

// Auth Service
app.use('/auth', createProxyMiddleware({
  target: getTargetUrl(process.env.AUTH_SERVICE_URL || 'http://banking-auth-service:8083'),
  changeOrigin: true,
  pathRewrite: {},  // FIXED: Stop rewriting paths
  onProxyReq: (proxyReq, req) => {
    console.log(`Routing ${req.method} /auth${req.url}`);
  },
  onError: (err, req, res) => {
    console.error(`Proxy error for /auth${req.url}:`, err.message);
    res.status(503).json({ error: 'Service unavailable' });
  }
}));

// Notification Service
app.use('/notifications', createProxyMiddleware({
  target: getTargetUrl(process.env.NOTIFICATION_SERVICE_URL || 'http://banking-notification-service:8084'),
  changeOrigin: true,
  pathRewrite: {},  // FIXED: Stop rewriting paths
  onProxyReq: (proxyReq, req) => {
    console.log(`Routing ${req.method} /notifications${req.url}`);
  },
  onError: (err, req, res) => {
    console.error(`Proxy error for /notifications${req.url}:`, err.message);
    res.status(503).json({ error: 'Service unavailable' });
  }
}));

// Fraud Detection Service
app.use('/fraud', createProxyMiddleware({
  target: getTargetUrl(process.env.FRAUD_SERVICE_URL || 'http://banking-fraud-detection:8085'),
  changeOrigin: true,
  pathRewrite: {},  // FIXED: Stop rewriting paths
  onProxyReq: (proxyReq, req) => {
    console.log(`Routing ${req.method} /fraud${req.url}`);
  },
  onError: (err, req, res) => {
    console.error(`Proxy error for /fraud${req.url}:`, err.message);
    res.status(503).json({ error: 'Service unavailable' });
  }
}));

// Gateway health check
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'UP',
    cache_proxy_enabled: USE_CACHE_PROXY,
    cache_proxy_url: USE_CACHE_PROXY ? CACHE_PROXY_URL : 'disabled',
    timestamp: new Date().toISOString()
  });
});

// Fallback error handler
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`✅ API Gateway running on port ${PORT}`);
});
'use strict'
exports.config = {
  app_name: ['Banking API Gateway'],
  license_key: '59829ffc48a17aa6783a0ee3cd15e230FFFFNRAL',
  logging: {
    level: 'trace'
  },
  enabled: true,
  allow_all_headers: true,
  distributed_tracing: {
    enabled: true
  }
}

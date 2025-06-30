#!/bin/bash
echo "Testing New Relic connection from inside the container..."
docker exec banking-api-gateway node -e "
const newrelic = require('newrelic');
console.log('New Relic status:', newrelic.agent.config.enabled ? 'ENABLED' : 'DISABLED');
console.log('New Relic config:', JSON.stringify(newrelic.agent.config, null, 2));
console.log('Attempting to record test event...');
newrelic.recordCustomEvent('TestEvent', {test: 'value', timestamp: Date.now()});
console.log('Test event recorded. Check New Relic UI in 1-2 minutes.');
"

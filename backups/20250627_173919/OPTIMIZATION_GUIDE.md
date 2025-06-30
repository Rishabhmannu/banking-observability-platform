# Redis Cache & Container Resource Optimization Guide

## Table of Contents
1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Redis Cache Monitoring](#redis-cache-monitoring)
4. [Container Resource Optimization](#container-resource-optimization)
5. [Integration with Banking Services](#integration-with-banking-services)
6. [Monitoring and Alerts](#monitoring-and-alerts)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)

## Overview

This guide covers two new monitoring and optimization services added to the DDoS Detection System:

1. **Redis Cache Monitoring**: Analyzes cache performance, provides recommendations, and helps optimize cache usage for banking operations.
2. **Container Resource Optimization**: Monitors container resource usage and provides right-sizing recommendations to reduce costs and improve stability.

## Quick Start

### Starting the Services

```bash
# Start all optimization services
python start-optimization-services.py

# Or manually with docker-compose
docker-compose -f docker-compose.optimization.yml up -d
```

### Verifying Services

```bash
# Test Redis cache services
python test-redis-cache.py

# Test container resource services
python test-container-resources.py
```

### Service URLs

- **Redis Cache Analyzer**: http://localhost:5012
- **Cache Load Generator**: http://localhost:5013
- **Container Resource Monitor**: http://localhost:5010
- **Resource Anomaly Generator**: http://localhost:5011
- **Redis Direct Access**: localhost:6379

## Redis Cache Monitoring

### Architecture

```
Banking Services → Redis Cache → Cache Analyzer
                        ↓              ↓
                  Load Generator → Prometheus → Grafana
```

### Key Features

1. **Real-time Cache Analysis**
   - Hit ratio monitoring
   - Eviction rate tracking
   - Memory usage analysis
   - Key pattern distribution

2. **Banking-Specific Metrics**
   - Account balance cache performance
   - Customer profile cache efficiency
   - Transaction history cache optimization
   - Session management metrics

3. **Load Testing Patterns**
   - Normal banking traffic
   - Cache stampede simulation
   - High eviction scenarios
   - Burst traffic (market open)
   - Cache miss patterns

### Using the Cache Load Generator

#### Start Normal Traffic
```bash
curl -X POST http://localhost:5013/start \
  -H "Content-Type: application/json" \
  -d '{"pattern": "normal", "ops_per_second": 10}'
```

#### Simulate Cache Stampede
```bash
curl -X POST http://localhost:5013/simulate/stampede
```

#### Available Patterns
- `normal`: Typical banking operations (80/20 rule)
- `stampede`: Many requests for same key
- `eviction`: High memory pressure
- `burst`: Market open simulation
- `miss`: High cache miss scenario

### Cache Recommendations API

```bash
# Get optimization recommendations
curl http://localhost:5012/recommendations | jq

# Get current cache statistics
curl http://localhost:5012/cache-stats | jq
```

## Container Resource Optimization

### Architecture

```
cAdvisor → Container Monitor → Resource Optimizer
                ↓                      ↓
        Anomaly Generator → Prometheus → Grafana
```

### Key Features

1. **Resource Analysis**
   - CPU usage vs. limits
   - Memory usage patterns
   - Stability scoring
   - Cost optimization

2. **Optimization Algorithms**
   - VPA-style recommendations
   - ML-based predictions
   - Right-sizing analysis
   - Priority-based optimization

3. **Cost Savings Calculation**
   - Monthly savings potential
   - Per-container breakdown
   - Total optimization value

### Using the Resource Monitor

#### Get All Recommendations
```bash
curl http://localhost:5010/recommendations | jq
```

#### Get Top Optimization Opportunities
```bash
curl http://localhost:5010/top-optimizations | jq
```

#### Get Container-Specific Recommendation
```bash
curl http://localhost:5010/recommendations/banking-api-gateway | jq
```

### Resource Anomaly Testing

#### Start CPU Spike
```bash
curl -X POST http://localhost:5011/start/cpu_spike \
  -H "Content-Type: application/json" \
  -d '{"spike_duration": 10, "spike_intensity": 0.8, "interval": 30}'
```

#### Run Predefined Scenarios
```bash
# Memory pressure scenario
curl -X POST http://localhost:5011/scenarios/memory_pressure

# Unstable container scenario
curl -X POST http://localhost:5011/scenarios/unstable_container

# Resource fluctuation
curl -X POST http://localhost:5011/scenarios/resource_fluctuation
```

## Integration with Banking Services

### Adding Redis Cache to Your Services

1. **Import the Cache Module**
```python
from shared.cache.redis_cache import BankingRedisCache, cache_result, invalidate_cache
```

2. **Initialize Cache in Your Service**
```python
class AccountService:
    def __init__(self):
        self._cache = BankingRedisCache(
            host='banking-redis',
            port=6379,
            service_name='account-service',
            default_ttl=300
        )
```

3. **Use Cache Decorators**
```python
@cache_result("account:{account_id}:balance", ttl=60, operation="get_balance")
def get_account_balance(self, account_id: str):
    # This will be cached for 60 seconds
    return self.db.query_balance(account_id)

@invalidate_cache(["account:{from_account}:balance", "account:{to_account}:balance"])
def transfer_money(self, from_account: str, to_account: str, amount: float):
    # This will invalidate balance cache for both accounts
    return self.db.execute_transfer(from_account, to_account, amount)
```

### Cache Key Patterns

Recommended patterns for banking operations:

- **Account Operations**: `account:{account_id}:{operation}`
- **Customer Data**: `customer:{customer_id}:{data_type}`
- **Transactions**: `transaction:{account_id}:history:{date_range}`
- **Sessions**: `session:{session_id}`
- **Fraud Scores**: `fraud:{account_id}:score`

### TTL Recommendations

| Operation | Recommended TTL | Reason |
|-----------|----------------|---------|
| Account Balance | 60s | Frequently changes |
| Customer Profile | 3600s | Rarely changes |
| Transaction History | 300s | Moderate updates |
| Auth Session | 1800s | Security timeout |
| Fraud Score | 120s | Real-time analysis |

## Monitoring and Alerts

### Prometheus Alerts

The system includes pre-configured alerts for:

1. **Cache Performance**
   - Low hit ratio (< 70% warning, < 50% critical)
   - High eviction rate (> 100 keys/min)
   - Low efficiency score (< 70)
   - Memory pressure (> 90% usage)

2. **Container Optimization**
   - Severely overprovisioned (> 70% waste)
   - High cost savings potential (> $50/month)
   - Container instability (score < 50)
   - Potential memory leaks

### Grafana Dashboards

Import the provided dashboards:

1. **Redis Cache Performance Dashboard**
   - File: `grafana/dashboards/redis-cache-performance.json`
   - Shows hit ratios, eviction rates, memory usage, key distribution

2. **Container Resource Optimization Dashboard**
   - File: `grafana/dashboards/container-resource-optimization.json`
   - Shows waste percentages, savings potential, recommendations

### Key Metrics to Monitor

#### Cache Metrics
- `redis_cache_hit_ratio`: Aim for > 80%
- `redis_cache_eviction_rate`: Should be near 0
- `redis_cache_efficiency_score`: Target > 80
- `banking_cache_operation_duration_seconds`: < 100ms

#### Container Metrics
- `container_cpu_optimization_score`: Lower is better
- `container_memory_waste_percent`: Target < 30%
- `container_stability_score`: Should be > 80
- `container_cost_savings_potential_dollars`: Identify top targets

## Troubleshooting

### Redis Cache Issues

#### Low Hit Ratio
1. Check TTL settings - may be too short
2. Verify key patterns are correct
3. Look for cache stampede scenarios
4. Review application cache usage

#### High Eviction Rate
1. Check Redis memory limit
2. Review key sizes and counts
3. Consider increasing Redis memory
4. Optimize data structures

#### Connection Issues
```bash
# Test Redis connectivity
docker exec -it banking-redis redis-cli ping

# Check Redis info
docker exec -it banking-redis redis-cli info stats
```

### Container Optimization Issues

#### No Recommendations Available
1. Ensure cAdvisor is running
2. Wait for sufficient data (needs 10+ data points)
3. Check only banking containers are analyzed
4. Verify Prometheus is scraping metrics

#### Incorrect Recommendations
1. Check resource limits are set in containers
2. Verify CPU/memory metrics are accurate
3. Review stability scoring factors
4. Adjust buffer percentages if needed

### Common Commands

```bash
# Check service logs
docker-compose -f docker-compose.optimization.yml logs [service-name]

# Restart a service
docker-compose -f docker-compose.optimization.yml restart [service-name]

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job | contains("redis") or contains("container"))'

# Manual cache operations
docker exec -it banking-redis redis-cli
> KEYS *
> INFO stats
> FLUSHALL  # Clear all cache (careful!)
```

## Best Practices

### Redis Cache

1. **Design Cache Keys Carefully**
   - Use consistent patterns
   - Include version numbers if needed
   - Avoid special characters

2. **Set Appropriate TTLs**
   - Balance freshness vs. performance
   - Use shorter TTLs for frequently changing data
   - Consider business requirements

3. **Monitor Cache Performance**
   - Set up alerts for low hit ratios
   - Track eviction patterns
   - Review efficiency scores regularly

4. **Handle Cache Failures Gracefully**
   - Always have fallback to database
   - Log cache errors for analysis
   - Don't let cache failures break the app

### Container Resources

1. **Regular Reviews**
   - Check optimization dashboard weekly
   - Prioritize high-value optimizations
   - Test recommendations in staging first

2. **Gradual Changes**
   - Don't reduce resources too aggressively
   - Monitor stability after changes
   - Keep some buffer for spikes

3. **Consider Service Priority**
   - Critical services need more buffer
   - Batch jobs can be more aggressive
   - Balance cost vs. reliability

4. **Use Anomaly Testing**
   - Test resource changes under load
   - Simulate failure scenarios
   - Verify stability scores

## Advanced Usage

### Custom Cache Patterns

Create custom cache patterns for specific use cases:

```python
# In cache_patterns.py
class CustomPattern(CachePattern):
    def generate_operations(self, count=100):
        # Implement your pattern
        pass

# Register the pattern
AVAILABLE_PATTERNS['custom'] = CustomPattern
```

### Container Resource Policies

Implement custom optimization policies:

```python
# In optimizer.py
class CustomOptimizer(ResourceOptimizer):
    def calculate_recommendation(self, metrics):
        # Implement custom logic
        pass
```

### Integration with CI/CD

```yaml
# Example: GitLab CI integration
test-optimization:
  script:
    - python test-redis-cache.py
    - python test-container-resources.py
    - curl http://localhost:5010/top-optimizations | jq '.total_containers_analyzed'
```

## Conclusion

The Redis Cache and Container Resource Optimization services provide powerful tools for improving the performance and cost-efficiency of your banking microservices. Regular monitoring and optimization based on the recommendations can lead to significant improvements in both user experience and operational costs.

For questions or issues, check the logs, review the metrics in Grafana, and use the troubleshooting guide above. Remember to test all changes in a staging environment before applying to production.
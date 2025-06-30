# 🚀 DDoS Detection & Auto-Baselining System - Docker Hub Deployment

## 🎯 Overview

This project provides a complete **DDoS Detection System with Auto-Baselining** that can be deployed instantly from Docker Hub. Perfect for disaster recovery, quick demos, and sharing your internship project.

### 🏗️ Architecture

- **6 Banking Microservices** (API Gateway, Account, Transaction, Auth, Notification, Fraud Detection)
- **Auto-Baselining Service** (4 ML algorithms for threshold optimization)
- **DDoS ML Detection** (optional - if included)
- **Complete Monitoring Stack** (Prometheus + Grafana + Dashboards)

## 🚀 Quick Deployment (2-3 Minutes)

### Option 1: Fresh Installation
```bash
# 1. Download disaster recovery script
curl -O https://raw.githubusercontent.com/[YOUR-REPO]/disaster_recovery.sh

# 2. Make executable and run
chmod +x disaster_recovery.sh
./disaster_recovery.sh

# 3. Enter your Docker Hub username when prompted
```

### Option 2: If You Have the Project Files
```bash
# 1. Use the quick deploy script
./quick_deploy_from_hub.sh

# 2. Everything pulls from Docker Hub (fast!)
```

## 📦 Docker Hub Images

All custom images are hosted on Docker Hub:

- `[USERNAME]/ddos-detection-banking-api-gateway:latest`
- `[USERNAME]/ddos-detection-banking-account-service:latest`
- `[USERNAME]/ddos-detection-banking-transaction-service:latest`
- `[USERNAME]/ddos-detection-banking-auth-service:latest`
- `[USERNAME]/ddos-detection-banking-notification-service:latest`
- `[USERNAME]/ddos-detection-banking-fraud-detection:latest`
- `[USERNAME]/ddos-detection-banking-auto-baselining:latest`

## 🌐 Access URLs

After deployment:

- **🏦 Banking API**: http://localhost:8080
- **🎯 Auto-Baselining**: http://localhost:5002
- **📊 Prometheus**: http://localhost:9090
- **📈 Grafana**: http://localhost:3000 (admin/bankingdemo)

## 🧪 Quick Tests

```bash
# Test banking services
curl http://localhost:8080/health

# Test auto-baselining
curl http://localhost:5002/health

# View threshold recommendations
curl http://localhost:5002/threshold-recommendations | jq .

# Test threshold calculation
curl 'http://localhost:5002/calculate-threshold?metric=sum(rate(http_requests_total[1m]))' | jq .
```

## 📊 Grafana Dashboards

Three pre-configured dashboards:

1. **🎯 Auto-Baselining & Threshold Optimization**
   - Algorithm performance metrics
   - Threshold recommendations timeline
   - Confidence scores

2. **🏦 Banking System Overview**
   - Service health monitoring
   - Request/error rates
   - System performance

3. **🚨 DDoS Detection & Security Monitoring**
   - Attack detection status
   - Security metrics
   - System load monitoring

## 🔧 Management Commands

```bash
# Stop everything
docker-compose -f docker-compose.hub.yml down

# Start everything
docker-compose -f docker-compose.hub.yml up -d

# View logs
docker-compose -f docker-compose.hub.yml logs -f

# Restart specific service
docker-compose -f docker-compose.hub.yml restart auto-baselining
```

## 🎓 For Your Internship Presentation

### Demo Flow:
1. **Show Disaster Recovery**: Demonstrate 3-minute full deployment
2. **Banking System**: Live microservices architecture
3. **Phase 1**: DDoS detection capabilities (if included)
4. **Phase 2**: Auto-baselining with 4 ML algorithms
5. **Monitoring**: Real-time dashboards and metrics
6. **Portability**: Works anywhere Docker runs

### Key Selling Points:
- ✅ **Production-Ready**: Complete CI/CD with Docker Hub
- ✅ **Disaster Recovery**: 3-minute full restoration
- ✅ **Scalable**: Microservices architecture
- ✅ **ML-Powered**: Advanced anomaly detection + threshold optimization
- ✅ **Observable**: Complete monitoring stack
- ✅ **Portable**: Deploy anywhere (cloud, local, demo environments)

## 🆘 Troubleshooting

### If Services Don't Start:
```bash
# Check Docker daemon
docker ps

# Check service logs
docker-compose -f docker-compose.hub.yml logs [service-name]

# Restart problematic service
docker-compose -f docker-compose.hub.yml restart [service-name]
```

### If Images Don't Pull:
```bash
# Login to Docker Hub
docker login

# Manual pull
docker pull [username]/ddos-detection-banking-auto-baselining:latest
```

### Performance Issues:
```bash
# Check resource usage
docker stats

# Restart with fresh state
docker-compose -f docker-compose.hub.yml down
docker system prune -f
docker-compose -f docker-compose.hub.yml up -d
```

## 🔄 Updates & Versioning

### Push New Version:
```bash
# Build and tag new version
docker build -t [username]/ddos-detection-banking-auto-baselining:v2.0 .

# Push to Docker Hub
docker push [username]/ddos-detection-banking-auto-baselining:v2.0
docker push [username]/ddos-detection-banking-auto-baselining:latest
```

### Update Production:
```bash
# Pull latest images
docker-compose -f docker-compose.hub.yml pull

# Restart with new images
docker-compose -f docker-compose.hub.yml up -d
```

## 🎉 Benefits of This Approach

1. **⚡ Speed**: 3-minute deployment vs 30-minute build
2. **🛡️ Reliability**: Docker corruption = quick recovery
3. **📦 Portability**: Share entire project easily
4. **🔄 Consistency**: Same environment everywhere
5. **🎯 Demo-Ready**: Perfect for presentations
6. **☁️ Cloud-Ready**: Easy deployment to any cloud provider

---

**Perfect for internships, presentations, and production deployments!** 🚀
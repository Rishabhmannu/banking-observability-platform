# Enterprise-Grade AIOps & Full-Stack Observability for Banking

[![MIT License](https://img.shields.io/badge/license-MIT-green)](LICENSE)  
[![Open Source](https://img.shields.io/badge/Open%20Source-100%25-blue)](https://github.com/Rishabhmannu/banking-observability-platform)

A **100% open-source**, production-grade AIOps and observability platform delivering unified **logs, metrics & traces** for containerized banking microservices.

---

## 🚀 Highlights

### 🔍 Full-Stack Observability  
Correlate logs, metrics, and traces across:
- **Application layer** (APM & distributed tracing)  
- **Infrastructure layer** (databases, message queues, containers)  
- **Security layer** (real-time DDoS detection)  
for a true “single pane of glass.”

### 🤖 AI-Driven Operations (AIOps)

- **ML-Powered DDoS Detection**  
  Trained a bespoke **Isolation Forest** model on banking API traffic for real-time anomaly scoring and attack classification.

- **Automated Baselining**  
  Four complementary methods for dynamic thresholding:  
  1. **Rolling Statistics** (moving mean & σ)  
  2. **Quantile Thresholding** (dynamic percentile windows)  
  3. **Isolation Forest** (unsupervised outlier isolation)  
  4. **One-Class SVM** (boundary-based anomaly detection)  
  Plus advanced **deep-learning models**—**LSTM Autoencoder** (reconstruction-error detection) and **LSTM Predictor** (forecast-error detection).

- **Chaos Engineering**  
  Anomaly Injector service simulates latency spikes, error floods, and load surges to validate resilience and alert accuracy under controlled fault scenarios.

### 💰 Cost & Resource Optimization  
Analyze resource usage across 25+ containers and Redis cache—generate actionable CPU/memory rightsizing and cost-saving recommendations.

### 🧩 Modular & Extensible  
Enable or disable monitoring stacks (tracing, messaging, optimization) independently via Docker Compose. Includes a mock Windows-IIS exporter to showcase legacy-system integration.

---

## 📊 System Architecture

```mermaid
flowchart LR
  subgraph "User"
    A[External Clients]
  end

  subgraph "Banking Services Layer"
    direction LR
    B[API Gateway]
    C[Auth Service]
    D[Transaction Service]
    E[Account Service]
    F[Fraud Detection]
    G[Notification Service]
  end

  A --> B
  B --> C
  B --> D
  D --> E
  D --> F
  D --> G

  subgraph "Monitoring & AIOps Stack"
    direction LR

    subgraph "Analysis & Intelligence"
      M[DDoS ML Detection]
      N[Auto-Baselining]
      O[Transaction Monitor]
      P[Cache Analyzer]
      Q[Container Monitor]
    end

    subgraph Collection
      T[Prometheus]
    end

    subgraph "Tracing & Visualization"
      R[Jaeger]
      S[Grafana]
    end

    M --> T
    N --> T
    O --> T
    P --> T
    Q --> T
    T --> S
    R --> S
  end

  subgraph "Data & Messaging Infra"
    direction LR
    H[MySQL]
    I[PostgreSQL]
    J[Redis Cache]
    K[RabbitMQ]
    L[Kafka]
  end

  D --> H
  E --> H
  O --> I
  P --> J
  G --> K
  G --> L
````

---

## 🔧 Technology Stack

| Category               | Technologies                                               |
| ---------------------- | ---------------------------------------------------------- |
| **Containerization**   | Docker, Docker Compose                                     |
| **Backend & Services** | Python (Flask), Node.js                                    |
| **Monitoring**         | Prometheus, Grafana, Alertmanager                          |
| **Tracing**            | OpenTelemetry, Jaeger                                      |
| **Databases & Cache**  | MySQL, PostgreSQL, Redis                                   |
| **Messaging**          | RabbitMQ, Kafka, Zookeeper                                 |
| **Core Libraries**     | Pandas, Scikit-learn, Tensorflow, Prometheus Client, OpenTelemetry SDK |

---

## 🏁 Getting Started

1. **Clone the repo**

   ```bash
   git clone https://github.com/Rishabhmannu/banking-observability-platform.git
   cd banking-observability-platform
   ```

2. **Launch the full stack**

   ```bash
   chmod +x safe_restart5.sh
   ./safe_restart5.sh
   ```

3. **Access UIs**

   * **Grafana**: [http://localhost:3000](http://localhost:3000) (admin / bankingdemo)
   * **Prometheus**: [http://localhost:9090](http://localhost:9090)
   * **Jaeger UI**: [http://localhost:16686](http://localhost:16686)
   * **RabbitMQ**: [http://localhost:15672](http://localhost:15672) (guest / guest)

---

## ⚙️ Operational Management

* `./system_status6.sh` – End-to-end health check
* `./safe_shutdown6.sh` – Graceful shutdown + backup
* `./safe_restart6.sh` – Staged restart + restore
* `./save_backup4.sh` – Live configuration snapshot

---

## 📈 Dashboards & Visualizations

*(Replace these placeholders with your actual screenshots)*

* **Transaction Performance Monitoring**
* **Container Resource Optimization**
* **Redis Cache Performance**

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).

---

## 👤 Author

**Rishabh Kumar** – Developed as part of the Summer Internship Program at ICICI Bank.

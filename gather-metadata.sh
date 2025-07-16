#!/usr/bin/env bash
set -euo pipefail

OUTFILE="services-metadata.txt"
PROM_API="http://localhost:9090/api/v1/targets"

# ─── Header ─────────────────────────────────────────────────────────────────
cat > "$OUTFILE" <<EOF
# Service Metadata Report
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

Fields:
  - Name
  - Port
  - Description
  - Category
  - Health endpoint
  - Key metrics (sample)
  - Docker image
EOF
echo >> "$OUTFILE"

# ─── Fetch & iterate targets ────────────────────────────────────────────────
curl -s "$PROM_API" \
  | jq -r '.data.activeTargets[]
      | select(.health=="up")
      | "\(.labels.job) \(.labels.instance)"' \
  | while read -r JOB INST; do

    echo "[gather] Processing $JOB @ $INST"
    HOST="${INST%%:*}"
    PORT="${INST##*:}"
    METRIC_URL="http://$INST/metrics"
    HEALTH_URL="http://$INST/healthz"

    # ─── Pre‑init defaults ───────────────────────────────────────────────────
    DESC="n/a"
    CAT="n/a"
    IMG="n/a"
    CID=""

    # ─── Special‑case host.docker.internal jobs ─────────────────────────────
    if [[ "$HOST" == "host.docker.internal" ]]; then
      # Try matching container by job name
      CID=$(docker ps \
            --filter "name=$JOB" \
            --format '{{.ID}}' \
            | head -n1 || true)

      # If we still don’t have a container, apply generic K8s description
      if [[ -z "$CID" ]]; then
        DESC="Kubernetes host‑level metrics (via Docker Desktop)"
        CAT="k8s‑monitoring"
      fi

    # ─── Special‑case Prometheus itself ───────────────────────────────────────
    elif [[ "$JOB" == "prometheus" ]]; then
      CID=$(docker ps \
            --filter "name=prometheus" \
            --format '{{.ID}}' \
            | head -n1 || true)

    # ─── Default: match container by instance hostname ────────────────────────
    else
      # strip any domain suffix, e.g. “node-exporter” from “node-exporter.local”
      SHORT_HOST="${HOST%%.*}"
      CID=$(docker ps \
            --filter "name=$SHORT_HOST" \
            --format '{{.ID}}' \
            | head -n1 || true)
    fi

    # ─── If container found, pull labels & image ─────────────────────────────
    if [[ -n "$CID" ]]; then
      # only overwrite if non‑empty
      tmp=$(docker inspect "$CID" \
            --format '{{ index .Config.Labels "description" }}' 2>/dev/null || echo "")
      [[ -n "$tmp" ]] && DESC="$tmp"

      tmp=$(docker inspect "$CID" \
            --format '{{ index .Config.Labels "category" }}' 2>/dev/null || echo "")
      [[ -n "$tmp" ]] && CAT="$tmp"

      tmp=$(docker inspect "$CID" --format '{{.Config.Image}}' 2>/dev/null || echo "")
      [[ -n "$tmp" ]] && IMG="$tmp"
    else
      echo "  → no container matching \"$HOST\" or job \"$JOB\""
    fi

    # ─── Sample first 5 metric names ──────────────────────────────────────────
    METRICS=$(curl -s "$METRIC_URL" \
                | awk '/^#/ { next } NF { print $1 }' \
                | sort -u \
                | head -n5 \
                | paste -sd"," - \
                || echo "n/a")

    # ─── Append to services.txt ───────────────────────────────────────────────
    cat >> "$OUTFILE" <<EOF

## $JOB
- **Port:** $PORT
- **Description:** $DESC
- **Category:** $CAT
- **Health endpoint:** $HEALTH_URL
- **Metrics (sample):** $METRICS
- **Docker image:** $IMG

EOF

done

echo "[gather] Complete: metadata written to $OUTFILE"

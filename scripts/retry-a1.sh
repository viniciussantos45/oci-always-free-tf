#!/usr/bin/env bash
# Keep trying to launch the Always Free A1 instance until Oracle has capacity.
#
# A1 "Out of host capacity" is transient: free ARM hosts appear and vanish
# minute-to-minute. This loops a *targeted* apply (A1 only, never the micros),
# cycling through the three Ashburn ADs, until one attempt succeeds.
#
# Usage:
#   ./scripts/retry-a1.sh                 # default: 270s between rounds, forever
#   SLEEP_SECONDS=120 MAX_ROUNDS=50 ./scripts/retry-a1.sh
#
# Stop early with Ctrl-C. Safe to re-run; it only ever targets the A1.
set -uo pipefail

cd "$(dirname "$0")/.."

SLEEP_SECONDS="${SLEEP_SECONDS:-270}"   # pause between full rounds (all 3 ADs)
MAX_ROUNDS="${MAX_ROUNDS:-0}"           # 0 = unlimited
AD_ORDER=(2 0 1)                        # AD-3 first, then AD-1, AD-2

round=0
while :; do
  round=$((round + 1))
  for idx in "${AD_ORDER[@]}"; do
    echo "[$(date '+%H:%M:%S')] round $round — trying A1 in AD index $idx ..."
    if terraform apply -auto-approve -compact-warnings \
         -target=oci_core_instance.a1 \
         -var="a1_availability_domain_index=${idx}"; then
      echo "[$(date '+%H:%M:%S')] SUCCESS — A1 created in AD index $idx 🎉"
      echo "Persist it: set a1_availability_domain_index = ${idx} in terraform.tfvars"
      exit 0
    fi
    echo "[$(date '+%H:%M:%S')] AD index $idx still out of capacity."
  done

  if [[ "$MAX_ROUNDS" -gt 0 && "$round" -ge "$MAX_ROUNDS" ]]; then
    echo "Gave up after $MAX_ROUNDS rounds. A1 still unavailable."
    exit 1
  fi
  echo "[$(date '+%H:%M:%S')] sleeping ${SLEEP_SECONDS}s before next round..."
  sleep "$SLEEP_SECONDS"
done

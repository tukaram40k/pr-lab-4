#!/usr/bin/env zsh

rm simulation/results.dat
rm simulation/diff*

QUORUMS=(1 2 3 4 5)
RESULTS_FILE="simulation/results.dat"

for q in $QUORUMS; do
  echo "========================================="
  echo "running with quorum=$q"

  file=".env"
  new_value=$q

  sed -i '' "s/^WRITE_QUORUM=[0-9][0-9]*$/WRITE_QUORUM=$new_value/" .env
  docker compose up -d

  while [ "$(docker compose ps --format '{{.Service}}' | wc -l)" -lt "6" ]; do
    sleep 1
  done
  sleep 1
  echo "running sim"

  latency=$(bundle exec ruby simulation/latency_tester.rb)
  store_invariant=$(bundle exec ruby simulation/follower_store_checker.rb)

  echo "$q $latency" >> $RESULTS_FILE
  echo "all stores match: $store_invariant"
  docker compose down -v
done

echo "done"

termgraph simulation/results.dat --delim " "
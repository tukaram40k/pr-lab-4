#!/usr/bin/env zsh

rm simulation/results.dat

QUORUMS=(1 2 3 4 5)
RESULTS_FILE="simulation/results.dat"

for q in $QUORUMS; do
  echo "========================================="
  echo "running with quorum=$q"

  export QUORUM=$q
  docker compose up -d --build

  latency=$(bundle exec ruby simulation/latency_tester.rb)

  echo "$q $latency" >> $RESULTS_FILE
  docker compose down -v
done

echo "done"

termgraph simulation/results.dat --delim " "
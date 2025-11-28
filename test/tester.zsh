#!/usr/bin/env zsh

sed -i '' "s/^WRITE_QUORUM=[0-9][0-9]*$/WRITE_QUORUM=2/" .env
docker compose up -d --build

while [ "$(docker compose ps --format '{{.Service}}' | wc -l)" -lt "6" ]; do
  sleep 1
done
sleep 1
echo "running test"

read -r mean_latency median_latency <<< "$(bundle exec ruby simulation/latency_tester.rb)"
store_invariant=$(bundle exec ruby simulation/follower_store_checker.rb)

if [[ -n "$mean_latency" && -n "$median_latency" ]]; then
    if [[ "$store_invariant" == "false" ]]; then
      echo "passed with quorum < num of followers"
    else
      echo "failed with quorum < num of followers"
      docker compose down -v
      exit 1
    fi
else
    echo "Error: latency metrics are empty"
    docker compose down -v
    exit 1
fi

docker compose down -v

sed -i '' "s/^WRITE_QUORUM=[0-9][0-9]*$/WRITE_QUORUM=5/" .env
docker compose up -d --build

while [ "$(docker compose ps --format '{{.Service}}' | wc -l)" -lt "6" ]; do
  sleep 1
done
sleep 1
echo "running test"

read -r mean_latency median_latency <<< "$(bundle exec ruby simulation/latency_tester.rb)"
store_invariant=$(bundle exec ruby simulation/follower_store_checker.rb)

if [[ -n "$mean_latency" && -n "$median_latency" ]]; then
    if [[ "$store_invariant" == "true" ]]; then
      echo "passed with quorum = num of followers"
    else
      echo "failed with quorum = num of followers"
      docker compose down -v
      echo "done"
      exit 1
    fi
else
    echo "latency metrics are empty"
    docker compose down -v
    exit 1
fi

docker compose down -v

echo "done"
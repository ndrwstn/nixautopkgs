#!/usr/bin/env bash

set -euo pipefail

results_dir="${1:-route-results}"
routing_file="${2:-packages/opencode-routing.json}"

systems=(
	"aarch64-darwin"
	"x86_64-darwin"
	"aarch64-linux"
	"x86_64-linux"
)

targets=("cli" "desktop")

if [[ ! -f "$routing_file" ]]; then
	echo "Routing file not found: $routing_file" >&2
	exit 1
fi

updated_routing="$(jq -c -S . "$routing_file")"
unresolved_count=0

for system in "${systems[@]}"; do
	result_file="${results_dir}/${system}.json"

	for target in "${targets[@]}"; do
		previous_route="$(jq -r --arg system "$system" --arg target "$target" '.[$system][$target] // empty' "$routing_file")"
		if [[ -z "$previous_route" ]]; then
			echo "Missing previous route for ${system}.${target}" >&2
			exit 1
		fi

		build_status="failure"
		bin_status="failure"

		if [[ -f "$result_file" ]]; then
			build_status="$(jq -r --arg target "$target" '.[$target].build // "failure"' "$result_file")"
			bin_status="$(jq -r --arg target "$target" '.[$target].bin // "failure"' "$result_file")"
		else
			echo "Missing result file for ${system}; holding previous routes" >&2
		fi

		if [[ "$build_status" == "success" ]]; then
			next_route="build"
		elif [[ "$bin_status" == "success" ]]; then
			next_route="bin"
		else
			next_route="$previous_route"
			unresolved_count=$((unresolved_count + 1))
			echo "No viable route for ${system}.${target}; preserving previous route (${previous_route})" >&2
		fi

		updated_routing="$(jq -c --arg system "$system" --arg target "$target" --arg route "$next_route" '.[$system][$target] = $route' <<<"$updated_routing")"
	done
done

printf '%s\n' "$updated_routing" | jq -S . >"$routing_file"

printf '%s\n' "$unresolved_count"

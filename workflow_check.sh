#!/bin/bash
# workflow_check.sh -- Monitor GitHub Actions workflow runs across all repos
# Usage: ./workflow_check.sh [--repo name] [--status all|success|failure] [--limit 20]

set -e
TOKEN="${GITHUB_TOKEN:?Set GITHUB_TOKEN env var}"
USER="OutrageousStorm"

check_workflows() {
    local repo_filter="${1:-}"
    local status_filter="${2:-all}"
    local limit="${3:-20}"

    echo "🔍 GitHub Actions Workflows"
    echo "User: $USER | Status: $status_filter | Limit: $limit"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Get all repos
    repos=$(curl -s -H "Authorization: token $TOKEN" \
        "https://api.github.com/users/$USER/repos?per_page=100" | \
        jq -r '.[].name')

    total_runs=0
    success_runs=0
    failed_runs=0

    for repo in $repos; do
        [[ -n "$repo_filter" && "$repo" != *"$repo_filter"* ]] && continue

        # Get workflow runs
        runs=$(curl -s -H "Authorization: token $TOKEN" \
            "https://api.github.com/repos/$USER/$repo/actions/runs?per_page=$limit" | \
            jq -r '.workflow_runs[] | "\(.name)|\(.status)|\(.conclusion)|\(.created_at)"')

        while IFS='|' read -r name status conclusion created; do
            [[ -z "$name" ]] && continue

            # Filter by status
            case "$status_filter" in
                success) [[ "$conclusion" != "success" ]] && continue ;;
                failure) [[ "$conclusion" != "failure" ]] && continue ;;
            esac

            icon="⏳"; [[ "$conclusion" == "success" ]] && icon="✅"
            [[ "$conclusion" == "failure" ]] && icon="❌"

            date_short=$(echo "$created" | cut -d'T' -f1)
            printf "  %-3s %-30s %-20s %s\n" "$icon" "${repo:0:25}" "${name:0:20}" "$date_short"

            ((total_runs++))
            [[ "$conclusion" == "success" ]] && ((success_runs++))
            [[ "$conclusion" == "failure" ]] && ((failed_runs++))
        done <<< "$runs"
    done

    echo ""
    echo "Summary: $total_runs runs | ✅ $success_runs | ❌ $failed_runs"
}

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo) REPO="$2"; shift 2 ;;
        --status) STATUS="$2"; shift 2 ;;
        --limit) LIMIT="$2"; shift 2 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

check_workflows "${REPO:-}" "${STATUS:-all}" "${LIMIT:-20}"

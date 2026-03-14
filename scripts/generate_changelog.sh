#!/usr/bin/env bash
###############################################################################
# generate_changelog.sh
# Generates a clean changelog for the BigWigsMods packager release pipeline.
# Strips release commits and Co-authored-by lines from the git log.
#
# Usage:  bash scripts/generate_changelog.sh [output_file]
# Env:    TAG_NAME           - tag to generate changelog for (optional)
#         GITHUB_REPOSITORY  - owner/repo for links (auto-set in GitHub Actions)
###############################################################################
set -euo pipefail

OUTPUT_FILE="${1:-.release/CHANGELOG.md}"
REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY must be set}"

PROJECT_NAME="${REPO##*/}"

if [[ -n "${TAG_NAME:-}" ]]; then
    current_tag="$TAG_NAME"
else
    current_tag="$(git describe --tags --abbrev=0)"
fi

previous_tag=""
if git describe --tags --abbrev=0 "${current_tag}^" >/dev/null 2>&1; then
    previous_tag="$(git describe --tags --abbrev=0 "${current_tag}^")"
fi

tag_date="$(git log -1 --format=%as "${current_tag}")"

mkdir -p "$(dirname "$OUTPUT_FILE")"

{
    echo "# ${PROJECT_NAME}"
    echo ""
    echo "## [${current_tag}](https://github.com/${REPO}/tree/${current_tag}) (${tag_date})"

    if [[ -n "$previous_tag" ]]; then
        printf "[Full Changelog](https://github.com/%s/compare/%s...%s)" \
            "$REPO" "$previous_tag" "$current_tag"
    else
        printf "[Full Changelog](https://github.com/%s/commits/%s)" \
            "$REPO" "$current_tag"
    fi

    printf " [Previous Releases](https://github.com/%s/releases)\n" "$REPO"
    echo ""
} > "$OUTPUT_FILE"

if [[ -n "$previous_tag" ]]; then
    range="${previous_tag}..${current_tag}"
else
    range="$current_tag"
fi

while IFS= read -r -d $'\0' record; do
    subject=""
    body=""
    while IFS= read -r line; do
        if [[ -z "$subject" ]]; then
            if [[ -n "$line" ]]; then
                subject="$line"
            fi
        else
            body+="$line"$'\n'
        fi
    done <<< "$record"

    [[ -z "$subject" ]] && continue

    if [[ "$subject" == chore:\ release\ * || "$subject" == chore\(*\):\ release\ * ]]; then
        continue
    fi

    echo "- ${subject}" >> "$OUTPUT_FILE"

    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*[Cc][Oo]-[Aa][Uu][Tt][Hh][Oo][Rr][Ee][Dd]-[Bb][Yy]: ]]; then
            continue
        fi

        if [[ "$line" =~ ^-+$ ]]; then
            continue
        fi

        if [[ -z "$line" ]]; then
            continue
        fi

        echo "    ${line}" >> "$OUTPUT_FILE"
    done <<< "$body"
done < <(git log --format='%s%n%b%x00' "$range")

echo "Changelog written to ${OUTPUT_FILE}"

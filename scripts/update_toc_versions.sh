#!/usr/bin/env bash
###############################################################################
# update_toc_versions.sh
# Fetches latest WoW interface versions from Blizzard's CDN and updates
# ## Interface directives in .toc files.
#
# Usage:  bash scripts/update_toc_versions.sh [--flavor FLAVOR]...
# Env:    None required (all config via CLI args)
###############################################################################
set -euo pipefail

readonly CDN_BASE="https://us.version.battle.net/v2/products"
readonly MAX_RETRIES=5
readonly RETRY_DELAY=2
readonly VALID_FLAVORS=("retail" "classic" "vanilla" "tbc")
readonly DEFAULT_EXCLUDE_DIRS=("Libs")

declare -A VERSION_CACHE

usage() {
    cat <<EOF
Usage: bash scripts/update_toc_versions.sh [OPTIONS]

Fetches latest WoW interface versions from Blizzard's CDN and updates
## Interface directives in .toc files.

Options:
  --flavor FLAVOR       Flavor to update (can be specified multiple times)
                        Valid: retail, classic, vanilla, tbc
                        Default: all flavors
  --exclude-dir DIR     Directory to exclude from TOC search (can be specified
                        multiple times). Default: Libs
  --help                Show this help message

Examples:
  bash scripts/update_toc_versions.sh
  bash scripts/update_toc_versions.sh --flavor retail --flavor classic
  bash scripts/update_toc_versions.sh --exclude-dir Libs --exclude-dir vendor
EOF
    exit 0
}

fetch_version() {
    local product="$1"

    if [[ -n "${VERSION_CACHE[$product]:-}" ]]; then
        echo "${VERSION_CACHE[$product]}"
        return 0
    fi

    local url="${CDN_BASE}/${product}/versions"
    local attempt=0
    local response=""

    while (( attempt < MAX_RETRIES )); do
        attempt=$((attempt + 1))
        response=$(curl -sf "$url" 2>/dev/null) && break

        if (( attempt < MAX_RETRIES )); then
            echo "  Retry ${attempt}/${MAX_RETRIES} for ${product}..." >&2
            sleep "$RETRY_DELAY"
        fi
    done

    if [[ -z "$response" ]]; then
        echo "ERROR: Failed to fetch version for ${product} after ${MAX_RETRIES} attempts" >&2
        return 1
    fi

    local versions_name=""
    versions_name=$(echo "$response" | awk -F'|' '$1 == "us" { print $6 }')

    if [[ -z "$versions_name" ]]; then
        echo "ERROR: Could not parse US region version for ${product}" >&2
        return 1
    fi

    local game_version=""
    game_version=$(echo "$versions_name" | awk -F. '{print $1"."$2"."$3}')

    local interface_version=""
    interface_version=$(echo "$game_version" | awk -F. '{printf "%d%02d%02d\n", $1, $2, $3}')

    VERSION_CACHE[$product]="$interface_version"

    echo "$interface_version"
}

find_toc_files() {
    local exclude_dirs=("$@")
    local find_args=()

    find_args+=("." "-name" "*.toc")

    for dir in "${exclude_dirs[@]}"; do
        find_args+=("-not" "-path" "*/${dir}/*")
    done

    find "${find_args[@]}"
}

update_toc_directive() {
    local toc_file="$1"
    local suffix="$2"
    local version="$3"

    local directive="## Interface${suffix}:"
    local pattern="^## Interface${suffix}: .*$"
    local replacement="## Interface${suffix}: ${version}"

    if ! grep -q "^## Interface${suffix}: " "$toc_file"; then
        return 1
    fi

    local current_value=""
    current_value=$(grep "^## Interface${suffix}: " "$toc_file" | sed "s/^## Interface${suffix}: //")

    local first_value
    first_value=$(echo "$current_value" | cut -d',' -f1 | tr -d ' ')

    if [[ "$first_value" == "$version" ]]; then
        echo "  ${directive} ${current_value} (unchanged)"
        return 1
    fi

    python3 - "$toc_file" "$suffix" "$version" <<'PY'
import pathlib
import re
import sys

toc_path = pathlib.Path(sys.argv[1])
suffix = sys.argv[2]
version = sys.argv[3]
pattern = re.compile(rf'^## Interface{re.escape(suffix)}: .*$', re.MULTILINE)
replacement = f'## Interface{suffix}: {version}'
content = toc_path.read_text(encoding='utf-8')
updated_content, replace_count = pattern.subn(replacement, content, count=1)

if replace_count != 1:
    raise SystemExit(f"Failed to update Interface{suffix} directive in {toc_path}")

toc_path.write_text(updated_content, encoding='utf-8')
PY

    echo "  ${directive} ${current_value} -> ${version}"
    return 0
}

update_toc_file() {
    local toc_file="$1"
    shift
    local flavors=("$@")

    local file_changed=false

    for flavor in "${flavors[@]}"; do
        case "$flavor" in
            retail)
                if update_toc_directive "$toc_file" "" "$RETAIL_VERSION"; then
                    file_changed=true
                fi
                ;;
            classic)
                if update_toc_directive "$toc_file" "-Mists" "$CLASSIC_VERSION"; then
                    file_changed=true
                fi
                if update_toc_directive "$toc_file" "-Classic" "$CLASSIC_VERSION"; then
                    file_changed=true
                fi
                ;;
            vanilla)
                if update_toc_directive "$toc_file" "-Vanilla" "$VANILLA_VERSION"; then
                    file_changed=true
                fi
                if [[ "$HAS_CLASSIC_FLAVOR" != "true" ]]; then
                    if update_toc_directive "$toc_file" "-Classic" "$VANILLA_VERSION"; then
                        file_changed=true
                    fi
                fi
                ;;
            tbc)
                if update_toc_directive "$toc_file" "-BCC" "$TBC_VERSION"; then
                    file_changed=true
                fi
                if update_toc_directive "$toc_file" "-TBC" "$TBC_VERSION"; then
                    file_changed=true
                fi
                ;;
        esac
    done

    $file_changed
}

main() {
    local flavors=()
    local exclude_dirs=()
    local exclude_dirs_specified=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help)
                usage
                ;;
            --flavor)
                if [[ -z "${2:-}" ]]; then
                    echo "ERROR: --flavor requires a value" >&2
                    exit 1
                fi
                local valid=false
                for v in "${VALID_FLAVORS[@]}"; do
                    if [[ "$2" == "$v" ]]; then
                        valid=true
                        break
                    fi
                done
                if [[ "$valid" != "true" ]]; then
                    echo "ERROR: Invalid flavor '${2}'. Valid: ${VALID_FLAVORS[*]}" >&2
                    exit 1
                fi
                flavors+=("$2")
                shift 2
                ;;
            --exclude-dir)
                if [[ -z "${2:-}" ]]; then
                    echo "ERROR: --exclude-dir requires a value" >&2
                    exit 1
                fi
                exclude_dirs+=("$2")
                exclude_dirs_specified=true
                shift 2
                ;;
            *)
                echo "ERROR: Unknown argument '${1}'" >&2
                echo "Run with --help for usage" >&2
                exit 1
                ;;
        esac
    done

    if [[ ${#flavors[@]} -eq 0 ]]; then
        flavors=("${VALID_FLAVORS[@]}")
    fi

    if [[ "$exclude_dirs_specified" != "true" ]]; then
        exclude_dirs=("${DEFAULT_EXCLUDE_DIRS[@]}")
    fi

    HAS_CLASSIC_FLAVOR="false"
    HAS_VANILLA_FLAVOR="false"
    for f in "${flavors[@]}"; do
        if [[ "$f" == "classic" ]]; then HAS_CLASSIC_FLAVOR="true"; fi
        if [[ "$f" == "vanilla" ]]; then HAS_VANILLA_FLAVOR="true"; fi
    done

    declare -A FLAVOR_PRODUCT
    FLAVOR_PRODUCT[retail]="wow"
    FLAVOR_PRODUCT[classic]="wow_classic"
    FLAVOR_PRODUCT[vanilla]="wow_classic_era"
    FLAVOR_PRODUCT[tbc]="wow_anniversary"

    declare -A FLAVOR_VERSION

    for flavor in "${flavors[@]}"; do
        local product="${FLAVOR_PRODUCT[$flavor]}"
        echo "Fetching ${flavor} (${product}) version from Blizzard CDN..."
        local version=""
        version=$(fetch_version "$product")
        FLAVOR_VERSION[$flavor]="$version"
        echo "  -> ${version}"
    done

    RETAIL_VERSION="${FLAVOR_VERSION[retail]:-}"
    CLASSIC_VERSION="${FLAVOR_VERSION[classic]:-}"
    VANILLA_VERSION="${FLAVOR_VERSION[vanilla]:-}"
    TBC_VERSION="${FLAVOR_VERSION[tbc]:-}"

    local updated_count=0
    local toc_files=()

    while IFS= read -r f; do
        toc_files+=("$f")
    done < <(find_toc_files "${exclude_dirs[@]}")

    if [[ ${#toc_files[@]} -eq 0 ]]; then
        echo "No .toc files found"
        exit 0
    fi

    for toc_file in "${toc_files[@]}"; do
        local has_directives=false
        for flavor in "${flavors[@]}"; do
            case "$flavor" in
                retail)
                    grep -q "^## Interface: " "$toc_file" 2>/dev/null && has_directives=true || true ;;
                classic)
                    grep -q "^## Interface-Mists: " "$toc_file" 2>/dev/null && has_directives=true || true
                    grep -q "^## Interface-Classic: " "$toc_file" 2>/dev/null && has_directives=true || true
                    ;;
                vanilla)
                    grep -q "^## Interface-Vanilla: " "$toc_file" 2>/dev/null && has_directives=true || true
                    if [[ "$HAS_CLASSIC_FLAVOR" != "true" ]]; then
                        grep -q "^## Interface-Classic: " "$toc_file" 2>/dev/null && has_directives=true || true
                    fi
                    ;;
                tbc)
                    grep -q "^## Interface-BCC: " "$toc_file" 2>/dev/null && has_directives=true || true
                    grep -q "^## Interface-TBC: " "$toc_file" 2>/dev/null && has_directives=true || true
                    ;;
            esac
        done

        if [[ "$has_directives" != "true" ]]; then
            continue
        fi

        echo "Updating ${toc_file}:"
        if update_toc_file "$toc_file" "${flavors[@]}"; then
            updated_count=$((updated_count + 1))
        fi
    done

    if (( updated_count > 0 )); then
        echo "Updated ${updated_count} files"
    else
        echo "No changes needed"
    fi

    exit 0
}

main "$@"

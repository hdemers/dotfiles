#!/usr/bin/env bash
#
# Generate a changelog grouped by tags from Jujutsu history.
#
# Usage:
#   changes.sh [options]
#
# Options:
#   -h, --help           Show this help message
#   -r, --revset         Custom revset for tags (default: 'tags()')
#   -s, --short          Show only first line of descriptions
#   -f, --from-version   Version tag to start the changelog from
#

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

readonly SCRIPT_NAME="${0##*/}"
DEFAULT_TAG_REVSET='tags()'

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [options]

Generate a changelog grouped by tags from Jujutsu history.

Options:
    -h, --help           Show this help message
    -r, --revset         Custom revset for tags (default: '${DEFAULT_TAG_REVSET}')
    -s, --short          Show only first line of descriptions
    -f, --from-version   Version tag to start the changelog from

Examples:
    ${SCRIPT_NAME}
    ${SCRIPT_NAME} --short
    ${SCRIPT_NAME} --from-version v1.2.0
    ${SCRIPT_NAME} --revset 'tags() & ancestors(@)'
EOF
}

die() {
    echo "${SCRIPT_NAME}: error: $*" >&2
    exit 1
}

check_dependencies() {
    if ! command -v jj &>/dev/null; then
        die "jj (Jujutsu) is not installed or not in PATH"
    fi
}

get_tags() {
    local revset="$1"
    jj log -r "${revset}" -T 'tags.join("\n") ++ "\n"' --no-graph --reversed 2>/dev/null \
        | grep -v '^$' \
        | uniq
}

format_description() {
    local short="$1"
    if [[ "${short}" == "true" ]]; then
        echo 'if(description, description.first_line() ++ "\n\n", "")'
    else
        echo 'if(description, description ++ "\n", "")'
    fi
}

print_changes_between() {
    local from_tag="$1"
    local to_tag="$2"
    local template="$3"

    local changes
    changes=$(jj log -r "${from_tag}..${to_tag}" -T "${template}" --no-graph --reversed 2>/dev/null || true)

    if [[ -n "${changes}" ]]; then
        echo "## ${to_tag}"
        echo
        echo "${changes}"
    fi
}

generate_changelog() {
    local tag_revset="$1"
    local short="$2"
    local from_version="$3"

    local template
    template=$(format_description "${short}")

    local tags_output
    tags_output=$(get_tags "${tag_revset}")

    if [[ -z "${tags_output}" ]]; then
        echo "No tags found matching revset: ${tag_revset}" >&2
        return 0
    fi

    local tags=()
    while IFS= read -r tag; do
        tags+=("${tag}")
    done <<<"${tags_output}"

    if [[ -n "${from_version}" ]]; then
        local found=false
        local filtered_tags=()
        local prev_for_filter=""
        local search_version="${from_version#v}"
        
        for tag in "${tags[@]}"; do
            local current_tag_stripped="${tag#v}"
            if [[ "${tag}" == "${from_version}" || "${current_tag_stripped}" == "${search_version}" ]]; then
                found=true
                if [[ -n "${prev_for_filter}" ]]; then
                    filtered_tags+=("${prev_for_filter}")
                fi
            fi
            if [[ "${found}" == "true" ]]; then
                filtered_tags+=("${tag}")
            fi
            prev_for_filter="${tag}"
        done

        if [[ "${found}" == "false" ]]; then
            echo "Error: --from-version tag '${from_version}' not found." >&2
            return 1
        fi
        tags=("${filtered_tags[@]}")
    fi

    local prev_tag=""
    for tag in "${tags[@]}"; do
        if [[ -n "${prev_tag}" ]]; then
            print_changes_between "${prev_tag}" "${tag}" "${template}"
        fi
        prev_tag="${tag}"
    done
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    local tag_revset="${DEFAULT_TAG_REVSET}"
    local short="false"
    local from_version=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -r|--revset)
                [[ $# -lt 2 ]] && die "option '$1' requires an argument"
                tag_revset="$2"
                shift 2
                ;;
            -s|--short)
                short="true"
                shift
                ;;
            -f|--from-version)
                [[ $# -lt 2 ]] && die "option '$1' requires an argument"
                from_version="$2"
                shift 2
                ;;
            -*)
                die "unknown option: $1"
                ;;
            *)
                die "unexpected argument: $1"
                ;;
        esac
    done

    check_dependencies
    generate_changelog "${tag_revset}" "${short}" "${from_version}"
}

main "$@"

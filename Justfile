template_path := "templates"
default_template_filename := "_posts-template.md"
default_path := "tech/techblog"
default_post_folder := "_posts"
today_date := `date "+%Y-%m-%d"`
# Create a new blog post
# Usage: just new POST_NAME [PATH]
new filename path=(default_path / default_post_folder):
    mkdir -p {{path}}
    cat {{template_path}}/{{default_template_filename}} > {{path}}/{{today_date}}-{{filename}}.md

# Create a new blog post with editor opening it.
# Usage: just newwith [editor] [POST_NAME] [PATH]
# [editor] will use $EDITOR as default
newwith editor=(env_var("EDITOR")) filename="new-post" path=(default_path / default_post_folder): (new filename path)
    @if [ -z "{{editor}}" ]; then \
        echo "ERROR: EDITOR environment variable is empty or not set (or editor argument missing)." >&2; \
        exit 1; \
    fi
    @if ! command -v {{editor}} > /dev/null 2>&1; then \
        echo "ERROR: EDITOR environment variable is set but the binary does not exist." >&2; \
        echo "WARN: The template is applied." >&2; \
        exit 1; \
    fi
    {{editor}} {{path}}/{{today_date}}-{{filename}}.md
# Single file auto-commit workflow
# Usage: just acsingle
# Prerequisite: must be in a git repository, and exactly 1 file changed (working tree + index)
acsingle:
    #!/usr/bin/env bash
    # Check if git command is available
    if ! command -v git > /dev/null 2>&1; then
        echo "ERROR: git not found" >&2
        exit 1
    fi
    # Check if current directory is a git repository
    if [ ! -d .git ]; then
        echo "ERROR: not a git repository (no .git directory)" >&2
        exit 1
    fi
    # Collect all changed files (unstaged, staged, untracked)
    all_files=$( { git diff --name-only -z; git diff --cached --name-only -z; git ls-files --others --exclude-standard -z; } | sort -u -z | tr '\0' '\n' | sed '/^$/d' )
    # Fail if no changes
    if [ -z "$all_files" ]; then
        echo "No changes" >&2
        exit 1
    fi
    # Count changed files, proceed only if exactly 1
    count=$(echo "$all_files" | wc -l | tr -d ' ')
    if [ "$count" -ne 1 ]; then
        echo "More than one file changed (or no changes)" >&2
        exit 1
    fi
    # Extract that single file name
    file=$(echo "$all_files")
    # Determine action type via git status (Create/Update/Delete)
    status=$(git status --porcelain -- "$file" | cut -c1-2)
    case "$status" in
        \?\?|A*) action="Create" ;;
        *D*)     action="Delete" ;;
        *)       action="Update" ;;
    esac
    # Stage all changes and commit
    git add -A
    git commit -m "$action $file"
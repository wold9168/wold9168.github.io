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
    {{editor}} {{path}}/{{today_date}}-{{filename}}.md
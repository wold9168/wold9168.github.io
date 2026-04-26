template := "---\nlayout: post\ntitle: \"TITLE\"\ntags: [TAGS,]\nauthor:\n  - wold9168\nmath: false\nrender_with_liquid: false\n---\n"
default_path := "tech/techblog"
default_post_folder := "_posts"
today_date := `date "+%Y-%m-%d"`
# Create a new blog post
# Usage: just new POST_NAME [PATH]
# Example: just new my-first-post
# Example: just new my-post "custom/path"
new filename path=(default_path / default_post_folder):
    mkdir -p {{path}}
    echo '{{template}}' > {{path}}/{{today_date}}-{{filename}}.md
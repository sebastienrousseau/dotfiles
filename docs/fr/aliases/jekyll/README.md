# Jekyll Core aliases

This `jekyll.aliases.zsh` file creates helpful shortcut aliases for many
commonly used [Jekyll](https://jekyllrb.com/) commands.

## Jekyll development aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| jkb | `JEKYLL_ENV=development bundle exec jekyll build` | Performs a one off build your site to ./_site. |
| jkc | `JEKYLL_ENV=development bundle exec jekyll clean` | Removes all generated files: destination folder, metadata file, Sass and Jekyll caches. |
| jkd | `JEKYLL_ENV=development bundle exec jekyll serve --watch --trace` | Does a development build of the site to '_site' and runs a local development server. |
| jkl | `JEKYLL_ENV=development bundle exec jekyll serve --livereload` | Does a development build of the site to '_site' and runs a local development server. |
| jko | `open http://localhost:4000/` | Open local development server. |

## Jekyll release aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| jkp | `JEKYLL_ENV=production bundle exec jekyll serve --watch --trace` | Does a production build of the site to '_site' and runs a local development server.|

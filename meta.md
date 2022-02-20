# Meta

I use [Obisidian](https://obsidian.md/) to edit this wiki. Because I'm a colossal cheapass, instead of using their publishing tools I publish using my own tool called [md_wiki_to_html](https://github.com/nickpegg/md_wiki_to_html)

md_wiki_to_html has a concept of ["flavors" of Markdown wikis that it supports](https://github.com/nickpegg/md_wiki_to_html/blob/93d3f04126474b1d2ba451507e3239f2107d5748/md_wiki_to_html/config.py#L30-L45). Has support for Obsidian right now but could support stuff like vimwiki in the future.

## Publish Process
1. I use the [shellcommands Obsidian plugin](https://publish.obsidian.md/shellcommands/) and have [a command defined](https://github.com/nickpegg/wiki.nickpegg.com/blob/2331e7476176ebd1fb2208662b918831a5fdf239/.obsidian/plugins/obsidian-shellcommands/data.json#L14-L17) which adds all .md and .obsidian files, does a `git commit`, then a `git push`
2. When the repo on GitHub receives a push to the `main` branch, it kicks off a workflow
3. The [workflow](https://github.com/nickpegg/wiki.nickpegg.com/blob/main/.github/workflows/publish.yml) runs `md_wiki_to_html` to render the HTML, then pushes to a Google Cloud Storage bucket for [wiki.nickpegg.com](https://wiki.nickpegg.com/)

## TODO
- [x] Write a basic tool to convert Obsidian Markdown to HTML
- [x] Open-source the publish tool
- [x] HTML template with CSS for wiki
- [x] Hosting on my server or a GCS bucket
- [x] fix wonky styling on [[test/styles]]
- [x] GitHub Action to publish to the bucket
- [x] Code highlighting
- [x] Make links look nicer on web
- [ ] Style wikilinks differently?
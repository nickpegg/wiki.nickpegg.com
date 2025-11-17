.PHONY: all init clean build push

all: clean push

.venv:
	uv venv

init: .venv
	uv pip install \
		mkdocs \
		mkdocs-terminal \
		mkdocs-git-revision-date-plugin \
		pygments \
		pymdown-extensions

clean:
	rm -r site || true

site:
	uv run mkdocs build

serve:
	uv run mkdocs serve

push: site
	gsutil -m rsync -d -r .output gs://wiki.nickpegg.com/

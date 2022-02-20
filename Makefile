.PHONY: all init clean build push

all: clean build push

init:
	python -m pip install --upgrade pip
	pip install git+https://github.com/nickpegg/md_wiki_to_html

clean:
	rm -r .output || true

build:
	md_wiki_to_html -v render --template .meta/template.html --output .output

push:
	gsutil -m rsync -d -r .output gs://wiki.nickpegg.com/

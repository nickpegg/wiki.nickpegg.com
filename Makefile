.PHONY: all clean build push

all: clean build push

clean:
	rm -r .output || true

build:
	md_wiki_to_html -v render --template .meta/template.html --output .output

push:
	gsutil -m rsync -d -r .output gs://wiki.nickpegg.com/

.PHONY: all clean build push

all: clean build push

clean:
	rm -r _output || true

build:
	md_wiki_to_html -v render --template _meta/template.html

push:
	gsutil -m rsync -d -r _output gs://wiki.nickpegg.com/

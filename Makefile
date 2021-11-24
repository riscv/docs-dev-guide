HEADER_SOURCE := book_header.adoc
PDF_RESULT := example.pdf
# Not all document sources are yet listed here.  Not just adoc files but
# images/ and resources/ content.  Once they are the target can remove the
# phony use.
SOURCES := $(HEADER_SOURCE)

all: $(PDF_RESULT)

.PHONY: $(PDF_RESULT)
$(PDF_RESULT): $(SOURCES)
	asciidoctor-pdf \
    --attribute=mathematical-format=svg \
    --attribute=pdf-fontsdir=resources/fonts \
    --attribute=pdf-style=resources/themes/riscv-pdf.yml \
    --failure-level=ERROR \
    --require=asciidoctor-bibtex \
    --require=asciidoctor-diagram \
    --require=asciidoctor-mathematical \
    --out-file=$@ \
    $(HEADER_SOURCE)

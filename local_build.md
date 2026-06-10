[![Build Document PDF](https://github.com/riscv/docs-templates/actions/workflows/build-pdf.yml/badge.svg?branch=main)](https://github.com/riscv/docs-templates/actions/workflows/build-pdf.yml)

# Setting up a local build

This documents requirements and procedures to set up a local build.

In addition, this record of the build process should be kept in sync with any changes made to the github actions build.

## A comment on Asciidoctor toolchains

Because there are several different toolchains that can be used for publishing content from AsciiDoc, you might come across different sources of information on the Web.

The Asciidoctor toolchains include ones that use:

- python (old)
- Ruby (established)
- NPM (new)

We are using the Ruby toolchain because it supports building the customizable, full-featured pdf required for RISC-V specifications.

To support building WaveDrom diagrams directly from scripts contained in blocks in the AsciiDoc source files, we use NPM to install the wavedrom-cli, even though we are using the Ruby toolchain.

NOTE: Even though NPM is required for the Wavedrom diagrams to work properly, we are *not* using the Asciidoctor NPM toolchain.

## Install Ruby on MacOS

Install Ruby using RVM, and then install the Asciidoctor gem.

RVM is a Ruby installation and version manager. RVM works by installing Ruby inside your home directory and manages the environment variables to allow you to switch between the system-wide Ruby and any Ruby installed using RVM.

ALERT: RVM is essential for creating pdfs because, paradoxically, the pdf build works best using Ruby version 2.5.x rather than more recent version.

- Install the RVM (https://rvm.io/rvm/install):

```cmd
\curl -sSL https://get.rvm.io | bash -s stable --ruby
```

RVM will download and build the Ruby language and RubyGems along with several essential gems and configure your PATH environment variable.

After the install is finished, open a new Terminal window and remove your local Gem configuration, if you have one (or move it out of the way):

```cmd
rm -f HOME/.gemrc
```

For the purpose of the pdf build, install Ruby version 2.5.x:


```cmd
rvm install ruby-2.5
```

## MacOS—use RVM on MacOS

When using RVM, you can switch between the system-wide Ruby and RVM-managed Ruby using these two commands:

- Switch to system-wide Ruby:

```cmd
rvm use system
```

- Switch to RVM-managed version 2.5.9 for use in building pdf:

```cmd
rvm use 2.5.9
```

ALERT: Ensure that you are using the same Ruby version for all Ruby gems that you install for the Asciidoctor toolchain.

## Windows—install Ruby with RVM

NOTE: Users of Windows 10 are reporting problems with RVM. We plan to test the use of Cygwin as a workaround. Please note that if you don't need asciidoctor-mathematical for rendering of mathematical expressions, you can make use of Ruby 2.7.2.

- For Windows, use: http://rubyinstaller.org/

NOTE: During the Windows install, click in the installer to:

- associate the .rvm with the current version
- add paths
- add tdtk

ALERT: Ensure that you are using the same Ruby version for all gems that you install for the Asciidoctor toolchain.

## MacOS--install Asciidoctor

- Install Asciidoctor:

```cmd
gem install asciidoctor
```

- Verify Asciidoctor is installed:

```cmd
asciidoctor --version
```

If you see the Asciidoctor version information printed in the terminal, then you’re already able to build html from an .adoc file using:

```cmd
asciidoctor filename.adoc
```

### Windows—add the Asciidoctor gem

- Navigate to the following url:

```cmd
https://rubygems.org/gems/asciidoctor/
```

- Scroll down to the latest version and click the *download* button.

- In Powershell, use the following command to install the Asciidoctor gem:

```cmd
gem install asciidoctor <path-to-downloaded-gem>
```

## Both Windows and MacOS, for pdf's and bibliographies

Install the following:

* asciidoctor-pdf gem, which is needed for pdf rendering.
* asciidoctor-bibtex gem, which is needed for auto-creation of a bibliography from citations.

```cmd
gem install asciidoctor-pdf
gem install asciidoctor-bibtex
```

Information on the markup required for use of diagramming, mathemtical notation, and creating a bibliography with references to it, see the `example.pdf` in this repo.


## Add syntax highlighting gems for AsciiDoc output

Install syntax highlighting gems as follows (for Windows, append the string `--source http://rubygems.org` to each command):

```cmd
gem install coderay
gem install rouge
gem install pygments.rb
```

## Add NVM, node 15, and `wavedrom-cli` for WaveDrom diagrams

For MacOS, use brew to install nvm and create an nvm directory:

```cmd
brew install nvm
mkdir ~/.nvm
```

open either ~/.bash_profile or ~/.zshrc (for macOS Catalina or later) in vim or nano.


```cmd
nano ~/.bash_profile
```

```cmd
vim ~/.zshrc
```

Add the following lines to the profile:

```cmd
export NVM_DIR=~/.nvm
source $(brew --prefix nvm)/nvm.sh
```

Load the profile:

```cmd
source ~/.zshrc
```

```cmd
source ~/.bash_profile
```

Install the most recent node, node 15, and make node 15 the version you use:

```cmd
nvm install node
nvm install 15
nvm use 15
```

And finally, on node 15, install wavedrom-cli:

```cme
npm install -g wavedrom-cli
```

Check that wavedrom-cli is in the path (this should display the help):

```cmd
wavedrom-cli
```

For Windows:

WARNING: We can guess that node 15 is required for Windows.

Download the installer from https://nodejs.org/en/ and install node, then use npm to install wavedrom-cli:

```cmd
npm install -g wavedrom-cli
```
Whether you are using Windows of MacOS, check that wavedrom-cli is in the path (this should display the help):

```cmd
wavedrom-cli
```

WARNING: For the MacOS, if you upgrade from a prior version to Big Sur, you must reinstall first the NPM and then the NPM version of the wavedrom-cli.

## Run a local Kroki server for diagrams

The RISC-V documentation site uses [Kroki](https://kroki.io) to render diagrams (including WaveDrom, Bytefield, Graphviz, and others) server-side. The dev playbook at `antora-dev.riscv.org` is configured to reach a local Kroki instance on port 9870.

Start the Kroki server with Docker:

```cmd
docker run -d -p 9870:8000 yuzutech/kroki
```

The `-d` flag runs it in the background. The container will restart automatically on subsequent Docker starts unless explicitly stopped.

To stop it:

```cmd
docker stop $(docker ps -q --filter ancestor=yuzutech/kroki)
```

The dev playbook already has `kroki-server-url: http://localhost:9870` set in its `asciidoc.attributes`, so no additional configuration is needed once the container is running.

## Graphviz is used for diagrams in some appendices

To support graphviz on the Mac, use brew

```cmd
brew install graphviz
```
For WIndows, see https://graphviz.org/download/

## Install the prerequisites for asciidoctor-mathematical

Support for mathematical notation is not required for each and every specification, and installing both the prerequisites and the gem itself have been tricky on the Mac.

```cmd
brew install pango gdk-pixbuf cairo cmake
```

ALERT: You can find various discussions about problems with getting asciidoctor-mathematical to install properly on the MacOS, and the solutions vary. It appears that after more than one MacOS update, the file permissions can cause problems. It appears that cleaning up prior versions of Ruby (while maintaining the current version installed with the Xcode developer tools), and completely removing and reinstalling RVM can resolve the problem.

## Install gems that support Wavedrom and for Mathematical

Now that the prerequisites are installed, install the two additional gems:

```cmd
gem install asciidoctor-diagram
gem install asciidoctor-mathematical
```

## Add a RISC-V bibliography

The `asciidoctor-bibtex` gem enables the use of bibtex directly from AsciiDoc for auto-generation of a bibliography from citations within the AsciiDoc text. It also allows for the use of the existing `riscv-spec.bib` file that was created for the LaTeX build.

To enable the use of `asciidoctor-bibtex`, install the prerequisites and the `asciidoctor-bibtex` gem:

```cmd
gem install ruby-dev
gem install citeproc-ruby
gem install csl-styles
gem install asciidoctor-bibtex
```

You can then add a bibliography to your appendices and use bibtex conventions to add citations into your AsciiDoc text files.

Details of how to work with bibtex and the RISC-V bibliogrpahy are in the example.pdf file.


## AsciiDoc document header and styles

Attributes in the document header for RISC-V AsciiDoc content control aspects of the pdf build. Together with the `docs-resources/themes/riscv-pdf.yml` file, they enable, among other things, numbered headings, a TOC, running headers and footers, footnotes at chapter ends, custom fonts, admonitions, an index, and an optional colophon.

The entry point for the build is `modules/ROOT/pages/spec-sample.adoc`. This file contains the document header attributes and uses `include::` directives to pull in the chapter files. The `docs-resources/global-config.adoc` submodule file provides shared attributes such as `:company:` and `:doctype:`.

NOTE: The header is already in the template. The only changes you normally need to make are to update `:revnumber:`, `:revremark:`, and author metadata, then add chapter files using `include::chapter.adoc[]` in the order you want them to appear.

## Create and add a new chapter file

- In your text editor, create a new file in `modules/ROOT/pages/`.
- Assign a meaningful name and save it with the `.adoc` extension.
- Begin the file with a section heading (`==`) rather than a document title (`=`), since it will be included into `spec-sample.adoc`.
- Add an `include::chapter-name.adoc[]` line in `modules/ROOT/pages/spec-sample.adoc` in the position where you want the chapter to appear.
- Add an `xref:chapter-name.adoc[Chapter Title]` entry to `modules/ROOT/nav.adoc` so the chapter appears in the Antora site navigation.

## HTML build

Building in HTML is a good way to check that your content under development builds properly.

The simplest approach from the repository root is:

```cmd
make
```

This builds both PDF and HTML output to the `build/` directory, using Docker if available or native tooling otherwise.

To build HTML only without the Makefile, run:

```cmd
asciidoctor modules/ROOT/pages/spec-sample.adoc
```

For pdf output without the Makefile, cd into the repository root and use:

```cmd
asciidoctor-pdf -r asciidoctor-mathematical -a mathematical-format=svg \
  -r asciidoctor-bibtex -r asciidoctor-diagram \
  -a pdf-theme=docs-resources/themes/riscv-pdf.yml \
  -a pdf-fontsdir=docs-resources/fonts/ \
  modules/ROOT/pages/spec-sample.adoc
```

ALERT: When copying/pasting commands for the CLI on the Windows OS, check that no substitutions are being made. We have seen the `=` get replaced with a `#`, causing an error message about fonts.

## Antora site build

To preview how the specification will appear as a multi-page HTML site (as it will be published on the RISC-V documentation site), use:

```cmd
make antora
```

Output is written to `build/site/`. This requires Node.js 18+ and either `antora` on your PATH or `npx` available.

### Install Antora

```cmd
npm install -g antora
```

Verify:

```cmd
antora --version
```

If you prefer not to install globally, `make antora` will automatically fall back to `npx antora` if `antora` is not on your PATH.

## AsciiDoc  and Asciidoctor toolchain documentation

* AsciiDoc writers' guide: https://asciidoctor.org/docs/asciidoc-writers-guide/
* AsciiDoc quick reference: http://asciidoctor.org/docs/asciidoc-syntax-quick-reference/
* Asciidoctor user manual: http://asciidoctor.org/docs/user-manual/

## Conversion

Almost all conversions require some cleanup.

The most reliable converter from LaTeX to AsciiDoc that I have found is Pandoc:

https://pandoc.org/getting-started.html

After installing Pandoc on your machine, you can begin the conversion using the following pattern:

```cmd
pandoc source_file.tex -s -o destination_file.adoc
```

After that first step, you must open the file using a text editor with a good AsciiDoc linter and clean it up.

You can find a list of text editors that support AsciiDoc authoring (with linters and/or syntax highlighting) in its documentation at https://docs.asciidoctor.org/asciidoctor/latest/tooling/, and a more comprehensive list at https://github.com/bodiam/awesome-asciidoc.

While Pandoc does a reasonably good job, there are always documentation nits that must be addressed.

## If you want to make use of change bars

The current procedure for changebars is, admittedly, a bit fiddly, but the convenience value of changebars that show up in a pdf can make them worth the effort.

To support changebars, the following has been added to the YAML stylesheet:

```yml
role:
  Changed:
    border:
      width: .25
      changebar: 1
      color: $base_font_color
      offset: 2
```
Note the changebar entry--this is used as a key to key to create the bars.

To support rendering of changebars in your local build, you must modify two files in your local gem:

transform.rb line18 :

```rb
       'border_changebar' => :border_changebar,
```

text_background_and_border_renderer.rb line 38:

```rb
if (border_width = data[:border_changebar])
        border_width = 1
        border_color = data[:border_color]
        prev_stroke_color = pdf.stroke_color
        prev_line_width = pdf.line_width
        pdf.stroke_color border_color
        pdf.line_width border_width
        pdf.stroke_vertical_line fragment.top + border_offset, fragment.top-height, :at => 50 - pdf.bounds.absolute_left
        pdf.stroke_color prev_stroke_color
        pdf.line_width prev_line_width
      elsif (border_width = data[:border_width])
```

At this point changebars require manual entry and removal. You can find documentation for how to use markup for changebars in the example.pdf.

Technical staff is exploring further automated processing and CI/CD.

### Link to more on authoring in AsciiDoc

https://docs.google.com/document/d/1fUWEM3b-lbHQRruvAw3BUOA_ND_cJD0bsijV5bESklA/edit#heading=h.vnvsmcc95mc3


### Link to JDK

You can find information on installing the JDK on a MacOS here: https://docs.oracle.com/en/java/javase/15/install/installation-jdk-macos.html#GUID-F575EB4A-70D3-4AB4-A20E-DBE95171AB5F

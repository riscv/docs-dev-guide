# Docs templates and build process

Documentation templates and build tools

This repo includes documentation and tools for building RISC-V specification documents using Asciidoc

When you clone this repo, you have the file structure on your machine that you need for creating pdfs from asciidoc, along with example files that demonstrate how to handle the use cases that we have encountered.

This is a work in progress, so please let us know if you have questions.

## Asciidoc needs Asciidoctor

- To author in Asciidoc, you must install Asciidoctor.

- To install Asciidoctor, you must install Ruby.

- To create a pdf from Asciidoc, you must install asciidoctor-pdf and a few additional rubies.

## Install Ruby on Mac

Asciidoctor's Web site recommends installing Ruby using RVM, and then Asciidoctor.

RVM is essential for creating pdfs because the pdf build requires Ruby version 2.7.x.

RVM is a Ruby installation and version manager. RVM works by installing Ruby inside your home directory and manages the environment variables to allow you to switch between the system-wide Ruby and any Ruby installed using RVM.

- Install RVM along with the latest version of Ruby:

```
\curl -#L https://get.rvm.io | bash -s stable --autolibs#3 --ruby
```

RVM will download and build the Ruby language, install RubyGems along with several essential gems and configure your PATH environment variable.

- Source your shell configuration (only necessary in the window you used to install RVM):

```
source HOME/.bash_profile
```

- Remove your local Gem configuration, if you have one (or move it out of the way):

```
rm -f HOME/.gemrc
```

## Mac—use RVM on Mac


When using RVM, you can switch between the system-wide Ruby and RVM-managed Ruby using these two commands:

- Switch to system-wide Ruby:

```
rvm use system
```

- Switch to RVM-managed versions 2.7.2 for use in building pdf:

```
rvm use 2.7.2
```

## Install Asciidoctor on Mac

- Install Asciidoctor:

```
gem install asciidoctor
```

- Verify Asciidoctor is installed:

```
asciidoctor --version
```

If you see the Asciidoctor version information printed in the terminal, then you’re already able to build html from an .adoc file using:

```
asciidcotor filename.adoc
```

## Windows—install Ruby with RVM

- For Windows, use: http://rubyinstaller.org/

NOTE: During the Windows install, click in the installer to:

- associate the .rvm with the current version
- add paths
- add tdtk

## Windows—add the Asciidoctor gem

- Navigate to the following url

```
https://rubygems.org/gems/asciidoctor/
```

- Scroll down to the latest version and click the *download* button.

- In Powershell, use the following command to install the Asciidoctor gem:

```
gem install asciidoctor <path-to-dowloaded-gem>
```

## Both Win and Mac, for pdf's

Install the asciidoctor-pdf gem, which is needed for pdf rendering:

```
gem install asciidoctor-pdf --pre --source http://rubygems.org
```

## Add syntax highlighting gems for Asciidoc output

Install syntax highlighting gems as follows (for Windows, append the string --source http://rubygems.org to each command):

```
gem install coderay
gem install rouge
gem install pygments
``` 

## Asciidoc headers

Most of the information in the book headers for RISC-V asciidoc content contain information that relates to the fully functional pdf build that enables, among other things, numbered headings, a TOC, running headers and footers, footnotes at chapter ends, custom fonts, admonitions, an index, and an optional colophon. 

For shorter documents, you have the option of using a report header.

NOTE: The headers are already in the template files. The only changes you normally need to make are to add chapter-sized sections in using the syntax `include::filename.adoc[]` in the order by which you want them to appear.

## Create and name a new .adoc file

- In your text editor, create a new file.
- Assign a name and save with the .adoc extension.
- In the first line, add `[file_name]` (using a meaningful string for the filename) and in the second line, use a double "==" to indicate a topic heading, add some content, and save the file with an `.adoc` file extension.
- In the header file, add `include::file_name.adoc` and save it.

NOTE: Blank lines are not allowed in between the `include::file_name.adoc` files.

## HTML build

Building in HTML is a good way to check that your content under development builds properly. 

As soon as you have installed asciidoctor, you can build HTML content from any `.adoc` file on your own machine:

- CD into the directory that contains your `.adoc` files.

```
asciidoctor any_file_name.adoc
```
This generates a file named `any_file_name.html`.

For pdf output, cd into this cloned directory and use this command:

```
asciidoctor-pdf book_header.adoc -a pdf-style#resources/themes/risc-v_spec-pdf.yml -a pdf-fontsdir=resources/fonts
```

This generates a file named `book_header.pdf`. 

For your own content, change the name of the header file to a meaningful file name.

## Asciidoc/asciidoctor documentation

* Asciidoc/asciidoctor writers' guide: https://asciidoctor.org/docs/asciidoc-writers-guide/
* Asciidoc quick reference: http://asciidoctor.org/docs/asciidoc-syntax-quick-reference/
* Asciidoctor user manual: http://asciidoctor.org/docs/user-manual/


## Conversion

All conversions require cleanup.

The most relaible converter from LaTeX to asciidoc that I have found is pandoc:

https://pandoc.org/getting-started.html

After installing pandoc on your machine, you can begin the conversion using the following pattern:

```cmd
pandoc source_file.tex destination_file.adoc
```

After that first step, you must open the file using a text editor with a good asciidoc linter and clean it up.

While pandoc does a reasonably good job, there are always documentation nits that must be addressed.


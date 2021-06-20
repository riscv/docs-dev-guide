# Docs templates and build process

This repo contains documentation templates and information on build tools for the Asciidoctor toolchain, for building professional quality pdfs of RISC-V specification documents using AsciiDoc with the Asciidoctor toolchain.

We have documented both MacOS and Windows installs--please scroll down to find Windows. If you are a contributor and need assistance, please contact us.

When you clone this repo, you have the file structure on your machine that you need for creating professional quality pdfs from AsciiDoc, along with example files that demonstrate how to handle the use cases that we have encountered.

This is a work in progress, and the tools can change, so please let us know if you run into problems and/or have questions.

NOTE: There is a separate pdf build process that uses a different toolchain.  

## To perform a build, AsciiDoc needs Asciidoctor

- To author in AsciiDoc, you must install Asciidoctor.

- For the full featured pdf that we are implementing, we use Ruby and install gems that support the features.

- To support building WaveDrom diagrams directly from scripts contained in blocks in the AsciiDoc source files, we use npm to install the wavedrom-cli.

- Support for mathematical notation is not required for each and every specification, and installing both the prerequisites and the gem itself has been tricky on the Mac. Use of `brew `

## Install Ruby on MacOS

Asciidoctor's Web site recommends first installing Ruby using RVM, and then Asciidoctor.

ALERT: RVM is essential for creating pdfs because, paradoxically, the pdf build works best using Ruby version 2.5.x rather than more recent version..

RVM is a Ruby installation and version manager. RVM works by installing Ruby inside your home directory and manages the environment variables to allow you to switch between the system-wide Ruby and any Ruby installed using RVM.

- Install the RVM (https://rvm.io/rvm/install):

```
\curl -sSL https://get.rvm.io | bash -s stable --ruby
```

RVM will download and build the Ruby language and RubyGems along with several essential gems and configure your PATH environment variable.

After the install is finished, open a new Terminal window and remove your local Gem configuration, if you have one (or move it out of the way):

```
rm -f HOME/.gemrc
```

For the purpose of the pdf build, install Ruby version 2.5.x:


```
rvm install ruby-2.5
```

## MacOS—use RVM on MacOS

When using RVM, you can switch between the system-wide Ruby and RVM-managed Ruby using these two commands:

- Switch to system-wide Ruby:

```
rvm use system
```

- Switch to RVM-managed versions 2.5.9 for use in building pdf:

```
rvm use 2.5.9
```

ALERT: Ensure that you are using Ruby 2.5.9 for all Ruby gems that you install for the Asciidoctor toolchain. 

## Windows—install Ruby with RVM

- For Windows, use: http://rubyinstaller.org/

NOTE: During the Windows install, click in the installer to:

- associate the .rvm with the current version
- add paths
- add tdtk

ALERT: Ensure that you are using Ruby 2.5.9 for all gems that you install for the Asciidoctor toolchain. 

## MacOS--install Asciidoctor

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
asciidoctor filename.adoc
```

### Windows—add the Asciidoctor gem

- Navigate to the following url:

```
https://rubygems.org/gems/asciidoctor/
```

- Scroll down to the latest version and click the *download* button.

- In Powershell, use the following command to install the Asciidoctor gem:

```
gem install asciidoctor <path-to-downloaded-gem>
```

## Both Windows and MacOS, for pdf's and bibliographies

Install the following:

* asciidoctor-pdf gem, which is needed for pdf rendering.
* asciidoctor-bibtex gem, which is needed for auto-creation of a bibliography from citations.

```
gem install asciidoctor-pdf 
gem install asciidoctor-bibtex
```

Information on the markup required for use of diagramming, mathemtical nottion, and creating a bibliography with references to it, see the `example.pdf` in this repo.

## 

## Add syntax highlighting gems for AsciiDoc output

Install syntax highlighting gems as follows (for Windows, append the string `--source http://rubygems.org` to each command):

```
gem install coderay
gem install rouge
gem install pygments.rb
``` 

## Add node and `wavedrom-cli` for WaveDrom diagrams

NOTE: It appears that Oracle JDK is also required for WaveDrom diagrams to work.

For MacOS:
```
brew install node
npm install -g wavedrom-cli
 ```

Check that wavedrom-cli is in the path (this should display the help):

```
wavedrom-cli
```

For Windows:

Download the installer from https://nodejs.org/en/ and install node, then use npm to install wavedrom-cli:

```
npm install -g wavedrom-cli
```
Check that wavedrom-cli is in the path (this should display the help):

```
wavedrom-cli
```

NOTE: For the MacOS, if you upgrade from a prior version to Big Sur, you must reinstall first the NPM and then the NPM version of the wavedrom-cli.

## Intall the prerequisites for Mathematical

```
brew install pango gdk-picbuf cairo 
```

## Install gems for Wavedrom and for Mathematical

Now that the prerequisites are installed, install the two additional gems:

```
gem install asciidoctor-diagram
gem instll asciidoctor-mathematical
```

## AsciiDoc book headers

Attributes in the book headers for RISC-V AsciiDoc content control aspects of the pdf build. Together with the `risc-v_spec-pdf.yml` file, they enable, among other things, numbered headings, a TOC, running headers and footers, footnotes at chapter ends, custom fonts, admonitions, an index, and an optional colophon. 

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

As soon as you have installed Asciidoctor, you can build HTML content from any `.adoc` file on your own machine:

- CD into the directory that contains your `.adoc` files.

```
asciidoctor any_file_name.adoc
```
This generates a file named `any_file_name.html`.

For pdf output, cd into this cloned directory and use this command:

```
asciidoctor-pdf -r asciidoctor-diagram book_header.adoc -a pdf-style=resources/themes/risc-v_spec-pdf.yml -a pdf-fontsdir=resources/fonts
```

This generates a file named `book_header.pdf` that makes use of the graphics, styles, and fonts that you can see in the example.pdf. 

For your own content, change the name of the header file to a meaningful file name.

ALERT: When copying/pasting commands for the CLI on the Windows OS, check that no substitutions are being made. We have seen the '=' get replaced with a '#', causing an error message about fonts.

## AsciiDoc  and Asciidoctor toolchain documentation

* AsciiDoc writers' guide: https://asciidoctor.org/docs/asciidoc-writers-guide/
* AsciiDoc quick reference: http://asciidoctor.org/docs/asciidoc-syntax-quick-reference/
* Asciidoctor user manual: http://asciidoctor.org/docs/user-manual/


## Conversion

Almost all conversions require some cleanup.

The most reliable converter from LaTeX to AsciiDoc that I have found is pandoc:

https://pandoc.org/getting-started.html

After installing pandoc on your machine, you can begin the conversion using the following pattern:

```cmd
pandoc source_file.tex destination_file.adoc
```

After that first step, you must open the file using a text editor with a good AsciiDoc linter and clean it up.

You can find a list of text editors that support AsciiDoc authoring in its documentation at https://docs.asciidoctor.org/asciidoctor/latest/tooling/, and a more comprehensive list at https://github.com/bodiam/awesome-asciidoc.

While pandoc does a reasonably good job, there are always documentation nits that must be addressed.





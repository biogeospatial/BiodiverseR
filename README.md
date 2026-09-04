
<!-- README.md is generated from README.Rmd. Please edit that file -->

**NOTE**: This is currently in development.

# BiodiverseR

Provides an R interface to the analyses available in Biodiverse.
Biodiverse is a tool for the spatial analysis of diversity using indices
based on taxonomic, phylogenetic, trait and matrix-based (e.g. genetic
distance) relationships, as well as related environmental and temporal
variations. More information is available at its [Github
page](https://github.com/shawnlaffan/biodiverse).

## Installation

You can install BiodiverseR as an end user or as a developer. If you
only want to use BiodiverseR, follow the [end user installation
instructions](#End-User-installation) below. If you want to develop
BiodiverseR, follow the [developer installation
instructions](#Developer_installation) below.

**NOTE:** You will need a working installation of R. Follow the R installation
instructions at [The R
Project](https://www.r-project.org/).

### End User installation

Below are instructions for installing BiodiverseR on Windows or
unix-derived systems like MacOS and Linux.

#### Windows

In R, run the following commands to install and test BiodiverseR:

``` r
install.packages("pak")               # Install pak for managing package installs
pak::pak("biogeospatial/BiodiverseR") # Install BiodiverseR from GitHub

# Load the BiodiverseR package
library(BiodiverseR)

# Load an example basedata file and start its server
bd <- BiodiverseR::basedata$new(
  filename = system.file("extdata", "example.bds", package = "BiodiverseR")
)

# Print the bd object to confirm successful creation
bd

# Confirm that the server is running
bd$server_status()

# Optional: stop the server when finished
bd$stop_server()
```

#### macOS and Linux

The simpler bundled installation is not yet available for macOS and Linux.

Most Unix-like systems, including Linux and macOS, provide a system Perl
installation. We recommend using a separate Perl installation managed by
[Perlbrew](https://perlbrew.pl/Installation.html) instead.

After installing Perlbrew, install `cpanm` by running this command in your
terminal:

``` sh
perlbrew install-cpanm
```

Git must also be installed because the Biodiverse engine and its Perl
dependencies are currently downloaded from GitHub. See the
[Git installation guide](https://git-scm.com/downloads) for installation
instructions.

In R, run:

``` r
install.packages("pak")
pak::pak("biogeospatial/BiodiverseR")

library(BiodiverseR)

init_perlbrewr()
install_perl_deps()

bd <- BiodiverseR::basedata$new(
  filename = system.file("extdata", "example.bds", package = "BiodiverseR")
)

bd
bd$server_status()

# Optional: stop the server
bd$stop_server()
```

**NOTE:** The dependency installation may take some time and may require development
tools and the GDAL development package.

### Developer installation

These instructions are for developing BiodiverseR from a local copy of the
Git repository. You will need working installations of [R](https://www.r-project.org/)
and [Git](https://git-scm.com/downloads).

In a terminal (PowerShell on Windows, or Terminal on macOS/Linux), clone the
repository and change to its top-level directory:

``` sh
git clone https://github.com/biogeospatial/BiodiverseR.git
cd BiodiverseR
```

Start R from this repository directory, or set the repository as R's working
directory. In RStudio, you can open `BiodiverseR.Rproj`. The
`devtools::load_all()` command must be run from the repository directory so
that it loads the local source code.

Install the package and load the local source code in R:

``` r
install.packages(c("pak", "devtools"))
pak::pak("biogeospatial/BiodiverseR")

devtools::load_all()
```

Install the Biodiverse engine and its Perl dependencies:

``` r
init_perlbrewr()
install_perl_deps()
```

On Windows, `init_perlbrewr()` does nothing and `install_perl_deps()` downloads
the bundled Strawberry Perl runtime automatically.

On macOS and Linux, install Perlbrew and `cpanm` first. Most Unix-like systems
provide a system Perl installation, but a separate Perlbrew installation is
recommended. See the [Perlbrew installation guide](https://perlbrew.pl/Installation.html)
and run `perlbrew install-cpanm` in your terminal before running the R commands.

**NOTE:** The dependency installation may take some time and may require development
tools and the [GDAL development package](https://gdal.org/en/latest/download.html#binaries).

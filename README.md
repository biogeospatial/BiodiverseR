
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

**NOTE:** You will need a working installation of R and Git. Follow the
R installation instructions at [The R
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

#### MacOS and Linux

### Developer installation

Below are instructions for installing BiodiverseR on Windows or
unix-derived systems like MacOS and Linux if you want to develop
BiodiverseR.

#### Windows

Install the R code

You can install the R code like so:

``` r
# install.packages("devtools")
library("devtools")
install.packages("pak")               # Install pak for managing package installs
pak::pak("biogeospatial/BiodiverseR") # Install BiodiverseR from GitHub
```

However, it is currently best to work within the git repo given ongoing
development updates.

Set your working directory to be the top of the git repo and then run
this:

``` r
# install.packages("devtools")
library("devtools")
load_all()
```

These next commands will install the Biodiverse engine and its perl
dependencies. The first one does nothing on Windows but there is no harm
in running it.

``` r
init_perlbrewr()
install_perl_deps()
```

Note that the above will take a while if you do not already have the
GDAL development package installed on your system. This is because it
will compile its own version if it is unable to find one on the system
(but maybe this is not such a bad thing as then it will be isolated from
system changes). If you do want to install a system version then see the
[GDAL documentation](https://gdal.org/en/latest/download.html#binaries).

#### MacOS and Linux

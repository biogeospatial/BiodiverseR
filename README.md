
<!-- README.md is generated from README.Rmd. Please edit that file -->

**NOTE: This is currently in development. **

# BiodiverseR

<!-- badges: start -->

[![R-CMD-check](https://github.com/shawnlaffan/Biodiverse-R/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/shawnlaffan/Biodiverse-R/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

Provides an R interface to the analyses available in Biodiverse.
Biodiverse is a tool for the spatial analysis of diversity using indices
based on taxonomic, phylogenetic, trait and matrix-based (e.g. genetic
distance) relationships, as well as related environmental and temporal
variations. More information is available at its [Github
page](https://github.com/shawnlaffan/biodiverse).

## Installation

This is a two step process. First, install Perl so the Biodiverse engine
can run. Second, install the BiodiverseR R package.

1.  Install Perl

BiodiverseR currently requires a working perl interpreter in your path.
(Future versions will provide self contained executables).

On Windows a perl interpreter can be obtained through the [Strawberry
perl project](https://strawberryperl.com/releases.html). This will be
downloaded automatically when using the commands below.

Most unix-derived systems such as Linux and Mac provide a perl
interpreter but it is best to avoid this and install
[perlbrew](https://perlbrew.pl/Installation.html) so you have a separate
installation.  
When you install perlbrew be sure to also install the cpanm utility (run
this in your shell after starting perlbrew: `perlbrew install-cpanm`).

You also need to have git installed on your system.

2.  Install the R code

You can install the R code like so:

``` r
# install.packages("devtools")
library("devtools")
install_github("shawnlaffan/BiodiverseR")
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

## Quick demo

Check that a Biodiverse server can be started. The analytical functions
call this internally so if it does not work then neither will rest of
the system.

``` r
#  If you have not used the perlbrewr() or strawberry perl options then this 
#  next (commented out) command is needed so the system can find wherever you 
#  have downloaded the package and thus the server code. 
#  This assumes you are already at the top level of the BiodiverseR repository.  
#  Sys.setenv("Biodiverse_basepath" = getwd())

#  library(BiodiverseR)
devtools::load_all()  #  for during development 
cs = start_server()
cs$server_object$is_alive()

#  cleanup
rm(cs)
gc()  #  server is not deleted until garbage collection is run
```

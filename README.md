
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

This is a two step process. First, install the Biodiverse engine.
Second, install the R package.

1.  Install the Biodiverse engine.

This currently requires a working perl interpreter in your path. (Future
versions will provide self contained executables).

On Windows a perl interpreter can be obtained through the [Strawberry
perl project](https://strawberryperl.com/releases.html). This will be
downloaded automatically when using the commands below.

Most unix-derived systems provide a perl interpreter but it is best to
avoid this and install [perlbrew](https://perlbrew.pl/) so you have a
separate installation.  
When you install perlbrew be sure to also install the cpanm utility (see
perlbrew site for details).

Use perlbrew to install a recent version of perl.

You also need to have git installed on your system and in the path.

2.  Install the R code

You can install the R code like so:

``` r
library("devtools")
devtools::install_github("shawnlaffan/BiodiverseR")
```

However, it is currently best to work within the git repo.  
Set your working directory to be the top of the git repo and then run
this:

``` r
library("devtools")
devtools::load_all()
```

To install the perl dependencies, run these commands.  
The first one does nothing on Windows but there is no harm in running
it.

``` r
init_perlbrewr()
install_perl_deps()
```

Note that the above will take a while if you do not already have the
GDAL development package installed on your system. This is because it
will compile its own version if it is unable to find one on the system
(but maybe this is not such a bad thing as then it will be isolated from
system changes).

## Quick demo

Check that the Biodiverse service can be accessed. The analytical
functions call this internally so this is just a check that the server
can be started.

``` r
# It is critical that this be set to wherever you have downloaded the package 
#  as otherwise the system will not find the server code.  
#  It is an ugly and temporary hack and will not be needed in the future.
#  This version assumes you are at the top level of the BiodiverseR repository.  
Sys.setenv("Biodiverse_basepath" = getwd())

#  library(BiodiverseR)
devtools::load_all()  #  for during development 
cs = start_server()
cs$server_object$is_alive()

#  cleanup
rm(cs)
gc()  #  server is not deleted until garbage collected
```


<!-- README.md is generated from README.Rmd. Please edit that file -->

**NOTE:** This is currently in development.

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

You can install BiodiverseR as an end user or as a developer. If you only want 
to use BiodiverseR, follow the [end user installation instructions](#End-User-installation) below. If 
you want to develop BiodiverseR, follow the [developer installation instructions](#Developer_installation) below.

**NOTE:** You will need a working installation of R. Follow the R installation 
instructions at [The R Project](https://www.r-project.org/).

### End User installation
Below are instructions for installing BiodiverseR on Windows or unix-derived 
systems like MacOS and Linux.

#### Windows

In R, run the following commands:

``` r
install.packages("pak")
pak::pak("shawnlaffan/BiodiverseR")
install_perl_deps()
```
**Note:** The above may take a while.

Once complete, follow the [End User Quick Test](#End-User-Quick-Test) instructions below to make sure 
BiodiverseR is working.

#### MacOS and Linux

#### End User Quick Test
To see if BiodiverseR is working, you will need to check if the Biodiverse 
server can be started. Run the code below in R to see if the Biodiverse 
server successfully starts. 
``` r
# start the server
cs = start_server()

# Check the server
cs$server_object$is_alive()

# cleanup the server
rm(cs)
gc()
```
If
``` r
cs$server_object$is_alive()
```
returns TRUE then the test was successful and BiodiverseR is working.

### Developer installation
Below are instructions for installing BiodiverseR on Windows or unix-derived 
systems like MacOS and Linux if you want to develop BiodiverseR.

#### Windows


#### MacOS and Linux


## Developer Quick test

To see if BiodiverseR is working, you will need to check if the Biodiverse 
server can be started. Run the code below in R to see if the Biodiverse 
server successfully starts. 

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

If
``` r
cs$server_object$is_alive()
```
returns TRUE then the test was successful and BiodiverseR is working.


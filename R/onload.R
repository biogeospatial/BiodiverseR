#' Set up for BiodiverseR when `loadNamespace` is called
#' Adapted from galah
#' @noRd
#' @keywords Internal
.onLoad <- function(libname, pkgname) {
  if (pkgname == "BiodiverseR") {
    set_up_potions()
  }
}

#' Internal function to set up potions storage.
#' Called by `.onLoad`, but also by `BiodiverseR_config()` when `BiodiverseR` not previously called by `library()`
#' @noRd
#' @keywords Internal
set_up_potions <- function(){
  stored_options <- getOption("potions-pkg")
  if(is.null(stored_options)){
    # set up storage of standard information via {potions}
    potions::brew(default_config(), .pkg = "BiodiverseR") # set up caching of behaviour
  }else if(length(stored_options$packages$BiodiverseR) < 1L){
    # this is necessary because `drain_package()` often leaves the *name*
    # of the package, but not the *content*. In which case we need to replace it.
    # This particularly hits the test suite, which calls
    # `pkgload:::run_pkg_hook(package, "attach")` internally
    potions::brew(default_config(), .pkg = "BiodiverseR")
  }
}

#' Remove BiodiverseR-specific information when `unloadNamespace` is called
#' @noRd
#' @keywords Internal
.onUnload <- function(libpath) {
  potions::drain_package("BiodiverseR")
}

#' Set-up for BiodiverseR when `library()` is called
#' @noRd
#' @keywords Internal
.onAttach <- function(libname, pkgname) {
  if (pkgname == "BiodiverseR") {

    set_up_potions()

    # get information to display to the user
    ## get the galah version, if we can
    bd_version <-  "version unknown"
    suppressWarnings(
      try(bd_version <- utils::packageDescription("BiodiverseR")[["Version"]],
          silent = TRUE))

    # run start-up message
    startup_message(version = bd_version) |>
      packageStartupMessage() # Mandatory: see `?packageStartupMessage` (required by `check()`)
  }
}

#' Display a startup message
#' @noRd
#' @keywords Internal
startup_message <- function(node, url, version) {
  lines <- cli::cli_fmt({
    cli::cli_text("BiodiverseR version {version}")
  })
  paste(lines, collapse = "\n")
}

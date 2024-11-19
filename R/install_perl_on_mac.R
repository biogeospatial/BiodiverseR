#' Set Perl up on non-Windows machines
#'
#' @param perl_version character string specifying version of perl needed
#' @importFrom perlbrewr perlbrew
#' @export

init_perlbrewr <- function(perl_version = NULL, locallib = NULL){
  # Perlbrewr function to tell R to use perlbrew

  if (get_os() == "windows") {
    return ()
  }

  # Check if root path exists in environment, if not set it
  #  perlbrew call will fail if the path does not exist or is not defined
  perlbrew_root = Sys.getenv("PERLBREW_ROOT")
  if(perlbrew_root == "") {
    path = fs::path (fs::path_home(), "perl5/perlbrew")
    if (fs::dir_exists (path)) {
      perlbrew_root = path
    }
  }

  if (missing(perl_version)) {
    available = perlbrewr::perlbrew_list(root=perlbrew_root)
    perl_version = attr(available, "active")
    #message ("bbbbb ", perl_version)
    if (missing (perl_version) || length(perl_version) == 0) {
      perl_version = available[1]
    }
    perl_version <- trimws(perl_version)
    message (paste0 ("Using system perlbrew version ", perl_version))
  }

  result <- perlbrewr::perlbrew(root = perlbrew_root, version = perl_version, lib = locallib)

  if (missing(locallib)) {
    locallib = "BiodiverseR"
    success = perlbrewr::perlbrew_lib_create(
      lib = locallib,
      version = perl_version,
      perlbrew.use = TRUE
    )
    message (paste0 ("Setting locallib result was ", success))
  }

  return(result)
}

#  should be a wrapper to handle platform differences
#  should also allow local::lib
#  one day Biodiverse will be on cpan, which will simplify things below

#' install_perl_deps
#'
#' @param cpanfile Path to cpanfile or a directory to find one, defaults to the BiodiverseR cpanfile
#' @export
#' @rdname install_perl_deps
install_perl_deps <- function(cpanfile = NULL, installdeps = TRUE, bd_git_path = NULL, quiet = FALSE, ...) {

    #  This should be conditional on not having been run already
    #  init_perlbrewr(perl_version)

    os = get_os()

    if (os == "windows") {
        return (init_strawberry_perl())
    }

    if (missing(cpanfile)) {
        cpanfile = fs::path (system.file("perl", package ="BiodiverseR"), "cpanfile")
    }

    #  should use ~/Library on Macs
    basepath = fs::path_home()
    bd_path  = fs::path (basepath, 'BiodiverseR')

    if (missing (bd_git_path)) {
        bd_git_path = fs::path(bd_path, "biodiverse_git")

        if (!fs::dir_exists(bd_git_path)) {
          system2 (
            "git",
            args = c(
              "clone",
              "--depth", "1",
              "https://github.com/shawnlaffan/biodiverse.git",
              bd_git_path
            )
          )
        }
    }

    #  should we always update?
    #  should also check it is a git path
    message ("Updating internal Biodiverse git repo in ", bd_git_path)
    system2 (
        "git",
        args = c(
          "-C",
          bd_git_path,
          "pull"
        )
    )

    bd_cpanfile = fs::path (bd_git_path)
    message ("Installing Biodiverse perl dependencies defined at ", bd_cpanfile)
    res = perlbrewr::cpanm(installdeps = installdeps, dist = bd_cpanfile, quiet = quiet, ...)
    if (res == FALSE) {
        stop ("Error when installing Biodiverse perl dependencies")
    }

    path = fs::path(bd_git_path, '.')
    message ("Installing Biodiverse perl libs from ", path)
    res = perlbrewr::cpanm(dist = path, quiet = quiet, ...)
    if (res == FALSE) {
        stop ("Error when installing Biodiverse")
    }

    if(basename(cpanfile) == "cpanfile") {
        cpanfile <- dirname(cpanfile)
    }
    message ("Installing BiodiverseR perl dependencies from ", path)
    res = perlbrewr::cpanm(installdeps = installdeps, dist = cpanfile, quiet = quiet, ...)
    if (res == FALSE) {
        stop ("Error when installing BiodiverseR perl dependencies")
    }
}

# https://www.r-bloggers.com/2015/06/identifying-the-os-from-r/
get_os <- function(){
  sysinf <- Sys.info()
  if (!is.null(sysinf)){
    os <- sysinf['sysname']
    if (os == 'Darwin')
      os <- "osx"
  } else { ## mystery machine
    os <- .Platform$OS.type
    if (grepl("^darwin", R.version$os))
      os <- "osx"
    if (grepl("linux-gnu", R.version$os))
      os <- "linux"
  }
  tolower(os)
}

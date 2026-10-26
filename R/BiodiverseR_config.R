#  Pilfered from galah_config()

#' View or set package behaviour
#'
#' @description
#' Goes here.
#' @param \dots Options can be defined using the form `name = "value"`, or
#' as a (single) named list. See details for accepted fields.
#' @details
#' Valid arguments to this function are:
#'   *  `use_exe` logical: explanation here
#'   *  `perl_path` string: path to the perl binary if not using an exe version
#'   *  `perl5lib` string: any additional paths to add the the perl package search path
#'     These are passed as arguments when calling perl, `-I.../...`.
#'     These have no effect when `use_exe` is `TRUE`.
#'   *  `verbose` logical: Verbose logging.  Has no effect yet.
#' @return Returns an object with classes `BiodiverseR_config` and `list`,
#' invisibly if arguments are supplied.
#' @examples \dontrun{
#' # Make debugging in your session easier by setting `verbose = TRUE`
#' BiodiverseR_config(verbose = TRUE)
#'
#' # Optionally supply arguments via a named list
#' list(perl_path = "some/path/bin/perl") |>
#'   BiodiverseR_config()
#' }
#' @export
BiodiverseR_config <- function(...) {

  # make sure dots are captured properly
  dots <- list(...)

  # set defaults, if this has not happened already
  set_up_potions() # defined in `.onLoad()`

  # add user-provided information
  if(length(dots) > 0){

    # add exception so that people can supply a named list
    # this avoids calling things like:
    # `x <- list(email = "something); do.call(BiodiverseR_config, x)`
    if(length(dots) == 1){
      if(is.list(dots[[1]])){
        dots <- dots[[1]]
      }
    }

    # check all values in dots to ensure they are named
    if(length(dots) != length(names(dots))){
      c("All arguments to `BiodiverseR_config() must be named.",
        i = "Did you use `==` instead of `=`?") |>
      cli::cli_abort()
    }

    # check all values in dots to ensure they are valid
    result <- restructure_config(dots)

    # look up what information has been given, write specific callouts for unusual cases
    supplied_names <- names(result)

    if(length(result) > 0){
      potions::brew(result, method = "leaves")
    }

    # invisibly return
    x <- potions::pour()
    as_BiodiverseR_config(x) |>
      invisible()

  }else{
    # visibly return
    x <- potions::pour()
    as_BiodiverseR_config(x)
  }
}

#' Internal function to convert lists to class `galah_config`
#' @noRd
#' @keywords Internal
as_BiodiverseR_config <- function(x){
  structure(x,
            class = c("BiodiverseR_config", "list"))
}

#' Set a 'default' object for storing config in `BiodiverseR`
#' @noRd
#' @keywords Internal
default_config <- function(){
  #  potion wants a one-level nesting at least
  list(
    package = list (
      verbose = TRUE,
      use_exe = NULL,
      perl_path = NULL,
      perl5lib = NULL
    )
  ) |> as_BiodiverseR_config()
}

#' Place new options into correctly nested structure
#' @noRd
#' @keywords Internal
restructure_config <- function(dots,
                               call = rlang::caller_env()){
  # NOTE: we use `lapply()` here rather than `purrr::map()` ON PURPOSE
  # It prevents error messages being prefaced with:
  # Error in `purrr::map()` at galah-R/R/galah_config.R:171:3:
  # ℹ In index: 1.
  # ...which is undesirable
  result <- lapply(names(dots),
                   \(a){validate_config(a,
                                        dots[[a]],
                                        call = call)})
  names(result) <- names(dots)
  result
}

#' Catch errors in user-provided config
#' @noRd
#' @keywords Internal
validate_config <- function(name,
                            value,
                            call = rlang::caller_env()) {
  result <- switch(name,
         "use_exe"    = enforce_logical_na_or_null(value, call = call),
         "perl_path"  = bd_config_process_perl_path (value, call = call),
         "perl5lib"   = bd_config_process_perl5lib (value, call = call),
         "verbose"    = enforce_logical(value, call = call),
         enforce_invalid_name(name,
                              call = call))
  result
}

is_null_or_na = function (x) {
  is.null(x) || is.na(x)
}

bd_config_process_perl_path = function (value, call = rlang::caller_env()) {
  if (is_null_or_na(value)) {
    value = Sys.getenv("BiodiverseR_PERL_PATH")
  }
  if (!is_null_or_na(value) || value == "") {
      value = enforce_exe_exists(v)
  }
  return (value)
}

bd_config_process_perl5lib = function (value, call = rlang::caller_env()) {
  if (is_null_or_na(value)) {
    value = Sys.getenv("BiodiverseR_PERL5LIB")
  }
  if (!is_null_or_na(value)) {
    v = unlist(strsplit(value, .Platform$path.sep))
    v = v[v != ""]
    if (length(v) == 0) {
      return (NULL)
    }
    value = enforce_path_exists(v)
  }
  return (value)
}

#' Ensure some arguments are logical
#' @noRd
#' @keywords Internal
enforce_logical <- function(value,
                                    call = rlang::caller_env()){
  if (!is.logical(value)) {
    cli::cli_abort("Supplied value must be TRUE or FALSE.",
                   call = call)
  }else{
    value
  }
}


#' Ensure some arguments are logical or NULL
#' @noRd
#' @keywords Internal
enforce_logical_na_or_null <- function(value,
                            call = rlang::caller_env()){
  if (is.na(value)) {
    return (NULL)
  }
  if (!is_null_or_na(value)) {
    cli::cli_abort("Supplied value must be TRUE, FALSE, NA or NULL.",
                   call = call)
  }

  return (value)
}

#' Ensure an executable file exists
#' @noRd
#' @keywords Internal
enforce_exe_exists <- function(value,
                           call = rlang::caller_env()){
  on_windows = Sys.info()[['sysname']] == "Windows"
  if (is_null_or_na(value) || value == "") {
    return (NULL)
  }
  if (on_windows && tools::file_ext(value) == "") {
    value = paste0(value, ".exe")
  }
  if (!file.exists(value)) {
    c("File does not exist.",
      i = "Does the directory entered exist?") |>
    cli::cli_abort(call = call)
  }
  return (value)
}

#' Ensure a dir exists
#' @noRd
#' @keywords Internal
enforce_path_exists <- function(value,
                           call = rlang::caller_env()){
  res = character()
  for (v in value) {
    if (!dir.exists(v)) {
      c("Cannot find dir",
        i = sprintf("Directory %s does not exist.", v)) |>
        cli::cli_abort(call = call)
    } else {
      res = append(res, v)
    }
  }
  res
}

#' Ensure provided value is a string
#' @noRd
#' @keywords Internal
enforce_character <- function(value,
                              call = rlang::caller_env()){
  # check type
  if (!(is.character(value) | is.na(value))) {
    c("Invalid type",
      i = "Value must be entered as a string or `NA`") |>
    cli::cli_abort(call = call)
  }
  value
}


#' catch all failure for unknown names
#' @noRd
#' @keywords Internal
enforce_invalid_name <- function(name,
                                 call = rlang::caller_env()){
  c("Invalid option name.",
    i = "See `?BiodiverseR_config()` for valid options.",
    x = "\"{name}\" is not a valid option name.") |>
  cli::cli_abort(call = call)
}


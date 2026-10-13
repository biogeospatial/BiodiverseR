#  internal class - not to be documented
BiodiverseRserver <- R6::R6Class ("BiodiverseRserver",
    cloneable = FALSE,
    public = list(
      port = NULL,
      using_exe = NULL,
      server_object = NULL,
      server_url = NULL,
      server_api_key = NULL,
      server_pid = -1,
      initialize = function(
        port = NULL,
        using_exe = NULL,
        server_object = NULL,
        server_url = NULL,
        server_api_key = NULL,
        server_pid = -1
      ) {
        self$port = port
        self$using_exe = using_exe
        self$server_object = server_object
        self$server_url = server_url
        self$server_api_key = server_api_key
        self$server_pid = server_pid
        return (self)
      },
      status = function () {
        s = self$server_object
        result = tryCatch ({
          s$is_alive()
        },
        error = function () {FALSE}
        )
        return (result)
      }
    ),
    private = list(
      finalize = function () {
        s = self$server_object

        if (is.null(s)) {
          return()
        }

        self$server_object = NULL

        pid = self$server_pid
        parent_pid = as.numeric(s$get_pid())

        tryCatch({
          s$kill_tree()
          #  when running under PAR the server is a separate process
          #  kill_tree does not always get it
          if (pid != -1 && as.numeric(pid) != as.numeric(parent_pid)) {
            library(ps)
            handle = ps_handle(pid)
            if (ps_is_running(handle)) {
              ps_kill(handle)
            }
          }
        },
        error= function (e) {}
        )

        gc()
      }
    )
)

# Published runtime bundle metadata used by the runtime installer.
biodiverser_server_json_url <- paste0(
  "https://raw.githubusercontent.com/biogeospatial/",
  "biodiverseR-perl-engine-builder/main/releases.json"
)

biodiverser_server_release <- get_release_metadata(biodiverser_server_json_url)
biodiverser_server_version <- biodiverser_server_release$version
biodiverser_server_sha256 <- biodiverser_server_release$sha256
biodiverser_server_url <- biodiverser_server_release$url

#' Start the Biodiverse server
#'
#' Starts a Biodiverse server.
#' The server is shut down when the process object is garbage collected,
#' or an explicit kill command is called on it.
#'
#' By default it will find an empty port, but you can select one if you so choose.
#'
#' This should not really be exported and is currently here for dev purposes
#'
#' @param port integer
#' @param use_exe boolean
#' @param perl_path character
#'
#' @export
#' @examples
#' if(interactive()) {
#'   start_server(port=3001, use_exe=FALSE)
#' }

start_server = function(
    port=0,
    use_exe=Sys.info()[["sysname"]] == "Windows",
    perl_path=""
  ) {

  process = NULL  #  silence some check warnings
  bd_base_dir = Sys.getenv("Biodiverse_basepath")
  if (bd_base_dir == "") {
    # bd_base_dir = getwd()
    bd_base_dir = find.package("BiodiverseR")
    message ("Env var Biodiverse_basepath not set, assuming ", bd_base_dir)
  }
  if (is.null(perl_path) || is.na(perl_path)) {
    perl_path = ""
  }

  path_extras = ""
  running_on_windows = Sys.info()[['sysname']] == "Windows"
  use_runtime <- runtime_available()

  # Use a packaged runtime when one is available for the current platform.
  # Otherwise fall back to the bundled Perl script.
  if (use_runtime) {

    server_path = ensure_biodiverser_executable()

  } else {

    server_path = file.path(
      bd_base_dir,
      "inst",
      "perl",
      "script",
      "BiodiverseR"
    )

    if (!file.exists(server_path)) {  # installed?
      server_path = file.path(
        bd_base_dir,
        "perl",
        "script",
        "BiodiverseR"
      )
    }

    if (running_on_windows && perl_path != "") {
      if (tools::file_ext(perl_path) == "") {
        perl_path = sprintf("%s.exe", perl_path)
      }

      stopifnot(
        "perl_path does not exist" = file.exists(perl_path)
      )
    }
  }

  message (sprintf("server_path is %s", server_path))
  if (!file.exists(server_path)) {
    message ("Cannot find server_path")
    stop()
  }

  host = "127.0.0.1"
  if (!is.numeric(port) || port <= 0) {
    port = httpuv::randomPort(min = 1024L, max = 49151L, host = host, n = 20)
  }
  server_url = sprintf ("http://%s:%d", host, as.integer(port))

  orig_path = Sys.getenv("PATH")
  api_key_received = "nonsense"
  pid = -1

  res = tryCatch (
    {
      #  need explicit perl call on windows
      # https://processx.r-lib.org/reference/process.html
      cmd = ""
      # Configure the command used to launch either the packaged runtime
      # or the bundled Perl script implementation.
      # Send stderr to a pipe for startup monitoring.

      if (use_runtime) {

        cmd = server_path
        args = c("daemon", "-l", server_url)

      } else if (running_on_windows) {

        args = c(server_path, "daemon", "-l", server_url)

        cmd = ifelse(
          perl_path == "",
          fs::path(
            Sys.getenv("APPDATA"),
            "BiodiverseR/sp5380/perl/bin/perl"
          ),
          perl_path
        )

      } else {

        args = c(server_path, "daemon", "-l", server_url)
        cmd = "perl"

      }
      message (sprintf ("Command: %s", paste (c(cmd, unlist(args)), collapse=" ")))
      # message (Sys.getenv("PATH"))

      server_object = processx::process$new(
        cmd, args,
        stdout = "",  #  dump log to stdout and stderr for debug
        stderr = "|"
      )

      target_url <- paste0(server_url, "/api_key")

      #  Grab the api key from the server. This also tells us it is running.
      #  The retries are because the prebuilt archive might be unpacking.
      #  Would be useful to detect this ahead of the call.
      req <- httr2::request(target_url) |>
        httr2::req_retry(max_tries=15, max_seconds=30, retry_on_failure=TRUE)
      response <- httr2::req_perform(req)
      api_key_received <- httr2::resp_body_json(response)

      #  Older server versions don't have the pid method.
      #  The problem, though, is that it takes ages for the non-response.
      tryCatch ({
          # message ("getting server pid")
          target_url <- paste0(server_url, "/pid")
          req <- httr2::request(target_url) |>
            httr2::req_headers(api_key = api_key_received) |>
            httr2::req_retry(
              max_tries=2,
              max_seconds=1,
              retry_on_failure=FALSE,
              failure_threshold=1,
              failure_timeout=1
            )
          response <- httr2::req_perform(req)
          # message ("Done")
          response <- httr2::resp_body_json(response)
          if (is.list(response)) {
            pid = response[['result']]
          } else {
            pid = response
          }
        },
        error = function (e) {}
      )

    },
    error=function(err){
      message(paste("Server call resulted in an error:  ", err))
      stop()
    }
  )

  if (path_extras != "") {
    Sys.setenv("PATH"=orig_path)
  }

  server = BiodiverseRserver$new (
    port = port,
    using_exe = use_exe,
    server_object = server_object,
    server_url = server_url,
    server_api_key = api_key_received,
    server_pid = pid
  )

  return(server)
}

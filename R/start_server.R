## Workaround an R CMD check false positive
dummy_r6 <- function() R6::R6Class


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


start_server = function(port=0, use_exe=FALSE, perl_path="") {

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

  #  this runs the perl version - need to find a way to locate it relative to the package
  #  currently we need an env var to locate everything...
  #  maybe this: https://stackoverflow.com/questions/42492572/how-to-find-location-of-package
  if (use_exe) {
    #  non-windows won't have exe extension
    server_path = file.path(bd_base_dir, 'inst', 'perl', "BiodiverseR")
    if (!file.exists(server_path)) {  #  installed?
      server_path = file.path(bd_base_dir, 'perl', "BiodiverseR")
    }
    if (Sys.info()[['sysname']] == "Windows") {
      server_path = sprintf("%s.exe", server_path)
    }
  } else {
    server_path = file.path(bd_base_dir, 'inst', 'perl', 'script', 'BiodiverseR')
    if (!file.exists(server_path)) {  #  installed? - needs a refactor
      server_path = file.path(bd_base_dir, 'perl', 'script', "BiodiverseR")
    }
    if (running_on_windows && perl_path != "") {
      if (tools::file_ext(perl_path) == "") {  #  append .exe if needed
        perl_path = sprintf ("%s.exe", perl_path)
      }
      stopifnot("perl_path does not exist"=file.exists(perl_path))
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

  res = tryCatch (
    {
      #  need explicit perl call on windows
      # https://processx.r-lib.org/reference/process.html
      cmd = ""
      #message (sprintf ("Command: %s daemon -l %s", server_path, server_url))
      #  no perl pfx on unix, let the shebang line do its work
      #  need to also send stdout and stderr to a log file
      if (running_on_windows) {
        message ("WE ARE RUNNING ON WINDOWS")
        args = c(server_path, "daemon", "-l", server_url)
        #  version should not be hard coded in the path
        cmd = ifelse(
          perl_path == "",
          fs::path (Sys.getenv("APPDATA"), "BiodiverseR/sp5380/perl/bin/perl"),
          perl_path
        )
      }
      else {
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
      poll_timer = 3000
      poll = server_object$poll_io(poll_timer)
      txt = server_object$read_error_lines()
      message("TXT: ", txt)
      tries = 1
      regex = r"(Listening at "http://127\.0\.0\.1:(\d+))"
      while (tries < 15 && !any(grepl(regex, txt, perl=TRUE))) {
        txt = server_object$read_error_lines()
        poll = server_object$poll_io(poll_timer)
        if (length(txt) == 0 || is.na(txt) || is.null(txt)) {
          message ("Waiting for server to start")
        }
        else {
          message (txt)
        }
        tries = tries + 1
      }
      # port = stringr::str_match(txt, regex)[2]
      # message ("port is: ", port)
    },
    error=function(err){
      message(paste("Server call resulted in an error:  ", err))
      stop()
    }
  )

  if (path_extras != "") {
    Sys.setenv("PATH"=orig_path)
  }

  config = list (
    port = port,
    using_exe = use_exe,
    server_object = server_object,
    server_url = server_url
  )

  # Grabs the api key from the mojolicious server
  target_url <- paste0(config$server_url, "/api_key")
  req <- httr2::request(target_url)
  response <- httr2::req_perform(req)
  api_key_received <- httr2::resp_body_json(response)
  config <- c(config, server_api_key=api_key_received)

  #  hopefully redundant now but leaving just in case
  server_running = 0
  max_tries = 10
  trycount = 1
  while (server_running == 0 && trycount <= max_tries) {
    #  give the server a chance to get going -
    #  there must be a better way such as checking the stderr of the process
    Sys.sleep(1)
    response = tryCatch({
        httr::GET(url = server_url)
        server_running = 1
      },
      error = function (c) {
        # message(
        #   sprintf(
        #     "Server still coming up - trying again in 1 second (attempt %d of %d)",
        #     trycount, max_tries
        #   )
        # )
      },
      finally = {
        trycount = trycount + 1
      }
    )
  }
  if (server_running == 0) {
    message ("server did not start in time")
    stop ()
  }

  return(config)
}

# start_server()

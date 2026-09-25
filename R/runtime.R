# Return the current runtime platform.
get_runtime_platform <- function() {
  switch(
    Sys.info()[["sysname"]],
    Windows = "windows",
    Darwin = "macos",
    Linux = "linux",
    stop("Unsupported platform")
  )
}

# Return the per-version user cache directory.
get_biodiverser_runtime_dir <- function() {

  platform <- get_runtime_platform()

  cache_root <- switch(
    platform,

    windows = {
      root <- Sys.getenv("LOCALAPPDATA")
      if (root == "") {
        root <- Sys.getenv("APPDATA")
      }
      if (root == "") {
        stop("Could not determine a Windows user cache directory")
      }
      root
    },

    macos = {
      path.expand("~/Library/Application Support")
    },

    linux = {
      Sys.getenv(
        "XDG_CACHE_HOME",
        unset = path.expand("~/.cache")
      )
    }
  )

  fs::path(
    cache_root,
    "BiodiverseR",
    "runtime",
    biodiverser_server_version 
  )
}

# Return the platform-specific runtime executable name.
get_biodiverser_executable_name <- function() {

  if (get_runtime_platform() == "windows") {
    return("BiodiverseR.exe")
  }

  return("BiodiverseR")
}

# Download and cache the BiodiverseR runtime when needed.
ensure_biodiverser_executable <- function() {
  runtime_dir <- get_biodiverser_runtime_dir()
  executable <- fs::path(
    runtime_dir,
    get_biodiverser_executable_name()
  )

  # Reuse the runtime if this version is already cached.
  if (fs::file_exists(executable)) {
    return(executable)
  }

  fs::dir_create(runtime_dir, recurse = TRUE)
  # Allow only one session to install this runtime at a time.
  lock_dir <- fs::path(runtime_dir, ".install.lock")
  lock_acquired <- FALSE
  deadline <- Sys.time() + 300
  while (!lock_acquired && Sys.time() < deadline) {
    lock_acquired <- dir.create(lock_dir, showWarnings = FALSE)
    if (!lock_acquired && fs::file_exists(executable)) {
      return(executable)
    }
    if (!lock_acquired) {
      Sys.sleep(0.25)
    }
  }
  if (!lock_acquired) {
    stop("Timed out waiting for another BiodiverseR runtime installation")
  }
  on.exit(unlink(lock_dir, recursive = TRUE, force = TRUE), add = TRUE)

  # Another process may have completed installation while we were waiting.
  if (fs::file_exists(executable)) {
    return(executable)
  }

  archive <- tempfile(fileext = ".zip")
  on.exit(unlink(archive), add = TRUE)

  # Download outside the cache until the archive has been extracted.
  message("Downloading the BiodiverseR runtime")
  response <- httr2::request(biodiverser_server_url) |>
    httr2::req_perform(path = archive)

  # Verify the archive before extracting or running the executable.
  archive_sha256 <- unname(as.character(gsub(":", "", openssl::sha256(file(archive)))))
  if (!isTRUE(tolower(archive_sha256) == tolower(biodiverser_server_sha256))) {
    stop("Downloaded BiodiverseR runtime archive failed SHA-256 verification") 
  }


  # Locate the executable in the extracted archive.
  utils::unzip(archive, exdir = runtime_dir)

  executable_name <- get_biodiverser_executable_name()

  matches <- fs::dir_ls(
    runtime_dir,
    regexp = paste0(executable_name, "$"),
    recurse = TRUE,
    type = "file"
  )

  if (length(matches) != 1) {
    stop(
      sprintf(
        "Downloaded archive does not contain exactly one %s",
        executable_name
      )
    )
  }

  # Keep the executable at the stable path returned to the caller.
  if (!identical(fs::path_norm(matches[[1]]), fs::path_norm(executable))) {
    fs::file_move(matches[[1]], executable)
  }

  executable
}

# Shared helper for resolving the current published artifact release metadata.
# This keeps the release JSON lookup logic in one place and lets the
# Strawberry Perl bootstrap and runtime bootstrap both use the same pattern.
get_release_metadata <- function(
  json_url,
  channel = "stable"
) {
  if (missing(json_url) || is.null(json_url) || !nzchar(json_url)) {
    stop("A release metadata URL must be supplied")
  }

  meta <- rjson::fromJSON(file = json_url)
  if (!is.null(meta$channels)) {

    if (!channel %in% names(meta$channels)) {
      stop(
        sprintf(
          "Unknown runtime release channel '%s'",
          channel
        )
      )
    }

    current_version <- meta$channels[[channel]]

  } else {

    current_version <- meta$current

  }

  if (is.null(current_version) || !nzchar(current_version)) {

    if (!is.null(meta$channels)) {

      stop(
        sprintf(
          "No release assigned to channel '%s'",
          channel
        )
      )

    }

    stop(
      "Could not resolve the current release metadata from the supplied JSON"
    )
  }

  if (is.null(meta$releases[[current_version]])) {
    stop(
      sprintf(
        "No release metadata found for version '%s'",
        current_version
      )
    )
  }

  release_info <- meta$releases[[current_version]]

  platform <- switch(
    tolower(Sys.info()[["sysname"]]),
    windows = "windows",
    darwin  = "macos",
    linux   = "linux",
    "unknown"
  )

  # New multi-platform manifest format.
  if (!is.null(platform) && !is.null(release_info[[platform]])) {
    platform_info <- release_info[[platform]]

    return(list(
      version = current_version,
      url = platform_info$url,
      sha256 = platform_info$sha256,
      metadata = meta
    ))
  }

  # Legacy manifest format.
  if (!is.null(release_info$url)) {
    return(list(
      version = current_version,
      url = release_info$url,
      sha256 = release_info$sha256,
      metadata = meta
    ))
  }

  stop(
    sprintf(
      "No release metadata found for platform '%s' in version '%s'",
      platform,
      current_version
    )
  )
}

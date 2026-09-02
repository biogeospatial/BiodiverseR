# Shared helper for resolving the current published artifact release metadata.
# This keeps the release JSON lookup logic in one place and lets the
# Strawberry Perl bootstrap and runtime bootstrap both use the same pattern.
get_release_metadata <- function(json_url) {
  if (missing(json_url) || is.null(json_url) || !nzchar(json_url)) {
    stop("A release metadata URL must be supplied")
  }

  meta <- rjson::fromJSON(file = json_url)
  current_version <- meta$current

  if (is.null(current_version) || is.null(meta$releases[[current_version]])) {
    stop("Could not resolve the current release metadata from the supplied JSON")
  }

  release_info <- meta$releases[[current_version]]

  list(
    version = current_version,
    url = release_info$url,
    sha256 = release_info$sha256,
    metadata = meta
  )
}

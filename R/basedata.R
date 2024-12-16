package_cache = new.env(parent = emptyenv())

#' Create a new BiodiverseR::basedata object
#' and its associated server object.
#'
#' Data can then be loaded onto the server,
#' analyses run and results returned.
#'
#' The filename argument is optional and can be used to load
#' a pre-generated basedata file, for example one created using
#' the Biodiverse GUI.
#' In that case the cellsizes and cellorigins parameters are ignored.
#'
#' If the name argument is not passed then a default name will
#' be generated using the current time.
#'
#'
#' @param name character
#' @param filename character
#' @param cellsizes numeric
#' @param cellorigins numeric
#' @param name character
#' @param port integer
#' @param use_exe boolean
#' @param perl_path character
#'
#' @export
#' @examples
#' if(interactive()) {
#'   b = BiodiverseR::basedata$new(name = "trial")
#' }
basedata = R6::R6Class("basedata",
   cloneable = FALSE, #  we need to dup the server for this to work
   public = list(
    name   = NULL,
    server = NULL,
    cellsizes   = NULL,
    cellorigins = NULL,
    cache_list = NULL,
    initialize = function(
        name = paste("BiodiverseR::basedata", date()),
        cellsizes,
        cellorigins,
        filename = '',
        port=0, use_exe=FALSE, perl_path=NA,
        cache_list = list()
      ) {
      self$name = name

      self$cache_list = cache_list


      if (filename == '') {
        checkmate::assert_vector(cellsizes, any.missing=FALSE, min.len=1)
        checkmate::assert_numeric(cellsizes)

        if (missing(cellorigins)) {
          cellorigins = cellsizes * 0
        }
        checkmate::assert_vector(cellorigins, any.missing=FALSE, min.len=1)
        checkmate::assert_numeric(cellorigins)
        if (length(cellsizes) != length(cellorigins)) {
          stop("cellsizes and cellorigins vectors must of of same length")
        }

        self$cellsizes   = cellsizes
        self$cellorigins = cellorigins
      }

      self$server = BiodiverseR::start_server(
        port=port,
        use_exe=use_exe,
        perl_path=perl_path
      )
      if (filename == '') {
        p = list (
          name = self$name,
          cellsizes = self$cellsizes,
          cellorigins = self$cellorigins
        )
        self$call_server (call_path = "init_basedata", params = p)
      } else {
        p = list (filename = filename)
        self$call_server (call_path = "init_basedata", params = p)
        r = self$call_server("bd_get_cell_sizes")
        self$cellsizes = unlist(r)
        r = self$call_server("bd_get_cell_origins")
        self$cellorigins = unlist(r)
      }

      return (self)
    },
    set_name = function(val) {
      self$name = val
    },
    stop_server = function () {
      s = self$server$server_object
      tryCatch({
          s$kill()
        },
        error= function (e) {}
      )
      self$server = NULL
    },
    server_status = function () {
      s = self$server$server_object
      result = tryCatch ({
          s$is_alive()
        },
        error = function () {FALSE}
      )
      return (result)
    },
    call_server = function (call_path, params=NULL) {
      target_url <- paste(self$server$server_url, call_path, sep = "/")

#message(target_url)
      #  filter any nulls
      if (!is.null(params)) {
        params[sapply(params, is.null)] <- NULL
      }
      params_as_json <- rjson::toJSON(params)

# message ("about to run call, params are:")
# message (params_as_json)
# message ("\n")
      # response <- httr::POST(
      #   url = target_url,
      #   body = params_as_json,
      #   encode = "json",
      # )
      # # httr::stop_for_status(response)
      # call_results <- httr::content(response, "parsed")

      req <- httr2::request(target_url)
      # if (!is.null(params)) {
       #   req <- httr2::req_body_raw(req, params_as_json)
      # }
      req <- httr2::req_body_raw(req, params_as_json)
      req <- httr2::req_headers(req, api_key = self$server$server_api_key)
      response <- httr2::req_perform(req)
      call_results <- httr2::resp_body_json(response)

      #  check the error field
      e = call_results[['error']]
      if (
           (checkmate::test_scalar(e) && e != "")
        || !checkmate::test_scalar(e) && length(e)
        ) {
        message ("ERROR is :", e, ":")
        stop (e)
      }

      call_results[['result']]
    },
    load_data = function (params) {
      load_data_(self, params = params)
    },
    run_spatial_analysis = function (...) {
      run_spatial_analysis(self, ...)
    },
    run_cluster_analysis = function (...) {
      run_cluster_analysis(self, ...)
    },
    run_randomisation_analysis = function (...) {
      run_randomisation_analysis(self, ...)
    },
    get_analysis_results = function (name) {
      #  needs to do more than spatial...
      params = list (name = name)
      results = self$call_server("bd_get_analysis_results", params)
      processed = NULL
      if (!is.null (results[['dendrogram']])) {
        processed = list()
        processed[['dendrogram']] = results[['dendrogram']]
        processed[['lists']] = process_tabular_results(results[['lists']])
      } else {
        processed = process_tabular_results(results)
      }
      return (processed)
    },
    #  we need to use factory generation of methods
    get_analysis_count = function () {
      self$call_server("bd_get_analysis_count")
    },
    delete_analysis = function (name) {
      params = list (name = name)
      self$call_server("bd_delete_analysis", params)
    },
    delete_all_analyses = function () {
      self$call_server("bd_delete_all_analyses")
    },
    save_to_bds = function (filename) {
      params = list (filename = filename)
      self$call_server("bd_save_to_bds", params)
    },
    get_group_count = function () {
      self$call_server("bd_get_group_count")
    },
    get_indices_metadata = function () {
      cache_key = 'indices_metadata'
      if (is.null(package_cache[[cache_key]])) {
        # message ("Populating indices cache")
        package_cache[[cache_key]] = new.env()
        indices_metadata = self$call_server("calculations_metadata")
        assign("metadata", indices_metadata, envir=package_cache)
      }

      return (package_cache[["metadata"]])
    },
    calcs_are_valid = function (calc_names, neighbours, spatial_conditions=NULL, def_query=NULL, tree_ref=NULL) {
      valid_calcs = c()
      count = 1
      metadata = self$get_indices_metadata()

      # Validate calc names
      all_valid = all(calc_names %in% names(metadata))
      if (!all_valid) {
        # message("Error in calcs_are_valid :")
        e = cat("Error invalid calc name(s): ", calc_names[which (!(calc_names %in% names(metadata)))])
        stop(e)
      }

      available_neighbour_sets = 1
      if (!is.null(spatial_conditions)) {
        # CHECK SPATIAL COND
        available_neighbour_sets = length(spatial_conditions)
      }
      
      if (!is.null(def_query) && checkmate::test_scalar(def_query)) {
        e = cat("Error: Invalid def_query (not a scalar): ")
        stop(e)
      }

      invalid_neighbour_sets = c()
      invalid_req_args = c()
      for (calc_name in calc_names) {
        curr_calc = metadata[[calc_name]]
        # print(curr_calc)

        if (available_neighbour_sets < curr_calc[["uses_nbr_lists"]]) {
          valid_calcs[count] = FALSE
          append(invalid_neighbour_sets, calc_name)
        }

        curr_req_args = as.character(curr_calc[["required_args"]])
        if (is.null(tree_ref) && any(curr_req_args == "tree")) {
          append(invalid_req_args, calc_name)
        }

        count = count + 1
      }

      if (any(!valid_calcs)) {
        message("Error in calcs_are_valid :")
        e = cat("Invalid calcs: ", paste(calc_names[!valid_calcs], collapse = ", "), "\n")
        stop(e)
      }

      return(TRUE)
    },
    get_label_count = function () {
      self$call_server("bd_get_label_count")
    },
    finalize = function () {
      # message("Finalise called for ", self$name)
      self$stop_server()
      gc()
    }
  )
)



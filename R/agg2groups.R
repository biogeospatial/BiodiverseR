#' Create groups for Biodiverse
#'
#'Use R to aggregate input data from several formats into user-defined groups
#'
#'
#' @param x input data as path, data source name to be passed to st_read, data.frame, sf object, or SpatRaster object
#' @param layer in case of shapefile data format: name of layer to be passed to st_read
#' @param coords in case of point data: names or numbers of the numeric columns holding coordinates, to be passed to st_as_sf. Required if reading data from .xls file or inputting data.frame
#' @param abund_col character vector containing the name of column(s) with abundances; defaults to "count" and is assumed to be 1 for all records if no column specified and count column is absent
#' @param ID_col character vector containing the name of column(s) with data labels or species names. Defaults to "label"
#' @param group_col character vector containing the name of column(s) by which to group observations; may be numeric or categorical.  Defaults to XY coordinates if no group_col is specified.
#' @param cellsizes numeric vector indicating the size of desired groups; length must be 1 or same length as group_col. If length is 1, then its value is recycled over all grouping columns. If value <= 0 exact matches are aggregated, including categorical variables.
#' @param cellorigins numeric vector of numbers specifying the dimensions of the spatial groups into which data needs to be aggregated. Length must match length of cellsize. Units should be the same as the data projection, usually metres.
#' @param fun name of aggregation function to be used. Defaults to sum.
#' @param ... passed on to agg2groups.sf call.
#'
#' @return Named list of numeric vectors corresponding to the result of the aggregation function for each unique label in the data. Names correspond to coordinates of bottom left corner of each group. This format is needed to pass through to Biodiverse server.
#'
#' @examples
#' agg2groups("./inst/extdata/r1.tif")
#' agg2groups("./inst/extdata/", layer = "r1")
#'


agg2groups <- function (x, ...) {
  UseMethod("agg2groups", x)
}

# read in files from path names, call appropriate method
agg2groups.character <- function(x, layer, coords = NULL, ...) {
  # recognise file type at end of path
  csv <- grepl(pattern = ".*?\\.csv$", x = x)
  xls <- grepl(pattern = ".*?\\.xlsx$", x = x)
  tif <- grepl(pattern = ".*?\\.tif$", x = x)
  shp <- grepl(pattern = ".*?/$", x = x)
  if(!csv & !xls & !tif) shp <- TRUE  #assume shp file if other types not recognised

  # read in data accordingly, as spatial object if possible.
  if(csv){
    out <- sf::st_read(x, options=c("X_POSSIBLE_NAMES=x*, X*,lon*","Y_POSSIBLE_NAMES=y*, Y*, lat*"), quiet = TRUE)
    if(!"sf" %in% class(out)) out <- sf::st_as_sf(out, coords = coords, ...) # if coords not in defaults, add coords to make sf
  } else if(xls) {
    out <- sf::st_read(x, quiet = TRUE)
    if(!is.null(coords)) out <- sf::st_as_sf(out, coords = coords)
  } # if coords specified, make sf
  if(shp) out <- sf::st_read(x, layer = layer)
  if(tif) out <- terra::rast(x)

  if("data.frame" == class(out)[1]) {
    return(agg2groups.data.frame(out, coords, ...))
  }
  if("sf" == class(out)[1]) {
    return(agg2groups.sf(out, csv, ...))
  }
  if("SpatRaster" == class(out)[1]) {
    return(agg2groups.SpatRaster(out, ...))
  }

}

# change to sf based on coords, call sf method
agg2groups.data.frame <- function(x, coords, ...) {

  x <- sf::st_as_sf(x, coords = coords)
  agg2groups.sf(x, ...)
}

# spatial aggregation, count and label columns specified with convenient defaults
agg2groups.sf <- function(x, csv, abund_col = c("count"), ID_col = c("label"), group_col = c("X", "Y"), cellsizes = 100, cellorigins = c(0,0), fun = sum) {
  # check for existence of abund_col names
  if(!all(abund_col %in% names(x))){
    missing <- abund_col[!abund_col %in% names(x)]
    if(length(abund_col) > 1){
      if(length(missing) == length(abund_col)){
        message("Abundance columns not found. Reverting to default: count = 1 for all rows.")
        abund_col <- "count"
        x <- x %>% dplyr::mutate("{abund_col}" = 1)

      } else{message(paste("Column ", missing[1], " not found. Missing columns are ignored."))
        abund_col <- abund_col[abund_col %in% names(x)]
      }

    }
    if(length(abund_col) == 1){
      message(paste("Column ", missing, " not found. Defaulting to count = 1."))
      x <- x %>% dplyr::mutate("{abund_col}" = 1)
    }
  }

  # code for aggregating point data
  if(all(sf::st_geometry_type(x) == "POINT")){
    # add XY if not present - need to handle Z and M
    if(!all(c("X", "Y") %in% names(x))) x <- data.frame(x, sf::st_coordinates(x))

    if(length(cellsizes) == 1){cellsizes <- rep_len(cellsizes, length(group_col))}
    if(length(cellsizes) == length(group_col)+2) group_col <- c("X", "Y", group_col) # add XY by default if 2 grouping dims missing.
    if(length(cellsizes) != length(group_col)) {
      stop("The number of cellsize dimensions must match the number of grouping dimensions.")
    }

    #  remove geometry field since we have them as columns now
    x <- sf::st_drop_geometry(x)

    #  aggregate if cell size > 0, otherwise leave as-is
    out <- purrr::map(1:length(cellsizes), ~if(cellsizes[.x] > 0) {
        round_any(x[,group_col[.x]], accuracy = cellsizes[.x], origin = cellorigins[.x])
      } else {
        x[,group_col[.x]]
      }
    )
    #names <- out %>% dplyr::select(dplyr::group_cols()) %>% apply(1, paste, collapse = ":")
    temp1 = purrr::reduce(out, cbind)
    temp2 = data.frame(temp1)
    temp3 = setNames(temp2, group_col) # Originally group_col was tidyselect::all_of(group_col) but this raised a deprecated warning.
    temp4 = data.frame(temp3, x %>% dplyr::select(-tidyselect::all_of(group_col)))

    gp_id_colname = ":GROUP_ID:"
    group_ids = temp3 %>%
      tidyr::unite(x, tidyselect::all_of(group_col), sep = ":", remove = TRUE)
    names(group_ids) = gp_id_colname
    temp4 = cbind (temp4, group_ids)


    # print(head(temp4, 10))
    # print(str(temp4))
    # This below hard converts column 3 and 4 to numeric from character. Not sure if this is going to always be the case. Passes R tests for now
    ## FIXME - this is not user proof
    if (csv) {
      temp4[, c(3,4)] <- sapply(temp4[, c(3,4)], as.numeric)
    }

    # temp5 = dplyr::group_by(temp4, dplyr::across(c(tidyselect::all_of(ID_col), tidyselect::all_of(group_col))))
    temp5 = dplyr::group_by(temp4, dplyr::across(c(tidyselect::all_of(ID_col), tidyselect::all_of(gp_id_colname))))
    temp6 = dplyr::summarise(temp5, value := dplyr::across(tidyselect::all_of(abund_col), fun), .groups = "keep")
    #  messy but as.data.frame() does not work properly due to the grouping or something
    df = data.frame(lb_id = temp6[[1]], gp_id = temp6[[2]], count = temp6$value$count)


    # Old Code for above
    # if(length(cellsize) == length(group_col)){
    #   x <- sf::st_drop_geometry(x)
    #   out <- purrr::map(1:length(cellsize), ~if(cellsize[.x] > 0) {round_any(x[,group_col[.x]], accuracy = cellsize[.x], origin = origin[.x])
    #   }else{x[,group_col[.x]]}) %>%
    #     purrr::reduce(cbind) %>% data.frame() %>%  setNames(tidyselect::all_of(group_col)) %>%
    #     data.frame(x %>% dplyr::select(-tidyselect::all_of(group_col))) %>%
    #     dplyr::group_by(dplyr::across(c(tidyselect::all_of(ID_col), tidyselect::all_of(group_col)))) %>%
    #     dplyr::summarise(value := dplyr::across(tidyselect::all_of(abund_col), fun), .groups = "keep")

    # }else stop("The number of cellsize dimensions must match the number of grouping dimensions.")

    # change to format required by json
    #names <- paste(out$x, out$y, sep = ":")
    # names <- out %>% dplyr::select(dplyr::group_cols()) %>% apply(1, paste, collapse = ":")
    # out <- out %>% split(names) %>%
    #   purrr::map(~dplyr::pull(.x, value) %>% unlist())

    #  should use an apply - fix later
    #  should also do outside this function as it can simplify some looping
    result = list()
    for (i in 1:nrow(df)) {
      row = df[i,]
      lb = as.character(row[1])
      gp = as.character(row[2])
      result[[gp]][[lb]] = row[3]+0
    }

    return(result)

  } else {
    # support line and polygon inputs when agg2group.sfpoly exists.
    # agg2group.sfpoly(x, ID_col, cellsize, origin)
  }

}

# raster aggregation
agg2groups.SpatRaster <- function(x, cellsize = 100, ...) {
  temp <- terra::aggregate(x, fact = cellsize/terra::res(x), fun = sum, ...) |>
    as.data.frame(xy = TRUE) |>
    dplyr::mutate(x = x - cellsize/2, y = y - cellsize/2) # change xy to represent bottom left corner rather than centre of cell

  # change data format to json
  names <- paste(temp$x, temp$y, sep = ":")
  out <- temp |> dplyr::select(-x, -y) |> split(names) |> purrr::map(unlist)

  return(out)
}


round_any <- function(number, accuracy = 100, origin = 0, f = floor){
  (f((number-origin)/accuracy) * accuracy) + origin + 0.5 * accuracy
}


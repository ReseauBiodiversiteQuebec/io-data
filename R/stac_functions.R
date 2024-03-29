
#' @name create_projection
#' @param predictors, a raster, either from raster or terra format
#' @param mask, a vector file, either from raster or terra format
#' @return the predictors raster cropped and masked by mask, in terra format
#' @import dplyr
create_projection <- function(obs, lon, lat, proj.from, 
                              proj.to, new.lon = NULL, new.lat = NULL) {
  
  if(is.null(new.lon)) {
    new.lon <- lon
  }
  
  if(is.null(new.lat)) {
    new.lat <- lat
  }
  
  new.coords <- project_coords(obs, lon, lat, proj.from, proj.to)
  new.coords.df <- data.frame(new.coords)%>% 
    setNames(c(new.lon, new.lat))
  
  suppressWarnings(obs <- obs %>%
                     dplyr::select(-one_of(c(new.lon, new.lat))) %>% dplyr::bind_cols(new.coords.df))
  
  return(obs)
}

#' @name project_coords
#' @param xy data frame, containing the coordinates to reproject
#' @param lon string, name of the longitude column
#' @param lat string, name of the latitude column
#' @param proj.from character, initial projection of the xy coordinates
#' @param proj.to character, target projection
#' @import sp dplyr
#' @return spatial points in the proj.to projection

project_coords <- function(xy, lon = "lon", lat = "lat", proj.from, proj.to = NULL) {
  xy <- dplyr::select(xy, dplyr::all_of(c(lon, lat)))
  sp::coordinates(xy) <-  c(lon, lat)
  sp::proj4string(xy) <- sp::CRS(proj.from)
  
  if (!is.null(proj.to)) {
    xy <- sp::spTransform(xy, sp::CRS(proj.to)) 
    
  }
  xy
}


#' @name create_box
#' @param xy data frame, containing the coordinates to reproject
#' @param buffer integer, buffer to add around the observations
#' @param proj.from character, initial projection of the xy coordinates
#' @param proj.to character, target projection 
#' @return a box extent
create_box <- function(xy, buffer = 0, proj.from = NULL, proj.to = NULL) {
  if (class(xy) != "SpatialPoints") {
    sp::coordinates(xy) <- colnames(xy)
    proj4string(xy) <- sp::CRS(proj.from)
  }
  bbox <-  sf::st_buffer(sf::st_as_sfc(sf::st_bbox(xy)), dist =  buffer)
  
  if (!is.null(proj.to) ) {
    bbox <- bbox  %>%
      sf::st_transform(crs = sp::CRS(proj.to))
  }
  bbox <- c(sf::st_bbox(bbox)$xmin, sf::st_bbox(bbox)$xmax,
            sf::st_bbox(bbox)$ymin, sf::st_bbox(bbox)$ymax)
  bbox
}




sample_cube <- function(cube, lon, lat, date) {
  
  x <- dimension_values(cube)$x
  y <- dimension_values(cube)$y
  
  all.points <- expand.grid(x,y) %>% setNames(c("x", "y"))
  sample.points <- all.points[sample(1:nrow(all.points), n.sample),]
  t <- rep(as.Date(date), nrow(sample.points) )
  
  value.points
}

#' Create a proxy data cube for current climate, 
#' which loads data from a given image collection according to a data cube view based
#' on a specific box coordinates or using a set of observations
#' 
#' @name load_cube
#' 
#' @param stac_path, a character, base url of a STAC web service.
#' @param limit, an integer defining the maximum number of results to return. 
#' @param collections, a character vector of collection IDs to include
#' subsetLayers, a vector, containing the name of layers to select. If NULL, all layers in dir.pred selected by default.
#' @param use.obs, a boolean. If TRUE, the provided observations will be sued as a basis for calculating the extent and bbox.
#' @param obs, a data.frame containg the observations (used if use.obs is T)
#' @param srs.obs, string, observations spatial reference system. Can be a proj4 definition, WKT, or in the form "EPSG:XXXX".
#' @param lon, a string, column from obs containing longitude
#' @param lat, a string, column from obs containing latitude
#' @param buffer.box, an integer, buffer to apply around the obs to calculate extent and bbox
#' @param bbox, a numeric vector of size 4 or 6. Coordinates of the bounding box (if use.obs is FALSE). Details in rstac::stac_search documentation.
#' @param layers, a string vector, names of bands to be used,. By default (NULL), all bands with "eo:bands" attributes will be used. 
#' @param srs.cube, string, target spatial reference system. Can be a proj4 definition, WKT, or in the form "EPSG:XXXX".
#' @param t0, ISO8601 datetime string, start date.
#' @param t1, ISO8601 datetime string, end date.
#' @param left, a float. Left coordinate of the extent. Used if use.obs = F
#' @param right, a float. Right coordinate of the extent. Used if use.obs = F
#' @param top, a float. Top coordinate of the extent. Used if use.obs = F
#' @param bottom, a float. Bottom coordinate of the extent. Used if use.obs = F
#' @param spatial.res, a float, size of pixels in longitude and latitude directions, in the unit of srs.cube spatial reference system.
#' @param temporal.res, size of pixels in time-direction, expressed as ISO8601 period string (only 1 number and unit is allowed) such as "P16D"
#' @param aggregation, a character, aggregation method as string, defining how to deal with pixels containing data from multiple images, can be "min", "max", "mean", "median", or "first"
#' @param resampling, a character, resampling method used in gdalwarp when images are read, can be "near", "bilinear", "bicubic" or others as supported by gdalwarp (see https://gdal.org/programs/gdalwarp.html)
#' @return a raster stack of variables not intercorrelated
#' @import gdalcubes dplyr sp sf rstac
#' @return a proxy raster data cube

load_cube <- function(stac_path =
                        "http://io.biodiversite-quebec.ca/stac/",
                      limit = 5000,
                      collections = c('chelsa-clim'),
                      use.obs = T,
                      obs = NULL,
                      lon = "lon",
                      lat = "lat",
                      buffer.box = 0,
                      bbox = NULL,
                      layers = NULL,
                      srs.cube = "EPSG:32198", 
                      t0 = "1981-01-01", 
                      t1 = "1981-01-01",
                      left = -2009488, right = 1401061,  bottom = -715776, top = 2597757,
                      spatial.res = 2000,
                      temporal.res  = "P1Y", 
                      aggregation = "mean",
                      resampling = "near") {
  
  # Creating RSTACQuery  query
  s <- rstac::stac(stac_path)
  
  # use observations to create the bbox and extent
  if (use.obs) {
    
    if (inherits(obs, "data.frame")) {
      # Reproject the obs to the data cube projection
      proj.pts <- project_coords(obs, lon = lon, lat = lat, proj.from = srs.cube)
      
    } else {
      proj.pts <- obs
    }
    
    # Create the extent (data cube projection)
    bbox.proj <- points_to_bbox(proj.pts, buffer = buffer.box)
    left <- bbox.proj[1]
    right <- bbox.proj[2]
    bottom <- bbox.proj[3]
    top <- bbox.proj[4]
    
    # Create the bbxo (WGS84 projection)
    bbox.wgs84 <- points_to_bbox(proj.pts, buffer = buffer.box, proj.to ="+proj=longlat +datum=WGS84")
    
  } else {
    
    bbox.wgs84 <- c(left, right, bottom, top) 
    
    if (left > right) stop("left and right seem reversed")
    if (bottom > top) stop("left and right seem reversed")
  }
  
  # Create datetime object
  datetime <- format(lubridate::as_datetime(t0), "%Y-%m-%dT%H:%M:%SZ")
  
  if (!is.null(t1) && t1 != t0) {
    datetime <- paste(datetime,
                      format(lubridate::as_datetime(t1), "%Y-%m-%dT%H:%M:%SZ"),
                      sep = "/")
    
  }
  
  
  RCurl::url.exists(stac_path)
  # CreateRSTACQuery object with the subclass search containing all search field parameters 
  it_obj <- s |>
    rstac::stac_search(bbox = bbox.wgs84, collections = collections, 
                       datetime = datetime,
                       limit = limit) |> rstac::get_request() # bbox in decimal lon/lat
  
  # If no layers is selected, get all the layers by default
  if (is.null(layers)) {
    layers <- unlist(lapply(it_obj$features, function(x){names(x$assets)}))
    
  }
  
  # Creates an image collection
  st <- gdalcubes::stac_image_collection(it_obj$features, asset_names = layers) 
  
  v <- gdalcubes::cube_view(srs = srs.cube,  extent = list(t0 = t0, t1 = t1,
                                                           left = left, right = right,  top = top, bottom = bottom),
                            dx = spatial.res, dy = spatial.res, dt = temporal.res, aggregation = aggregation, resampling = resampling)
  gdalcubes::gdalcubes_options(parallel = 4)
  cube <- gdalcubes::raster_cube(st, v)
  
  return(cube)
}



#' Extract values of a proxy raster data cube
#' 
#' @name extractCubeValues
#' 
#' @param cube, a proxy raster data cube (raster_cube object, or output of loadCube)
#' @param points, spatial points object from which to extract values, in the same projection system as the data cube
#' @param date, ISO8601 datetime string, same as t0 used to load raster cube
#' @import gdalcubes
#' @return a data.frame containing values (one row per points in points, one column per varieble -or layer-)

extractCubeValues <- function(cube, points, date) {

  value.points <- gdalcubes::query_points(cube, points@coords[,1],
                                          points@coords[,2],
                                          pt = rep(as.Date(date),length(points@coords[,1])), 
                                          srs(cube))
    

  return(value.points)
}


#' Create a proxy data cube for future climate, 
#' which loads data from a given image collection according to a data cube view based
#' on a specific box coordinates or using a set of observations
#' 
#' @name load_cube_projection
#' 
#' @param stac_path, a character, base url of a STAC web service.
#' @param limit, an integer defining the maximum number of results to return. 
#' @param collections, a character vector of collection IDs to include
#' subsetLayers, a vector, containing the name of layers to select. If NULL, all layers in dir.pred selected by default.
#' @param use.obs, a boolean. If TRUE, the provided observations will be sued as a basis for calculating the extent and bbox.
#' @param obs, a data.frame containg the observations (used if use.obs is T)
#' @param srs.obs, string, observations spatial reference system. Can be a proj4 definition, WKT, or in the form "EPSG:XXXX".
#' @param lon, a string, column from obs containing longitude
#' @param lat, a string, column from obs containing latitude
#' @param buffer.box, an integer, buffer to apply around the obs to calculate extent and bbox
#' @param bbox, a numeric vector of size 4 or 6. Coordinates of the bounding box (if use.obs is FALSE). Details in rstac::stac_search documentation.
#' @param layers, a string vector, names of bands to be used,. By default (NULL), all bands with "eo:bands" attributes will be used. 
#' @param srs.cube, string, target spatial reference system. Can be a proj4 definition, WKT, or in the form "EPSG:XXXX".
#' @param time.span, a string, time interval of the projection model.
#' @param rcp, a string, climatic scenario
#' @param left, a float. Left coordinate of the extent. Used if use.obs = F
#' @param right, a float. Right coordinate of the extent. Used if use.obs = F
#' @param top, a float. Top coordinate of the extent. Used if use.obs = F
#' @param bottom, a float. Bottom coordinate of the extent. Used if use.obs = F
#' @param spatial.res, a float, size of pixels in longitude and latitude directions, in the unit of srs.cube spatial reference system.
#' @param temporal.res, size of pixels in time-direction, expressed as ISO8601 period string (only 1 number and unit is allowed) such as "P16D"
#' @param aggregation, a character, aggregation method as string, defining how to deal with pixels containing data from multiple images, can be "min", "max", "mean", "median", or "first"
#' @param resampling, a character, resampling method used in gdalwarp when images are read, can be "near", "bilinear", "bicubic" or others as supported by gdalwarp (see https://gdal.org/programs/gdalwarp.html)
#' @return a raster stack of variables not intercorrelated
#' @import gdalcubes, dplyr, sp, sf, rstac
#' @return a proxy raster data cube

load_cube_projection <- function(stac_path =
                                 "http://io.biodiversite-quebec.ca/stac/",
                               limit = 5000,
                               collections = c('chelsa-clim-proj'),
                               use.obs = T,
                               obs = NULL,
                               lon = "lon",
                               lat = "lat",
                               buffer.box = 0,
                               bbox = NULL,
                               layers = NULL,
                               srs.cube = "EPSG:32198",  
                               time.span = "2041-2070",
                               rcp = "ssp585",
                               left = -2009488, right = 1401061,  bottom = -715776, top = 2597757,
                               spatial.res = 2000,
                               temporal.res  = "P1Y", aggregation = "mean",
                               resampling = "near") {
  
  #t0 param
  if (time.span == "2041-2070") {
    t0 <- "2041-01-01"
  }
  
  if (time.span == "2071-2100") {
    t0 <- "2071-01-01"
  }
  
   s <- stac(stac_path)
  
    if (use.obs) {
    
    if (inherits(obs, "data.frame")) {
     # Transform into spatial points
      proj.pts <- project_coords(obs, lon = lon, lat = lat, proj.from = srs.cube)
               
     } else {
      proj.pts <- obs
    }

    bbox <- create_box(proj.pts, buffer = buffer.box, proj.to ="+proj=longlat +datum=WGS84")
    bbox.proj <- create_box(proj.pts, buffer = buffer.box)
    left <- bbox.proj[1]
    right <- bbox.proj[2]
    bottom <- bbox.proj[3]
    top <- bbox.proj[4]
  }
  
  it_obj <- s |>
    stac_search(bbox = bbox, collections = collections, limit = limit) |> get_request() # bbox in decimal lon/lat
  
  all.layers <- unlist(lapply(it_obj$features,function(x){names(x$assets)}))
  
  
  st <- stac_image_collection(it_obj$features, asset_names = all.layers,
                              property_filter = function(x) {x[["variable"]] %in% layers & x[["time_span"]] == time.span  & x[["rcp"]] == rcp })
  
  #if layers = NULL, load all the layers
  v <- cube_view(srs = srs.cube,  extent = list(t0 = t0, t1 = t0,
                                           left = left, right = right,  top = top, bottom = bottom),
                 dx = spatial.res, dy = spatial.res, dt = temporal.res, aggregation = aggregation, resampling = resampling)
  gdalcubes_options(threads = 4)
  cube <- raster_cube(st, v)
  return(cube)
}




cube_to_raster <- function(cube, format = "raster") {
  # Transform to a star object
  cube.xy <- cube %>%
    stars::st_as_stars()
  
  # If not, names are concatenated with temp file names
  names(cube.xy) <- names(cube)
  
  # We remove the temporal dimension
  cube.xy <- cube.xy|> abind::adrop(c(F,F,T))
  
  # Conversion to a spatial object
  
  if (format == "raster") {
    # Raster format
    cube.xy <- raster::stack(as(cube.xy, "Spatial"))
    
  } else {
    # Terra format
    cube.xy <- terra::rast(cube.xy)
  }
  
  cube.xy
  
}



extract_gdal_cube <- function(cube, n_sample = 5000, simplify = T) {
  
  x <- gdalcubes::dimension_values(cube)$x
  y <- gdalcubes::dimension_values(cube)$y
  
  all_points <- expand.grid(x,y) %>% setNames(c("x", "y"))
  
  if (n_sample >= nrow(all_points)) {
    value_points <- gdalcubes::extract_geom(cube, sf::st_as_sf(all_points, coords = c("x", "y"),
                                               crs = srs(cube))) 
  } else {
    sample_points <- all_points[sample(1:nrow(all_points), n_sample),]
    value_points <- gdalcubes::extract_geom(cube, sf::st_as_sf(sample_points, coords = c("x", "y"),
                                                               crs = srs(cube))) 
  }
  
  if (simplify) {
    value_points <- value_points %>% dplyr::select(-FID, -time)
  }
  value_points
}

#' @name points_to_bbox
#' @param xy data frame, containing the coordinates to reproject
#' @param buffer integer, buffer to add around the observations
#' @param proj.from character, initial projection of the xy coordinates
#' @param proj.to character, target projection 
#' @return a box extent
points_to_bbox <- function(xy, buffer = 0, proj.from = NULL, proj.to = NULL) {
  if (class(xy) != "SpatialPoints") {
    sp::coordinates(xy) <- colnames(xy)
    proj4string(xy) <- sp::CRS(proj.from)
  }
  bbox <-  sf::st_buffer(sf::st_as_sfc(sf::st_bbox(xy)), dist =  buffer)
  
  if (!is.null(proj.to) ) {
    bbox <- bbox  %>%
      sf::st_transform(crs = sp::CRS(proj.to))
  }
  bbox <- c(sf::st_bbox(bbox)$xmin, sf::st_bbox(bbox)$xmax,
            sf::st_bbox(bbox)$ymin, sf::st_bbox(bbox)$ymax)
  bbox
}

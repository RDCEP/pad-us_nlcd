
    ## library( raster)
    library( raster, lib.loc="~/src/R/lib/")
    setOptions( progress= "text")
    library( plyr)
    library( stringr)
    
    overwriteRasters <- TRUE
  
  world <- raster()
  res( world) <- 5/60
  ## dataType( world) <- "INT4U"
  world[ ] <-
    1:ncell( world)
  world <-
    writeRaster(
      world, "gdal/grid5minWorld.tif",
      datatype= "INT4U",
      overwrite= overwriteRasters)

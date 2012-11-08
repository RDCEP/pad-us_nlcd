#!/bin/bash -v

    # path to GRASS binaries and libraries:
    export GISBASE=/usr/lib/grass64
    export PATH=$PATH:$GISBASE/bin:$GISBASE/scripts
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$GISBASE/lib
    
    # use process ID (PID) as lock file number:
    export GIS_LOCK=$$
    
    # path to GRASS settings file
    export GISRC=./.grassrc6
    EOF
    
    cat <<EOF
    g.gisenv set=LOCATION_NAME=\$GIS_LOCK
    eval \$(g.gisenv)
    mkdir -p \$GISDBASE/\$GIS_LOCK
    g.mapset -c mapset=temp
    r.in.gdal in=aeaGrid5min${REGION}.img out=grid_5min location=${REGION}
    # g.gisenv set=LOCATION_NAME=${REGION}
    # g.gisenv set=MAPSET=PERMANENT
    g.mapset mapset=PERMANENT location=${REGION}
    rm -rf \$GISDBASE/\$GIS_LOCK/temp
    # g.rename rast=aeaGrid5min${REGION}.img,grid_5min
    r.in.gdal input=pad-us/PADUS1_2_regions/PADUS1_2_${REGION}_GAP.tif output=gap
    EOF
  r.in.gdal input=nlcd/pr_landcover_wimperv_10-28-08_se5.img output=Nlcd01v1PRnbest@ci.uchicago.edu
#+DATE:      2012-04-13 Fri
#+DESCRIPTION:
#+KEYWORDS:
#+LANGUAGE:  en
#+OPTIONS:   H:3 num:t toc:t \n:nil @:t ::t |:t ^:t -:t f:t *:t <:t
#+OPTIONS:   TeX:t LaTeX:t skip:nil d:nil todo:t pri:nil tags:not-in-toc
#+INFOJS_OPT: view:nil toc:nil ltoc:t mouse:underline buttons:0 path:http://orgmode.org/org-info.js
#+EXPORT_SELECT_TAGS: export
#+EXPORT_EXCLUDE_TAGS: noexport
#+LINK_UP:   
#+LINK_HOME: 
#+XSLT:

#+PROPERTY: session *R*
#+PROPERTY: results silent

* DONE tangle out the R code and run it from the Makefile

This won't work until another function call is included to run the R code.


* initialize the session
#+NAME: init
#+BEGIN_SRC R :tangle no
  ## library( raster)
  library( raster, lib.loc="~/src/R/lib/")
  setOptions( progress= "text")
  library( plyr)
  library( stringr)
  
  overwriteRasters <- TRUE
#+END_SRC

* are these obsolete?
** process Puerto Rico to work out steps

#+NAME: grid
#+BEGIN_SRC R :tangle no :eval no
  
  pr <- raster( "nlcd2006/pr_landcover_wimperv_10-28-08_se5.img")
  NAvalue( pr) <- 0
  pr <- setMinMax( pr)
  
  prGrid <- try( raster( "prGrid.tif"), silent= TRUE)
  if( inherits( prGrid, "try-error") || overwriteRasters) {             
    prGrid <- raster( pr)
    prGrid[] <- seq( 1, ncell( prGrid))
    prGrid <-
      mask( prGrid, pr,
           filename= "prGrid.tif",
           overwrite= TRUE,
           progress= "text")
  }
  
  gridProjFunc <- function( cell) {
    cellFromXY( world,
               project( xyFromCell( prGrid, cell),
                       projection( prGrid),
                       inv= TRUE))
  }  
  
  prWorld <- try( raster( "world_5min_PuertoRico.tif"), silent= TRUE)
  if( inherits( prWorld, "try-error") || overwriteRasters) {             
    prWorld <-
      calc( prGrid, gridProjFunc,
           filename= "world_5min_PuertoRico.tif",
           datatype= "INT4U",
           overwrite= TRUE,
           progress= "text")
  }
  
  prGap <- raster( "pad-us/PADUS1_2_regions/PADUS1_2_PuertoRico_GAP.tif")
  prGap <- setMinMax( prGap)
  NAvalue( prGap) <- 255
    
  prGap <- overlay( prGap, prGrid, fun= setGapZero,
                   filename= "prGap.tif", datatype= "INT1U", progress= "text", overwrite= TRUE)
  NAvalue( prGap) <- 255
  
  
  prStack <- stack(prWorld, pr, prGap)
  layerNames( prStack) <- c( "grid", "nlcd", "gap")
  
  ct <- crosstab( prStack, useNA= "always", long= TRUE, responseName= "n", progress="text")
#+END_SRC

#+results:


* load NLCD rasters


#+NAME: regionPatterns
#+BEGIN_SRC R
  
  regionPatterns <-
    list(
      Nlcd01v1PR= "pr.*?img$",
      Nlcd01v1HI= "hi.*?img$",
      Nlcd01v1AK= "ak.*?img$",
      Nlcd01v1= "nlcd2001_mosaic_2-20-07.img$",
      Nlcd01v2= "nlcd2001_landcover_v2_2-13-11.img$",
      Nlcd06= "nlcd2006_landcover_4-20-11_se5.img$")
  
  regions <-
    names( regionPatterns)
  names( regions) <-
    names( regionPatterns)
          
#+END_SRC

#+BEGIN_SRC 

  nlcdRasters <-
    llply(
      regionPatterns,
      function( patt) {
        r <-
          raster(
            list.files(
              "nlcd",
              patt= patt,
              full.names= TRUE,
              recursive= TRUE))
        NAvalue( r) <- 0
        r
      })
  
#+END_SRC

#+results:
   


* extend PR example for batch processing

** calculate 5' cell ID for each 30m pixel

Write out a 5' raster in geographic projection where the value of each
cell is its grid ID.  This will be reprojected into the cooridnate
space of each PAD-US/NLCD stack.

#+NAME: world  
#+BEGIN_SRC R :noweb yes :tangle tangle/grid5minWorld.R
  <<init>>
  
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
#+END_SRC

#+begin_src makefile :tangle tangle/pad-us_nlcd.make
gdal/grid5minWorld.tif: scripts/grid5minWorld.R
	Rscript --vanilla $<

gdal/grid5minAeaCUSA.img: gdal/grid5minWorld.tif
	gdalwarp -overwrite -of HFA -t_srs "+proj=aea +lat_1=29.5 +lat_2=45.5 +lat_0=23 +lon_0=-96 +x_0=0 +y_0=0 +ellps=GRS80 +units=m +no_defs" -te -2493045 177285 2342655 3310005 -tr 30 30 -co "COMPRESSED=YES" $< $@

#+end_src


*** TODO How did I write the gdalwarp command for the grid IDs?
I must have done it by hand.  This should be tangled out and called in
the Makefile.

** add zeroes to GAP data for unprotected land and coastal areas

#+BEGIN_SRC R :session *R:2*
  gapFiles <-
    list.files( "pad-us/PADUS1_2_regions/",
               patt= "^PADUS1_2_.*?tif$",
               full.names= TRUE)
  names( gapFiles) <-
    str_match( gapFiles,
              "PADUS1_2_([^_]+)_GAP\\.tif$")[, 2]
  
  gapRasters <-
    llply( names( regionPatterns),
          function ( region) {
            r <- raster( gapFiles[[ region]])
            NAvalue( r) <- 255
            ## r <- setMinMax( r)
            layerNames( r) <- region
            r
  })
  names( gapRasters) <- names( regionPatterns)
  
  setGapZero <- function( gap, grid) {
    ifelse( is.na( gap) & !is.na( grid), 0, gap)
  }

  gapOverlayFunc <-
    function ( gap, nlcd) {
      fn <- sprintf( "gap%s.grd", layerNames( gap))
      if( overwriteRasters | !file.exists( fn)) {
        overlay( gap, nlcd,
                fun= setGapZero,
                filename= fn,
                datatype= "INT1U",
                overwrite= TRUE)
      } else try( raster( fn), silent= TRUE)
    }
  
  prOverlay <- gapOverlayFunc( gapRasters[[ "PuertoRico"]],
                              nlcdRasters[[ "PuertoRico"]])
  
  ## gapOverlays <-
  ##   mapply( gapRasters, nlcdRasters,
  ##          FUN= gapOverlayFunc) 
  
  gapOverlays <-
    llply( regions,
          function( region) {
            gapOverlayFunc( gapRasters[[ region]],
                           nlcdRasters[[ region]])
          })
  
#+END_SRC

#+results:
   
** create stacks and tabulate

#+NAME: stacks
#+BEGIN_SRC R
  ## prStack <- stack(prWorld, pr, prGap)
  ## layerNames( prStack) <- c( "grid", "nlcd", "gap")
  
  ## prStack <- stack( raster( "aeaGrid5minPuertoRico.img"),
  ##                  nlcdRasters[[ "PuertoRico"]],
  ##                  prOverlay)
  
  ## prLowRes <- raster( prStack)
  ## res( prLowRes) <- 3000
  
  ## prStackSmall <- resample( prStack, prLowRes, method= "ngb")
  ## layerNames( prStackSmall) <- c( "grid", "nlcd", "gap")
  
  ## prCt <- crosstab( prStackSmall, long= TRUE, responseName= "n")
  
  ## prCt <- crosstab( prStack, long= TRUE)
  
  
  aeaGridFunc <-
    function( region) {
      raster( sprintf( "aeaGrid5min%s.img", region))
    }
    
  aeaGrids <- llply( regions, aeaGridFunc)
                    
  gapStackFunc <-
    function( region) {
      s <- stack( aeaGrids[[ region]],
                 nlcdRasters[[ region]],
                 gapOverlays[[ region]])
      layerNames( s) <- c( "grid", "nlcd", "gap")
      s
    }
                 
  gapStacks <- llply( regions, gapStackFunc)
          
  writeCrosstabs <-
    function( region) {
      fn <- sprintf( "pad-us_nlcd_%s.csv", region)
      ct <- crosstab( gapStacks[[ region]])
      write.csv( ct, row.names= FALSE, file= fn)
      fn
    }
  
  ctFiles <- llply( regions, writeCrosstabs)
#+END_SRC

#+results:

** write out GRASS scripts

#+NAME: grassPuertoRico
#+BEGIN_SRC sh
  ./create_location.sh aeaGrid5minPuertoRico.img PuertoRico grass
  g.rename rast=aeaGrid5minPuertoRico.img,grid_5min
  r.in.gdal input=nlcd2006/pr_landcover_wimperv_10-28-08_se5.img output=nlcd2006
  r.in.gdal input=pad-us/PADUS1_2_regions/PADUS1_2_PuertoRico_GAP.tif output=gap
  
  r.mapcalc MASK="if( nlcd2006 > 0, 1, null())"
  echo grid_5min,nlcd2006,gap,n > statsPuertoRico.csv
  r.stats -c input=grid_5min,nlcd2006,gap fs=, >> statsPuertoRico.csv
  r.mask -r
  echo grid_5min,n > gridPuertoRico.csv
  r.stats -c input=grid_5min fs=, >> gridPuertoRico.csv
  
#+END_SRC


*** grassCreate( REGION="Nlcd01v1PR")

#+NAME: grassCreate( REGION="Nlcd01v1PR")
#+BEGIN_SRC sh :session :noweb yes :results output code replace
  # echo ./create_location.sh aeaGrid5min${REGION}.img ${REGION} grass
  
  cat <<'EOF'
  # path to GRASS binaries and libraries:
  export GISBASE=/usr/lib/grass64
  export PATH=$PATH:$GISBASE/bin:$GISBASE/scripts
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$GISBASE/lib
  
  # use process ID (PID) as lock file number:
  export GIS_LOCK=$$
  
  # path to GRASS settings file
  export GISRC=./.grassrc6
  EOF
  
  cat <<EOF
  g.gisenv set=LOCATION_NAME=\$GIS_LOCK
  eval \$(g.gisenv)
  mkdir -p \$GISDBASE/\$GIS_LOCK
  g.mapset -c mapset=temp
  r.in.gdal in=aeaGrid5min${REGION}.img out=grid_5min location=${REGION}
  # g.gisenv set=LOCATION_NAME=${REGION}
  # g.gisenv set=MAPSET=PERMANENT
  g.mapset mapset=PERMANENT location=${REGION}
  rm -rf \$GISDBASE/\$GIS_LOCK/temp
  # g.rename rast=aeaGrid5min${REGION}.img,grid_5min
  r.in.gdal input=pad-us/PADUS1_2_regions/PADUS1_2_${REGION}_GAP.tif output=gap
  EOF
#+END_SRC
  

*** rInGdalNlcd( region= "Nlcd01v1PR")

#+NAME: rInGdalNlcd( region= "Nlcd01v1PR")
#+BEGIN_SRC R :noweb yes :session :results output verbatim replace 
  <<regionPatterns>>
  path <-
    list.files(
      "nlcd",
      patt= regionPatterns[[ region]],
      full.names= TRUE,
      recursive= TRUE)
  cat( sprintf( "r.in.gdal input=%s output=%s", path, region), "\n")
#+END_SRC

#+RESULTS: rInGdalNlcd
: r.in.gdal input=nlcd/pr_landcover_wimperv_10-28-08_se5.img output=Nlcd01v1PR

#+CALL: rInGdalNlcd( "Nlcd01v1")

#+begin_src sh
  r.in.gdal input=nlcd2006/NLCD2001_landcover_v2_2-13-11/nlcd2001_landcover_v2_2-13-11.img output=nlcd2001
  r.reclass input=nlcd2001 output=nlcd2001_71 <<EOF 
  71 = 71
 ,* = 0
  EOF
  
#+end_src

**** TODO add '-N' to r.stats for NLCD/GAP tabulation to eliminate *,*,*,n record created by the mask

*** grassMapcalc( REGION= "Nlcd01v1PR")

#+NAME: grassMapcalc( REGION= "Nlcd01v1PR")
#+BEGIN_SRC sh :session :results output code replace
  cat <<EOF 
  r.mapcalc MASK="if( ${REGION} > 0, 1, null())"
  echo grid_5min,${REGION},gap,n > stats${REGION}.csv
  r.stats -c input=grid_5min,${REGION},gap fs=, >> stats${REGION}.csv
  r.mask -r
  echo grid_5min,n > grid${REGION}.csv
  r.stats -c input=grid_5min fs=, >> grid${REGION}.csv
  EOF
#+END_SRC

#+results: grassMapcalc
#+BEGIN_SRC sh
r.mapcalc MASK="if( Nlcd01v1PR > 0, 1, null())"
echo grid_5min,Nlcd01v1PR,gap,n > statsNlcd01v1PR.csv
r.stats -c input=grid_5min,Nlcd01v1PR,gap fs=, >> statsNlcd01v1PR.csv
r.mask -r
echo grid_5min,n > gridNlcd01v1PR.csv
r.stats -c input=grid_5min fs=, >> gridNlcd01v1PR.csv
#+END_SRC


*** TODO change function args to match new region names

#+NAME: grassPuertoRico
#+BEGIN_SRC sh :session :eval no :noweb yes :tangle tangle/grassPuertoRico.sh :shebang "#!/bin/bash -v"
    # path to GRASS binaries and libraries:
    export GISBASE=/usr/lib/grass64
    export PATH=$PATH:$GISBASE/bin:$GISBASE/scripts
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$GISBASE/lib
    
    # use process ID (PID) as lock file number:
    export GIS_LOCK=$$
    
    # path to GRASS settings file
    export GISRC=./.grassrc6
    EOF
    
    cat <<EOF
    g.gisenv set=LOCATION_NAME=\$GIS_LOCK
    eval \$(g.gisenv)
    mkdir -p \$GISDBASE/\$GIS_LOCK
    g.mapset -c mapset=temp
    r.in.gdal in=aeaGrid5min${REGION}.img out=grid_5min location=${REGION}
    # g.gisenv set=LOCATION_NAME=${REGION}
    # g.gisenv set=MAPSET=PERMANENT
    g.mapset mapset=PERMANENT location=${REGION}
    rm -rf \$GISDBASE/\$GIS_LOCK/temp
    # g.rename rast=aeaGrid5min${REGION}.img,grid_5min
    r.in.gdal input=pad-us/PADUS1_2_regions/PADUS1_2_${REGION}_GAP.tif output=gap
    EOF
  r.in.gdal input=nlcd/pr_landcover_wimperv_10-28-08_se5.img output=Nlcd01v1PR
    r.mapcalc MASK="if( Nlcd01v1PR > 0, 1, null())"
    echo grid_5min,Nlcd01v1PR,gap,n > statsNlcd01v1PR.csv
    r.stats -c input=grid_5min,Nlcd01v1PR,gap fs=, >> statsNlcd01v1PR.csv
    r.mask -r
    echo grid_5min,n > gridNlcd01v1PR.csv
    r.stats -c input=grid_5min fs=, >> gridNlcd01v1PR.csv
    EOF
#+END_SRC

#+NAME: grassHawaii
#+BEGIN_SRC sh :session :eval no :noweb yes :tangle tangle/grassHawaii.sh :shebang "#!/bin/bash -v"
    # path to GRASS binaries and libraries:
    export GISBASE=/usr/lib/grass64
    export PATH=$PATH:$GISBASE/bin:$GISBASE/scripts
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$GISBASE/lib
    
    # use process ID (PID) as lock file number:
    export GIS_LOCK=$$
    
    # path to GRASS settings file
    export GISRC=./.grassrc6
    EOF
    
    cat <<EOF
    g.gisenv set=LOCATION_NAME=\$GIS_LOCK
    eval \$(g.gisenv)
    mkdir -p \$GISDBASE/\$GIS_LOCK
    g.mapset -c mapset=temp
    r.in.gdal in=aeaGrid5min${REGION}.img out=grid_5min location=${REGION}
    # g.gisenv set=LOCATION_NAME=${REGION}
    # g.gisenv set=MAPSET=PERMANENT
    g.mapset mapset=PERMANENT location=${REGION}
    rm -rf \$GISDBASE/\$GIS_LOCK/temp
    # g.rename rast=aeaGrid5min${REGION}.img,grid_5min
    r.in.gdal input=pad-us/PADUS1_2_regions/PADUS1_2_${REGION}_GAP.tif output=gap
    EOF
  r.in.gdal input=nlcd/hi_landcover_wimperv_9-30-08_se5.img output=Nlcd01v1HI
    r.mapcalc MASK="if( Nlcd01v1HI > 0, 1, null())"
    echo grid_5min,Nlcd01v1HI,gap,n > statsNlcd01v1HI.csv
    r.stats -c input=grid_5min,Nlcd01v1HI,gap fs=, >> statsNlcd01v1HI.csv
    r.mask -r
    echo grid_5min,n > gridNlcd01v1HI.csv
    r.stats -c input=grid_5min fs=, >> gridNlcd01v1HI.csv
    EOF
#+END_SRC

#+NAME: grassAlaska
#+BEGIN_SRC sh :session :eval no :noweb yes :tangle tangle/grassAlaska.sh :shebang "#!/bin/bash -v"
    # path to GRASS binaries and libraries:
    export GISBASE=/usr/lib/grass64
    export PATH=$PATH:$GISBASE/bin:$GISBASE/scripts
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$GISBASE/lib
    
    # use process ID (PID) as lock file number:
    export GIS_LOCK=$$
    
    # path to GRASS settings file
    export GISRC=./.grassrc6
    EOF
    
    cat <<EOF
    g.gisenv set=LOCATION_NAME=\$GIS_LOCK
    eval \$(g.gisenv)
    mkdir -p \$GISDBASE/\$GIS_LOCK
    g.mapset -c mapset=temp
    r.in.gdal in=aeaGrid5min${REGION}.img out=grid_5min location=${REGION}
    # g.gisenv set=LOCATION_NAME=${REGION}
    # g.gisenv set=MAPSET=PERMANENT
    g.mapset mapset=PERMANENT location=${REGION}
    rm -rf \$GISDBASE/\$GIS_LOCK/temp
    # g.rename rast=aeaGrid5min${REGION}.img,grid_5min
    r.in.gdal input=pad-us/PADUS1_2_regions/PADUS1_2_${REGION}_GAP.tif output=gap
    EOF
  r.in.gdal input=nlcd/ak_nlcd_2001_land_cover_3-13-08_se5.img output=Nlcd01v1AK
    r.mapcalc MASK="if( Nlcd01v1AK > 0, 1, null())"
    echo grid_5min,Nlcd01v1AK,gap,n > statsNlcd01v1AK.csv
    r.stats -c input=grid_5min,Nlcd01v1AK,gap fs=, >> statsNlcd01v1AK.csv
    r.mask -r
    echo grid_5min,n > gridNlcd01v1AK.csv
    r.stats -c input=grid_5min fs=, >> gridNlcd01v1AK.csv
    EOF
#+END_SRC

#+NAME: grassNlcd
#+BEGIN_SRC sh :session :noweb yes :tangle tangle/grasscUSA.sh :shebang "#!/bin/bash -v"
    # path to GRASS binaries and libraries:
    export GISBASE=/usr/lib/grass64
    export PATH=$PATH:$GISBASE/bin:$GISBASE/scripts
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$GISBASE/lib
    
    # use process ID (PID) as lock file number:
    export GIS_LOCK=$$
    
    # path to GRASS settings file
    export GISRC=./.grassrc6
    EOF
    
    cat <<EOF
    g.gisenv set=LOCATION_NAME=\$GIS_LOCK
    eval \$(g.gisenv)
    mkdir -p \$GISDBASE/\$GIS_LOCK
    g.mapset -c mapset=temp
    r.in.gdal in=aeaGrid5min${REGION}.img out=grid_5min location=${REGION}
    # g.gisenv set=LOCATION_NAME=${REGION}
    # g.gisenv set=MAPSET=PERMANENT
    g.mapset mapset=PERMANENT location=${REGION}
    rm -rf \$GISDBASE/\$GIS_LOCK/temp
    # g.rename rast=aeaGrid5min${REGION}.img,grid_5min
    r.in.gdal input=pad-us/PADUS1_2_regions/PADUS1_2_${REGION}_GAP.tif output=gap
    EOF
  r.in.gdal input=nlcd/nlcd2001_landcover_mosaic_2-20-07/nlcd2001_mosaic_2-20-07.img output=Nlcd01v1
  r.in.gdal input=nlcd/NLCD2001_landcover_v2_2-13-11/nlcd2001_landcover_v2_2-13-11.img output=Nlcd01v2
  r.in.gdal input=nlcd/nlcd2006_landcover_4-20-11_se5.img output=Nlcd06
    r.mapcalc MASK="if( Nlcd01v1 > 0, 1, null())"
    echo grid_5min,Nlcd01v1,gap,n > statsNlcd01v1.csv
    r.stats -c input=grid_5min,Nlcd01v1,gap fs=, >> statsNlcd01v1.csv
    r.mask -r
    echo grid_5min,n > gridNlcd01v1.csv
    r.stats -c input=grid_5min fs=, >> gridNlcd01v1.csv
    EOF
    r.mapcalc MASK="if( Nlcd01v2 > 0, 1, null())"
    echo grid_5min,Nlcd01v2,gap,n > statsNlcd01v2.csv
    r.stats -c input=grid_5min,Nlcd01v2,gap fs=, >> statsNlcd01v2.csv
    r.mask -r
    echo grid_5min,n > gridNlcd01v2.csv
    r.stats -c input=grid_5min fs=, >> gridNlcd01v2.csv
    EOF
    r.mapcalc MASK="if( Nlcd06 > 0, 1, null())"
    echo grid_5min,Nlcd06,gap,n > statsNlcd06.csv
    r.stats -c input=grid_5min,Nlcd06,gap fs=, >> statsNlcd06.csv
    r.mask -r
    echo grid_5min,n > gridNlcd06.csv
    r.stats -c input=grid_5min fs=, >> gridNlcd06.csv
    EOF
  cat <<'EOF'
  # run GRASS' cleanup routine
  $GISBASE/etc/clean_temp
  
  # remove session tmp directory:
  rm -rf /tmp/grass6-$USER-$GIS_LOCK
  EOF
#+END_SRC

** aggregate the results

#+NAME: writeFracsProto
#+begin_src R :eval no
  library( reshape)
  library( Hmisc)
  
  cells <-
    read.csv( "gridPuertoRico.csv",
             col.names= c( "cell", "n"))
  
  stats <-
    read.csv( "statsPuertoRico.csv",
             na.strings= "*",
             col.names= c( "cell", "nlcd", "gap", "n"),
             colClasses= c("numeric", "factor", "factor", "numeric"))
  ## won't need this when r.stats in previous GRASS step is fixed
  stats <- stats[ !is.na(stats$cell),]
  
  ## stats <- stats[ !is.na(stats$grid),]
  ## stats <- stats[ stats$cell != "*",]
  
  ## stats <- within( stats, gap[ is.na( gap)] <- 0)
  
  
  stats <-
    within( stats,
           { levels( gap) <- c( levels( gap), "0")
             gap[ is.na( gap)] <- "0"
             gap <- combine_factor( gap, c(0,1,1,1,0))
             levels( gap) <- c( "no", "yes")
           })
  
  stats <-
    cast( data= stats,
         formula= cell ~ gap + nlcd,
         fun.aggregate= sum,
         margins= "grand_col",
         value= "n" )
  colnames( stats)[ colnames( stats) == "(all)_(all)"] <- "nlcd"
  
  merged <-
    within( merge( stats, cells, by= "cell", all.x= TRUE),
           no_11 <- no_11 + n - nlcd)
  
  fracs <-
    cast( within( melt( merged,
                       c( "cell", "n")),
                 value <- value / n),
         formula= cell ~ variable,
         subset= variable != "nlcd",
         margins= "grand_col",
         fun.aggregate= sum)
  
  write.csv( format.df( fracs,
                       dec= 3,
                       numeric.dollar= FALSE,
                       na.blank= TRUE),
            row.names= FALSE,
            file= "fracsPuertoRico.csv",
            quote= FALSE)
#+END_SRC
  
#+NAME: writeFracs
#+begin_src R 
  library( reshape)
  library( Hmisc)

  writeFracs <- function( region) {
    cells <-
      read.csv( sprintf( "grid%s.csv", region),
               col.names= c( "cell", "n"))
    stats <-
      read.csv( sprintf( "stats%s.csv", region),
               na.strings= "*",
               col.names= c( "cell", "nlcd", "gap", "n"),
               colClasses= c("numeric", "factor", "factor", "numeric"))
    ## won't need this when r.stats in previous GRASS step is fixed
    stats <- stats[ !is.na(stats$cell),]
    stats <-
      within( stats,
             { levels( gap) <- c( levels( gap), "0")
               gap[ is.na( gap)] <- "0"
               gap <- combine_factor( gap, c(0,1,1,1,0))
               levels( gap) <- c( "no", "yes")
             })
    stats <-
      cast( data= stats,
           formula= cell ~ gap + nlcd,
           fun.aggregate= sum,
           margins= "grand_col",
           value= "n" )
    colnames( stats)[ colnames( stats) == "(all)_(all)"] <- "nlcd"
    merged <-
      within( merge( stats, cells, by= "cell", all.x= TRUE),
             no_11 <- no_11 + n - nlcd)
    fracs <-
      cast( within( melt( merged,
                         c( "cell", "n")),
                   value <- value / n),
           formula= cell ~ variable,
           subset= variable != "nlcd",
           margins= "grand_col",
           fun.aggregate= sum)
    fn <- sprintf( "fracs%s.csv", region)
    write.csv( format.df( fracs,
                         dec= 3,
                         numeric.dollar= FALSE,
                         na.blank= TRUE),
              row.names= FALSE,
              file= fn,
              quote= FALSE)
    fn
  }
  
  regions <- c( "PuertoRico", "Hawaii", "Alaska", "cUSA")
  names( regions) <- regions
  
  fracFiles <- llply( regions, writeFracs)
  
  zip( "pad-us_nlcd.zip", list.files( patt= "^fracs.*?\\csv$"))
#+end_src
   

*** TODO do this with data.table


** generate NBCD statistics


*** by 5' grid cells

#+NAME: writeNbcdStats
#+begin_src R 
  library( reshape)
  library( Hmisc)
  library( data.table)

  stats <-
    read.csv( "statsNbcd.csv",
             na.strings= "*",
             col.names= c( "cell", "nlcd", "gap", "nbcd", "n"),
             colClasses= c("numeric", "factor", "factor", "numeric"))
  
  stats <-
    within(
      stats,
      { levels( gap) <- c( levels( gap), "0")
        gap[ is.na( gap)] <- "0"
        gap <- combine_factor( gap, c(0,1,1,1,0))
        levels( gap) <- c( "no", "yes")
        nbcd[ is.na( nbcd)] <- 0
      })
  
  dt <- data.table( stats)
  setkey( dt, cell, nlcd, gap)
  
  wm <- dt[, list( wm= weighted.mean( nbcd, n)), by= "cell,nlcd,gap"]
  
  wmCt <-
    cast(
      data= wm,
      formula= cell ~ gap + nlcd,
      ## fun.aggregate= sum,
      ## margins= "grand_col",
      value= "wm" )
  
  write.csv(
    format.df(
      wmCt,
      cdec= c( 0, rep( 1, ncol( wmCt) - 1)),
      numeric.dollar= FALSE,
      na.blank= TRUE),
    row.names= FALSE,
    file= "nbcdFiaAldb.csv",
    quote= FALSE)
  
  zip( "pad-us_nlcd_nbcd.zip", "fracscUSA.csv")
  zip( "pad-us_nlcd_nbcd.zip", "nbcdFiaAldb.csv")
  
#+end_src
  

*** TODO convert NAs to zeros for \*Fr and \*Ha in CSVs and SHPs
*** TODO trim spaces in char data frames before writing CSVs


*** aggregate r.stats output

This functions loads r.stats output from GRASS for any of the
following aggregations based on vector maps.

**** The old way

#+begin_src R
  ## aggregateNbcd <-
  ##   function( csvFile, ...) {
  ##     stats <-
  ##       read.csv(
  ##         csvFile,
  ##         na.strings= "*",
  ##         header= TRUE,
  ##         ...)
  ##     stats <-
  ##       within(
  ##         stats,
  ##         { levels( gap) <- c( levels( gap), "0")
  ##           gap[ is.na( gap)] <- "0"
  ##           gap <- combine_factor( gap, c(0,1,1,1,0))
  ##           levels( gap) <- c( "no", "yes")
  ##           aldb[ is.na( aldb)] <- 0
  ##         })
  ##     dt <- data.table( stats)
  ##     keycols <-
  ##       colnames(stats)[ !colnames(stats)
  ##                       %in% c( "aldb", "n")]
  ##     setkeyv( dt, keycols)
  ##     ## dt[, list( aldb= weighted.mean( aldb, n),
  ##     ##           ha= sum(n) * 30^2 / 10^4),
  ##     ##    by= keycols]
  ##     dt <- dt[, n2 := replace( n, aldb == 0, 0)]
  ##     dt <- dt[, list( aldb= weighted.mean( aldb, n),
  ##                     aldb2= weighted.mean( aldb, n2),
  ##                     n= sum( n),
  ##                     n2= sum( n2),
  ##                     ha= sum(n) * 30^2 / 10^4,
  ##                     ha2= sum(n2) * 30^2 / 10^4),
  ##              by= keycols]
  ##     dt
  ##   }
  
  
  ## stats <-
  ##   read.csv(
  ##     "statsNbcdCounty.csv",
  ##     na.strings= "*",
  ##     header= TRUE,
  ##     col.names= c(
  ##       "state", "county", "nlcd", 
  ##       "gap", "aldb", "n"),
  ##     colClasses= c(
  ##       "character", "character", "character",
  ##       "numeric", "numeric", "numeric"))
  ## stats <-
  ##   within( stats, {
  ##     gap[ is.na( gap)] <- 0
  ##     gap[ gap == 4] <- 0
  ##     gap[ gap !=0] <- 1
  ##     aldb[ is.na( aldb)] <- 0
  ##     gap <- as.logical( gap) } )

#+end_src


**** The new way

#+begin_src R
  
  library( reshape)
  library( Hmisc)
  library( data.table)
  library( stringr)
  
  rawCountyStats <-
    read.csv(
      "csv/statsNbcdNlcd01v1County.csv",
      na.strings= "*",
      header= TRUE,
      col.names= c(
        "state", "county", "nlcd", 
        "gap", "aldb", "n"),
      colClasses= c(
        "character", "character", "character",
        "numeric", "numeric", "numeric"))
  
  rawCountyStats <-
    within( rawCountyStats, {
      state[  is.na(  state)] <- 0   
      county[ is.na( county)] <- 0    
      state <-
        str_pad( state,
                2, pad= "0")
      county <-
        str_pad( county,
                3, pad= "0")
      gap[ is.na( gap)] <- 0
      gap[ gap == 4] <- 0
      gap[ gap !=0] <- 1
      aldb[ is.na( aldb)] <- 0
      gap <- as.logical( gap) } )
  
  rawCountyStats <- data.table( rawCountyStats)
  keycols <-
    colnames(rawCountyStats)[ colnames(rawCountyStats) != "n"]
  setkeyv( rawCountyStats, keycols)
  rawCountyStats <-
    rawCountyStats[, list( n= sum( n),
                          n2 = sum( replace( n, aldb <= 0, 0))),
       keyby= keycols ]
  
  rawStateStats <- 
    rawCountyStats[, list( n= sum( n),
                         n2= sum( n2)),
       keyby= keycols[ -2] ]
  
#+end_src


*** by NBCD mapping zones
  
#+begin_src R
  library( reshape)
  library( Hmisc)
  library( data.table)
  library( stringr)
  
  ## define aggregateNbcd()
  
  ## statsNbcdZone <-
  ##   aggregateNbcd(
  ##     "statsNbcdZone.csv",
  ##     col.names= c(
  ##       "zone", "nlcd", "gap",
  ##       "aldb", "n"),
  ##     colClasses= c(
  ##       "character", "character", "factor",
  ##       "numeric", "numeric"))
  
  rawZoneStats <-
    read.csv(
      "csv/statsNbcdNlcd01v1Zone.csv",
      na.strings= "*",
      header= TRUE,
      col.names= c(
        "zone", "nlcd", 
        "gap", "aldb", "n"),
      colClasses= c(
        "character", "character",
        "numeric", "numeric", "numeric"))
  
  rawZoneStats <-
    within( rawZoneStats, {
      state[  is.na(  state)] <- 0   
      zone[ is.na( zone)] <- 0    
      gap[ is.na( gap)] <- 0
      gap[ gap == 4] <- 0
      gap[ gap !=0] <- 1
      aldb[ is.na( aldb)] <- 0
      gap <- as.logical( gap) } )
  
  rawCountyStats <- data.table( rawCountyStats)
  keycols <-
    colnames(rawCountyStats)[ colnames(rawCountyStats) != "n"]
  setkeyv( rawCountyStats, keycols)
  rawCountyStats <-
    rawCountyStats[, list( n= sum( n),
                          n2 = sum( replace( n, aldb <= 5, 0))),
       keyby= keycols ]
  
  zoneAreas <-
    statsNbcdZone[, list( totHa= sum(ha)),
                  by= "zone"]
  statsNbcdZone <-
    statsNbcdZone[ zoneAreas][, frac:=ha/totHa]
  
  nbcdZoneAldb <- 
      data.table(
        cast(
          data= statsNbcdZone,
          formula= zone ~ gap + nlcd,
          value= "aldb",
          subset= !is.na( aldb)),
        key= "zone")
  
  setnames(
    nbcdZoneAldb,
    colnames(nbcdZoneAldb),
    str_replace( colnames(nbcdZoneAldb), "_", ""))
  
  nbcdZoneAldbMeans <- 
    data.table(
      cast(
        data=
        statsNbcdZone[, list( aldbAve= weighted.mean( aldb, ha)),
                 by= c( "zone", "gap")],
        formula= zone ~ gap,
        value= "aldbAve",
        subset= !is.na( aldbAve)),
      key= "zone")
  
  setnames(
    nbcdCountyAldbMeans,
    colnames( nbcdCountyAldbMeans)[ -1],
    sprintf(
      "%sAll",
      colnames( nbcdCountyAldbMeans)[ -1]))
  
  nbcdZoneGapFrac <-
    data.table(
      cast(
        data= statsNbcdZone,
        formula= zone ~ gap,
        value= "frac",
        fun.aggregate= sum,
        subset= !is.na( aldb)),
      key= "zone")
  
  setnames(
    nbcdZoneGapFrac,
    colnames( nbcdZoneGapFrac)[ -1],
    sprintf(
      "%sAllFr",
      str_replace(
        colnames( nbcdZoneGapFrac)[ -1],
        "_", "")))
  
  nbcdZoneGapHa <-
    data.table(
      cast(
        data= statsNbcdZone,
        formula= zone ~ gap,
        value= "ha",
        fun.aggregate= sum,
        subset= !is.na( aldb)),
      key= "zone")
  
  setnames(
    nbcdZoneGapHa,
    colnames( nbcdZoneGapHa)[ -1],
    sprintf(
      "%sAllHa",
      str_replace(
        colnames( nbcdZoneGapHa)[ -1],
        "_", "")))
  
   nbcdZoneFrac <- 
    data.table(
      cast(
        data= statsNbcdZone,
        formula= zone ~ gap + nlcd,
        value= "frac",
        subset= !is.na( aldb)),
      key= "zone")
  
  setnames(
    nbcdZoneFrac,
    colnames( nbcdZoneFrac)[ -1],
    sprintf(
      "%sFr",
      str_replace(
        colnames( nbcdZoneFrac)[ -1],
        "_", "")))
  
  nbcdZoneHa <- 
    data.table(
      cast(
        data= statsNbcdZone,
        formula= zone ~ gap + nlcd,
        value= "ha",
        subset= !is.na( aldb)),
      key= "zone")
  
  setnames(
    nbcdZoneHa,
    colnames( nbcdZoneHa)[ -1],
    sprintf(
      "%sHa",
      str_replace(
        colnames( nbcdZoneHa)[ -1],
        "_", "")))
   
  nbcdZone <- nbcdZoneAldb[ nbcdZoneAldbMeans]
  nbcdZone <- nbcdZone[ nbcdZoneGapFrac][ nbcdZoneGapHa]
  nbcdZone <- nbcdZone[ nbcdZoneFrac][ nbcdZoneHa]
  setcolorder(
    nbcdZone,
    c( 1,
      order( colnames( nbcdZone)[ -1]) +1))
  
  nbcdZoneChar <-
    str_trim(
      format.df(
        nbcdZone,
        cdec= sapply(
          colnames( nbcdZone),
          function( x)
          ifelse(
            x == "zone", 0,
            ifelse(
              str_detect( x, "Ha$"), 1,
              ifelse(
                str_detect( x, "Fr$"), 3,
                1)))),
        numeric.dollar= FALSE,
        na.blank= TRUE))
  
  write.csv(
    nbcdZoneChar,
    row.names= FALSE,
    file= "nbcdZone.csv",
    quote= FALSE)
  
  zip( "pad-us_nlcd_nbcd.zip", "nbcdZone.csv")
   
  options(useFancyQuotes = FALSE)
   cat(
     sapply(
       colnames( nbcdZone),
       function( x) {
         dQuote(
           ifelse(
             x == "zone", "String(3)",
             ifelse(
               str_detect( x, "Ha$"),
               "Real(10.1)",
               ifelse(
                 str_detect( x, "Fr$"),
                 "Real(5.3)",
                 "Real(5.1)"))))
       }),
     sep= ",",
     file= "nbcdZone.csvt")
  
  ogr2ogr <-
    paste(
      "ogr2ogr -overwrite -progress -sql",
      sprintf(
        "\"select %s from nbcdZones a",
        paste( colnames( nbcdZone), collapse= ",")),
      "left join 'nbcdZone.csv'.nbcdZone b",
      "on a.zone = b.zone\"",
      "shp/nbcdZone.shp shp/nbcdZones.shp")
  
  system( ogr2ogr)
  
  zip(
    "pad-us_nlcd_nbcd.zip",
    list.files(
      path= "shp",
      pattern= "^nbcdZone\\.",
      full.names= TRUE))
  
  
#+end_src

**** TODO finish updating zone stat procedure to match state/county

GAP TRUE/FALSE naming, . . .


**** TODO figure out where null values in NBCD are coming from


*** repeat for states

    
#+begin_src R
  
  statsNbcdState <-
    rawStateStats[, list( aldb= weighted.mean( aldb, n),
                         aldb2= weighted.mean( aldb, n2),
                         n= sum( n),
                         n2= sum( n2),
                         ha= sum(n) * 30^2 / 10^4,
                         ha2= sum(n2) * 30^2 / 10^4),
                  keyby= "state,nlcd,gap"] 
  stateAreas <-
    statsNbcdState[ , list( totHa= sum(ha)),
                   keyby= "state"]
  statsNbcdState <-
    statsNbcdState[ stateAreas][, frac:=ha/totHa]
   
  statsNbcdState <-
    rbind(
      statsNbcdState[ !nlcd %in% as.character( c( 41, 42, 43, 90)),
                      list( state, nlcd, gap, aldb, ha, frac)],
      statsNbcdState[  nlcd %in% as.character( c( 41, 42, 43, 90)),
                      list( state, nlcd, gap, aldb= aldb2, ha, frac)])
  setkey( statsNbcdState, state, nlcd, gap)
  
  ## test
  ## any( abs( statsNbcdState[, list( frac= sum(frac)), by= state][, frac] - 1) > 0.001)
  
  nbcdStateAldb <- 
    data.table(
      cast(
        data= statsNbcdState,
        formula= state ~ gap + nlcd,
        value= "aldb",
        ## subset= !is.na( aldb)
        ),
      key= "state")
  
  setnames(
    nbcdStateAldb,
    colnames( nbcdStateAldb),
    str_replace(
      str_replace(
        colnames(nbcdStateAldb),
        "TRUE_", "yes"),
      "FALSE_", "no"))
  
  
  nbcdStateAldbMeans <- 
     data.table(
       cast(
         data=
         statsNbcdState[, list( aldbAve= weighted.mean( aldb, ha)),
                  by= c( "state", "gap")],
         formula= state ~ gap,
         value= "aldbAve",
         subset= !is.na( aldbAve)),
       key= "state")
  
  setnames(
    nbcdStateAldbMeans,
    c( "FALSE", "TRUE"),
    c( "noAll", "yesAll"))
  
  nbcdStateGapFrac <-
    data.table(
      cast(
        data= statsNbcdState,
        formula= state ~ gap,
        value= "frac",
        fun.aggregate= sum,
        ## subset= !is.na( aldb)
        na.rm = TRUE),
      key= "state")
  
  setnames(
    nbcdStateGapFrac,
    c( "FALSE", "TRUE"),
    c( "noAllFr", "yesAllFr"))
  
  nbcdStateGapHa <-
    data.table(
      cast(
        data= statsNbcdState,
        formula= state ~ gap,
        value= "ha",
        fun.aggregate= sum,
        ## subset= !is.na( aldb)
        na.rm= TRUE),
      key= "state")
  
  setnames(
    nbcdStateGapHa,
    c( "FALSE", "TRUE"),
    c( "noAllHa", "yesAllHa"))
  
   nbcdStateFrac <- 
    data.table(
      cast(
        data= statsNbcdState,
        formula= state ~ gap + nlcd,
        value= "frac",
        ## subset= !is.na( aldb)
        ),
      key= "state")
  
  setnames(
    nbcdStateFrac,
    colnames( nbcdStateFrac)[ -1],
    paste(
      str_replace(
        str_replace(
          colnames( nbcdStateFrac)[ -1],
          "TRUE_", "yes"),
        "FALSE_", "no"),
      "Fr", sep= ""))
  
  nbcdStateHa <- 
    data.table(
      cast(
        data= statsNbcdState,
        formula= state ~ gap + nlcd,
        value= "ha",
        ## subset= !is.na( aldb)
        ),
      key= "state")
  
  setnames(
    nbcdStateHa,
    colnames( nbcdStateHa)[ -1],
    paste(
      str_replace(
        str_replace(
          colnames( nbcdStateHa)[ -1],
          "TRUE_", "yes"),
        "FALSE_", "no"),
      "Ha", sep= ""))
   
  nbcdState <-
    nbcdStateAldb[ nbcdStateAldbMeans]
  nbcdState <-
    nbcdState[ nbcdStateGapFrac][ nbcdStateGapHa]
  nbcdState <-
    nbcdState[ nbcdStateFrac][ nbcdStateHa]
  
  setnames(
    nbcdState,
    "state", "fips")
  
  setcolorder(
    nbcdState,
    order( colnames( nbcdState)))
  
  nbcdStateChar <-
    str_trim(
      format.df(
        nbcdState,
        cdec= sapply(
          colnames( nbcdState),
          function( x) {
            ifelse(
              x == "fips", 0,
              ifelse(
                str_detect( x, "Ha$"), 1,
                ifelse(
                  str_detect( x, "Fr$"), 3,
                  1)))
          }),
        numeric.dollar= FALSE,
        na.blank= TRUE))
  
  write.csv(
    nbcdStateChar,
    row.names= FALSE,
    file= "nbcdState.csv",
    quote= FALSE)
  
  zip( "pad-us_nlcd_nbcd.zip", "nbcdState.csv")
   
  options(useFancyQuotes = FALSE)
   cat(
     sapply(
       colnames( nbcdState),
       function( x) {
         dQuote(
           ifelse(
             x == "fips", "String(2)",
             ifelse(
               str_detect( x, "Ha$"),
               "Real(10.1)",
               ifelse(
                 str_detect( x, "Fr$"),
                 "Real(5.3)",
                 "Real(5.1)"))))
       }),
     sep= ",",
     file= "nbcdState.csvt")
  
  ogr2ogr <-
    paste(
      "ogr2ogr -overwrite -progress -sql",
      sprintf(
        "\"select %s from cusaStatesAea a",
        paste( colnames( nbcdState), collapse= ",")),
      "left join 'nbcdState.csv'.nbcdState b",
      "on a.GEOID10 = b.fips\"",
      "shp/nbcdState.shp shp/cusaStatesAea.shp")
  
  system( ogr2ogr)
  
  zip(
    "pad-us_nlcd_nbcd.zip",
    list.files(
      path= "shp",
      pattern= "^nbcdState",
      full.names= TRUE))
#+end_src

**** TODO figure out if is.na( aldb2) is correct
    

*** repeat for counties

#+begin_src R
  ## library( reshape)
  ## library( Hmisc)
  ## library( data.table)
  ## library( stringr)
  
  statsNbcdCounty <-
    rawCountyStats[, list(
                       aldb= weighted.mean( aldb, n),
                       aldb2= weighted.mean( aldb, n2),
                       n= sum( n),
                       n2= sum( n2),
                       ha= sum(n) * 30^2 / 10^4,
                       ha2= sum(n2) * 30^2 / 10^4),
                   keyby= "state,county,nlcd,gap"]
  countyAreas <-
    statsNbcdCounty[, list( totHa= sum(ha)),
                    keyby= c( "state", "county")]
  statsNbcdCounty <-
    statsNbcdCounty[ countyAreas][, frac:=ha/totHa]
  
  statsNbcdCounty <-
    rbind(
      statsNbcdCounty[ !nlcd %in% as.character( c( 41, 42, 43, 90)),
                      list( state, county, nlcd, gap, aldb, ha, frac)],
      statsNbcdCounty[  nlcd %in% as.character( c( 41, 42, 43, 90)),
                      list( state, county, nlcd, gap, aldb= aldb2, ha, frac)])
  setkey( statsNbcdCounty, state, county, nlcd, gap)
  
  ## test
  ## any( abs( statsNbcdCounty[, list( frac= sum(frac)), by= "state,county"][, frac] - 1) > 0.001)
  
  zeroCarbonForestsIndex <-
    with(
      statsNbcdCounty,
      nlcd %in% as.character( c( 41, 42, 43, 90)) & is.na( aldb))
  
  statsNbcdCounty <-
    rbind(
      statsNbcdCounty[ !zeroCarbonForestsIndex],
      merge(
        statsNbcdCounty[ zeroCarbonForestsIndex],
        statsNbcdState,
        all.x= TRUE)[, list( state, county, nlcd, gap, aldb= aldb.y, ha = ha.x, frac= frac.x)])
  setkey( statsNbcdCounty, state, county, nlcd, gap)
  
  nbcdCountyAldb <- 
      data.table(
        cast(
          data= statsNbcdCounty,
          formula= state + county ~ gap + nlcd,
          value= "aldb",
          ## subset= !is.na( aldb)
          ),
        key= "state,county")
  
  setnames(
    nbcdCountyAldb,
    colnames(nbcdCountyAldb),
    str_replace(
      str_replace(
        colnames(nbcdCountyAldb),
        "TRUE_", "yes"),
      "FALSE_", "no"))
  
  nbcdCountyAldbMeans <- 
    data.table(
      cast(
        data=
        statsNbcdCounty[, list( aldbAve= weighted.mean( aldb, ha,
                                  na.rm= TRUE)),
                 by= c( "state", "county", "gap")],
        formula= state + county ~ gap,
        value= "aldbAve"),
        ## subset= !is.na( aldbAve)),
      key= "state,county")
  
  setnames(
    nbcdCountyAldbMeans,
    c( "FALSE", "TRUE"),
    c( "noAll", "yesAll"))
  
  nbcdCountyGapFrac <-
    data.table(
      cast(
        data= statsNbcdCounty,
        formula= state + county ~ gap,
        value= "frac",
        fun.aggregate= sum,
        ## subset= !is.na( aldb)
        na.rm= TRUE),
      key= "state,county")
  
  setnames(
    nbcdCountyGapFrac,
    c( "FALSE", "TRUE"),
    c( "noAllFr", "yesAllFr"))
  
  nbcdCountyGapHa <-
    data.table(
      cast(
        data= statsNbcdCounty,
        formula= state + county ~ gap,
        value= "ha",
        fun.aggregate= sum,
        ## subset= !is.na( aldb)
        na.rm= TRUE),
      key= "state,county")
  
  setnames(
    nbcdCountyGapHa,
    c( "FALSE", "TRUE"),
    c( "noAllHa", "yesAllHa"))
  
  nbcdCountyFrac <- 
    data.table(
      cast(
        data= statsNbcdCounty,
        formula= state + county ~ gap + nlcd,
        value= "frac",
        ## subset= !is.na( aldb)
        ),
      key= "state,county")
  
  setnames(
    nbcdCountyFrac,
    colnames( nbcdCountyFrac)[ -(1:2)],
    paste(
      str_replace(
        str_replace(
          colnames( nbcdCountyFrac)[ -(1:2)],
          "TRUE_", "yes"),
        "FALSE_", "no"),
      "Fr", sep= ""))
  
  nbcdCountyHa <- 
    data.table(
      cast(
        data= statsNbcdCounty,
        formula= state + county ~ gap + nlcd,
        value= "ha",
        ## subset= !is.na( aldb)
        ),
      key= "state,county")
  
  setnames(
    nbcdCountyHa,
    colnames( nbcdCountyHa)[ -(1:2)],
    paste(
      str_replace(
        str_replace(
          colnames( nbcdCountyHa)[ -(1:2)],
          "TRUE_", "yes"),
        "FALSE_", "no"),
      "Ha", sep= ""))
  
   
  nbcdCounty <-
    nbcdCountyAldb[ nbcdCountyAldbMeans]
  nbcdCounty <-
    nbcdCounty[ nbcdCountyGapFrac][ nbcdCountyGapHa]
  nbcdCounty <-
    nbcdCounty[ nbcdCountyFrac][ nbcdCountyHa]
  
  nbcdCounty <-
    nbcdCounty[, fips := paste( state, county, sep= "")]
  nbcdCounty <-
    nbcdCounty[, state := NULL][, county := NULL]
  setkey( nbcdCounty, fips)
  setcolorder( nbcdCounty, order( colnames( nbcdCounty)))
  
  nbcdCountyChar <-
    str_trim(
      format.df(
        nbcdCounty,
        cdec= sapply(
          colnames( nbcdCounty),
          function( x)
          ifelse(
            x == "fips", 0,
            ifelse(
              str_detect( x, "Ha$"), 1,
              ifelse(
                str_detect( x, "Fr$"), 3,
                1)))),
        numeric.dollar= FALSE,
        na.blank= TRUE))
  
  write.csv(
    nbcdCountyChar,
    row.names= FALSE,
    file= "nbcdCounty.csv",
    quote= FALSE)
  
  zip( "pad-us_nlcd_nbcd.zip", "nbcdCounty.csv")
   
  options(useFancyQuotes = FALSE)
   cat(
     sapply(
       colnames( nbcdCounty),
       function( x) {
         dQuote(
           ifelse(
             x == "fips", "String(5)",
             ifelse(
               str_detect( x, "Ha$"),
               "Real(10.1)",
               ifelse(
                 str_detect( x, "Fr$"),
                 "Real(5.3)",
                 "Real(5.1)"))))
       }),
     sep= ",",
     file= "nbcdCounty.csvt")
  
  ogr2ogr <-
    paste(
      "ogr2ogr -overwrite -progress -sql",
      sprintf(
        "\"select %s from cusaCountiesAea a",
        paste( colnames( nbcdCounty), collapse= ",")),
      "left join 'nbcdCounty.csv'.nbcdCounty b",
      "on a.GEOID10 = b.fips\"",
      "shp/nbcdCounty.shp shp/cusaCountiesAea.shp")
  
  system( ogr2ogr)
  
  zip(
    "pad-us_nlcd_nbcd.zip",
    list.files(
      path= "shp",
      pattern= "^nbcdCounty\\.",
      full.names= TRUE))
  
  
#+end_src


*** Plots


#+begin_src R
  
  library( ggplot2)
  library( scales)
  
  totalTonnes <-
    statsNbcdCounty[, list( aldb= sum( aldb * ha, na.rm= TRUE)),
                    keyby= "gap,nlcd"]
  
  totalTonnes[, labelY := aldb/2 + c(0, cumsum( aldb)[-length( aldb)])]
  
  totalTonnes[, pct := round( aldb / sum( aldb) *100, 1)]
  totalTonnes[, label := ifelse( pct >= 0.5,
                  sprintf( "%s, %3.1f%%", nlcd, pct), "")]
  
  totalTonnes[, label := sprintf( "%s, %d%%", nlcd, pct)]
  
  
  
  totalTonnes <-
    statsNbcdCounty[, list( aldb= sum( aldb * ha, na.rm= TRUE)),
                    keyby= "nlcd,gap"]
  totalTonnes <-
    totalTonnes[, frac := aldb / sum( aldb)]
  
  nlcdColors <-
    c(
      "11" = "#5475A8",
      "12" = "#FFFFFF",
      "21" = "#E8D1D1",
      "22" = "#E29E8C",
      "23" = "#FF0000",
      "24" = "#B50000",
      "31" = "#D2CDC0",
      "41" = "#85C77E",
      "42" = "#38814E",
      "43" = "#D4E7B0",
      "52" = "#DCCA8F",
      "71" = "#FDE9AA",
      "81" = "#FBF65D",
      "82" = "#CA9146",
      "90" = "#C8E6F8",
      "95" = "#64B3D5")
  
  nlcdCovers <-
    c(
      "11" = "water",
      "12" = "ice",
      "21" = "dev open",
      "22" = "dev low",
      "23" = "dev med",
      "24" = "dev high",
      "31" = "barren",
      "41" = "deciduous",
      "42" = "evergreen",
      "43" = "mixed",
      "52" = "shrub",
      "71" = "grass",
      "81" = "pasture",
      "82" = "crop",
      "90" = "woody wet",
      "95" = "wetland")
  
  nlcdMeta <-
    data.table(
      nlcd= factor( names( nlcdColors)),
      color= nlcdColors,
      cover= nlcdCovers,
      key= "nlcd")
  
  totalTonnes[, list( gap, nlcd,
                     frac = sprintf( "%5.4f", frac)),
              key= "nlcd"][ nlcdMeta]
  
  totalTonnes <-
    totalTonnes[, nlcd := reorder( factor(nlcd), frac, max)]
  setkey( totalTonnes, nlcd)
  
  with( totalTonnes, reorder( factor(nlcd), frac, max))
  
  
  ( massFracPlot <-
   ggplot(
     totalTonnes,
     aes(
       x= nlcd,
       y= frac,
       color= gap )) +
   geom_point(
     size= 4) +
   scale_x_discrete(
     name= "NLCD 2001 v1", ## ) +
     labels= nlcdMeta[ J( levels( totalTonnes$nlcd))][, cover]) +
   ylab( "Total mass fraction") +
   scale_color_manual(
     values= c( ## "#8C510A",
       "#D8B365", ## 0xF6E8C3; 0xC7EAE5;
       "#5AB4AC" ## "#01665E"
       )) + 
   coord_flip() +
   labs( colour= "Protected") +
   theme_bw())
  
   
  massFracPlot +
    scale_y_log10(
      limits= c(0.003, 0.35),
      breaks= c( 0.01, 0.02, 0.03, 0.1, 0.2, 0.3), 
      labels= percent)
  
  massFracPlot %+%
    as.data.frame( totalTonnes[ frac > 0.003]) +
    scale_x_discrete(
      ## breaks= nlcdCovers[ as.character( totalTonnes[ frac > 0.003]$nlcd)],
      labels= nlcdCovers[ as.character( totalTonnes[ frac > 0.003]$nlcd),
        drop= TRUE])
  
  last_plot() +
    scale_y_log10(
      limits= c(0.003, 0.35),
      breaks= c( 0.01, 0.02, 0.03, 0.1, 0.2, 0.3), 
      labels= percent)
  
#+end_src
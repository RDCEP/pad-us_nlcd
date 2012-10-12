
gdal/grid5minWorld.tif: scripts/grid5minWorld.R
	Rscript --vanilla $<

gdal/grid5minAeaCUSA.img: gdal/grid5minWorld.tif
	gdalwarp -overwrite -of HFA -t_srs "+proj=aea +lat_1=29.5 +lat_2=45.5 +lat_0=23 +lon_0=-96 +x_0=0 +y_0=0 +ellps=GRS80 +units=m +no_defs" -te -2493045 177285 2342655 3310005 -tr 30 30 -co "COMPRESSED=YES" $< $@

#!/usr/bin/make -f -I scripts

vpath %.R scripts
vpath %.mk scripts
vpath %.tif data
vpath %.img data

.PHONY: cusa pad-us ak hi pr small nbcdZones counties nbcd 

nbcd: scripts/grassNbcd.sh nlcd pad-us counties
	$(MAKE) --directory=$@ execute

# nbcd: grasscUSA
# 	scripts/grassNbcd.sh

nlcd:
	$(MAKE) --directory=$@ nlcd01v1

pad-us:
        $(MAKE) --directory=$@ -I scripts --no-builtin-rules cusa

tangle: pad-us_nlcd.org Makefile
	emacs --quick --batch \
	  --file=pad-us_nlcd.org \
	  --funcall=org-babel-tangle 2>&1 \
          | tee log/tangle.log | grep ^Wrote
	rsync -arv tangled/ scripts
#	touch $@

scripts/pad-us_nlcd.mk: tangle

scripts/*.R scripts/*.sh: tangle

data/grid5minWorld.tif: init.R
#	Rscript --vanilla $<


# -include scripts/pad-us_nlcd.mk
cusaProj  = +proj=aea +lat_1=29.5 +lat_2=45.5 +lat_0=23 
cusaProj += +lon_0=-96 +x_0=0 +y_0=0 +ellps=GRS80 +units=m +no_defs

data/grid5minAeaCUSA.img: 
	gdalwarp -overwrite -of HFA \
          -t_srs "$(cusaProj)" \
          -te -2493045 177285 2342655 3310005 \
          -tr 30 30 -co "COMPRESSED=YES" data/grid5minWorld.tif $@

data/grid5minAeaCUSA.vrt: 
	gdalwarp -overwrite -of VRT \
          -t_srs "$(cusProj)" \
          -te -2493045 177285 2342655 3310005 \
          -tr 30 30 data/grid5minWorld.tif $@

countiesUrl := ftp://ftp2.census.gov/geo/tiger/
countiesUrl := $(countiesUrl)TIGER2010/COUNTY/2010/tl_2010_us_county10.zip

counties:
	wget --no-clobber --progress=dot:mega \
	  --directory-prefix=data \
	  $(countiesUrl) # 2>&1 > log/$@.log
	unzip -n -d data data/tl_2010_us_county10.zip
	ogr2ogr -overwrite -progress \
	  -select STATEFP10,COUNTYFP10,GEOID10 \
	  -clipdst -2493045 177285 2342655 3310005 \
	  -t_srs "$(cusaProj)" \
	  data/cusaCountiesAea.shp data/tl_2010_us_county10.shp
	gdal_rasterize -at -tr 30 30 -co "COMPRESSED=YES" \
	  -l cusaCountiesAea -a_nodata 0 -a COUNTYFP10 -ot UInt16 -of HFA \
	  data/cusaCountiesAea.shp data/cusaCountiesAea.img

states: counties
#	wget -nc -P shp ftp://ftp2.census.gov/geo/tiger/TIGER2010/STATE/2010/tl_2010_us_state10.zip
#	unzip -n -d shp shp/tl_2010_us_state10.zip
#	ogr2ogr -overwrite -progress \
	  -select STATEFP10,GEOID10 \
	  -clipdst -2493045 177285 2342655 3310005 \
	  -t_srs "$(cusaProj)" \
	  shp/cusaStatesAea.shp shp/tl_2010_us_state10.shp
	gdal_rasterize -at -tr 30 30 -co "COMPRESSED=YES" \
	  -l cusaCountiesAea -a_nodata 0 -a STATEFP10 -ot Byte -of HFA \
	  data/cusaCountiesAea.shp data/cusaStatesAea.img

nbcdZones: # nbcdZones.R
	ogr2ogr -overwrite \
-select zone_id2 -clipdst -2493045 177285 2342655 3310005 \
-t_srs "+proj=aea +lat_1=29.5 +lat_2=45.5 +lat_0=23 +lon_0=-96 +x_0=0 +y_0=0 +ellps=GRS80 +units=m +no_defs" \
shp/nbcdZones.shp nbcd/shp/mapping_zone_shapefile.shp 
	Rscript --vanilla --quiet $<
	gdal_rasterize -at -tr 30 30 -co "COMPRESSED=YES" \
-l nbcdZones -a_nodata 0 -a zoneId -ot UInt16 -of HFA \
shp/nbcdZones.shp nbcdZones.img

shp/nbcdZoneAldb.shp: nbcdZoneAldb.csv
	ogr2ogr -overwrite -sql "select zone_id2,zone,no_11,no_12,no_21,no_22,no_23,no_24,no_31,no_41,no_42,no_43,no_52,no_71,no_81,no_82,no_90,no_95,yes_11,yes_12,yes_21,yes_22,yes_23,yes_24,yes_31,yes_41,yes_42,yes_43,yes_52,yes_71,yes_81,yes_82,yes_90,yes_95,no,yes from nbcdZones a left join 'nbcdZoneAldb.csv'.nbcdZoneAldb b on a.zone = b.zone" $@ shp/nbcdZones.shp

shp/nbcdCountyAldb.shp: # nbcdCountyAldb.csv nbcdCountyAldb.csvt
	ogr2ogr -overwrite -progress -sql "select fips,no_11,no_12,no_21,no_22,no_23,no_24,no_31,no_41,no_42,no_43,no_52,no_71,no_81,no_82,no_90,no_95,yes_11,yes_12,yes_21,yes_22,yes_23,yes_24,yes_31,yes_41,yes_42,yes_43,yes_52,yes_71,yes_81,yes_82,yes_90,yes_95,no,yes from cusaCountiesAea a left join 'nbcdCountyAldb.csv'.nbcdCountyAldb b on a.GEOID10 = b.fips" $@ shp/cusaCountiesAea.shp

small:
	find nbcd/atlas.whrc.org/NBCD2000/ -not -name "*.tgz" -type f -delete
	find nbcd/atlas.whrc.org/gfiske/ -not -name "*.zip" -type f -delete


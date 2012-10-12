
library( foreign)
library( stringr)

nbcdZonesAtts <-
  read.dbf( "shp/nbcdZones.dbf")

convertZoneId <-
  function( zone_id2) {
    charArr <-
      do.call(
        rbind,
        str_match_all(
          zone_id2,
          "^Z([0-9]+)([ab])?$"))
    zone <- charArr[,2]
    subZone <- charArr[,3]
    subZone[ subZone == ""] <- " "
    as.integer(
      paste(
        zone,
        chartr( " ab", "012", subZone),
        sep= ""))
}

nbcdZonesAtts <-
  within(
    nbcdZonesAtts,
    zone <- convertZoneId( zone_id2))

write.dbf( nbcdZonesAtts, "shp/nbcdZones.dbf")

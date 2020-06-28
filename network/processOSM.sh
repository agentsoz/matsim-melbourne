#!/bin/bash

# change to the directory this script is located in
cd "$(dirname "$0")"
# extract the roads from the osm file, put in melbourne.sqlite
ogr2ogr -update -overwrite -nln roads -f "SQLite" -dsco SPATIALITE=YES \
  -dialect SQLite -sql \
  "SELECT CAST(osm_id AS DOUBLE PRECISION) AS osm_id, highway, other_tags, \
    GEOMETRY FROM lines \
    WHERE (highway IS NOT NULL AND \
      highway NOT LIKE '%construction%' AND \
      highway NOT LIKE '%proposed%' AND \
      highway NOT LIKE '%disused%' AND \
      highway NOT LIKE '%abandoned%') AND \
      (other_tags IS NULL OR
       (other_tags NOT LIKE '%busbar%' AND \
        other_tags NOT LIKE '%abandoned%' AND \
        other_tags NOT LIKE '%parking%' AND \
        other_tags NOT LIKE '%\"access\"=>\"private\"%')) " \
  ./data/melbourne.sqlite ./data/melbourne.osm
#      highway NOT LIKE '%service%' AND \
# Removed since some service roads are used as footpaths (e.g., Royal Exhibition
# building

# extract the traffic signals, put in melbourne.sqlite
ogr2ogr -update -overwrite -nln roads_points -f "SQLite" -dsco SPATIALITE=YES \
  -dialect SQLite -sql \
  "SELECT CAST(osm_id AS DOUBLE PRECISION) AS osm_id, highway, other_tags, \
    GEOMETRY FROM points \
    WHERE highway LIKE '%traffic_signals%' " \
  ./data/melbourne.sqlite ./data/melbourne.osm

# extract the train and tram lines and add to melbourne.sqlite
# apparently there are minature railways
ogr2ogr -update -overwrite -nln pt -f "SQLite" -dialect SQLite -sql \
  "SELECT CAST(osm_id AS DOUBLE PRECISION) AS osm_id, highway, other_tags, \
    GEOMETRY FROM lines \
    WHERE other_tags LIKE '%railway%' AND \
      other_tags NOT LIKE '%busbar%' AND \
      other_tags NOT LIKE '%abandoned%' AND \
      other_tags NOT LIKE '%parking%' AND \
      other_tags NOT LIKE '%miniature%' AND \
      other_tags NOT LIKE '%proposed%' AND \
      other_tags NOT LIKE '%disused%' AND \
      other_tags NOT LIKE '%preserved%' AND \
      other_tags NOT LIKE '%construction%' AND \
      other_tags NOT LIKE '%\"service\"=>\"yard\"%'" \
  ./data/melbourne.sqlite ./data/melbourne.osm

# the postgres database name.
DB_NAME="network_test"

# Delete the database if it already exists
COMMAND="psql -U postgres -c 'DROP DATABASE ${DB_NAME}' postgres"
eval $COMMAND
# Create the database and add the postgis extension
createdb -U postgres ${DB_NAME}
psql -c 'create extension postgis' ${DB_NAME} postgres

ogr2ogr -overwrite -lco GEOMETRY_NAME=geom -lco SCHEMA=public -f "PostgreSQL" \
  PG:"host=localhost port=5432 user=postgres dbname=${DB_NAME}" \
  -a_srs "EPSG:4326" ./data/melbourne.sqlite roads

# run the sql statements
psql -U postgres -d ${DB_NAME} -a -f melbNetwork.sql

# extract the nodes and edges to the network file
ogr2ogr -update -overwrite -f SQLite -dsco SPATIALITE=yes ./data/network.sqlite PG:"dbname=${DB_NAME} user=postgres" public.line_cut3 -nln edges
ogr2ogr -update -overwrite -f SQLite -update ./data/network.sqlite PG:"dbname=${DB_NAME} user=postgres" public.endpoints_filtered -nln nodes

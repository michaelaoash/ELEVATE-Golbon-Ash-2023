## pdf(file="holyoke-poverty.pdf",height=0,width=0, paper="USr")
## https://www.holyoke.org/maps-of-holyoke/
## https://en.wikipedia.org/wiki/Template:Holyoke,_Massachusetts_Labelled_Map
library(tidyverse)
library(janitor)
library(tidycensus)
library(tigris)
options(tigris_use_cache = TRUE)
library(sp)
library(sf)
options(width=200)
## Documentation https://walker-data.com/tidycensus/articles/basic-usage.html
## Get your own Census API Key
## https://api.census.gov/data/key_signup.html
census_api_key("cb9bd8756de7ba64b3c95ec0bd9193fc98d7cfe1")

setwd("tidycensus-demo/holyoke/")

## Variable lists
acs_v2020 <- load_variables(2020, "acs5", cache = TRUE)
acs_v2020 %>% filter(grepl("B17010[AB]_((004)|(011)|(017)|(024)|(031)|(037))",name)) %>% select(label)
acs_v2020 %>% filter(grepl("B17010._(004)",name)) 

## Get the blockgroups from ACS
## Family poverty counts are available at the Block Group Level
## Family poverty counts by race are available only at/above the Tract Level
## "B17010_004","Estimate!!Total:!!Income in the past 12 months below poverty level:!!Married-couple family:!!With related children of the householder under 18 years:"
## "B17010_011","Estimate!!Total:!!Income in the past 12 months below poverty level:!!Other family:!!Male householder, no spouse present:!!With related children of the householder under 18 years:"
## "B17010_017","Estimate!!Total:!!Income in the past 12 months below poverty level:!!Other family:!!Female householder, no spouse present:!!With related children of the householder under 18 years:"
## "B17010_024","Estimate!!Total:!!Income in the past 12 months at or above poverty level:!!Married-couple family:!!With related children of the householder under 18 years:"
## "B17010_031","Estimate!!Total:!!Income in the past 12 months at or above poverty level:!!Other family:!!Male householder, no spouse present:!!With related children of the householder under 18 years:"
## "B17010_037","Estimate!!Total:!!Income in the past 12 months at or above poverty level:!!Other family:!!Female householder, no spouse present:!!With related children of the householder under 18 years:"


## Use these to get some useful geography
ma_towns_acs2020 <- get_acs(year=2020, geography = "county subdivision", state="MA", keep_geo_vars=TRUE, geometry = TRUE, output="wide",
                            variables = "B01001_001")
holyoke_acs2020 <- ma_towns_acs2020 %>% filter(NAME.x=="Holyoke")

## Download blockgroup-level family poverty counts for all of Massachusetts
ma_blockgroups_acs2020 <- get_acs(year=2020, geography = "block group", state="MA", keep_geo_vars=TRUE, geometry = TRUE, output="wide",
                                  variables = c(
                                      "B17010_004",
                                      "B17010_011",
                                      "B17010_017",
                                      "B17010_024",
                                      "B17010_031",
                                      "B17010_037"
                                  )
                                  )

## Compute the poverty rate from the count data
ma_blockgroups_acs2020 <- ma_blockgroups_acs2020 %>% mutate(
                                                         poor_families_with_children = B17010_004E + B17010_011E + B17010_017E,
                                                         families_with_children = B17010_004E + B17010_011E + B17010_017E + B17010_024E + B17010_031E + B17010_037E,
                                                         percent_families_with_children_in_poverty = poor_families_with_children/families_with_children * 100
                                                         )

## Plot some maps
ggplot(ma_blockgroups_acs2020) + geom_sf()

hampden_blockgroups_acs2020 <- filter(ma_blockgroups_acs2020, COUNTYFP=="013")

ggplot(hampden_blockgroups_acs2020) + geom_sf()

## As it happens, Tracts can neatly distinguish Holyoke from surrounding cities and towns.
holyoke_blockgroups_acs2020 <- filter(hampden_blockgroups_acs2020, substr(TRACTCE,1,4) %in% c("8114","8115","8116","8117","8118","8119","8120","8121"))

ggplot(holyoke_blockgroups_acs2020) + geom_sf() + geom_sf_text(aes(label=GEOID))

ggplot(holyoke_blockgroups_acs2020) + geom_sf(aes(fill=percent_families_with_children_in_poverty))


## Source: https://www2.census.gov/geo/tiger/TIGER2022/
## Get the 2010 Precinct Map of Hampden (from Census/Tigerline)
hampden_VTD_2010  <- st_read("tl_25013/tl_2010_25013_vtd10.shp")
head(hampden_VTD_2010)
ggplot(hampden_VTD_2010) + geom_sf() + geom_sf_text(aes(label=VTDST10))
holyoke_VTD_2010  <-    filter(hampden_VTD_2010, as.numeric(substr(VTDST10,1,4))>=2784, as.numeric(substr(VTDST10,1,4))<=2797)
ggplot(holyoke_VTD_2010) + geom_sf() + geom_sf_text(aes(label=VTDST10))

holyoke_VTD_2010 <- holyoke_VTD_2010 %>% mutate(
                         ward = substr(NAME10,9,14)
                     ) %>%
    group_by(ward) %>%
    summarize()


## See https://www2.census.gov/geo/pdfs/maps-data/data/tiger/tgrshp2009/TGRSHP09AF.pdf for MTFCC codes
areawater  <- st_read("tl_25013/tl_2022_25013_areawater.shp")
## ggplot() + geom_sf(data=areawater, color="blue") + geom_sf_label(data=areawater,aes(label=HYDROID))
holyoke_water  <- st_intersection(areawater,holyoke_acs2020)

## Limit roads to interstates and major roads in Providence
roads  <- st_read("tl_25013/tl_2022_25013_roads.shp") %>% filter(MTFCC %in% c("S1100","S1200"))
holyoke_roads  <- st_intersection(roads,holyoke_acs2020)
## ggplot() + geom_sf(data=pvd_roads, color="grey")

ggplot(data=holyoke_VTD_2010) + geom_sf() + geom_sf_text(aes(label=ward)) +
    geom_sf(data=holyoke_water, fill="blue") +
    geom_sf(data=holyoke_roads, color="pink") 


ggplot(holyoke_blockgroups_acs2020) +
    geom_sf(aes(fill=percent_families_with_children_in_poverty)) +
    scale_fill_gradient(low="gray", high="yellow") +
    geom_sf_text(data=holyoke_VTD_2010, aes(label=ward)) +
    geom_sf(data=holyoke_water, fill="blue") +
    geom_sf(data=holyoke_roads, color="pink") ## + geom_sf_text(data=holyoke_roads, aes(label=FULLNAME))


## Distance from each fossil fuel facility in MA to the Wards of Holyoke
fossil_ma <- readRDS("../../egrid2020/fossil-ma-egrid-2020.RDS")
fossil_ma_sf <- st_as_sf(fossil_ma, crs="NAD83", coords = c("LON", "LAT"))
st_distance(fossil_ma_sf, holyoke_VTD_2010)

fossil_ma_sf[23,]
fossil_ma_sf[29,]


ggplot(ma_towns_acs2020) + geom_sf() + geom_sf(data=fossil_ma_sf, aes(color=PLFUELCT))

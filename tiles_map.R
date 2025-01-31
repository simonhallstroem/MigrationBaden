library(ggplot2) #Access functions to e.g. plot data (ggplot) and read files(readxl/readr)
library(dplyr)
library(tidyverse) 
library(sf) # spatial data handling
library(raster)
library(viridis) # viridis color scale
library(readxl)
library(readr)
library(lintr)
library(xlsx)

#Open 2 databases, the first one contains coordinate system and population
#each municipality is depicted as 1 hectare in STATPOP, so cannot be used alone
coords_gmde <- read_delim("analysis/statpop/NOLOC/STATPOP2021_NOLOC.csv", delim = ";", escape_double = FALSE, trim_ws = TRUE)%>%
  dplyr::select(E_KOORD,N_KOORD,RELI,GMDE) 
gemeinden_baden <- read_excel("analysis/2021_Gemeinden.xlsx") %>% 
  mutate(GMDE=`Gmd-Nr.`) #give the municipality number column the same name as in coords_gmde

#combines the above datasets and groups them by GMDE,
#for all municipalities outside Baden, this will create NA, which is then filtered out
gmd_data <- left_join(coords_gmde,gemeinden_baden, by="GMDE") %>%
  filter(!is.na(Gemeinde))
#Get the coordinate range of municipalites
#This range is the reason why statpop data is used and not just gemeinden_baden
x_range <- range(gmd_data$E_KOORD)
y_range <- range(gmd_data$N_KOORD)

#Population data per hectare
pop_data <- read_csv("analysis/PopDataperHectare.csv")%>%
  filter(E_KOORD %in% (x_range[1]:x_range[2]), N_KOORD %in% (y_range[1]:y_range[2])) 
#filters data to only show that around Baden

#Buildings
#FILE TOO LARGE FOR GITHUB, THIS PART DOESNT WORK
building_data <- read_delim("GebäudeStatistik/GWS2021.csv", 
              delim = ";", escape_double = FALSE, trim_ws = TRUE) %>%
  filter(E_KOORD %in% (x_range[1]:x_range[2]), N_KOORD %in% (y_range[1]:y_range[2]))

  right_join(pop_data, by = c(`N_KOORD`=`N_KOORD`,`E_KOORD`=`E_KOORD`))

write.csv(building_data, "analysis/Building_per_ha_Baden.csv")

map500 <- raster("Maps/Baden_500.tif")%>% #Map background
  as("SpatialPixelsDataFrame") %>% #Turn into dataframe to plot into ggplot
  as.data.frame() %>%
  rename(relief = `Baden_500`)


baden_hectare <- function(visual_data,e_coord,n_coord, fill_data) {
  ggplot(visual_data, aes(x=e_coord,y= n_coord)) + 
    geom_raster(
      data = map500,
      inherit.aes = FALSE,
      aes(x,y,
          alpha=relief 
          #since fill is already used for the data, alpha values are used to paint the map
          #eventually, either a 2nd fill will be attempted with workarounds, or plot transitioned to leaflet instead of ggplot
      ),
    ) +
    scale_alpha(
      name = "",
      range = c(0.9,0),
      guide = F 
    ) +
#visualization of data
    geom_tile(aes(fill=cut(fill_data,
                           c(1,4,7,16,41,121,Inf))
                  ),
              ) + 
    #geom_tile(aes(fill=fill_data
    #),
    #) + 
    #by cutting B21BTOT (total population per hectare), you can set a colour to each part, colours mimic those found on the STATPOP website
    #gradients were avoided for the first test, as data wasnt visualsed nicely with gradients
    scale_fill_manual(
      values=c("(1,4]"="#ffffb2",
               "(4,7]"="#fdd976",
               "(7,16]"="#feb243",
               "(16,41]"="#fd8d3c",
               "(41,121]"="#f03b20",
               "(121,Inf]"="#bd0026"), 
      labels=c("1-3","4-6","7-15","16-40","41-120",">120"),
      name="population per ha",
      na.value = "green") +
    #scale_fill_gradient(
    #  name="buildings per ha",
    #  na.value = "green"
    #)+
    #remove visual clutter
    theme_minimal()+
    theme(
      axis.line = element_blank(),
      axis.text.x = element_blank(),
      axis.text.y = element_blank(),
      axis.ticks = element_blank(),
      axis.title = element_blank(),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
    )
}

baden_hectare(pop_data,pop_data$E_KOORD, pop_data$N_KOORD, pop_data$B21BTOT)

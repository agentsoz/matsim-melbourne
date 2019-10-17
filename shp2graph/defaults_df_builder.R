defaults_df_builder <- function(){
  
  defaults_df <- data.frame()
  defaults_df <- rbind(defaults_df, 
                       data.frame(highwayType = "motorway", permlanes = 2, freespeed = (80/3.6), 
                                  oneway = 1, capacity = 3600, modes = "car"))
  defaults_df <- rbind(defaults_df, 
                       data.frame(highwayType = "motorway_link", permlanes = 2, freespeed = (80/3.6), 
                                  oneway = 1, capacity = 3000, modes = "car"))
  defaults_df <- rbind(defaults_df, 
                       data.frame(highwayType = "trunk", permlanes = 2, freespeed = (70/3.6), 
                                  oneway = 1, capacity = 3000, modes = "car"))
  defaults_df <- rbind(defaults_df, 
                       data.frame(highwayType = "trunk_link", permlanes = 2, freespeed = 70/3.6, 
                                  oneway = 1, capacity = 2500, modes = "car"))
  defaults_df <- rbind(defaults_df, 
                       data.frame(highwayType = "primary", permlanes = 2, freespeed = 60/3.6, 
                                  oneway = 1, capacity = 2000, modes = "car,bike"))
  defaults_df <- rbind(defaults_df, 
                       data.frame(highwayType = "primary_link", permlanes = 1, freespeed = 60/3.6, 
                                  oneway = 1, capacity = 800, modes = "car,bike"))
  defaults_df <- rbind(defaults_df, 
                       data.frame(highwayType = "secondary", permlanes = 1, freespeed = 60/3.6, 
                                  oneway = 1, capacity = 800, modes = "car,bike"))
  defaults_df <- rbind(defaults_df, 
                       data.frame(highwayType = "secondary_link", permlanes = 1, freespeed = 60/3.6, 
                                  oneway = 1, capacity = 800, modes = "car,bike"))
  defaults_df <- rbind(defaults_df, 
                       data.frame(highwayType = "tertiary", permlanes = 1, freespeed = 50/3.6, 
                                  oneway = 1, capacity = 600, modes = "car,bike"))
  defaults_df <- rbind(defaults_df, 
                       data.frame(highwayType = "tertiary_link", permlanes = 1, freespeed = 50/3.6, 
                                  oneway = 1, capacity = 600, modes = "car,bike"))
  defaults_df <- rbind(defaults_df, 
                       data.frame(highwayType = "residential", permlanes = 1, freespeed = 50/3.6, 
                                  oneway = 1, capacity = 600, modes = "car,bike"))
  defaults_df <- rbind(defaults_df, 
                       data.frame(highwayType = "unclassified", permlanes = 1, freespeed = 50/3.6, 
                                  oneway = 1, capacity = 600, modes = "car,bike"))
  defaults_df <- rbind(defaults_df, 
                       data.frame(highwayType = "living_street", permlanes = 1, freespeed = 20/3.6, 
                                  oneway = 1, capacity = 300, modes = "car,bike"))
  defaults_df <- rbind(defaults_df, 
                       data.frame(highwayType = "cycleway", permlanes = 1, freespeed = 30/3.6, 
                                  oneway = 1, capacity = 300, modes = "bike"))
  defaults_df <- rbind(defaults_df, 
                       data.frame(highwayType = "track", permlanes = 1, freespeed = 30/3.6, 
                                  oneway = 1, capacity = 300, modes = "bike"))
  defaults_df <- rbind(defaults_df, 
                       data.frame(highwayType = "service", permlanes = 1, freespeed = 40/3.6, 
                                  oneway = 1, capacity = 200, modes = "bike"))
  defaults_df <- rbind(defaults_df, 
                       data.frame(highwayType = "pedestrian", permlanes = 1, freespeed = 30/3.6, 
                                  oneway = 1, capacity = 120, modes = "walk"))
  defaults_df <- rbind(defaults_df, 
                       data.frame(highwayType = "footway", permlanes = 1, freespeed = 15/3.6, 
                                  oneway = 1, capacity = 120, modes = "walk"))
  defaults_df <- rbind(defaults_df, 
                       data.frame(highwayType = "path", permlanes = 1, freespeed = 15/3.6, 
                                  oneway = 1, capacity = 120, modes = "walk"))
  defaults_df <- rbind(defaults_df, 
                       data.frame(highwayType = "steps", permlanes = 1, freespeed = 15/3.6, 
                                  oneway = 1, capacity = 10, modes = "walk"))
  
  colnames(defaults_df) <- c("highwayType", "permlanes", "freespeed", "oneway", "capacity", "modes")
  

  return(defaults_df)
}
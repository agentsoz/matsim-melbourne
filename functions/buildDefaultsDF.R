buildDefaultsDF <- function(){
  
  defaults_df <- tribble(
    ~highwayType      , ~permlanes, ~freespeed, ~oneway, ~capacity, ~isCycle, ~isWalk, ~isCar,
     "motorway"       ,  2        ,  (80/3.6) ,  1     ,  3600    ,  FALSE  ,  FALSE ,  TRUE ,
     "motorway_link"  ,  2        ,  (80/3.6) ,  1     ,  3000    ,  FALSE  ,  FALSE ,  TRUE ,
     "trunk"          ,  2        ,  (70/3.6) ,  1     ,  3000    ,  FALSE  ,  FALSE ,  TRUE ,
     "trunk_link"     ,  2        ,  (70/3.6) ,  1     ,  2500    ,  FALSE  ,  FALSE ,  TRUE ,
    
     "primary"        ,  2        ,  (60/3.6) ,  1     ,  2000    ,  TRUE   ,  FALSE ,  TRUE ,
     "primary_link"   ,  1        ,  (60/3.6) ,  1     ,   800    ,  TRUE   ,  FALSE ,  TRUE ,
     "secondary"      ,  1        ,  (60/3.6) ,  1     ,   800    ,  TRUE   ,  FALSE ,  TRUE ,
     "secondary_link" ,  1        ,  (60/3.6) ,  1     ,   800    ,  TRUE   ,  FALSE ,  TRUE ,
    
     "tertiary"       ,  1        ,  (50/3.6) ,  1     ,   600    ,  TRUE   ,  FALSE ,  TRUE ,
     "tertiary_link"  ,  1        ,  (50/3.6) ,  1     ,   600    ,  TRUE   ,  FALSE ,  TRUE ,
     "residential"    ,  1        ,  (50/3.6) ,  1     ,   600    ,  TRUE   ,  FALSE ,  TRUE ,
     "unclassified"   ,  1        ,  (50/3.6) ,  1     ,   600    ,  TRUE   ,  FALSE ,  TRUE ,
    
     "living_street"  ,  1        ,  (20/3.6) ,  1     ,   300    ,  TRUE   ,  FALSE ,  TRUE ,
     "cycleway"       ,  1        ,  (30/3.6) ,  1     ,   300    ,  TRUE   ,  FALSE ,  FALSE,
     "track"          ,  1        ,  (30/3.6) ,  1     ,   300    ,  TRUE   ,  FALSE ,  FALSE,
     "service"        ,  1        ,  (40/3.6) ,  1     ,   200    ,  TRUE   ,  FALSE ,  TRUE ,
    
     "pedestrian"     ,  1        ,  (30/3.6) ,  1     ,   120    ,  FALSE  ,  TRUE  ,  FALSE,
     "footway"        ,  1        ,  (15/3.6) ,  1     ,   120    ,  FALSE  ,  TRUE  ,  FALSE,
     "path"           ,  1        ,  (15/3.6) ,  1     ,   120    ,  FALSE  ,  TRUE  ,  FALSE,
     "steps"          ,  1        ,  (15/3.6) ,  1     ,    10    ,  FALSE  ,  TRUE  ,  FALSE
  )

  return(defaults_df)
}
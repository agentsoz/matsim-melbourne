buildDefaultsDF <- function(){
  
  defaults_df <- tribble(
    ~highway          , ~permlanes, ~freespeed, ~oneway, ~capacity, ~isCycle, ~isWalk, ~isCar,
     "motorway"       ,  4        ,  (110/3.6),  1     ,  2000    ,  0      ,  0     ,  1    ,
     "motorway_link"  ,  2        ,  (80/3.6) ,  1     ,  1500    ,  0      ,  0     ,  1    ,
     "trunk"          ,  3        ,  (100/3.6),  1     ,  2000    ,  0      ,  0     ,  1    ,
     "trunk_link"     ,  2        ,  (80/3.6) ,  1     ,  1500    ,  0      ,  0     ,  1    ,
    
     "primary"        ,  2        ,  (80/3.6) ,  1     ,  1500    ,  1      ,  1     ,  1    ,
     "primary_link"   ,  1        ,  (60/3.6) ,  1     ,  1500    ,  1      ,  1     ,  1    ,
     "secondary"      ,  1        ,  (60/3.6) ,  1     ,  1000    ,  1      ,  1     ,  1    ,
     "secondary_link" ,  1        ,  (60/3.6) ,  1     ,  1000    ,  1      ,  1     ,  1    ,
    
     "tertiary"       ,  1        ,  (50/3.6) ,  1     ,   600    ,  1      ,  1     ,  1    ,
     "tertiary_link"  ,  1        ,  (50/3.6) ,  1     ,   600    ,  1      ,  1     ,  1    ,
     "residential"    ,  1        ,  (50/3.6) ,  1     ,   600    ,  1      ,  1     ,  1    ,
     "road"           ,  1        ,  (50/3.6) ,  1     ,   600    ,  1      ,  1     ,  1    ,
     "unclassified"   ,  1        ,  (50/3.6) ,  1     ,   600    ,  1      ,  1     ,  1    ,
    
     "living_street"  ,  1        ,  (40/3.6) ,  1     ,   300    ,  1      ,  1     ,  1    ,
     "cycleway"       ,  1        ,  (30/3.6) ,  1     ,   300    ,  1      ,  0     ,  0    ,
     "track"          ,  1        ,  (30/3.6) ,  1     ,   300    ,  1      ,  0     ,  0    ,
     "service"        ,  1        ,  (40/3.6) ,  1     ,   200    ,  1      ,  1     ,  1    ,

     "pedestrian"     ,  1        ,  (30/3.6) ,  1     ,   120    ,  0      ,  1     ,  0    ,
     "footway"        ,  1        ,  (15/3.6) ,  1     ,   120    ,  0      ,  1     ,  0    ,
     "path"           ,  1        ,  (15/3.6) ,  1     ,   120    ,  0      ,  1     ,  0    ,
     "corridor"       ,  1        ,  (15/3.6) ,  1     ,    50    ,  0      ,  1     ,  0    ,
     "steps"          ,  1        ,  (15/3.6) ,  1     ,    10    ,  0      ,  1     ,  0    
  )

  return(defaults_df)
}
suppressMessages(library(reshape2))
suppressMessages(library(ggplot2))
suppressMessages(library(plyr))
suppressMessages(library(dplyr))
suppressMessages(library(scales))

extract_and_write_activities_from<-function(in_vista_csv, out_weekday_activities_csv_gz, out_weekend_activities_csv_gz) {
  gz1 <- gzfile(in_vista_csv,'rt')
  vista_data<-read.csv(gz1,header = T,sep=',',stringsAsFactors = F,strip.white = T)
  close(gz1)
  
  datacols<-c("PERSID",
              "TRAVDOW",
              "ORIGPURP1",
              "DESTPURP1",
              "STARTIME","ARRTIME",
              "CW_WDSTOPWGT_LGA",
              "CW_WESTOPWGT_LGA")
              
  orig<-vista_data[,datacols]
  
  # For each trip (row) we need to use the weight to represent the number of such trips in the full population.
  # Doesn't matter if we use CW_*_LGA or CW_*_SA3 since we are only looking at the full set and not cut up by 
  # region. Though the respective cols do not add up to the same number (see bleow) so maybe I don't understand 
  # this correctly:
  #  > sum(orig$CW_ADSTOPWGT_SA3, na.rm = TRUE)
  #  [1] 16487629
  #  > sum(orig$CW_ADSTOPWGT_LGA, na.rm = TRUE)
  #  [1] 16117137
  
  get_activities<-function (dataset) {
    # Get the activities and their start/end times
    df<-data.frame(row.names = 1:length(dataset$PERSID)) # create a data frame of the correct row size
    df$Person<-dataset$PERSID
    df$Index<-as.numeric(rownames(dataset)) # save the index of the activity
    df$Activity<-dataset$ORIGPURP1 # activity is ORIGPURP1
    df$Act.Start.Time<-c(0,dataset$ARRTIME[1:length(dataset$ARRTIME)-1]) # start time is arrive time of the previous row
    df$Act.End.Time<-dataset$STARTIME # end time is the start time of the trip
    df$Count<-dataset$Count
    
    # What is left is the final "Go Home" activity of each person
    lastact<-dataset[dataset$DESTPURP1=="Go Home",c("PERSID","DESTPURP1","ARRTIME", "Count")] # get all the "Go Home" activities
    colnames(lastact)<-c("Person","Activity", "Act.Start.Time", "Count") # rename the cols
    lastact$Index<-as.numeric(rownames(lastact)) # save the index of the activity
    lastact<-aggregate(lastact,by=list(lastact$Person),FUN=tail,n=1) # remove all but the last "Go Home" for each person
    lastact$Act.End.Time<-1439 # assign these final activities of the day the end time of 23:59
    
    # Now we want to insert these activities at the given index into the original list of activities
    dd<-rbind(df,lastact[,colnames(df)]) # first append them to the end of original set of activities
    id<- c(df$Index,(lastact$Index+0.5)) #give them half-rank indices ie where they should be slotted
    dy<-dd[order(id),] # now use order to pluck the set in the correct order
    
    # Assign the first activitiy of the person a start time of 0
    xx<-aggregate(dy,by=list(dy$Person),FUN=head,1)
    dy$Act.Start.Time<-apply(dy,1,function(x) {
      ifelse(as.numeric(x["Index"]) %in% xx$Index, 0, as.numeric(x["Act.Start.Time"])
      )
    })
    dy
  }
  
  # Split into weekday/weekend and set the weights (ie counts here) correctly
  week<-orig[,datacols]
  isWeekday<-week$TRAVDOW!="Saturday" & week$TRAVDOW!="Sunday"
  weekdays<-week[isWeekday,]; weekdays$Count<- weekdays$CW_WDSTOPWGT_LGA
  weekends<-week[!isWeekday,]; weekends$Count<-weekends$CW_WESTOPWGT_LGA

  # Fix any rows where the weights are not defined
  if(any(is.na(weekends$Count))) {
    weekends[is.na(weekends$Count),]$Count<-0
  }
  if(any(is.na(weekdays$Count))) {
    weekdays[is.na(weekdays$Count),]$Count<-0
  }
  
  # Get the activities for each set
  weekday_activities<-get_activities(weekdays)
  weekend_activities<-get_activities(weekends)
  
  # Write them out
  gz1 <- gzfile(out_weekday_activities_csv_gz, "w")
  write.csv(weekday_activities, gz1)
  close(gz1)
  gz1 <- gzfile(out_weekend_activities_csv_gz, "w")
  write.csv(weekend_activities, gz1, row.names=FALSE, quote=TRUE)
  close(gz1)
}

simplify_activities_and_create_groups<-function(gzfile) {
  
  gz1 <- gzfile(gzfile,'rt')
  activities<-read.csv(gz1,header = T,sep=',',stringsAsFactors = F,strip.white = T)
  close(gz1)
  
  # Simplify the activities as follows:
  # 1. remove "Change Mode" activities which are just in-transit mode-change activities
  # 2. remove "Accompany Someone" which is a secondary activitiy
  df<-activities
  df<-df[df$Activity!="Change Mode",]
  df<-df[df$Activity!="Accompany Someone",]
  
  # Assign activities into groups as follows:
  df$Activity.Group<-""
  df$Activity.Group<-ifelse(
    df$Activity=="At Home" | df$Activity=="Go Home", 
    "Home", df$Activity.Group)
  df$Activity.Group<-ifelse(
    df$Activity=="Personal Business", 
    "Personal", df$Activity.Group)
  df$Activity.Group<-ifelse(
    df$Activity=="Work Related", 
    "Work", df$Activity.Group)
  df$Activity.Group<-ifelse(
    df$Activity=="Education", 
    "Study", df$Activity.Group)
  df$Activity.Group<-ifelse(
    df$Activity=="Buy Something", 
    "Shop", df$Activity.Group)
  df$Activity.Group<-ifelse(
    df$Activity=="Unknown Purpose (at start of day)" | df$Activity=="Other Purpose" | df$Activity=="Not Stated", 
    "Other", df$Activity.Group)
  df$Activity.Group<-ifelse(
    df$Activity=="Social" | df$Activity=="Recreational", 
    "Social/Recreational", df$Activity.Group)
  df$Activity.Group<-ifelse(
    df$Activity=="Pick-up or Drop-off Someone" | df$Activity=="Pick-up or Deliver Something",
    "Pickup/Dropoff/Deliver", df$Activity.Group)
  
  gz1 <- gzfile(gzfile, "w")
  write.csv(df, gz1, row.names=FALSE, quote=TRUE)
  close(gz1)
  
}

extract_activities_by_minute_of_day <- function(in_activities_csv_gz, out_activities_by_time_of_day_csv_gz) {
  gzfile<-in_activities_csv_gz
  gz1 <- gzfile(gzfile,'rt')
  activities<-read.csv(gz1,header = T,sep=',',stringsAsFactors = F,strip.white = T)
  close(gz1)
  
  minsOfDay<-seq(1:(60*24))-1
  actCounts<-data.frame(row.names = minsOfDay)
  actCounts[,unique(sort(activities$Activity.Group))]<-0
  for(row in 1:nrow(activities)) {
    x<-activities[row,]
    actCounts[,x$Activity.Group]<-actCounts[,x$Activity.Group] +
      ifelse((minsOfDay>=x$Act.Start.Time) & (minsOfDay<=x$Act.End.Time),x$Count,0)
  }
  
  gz1 <- gzfile(out_activities_by_time_of_day_csv_gz, "w")
  write.csv(actCounts, gz1, row.names=FALSE, quote=TRUE)
  close(gz1)
  
}

plot_activities_by_time_of_day <- function(in_activities_csv_gz, blockSizeInMins) {

  gzfile<-in_activities_csv_gz
  gz1 <- gzfile(gzfile,'rt')
  activities<-read.csv(gz1,header = T,sep=',',stringsAsFactors = F,strip.white = T)
  close(gz1)
  
  blocksize<-(24*60)/blockSizeInMins
  df<-data.frame(row.names = seq(1:blocksize))
  for (colname in colnames(activities)) {
    df[,colname]<-colSums(matrix(activities[,colname], ncol=blocksize))
  }
  #df$HourRange<-c("0-2","2-4","4-6","6-8","8-10","10-12","12-14","14-16","16-18","18-20","20-22","22-24")
  
  d<-melt(t(df))
  colnames(d)<-c("Activity", "HourRange", "Count")
  ggplot(d, aes(HourRange,Count, col=Activity, fill=Activity)) + 
    theme(axis.text.x = element_text(angle = 60, hjust = 1)) +
    geom_bar(stat="identity", color="black", size=0.1, position = "stack") +
    scale_y_continuous(labels = comma) +
    xlab(paste0("Time of day (",blockSizeInMins,"min blocks)")) + ylab("Population") + 
    ggtitle(NULL)
}

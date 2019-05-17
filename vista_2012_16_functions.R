suppressMessages(library(reshape2))
suppressMessages(library(ggplot2))
suppressMessages(library(plyr))
suppressMessages(library(dplyr))
suppressMessages(library(scales))
suppressMessages(library(markovchain))

extract_and_write_activities_from<-function(in_vista_csv, out_weekday_activities_csv_gz, out_weekend_activities_csv_gz) {
  gz1 <- gzfile(in_vista_csv,'rt')
  vista_data<-read.csv(gz1,header = T,sep=',',stringsAsFactors = F,strip.white = T)
  close(gz1)
  
  datacols<-c("PERSID",
              "TRAVDOW",
              "ORIGPURP1",
              "DESTPURP1",
              "STARTIME","ARRTIME",
              "CW_WDTRIPWGT_LGA",
              "CW_WETRIPWGT_LGA")
              
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
    lastact<-dataset[dataset$DESTPURP1=="At or Go Home",c("PERSID","DESTPURP1","ARRTIME", "Count")] # get all the "Go Home" activities
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
  weekdays<-week[isWeekday,]; weekdays$Count<- weekdays$CW_WDTRIPWGT_LGA
  weekends<-week[!isWeekday,]; weekends$Count<-weekends$CW_WETRIPWGT_LGA

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
  write.csv(weekday_activities, gz1, row.names=FALSE, quote=TRUE)
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
  #df<-df[df$Activity!="Change Mode",]
  #df<-df[df$Activity!="Accompany Someone",]
  
  # Assign activities into groups as follows:
  df$Activity.Group<-""
  df$Activity.Group<-ifelse(
    df$Activity=="At or Go Home", 
    "Home", df$Activity.Group)
  df$Activity.Group<-ifelse(
    df$Activity=="Personal Business", 
    "Personal", df$Activity.Group)
  df$Activity.Group<-ifelse(
    df$Activity=="Work Related", 
    "Work", df$Activity.Group)
  df$Activity.Group<-ifelse(
    df$Activity=="Change Mode", 
    "Mode Change", df$Activity.Group)
  df$Activity.Group<-ifelse(
    df$Activity=="Accompany Someone", 
    "With Someone", df$Activity.Group)
  df$Activity.Group<-ifelse(
    df$Activity=="Education", 
    "Study", df$Activity.Group)
  df$Activity.Group<-ifelse(
    df$Activity=="Buy Something", 
    "Shop", df$Activity.Group)
  df$Activity.Group<-ifelse(
    df$Activity=="Unknown purpose (at start of day)" | df$Activity=="Other Purpose" | df$Activity=="Not Stated", 
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

extract_activities_by_time_of_day <- function(in_activities_csv_gz, blockSizeInMins, out_activities_by_time_of_day_csv_gz) {
  
  gzfile<-in_activities_csv_gz
  gz1 <- gzfile(gzfile,'rt')
  activities<-read.csv(gz1,header = T,sep=',',stringsAsFactors = F,strip.white = T)
  close(gz1)
  
  minsOfDay<-seq(from=0,to=(24*60)-1,by=blockSizeInMins)
  actCounts<-data.frame(row.names = minsOfDay)
  actCounts[,unique(sort(activities$Activity.Group))]<-0
  for(row in 1:nrow(activities)) {
    x<-activities[row,]
    actCounts[,x$Activity.Group]<-actCounts[,x$Activity.Group] +
      ifelse((minsOfDay>=x$Act.Start.Time) & (minsOfDay<=x$Act.End.Time),x$Count,0)
  }

  # now rescale the distribution of values to match the population size 
  dd<-aggregate(activities,by=list(activities$Person),FUN=head,n=1)
  popnsize<-sum(dd$Count)
  actCounts<-t(apply(actCounts,1, function(x, mx) {(x/sum(x))*mx}, mx=popnsize))
  
  gz1 <- gzfile(out_activities_by_time_of_day_csv_gz, "w")
  write.csv(round(actCounts, digits = 0), gz1, row.names=TRUE, quote=TRUE)
  close(gz1)
  
}

plot_activities_by_hour_of_day <- function(in_activities_csv_gz) {
  gzfile<-in_activities_csv_gz
  gz1 <- gzfile(gzfile,'rt')
  activities<-read.csv(gz1,header = T,sep=',',stringsAsFactors = F,strip.white = T)
  close(gz1)
  
  activities$X<-activities$X/60 # mins to hours
  
  d<-melt((activities), id.vars=c("X"))
  colnames(d)<-c("HourRange", "Activity", "Count")
  
  ggplot(d, aes(HourRange,Count, col=Activity, fill=Activity)) + 
    #theme(axis.text.x = element_text(angle = 60, hjust = 1)) +
    geom_bar(stat="identity", color="black", size=0.1, position = "stack") +
    scale_y_continuous(labels = comma) +
    xlab("Hour of day") + ylab("Population") + 
    ggtitle(NULL)
  
}

plot_week_activities_by_hour_of_day <- function(wd_activities_csv_gz, we_activities_csv_gz) {
  gzfile<-wd_activities_csv_gz
  gz1 <- gzfile(gzfile,'rt')
  wd_activities<-read.csv(gz1,header = T,sep=',',stringsAsFactors = F,strip.white = T)
  close(gz1)
  
  gzfile<-we_activities_csv_gz
  gz1 <- gzfile(gzfile,'rt')
  we_activities<-read.csv(gz1,header = T,sep=',',stringsAsFactors = F,strip.white = T)
  close(gz1)
  
  df<-wd_activities
  df$Day<-"Weekday"
  activities<-df
  df<-we_activities
  df$Day<-"Weekend"
  activities<-rbind(activities,df)
  
  activities$X<-activities$X/60 # mins to hours
  
  d<-melt((activities), id.vars=c("X","Day"))
  colnames(d)<-c("HourRange", "Day", "Activity", "Count")
  
  ggplot(d, aes(HourRange,Count, col=Activity, fill=Activity)) + 
    geom_bar(stat="identity", color="black", size=0.1, position = "stack") +
    facet_wrap(~Day, ncol=2) + 
    scale_y_continuous(labels = comma) +
    xlab("Hour of day") + ylab("Population") + 
    theme(legend.position = "bottom") +
    ggtitle(NULL)
  
}

create_markov_chain_model<-function(modelname, activities_csv_gz) {
  gz1 <- gzfile(activities_csv_gz,'rt')
  orig<-read.csv(gz1,header = T,sep=',',stringsAsFactors = F,strip.white = T)
  close(gz1)
  
  activities<-orig
  activities$Order<-order(activities$Person) # record order, used for filtering
  # Rename 'Home' activities to 'Home Daytime'
  activities[activities$Activity.Group=="Home",]$Activity.Group<-"Home Daytime"
  # Rename start of the day 'Home' activities to 'Home Morning'
  df<-activities
  df<-aggregate(df,by=list(df$Person),FUN=head,1) # get first activities
  df<-df[df$Activity.Group=="Home Daytime",] # remove all but home activities
  activities[activities$Order%in%df$Order,]$Activity.Group<-"Home Morning" # rename those activities
  # Rename end of the day 'Home' activities to 'Home Night'
  df<-activities
  df<-aggregate(df,by=list(df$Person),FUN=tail,1) # get last activities
  df<-df[df$Activity.Group=="Home Daytime",] # remove all but home activities
  activities[activities$Order%in%df$Order,]$Activity.Group<-"Home Night" # rename those activities
  activities$Order<-NULL # done with temporary column
  
  # Get list of activities per person
  activity.chains<-activities%>%
    group_by(Person) %>% 
    summarise(Activity.Chain = paste0(Activity.Group, collapse=","))
  
  states<-unique(sort(activities$Activity.Group))
  probs<-data.frame(
    matrix(0, nrow=length(states), ncol=length(states)),
    row.names = states)
  colnames(probs)<-states
  for (j in 1:length(activity.chains$Activity.Chain)) {
    chain<-activity.chains$Activity.Chain[j]
    sq<-strsplit(chain, ",")[[1]]
    if(length(sq)>1) {
      for(i in 2:length(sq)) {
        if (sq[i]%in%states && sq[i-1]%in%states) {
          probs[sq[i-1],sq[i]]<-probs[sq[i-1],sq[i]]+1
        } else {
          print(paste0(sq[i-1],"|",sq[i]))
        }
      }
    }
  }
  df<-probs
  df["Home Night","Home Night"]<-1 # absorbing markov state
  df<-df/rowSums(df)
  mc<-new("markovchain", 
          states = states,
          transitionMatrix = as.matrix(df),
          name="Activity Chains")
  return(mc)
}

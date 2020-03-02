options(scipen=999) # disable scientific notation for more readible filenames with small sample sizes

selectIndexFromProbabilities <-function(vv) {
  vv<-vv/sum(vv) # normalise to 1
  v<-cumsum(vv) # cumulative sum to 1
  roll<-runif(1)
  select<-match(TRUE,v>roll) # pick the first col that is higher than the dice roll
  return(select)
}

echo<- function(msg) {
  cat(paste0(as.character(Sys.time()), ' | ', msg))
}

printProgress<-function(row, char) {
  if((row-1)%%100==0) echo('')
  cat(char)
  if(row%%10==0) cat('|')
  if(row%%100==0) cat(paste0(' ', row,'\n'))
}

getActivityGroups <- function(bins) {
  groups<-unique(bins$Activity.Group)
  groups<-groups[groups!="Mode Change" & groups !="With Someone"]
  return(groups)
}

createNewPlan <- function(bins, newbins, binCols) {
  
  getProbabilitiesMatrix <- function(bins, stat, binCols) {
    df<-bins
    df<-df[df$Activity.Group!="Mode Change" & df$Activity.Group!="With Someone",]
    df<-df[df$Activity.Stat==stat,]
    rnames<-df$Activity.Group
    cnames<-paste0("Bin",1:length(binCols))
    df<-as.matrix(df[,binCols])
    rownames(df)<-rnames
    colnames(df)<-cnames
    return(df)
  }  
  
  binsize<-length(binCols)
  binSizeInMins<-floor(60*24)/binsize
  binStartMins<-seq(0,binsize-1)*binSizeInMins
  binEndMins<-binStartMins+binSizeInMins-1
  
  groups<-getActivityGroups(bins)
  astp <- getProbabilitiesMatrix(bins, "Act.Start.Time.Prob", binCols)
  aetp <- getProbabilitiesMatrix(bins, "Act.End.Time.Prob", binCols)
  admm <- getProbabilitiesMatrix(bins, "Act.Duration.Mins.Mean", binCols)
  adms <- getProbabilitiesMatrix(bins, "Act.Duration.Mins.Sigma", binCols)

  nastp <- getProbabilitiesMatrix(newbins, "Act.Start.Time.Prob", binCols)
  naetp <- getProbabilitiesMatrix(newbins, "Act.End.Time.Prob", binCols)
  nadmm <- getProbabilitiesMatrix(newbins, "Act.Duration.Mins.Mean", binCols)
  nadms <- getProbabilitiesMatrix(newbins, "Act.Duration.Mins.Sigma", binCols)

  # normalise new-activity-start-time-probs (nastp) row-wise if non-zero
  xastp<-t(apply(nastp, 1, function(x) {
    if (sum(x==0)!=length(x)) {
      x/sum(x)
    } else {
      x
    }
  }))

  # get the difference from expected
  xastp<-(astp-xastp)
  xastp<-t(apply(xastp,1,function(x) {
    (x-min(x))^2
  }))
  xastp[astp==0]<-0
  # normalise new-activity-start-time-probs (nastp) row-wise if non-zero
  xastp<-t(apply(xastp, 1, function(x) {
    if (sum(x==0)!=length(x)) {
      x/sum(x)
    } else {
      x
    }
  }))
  
  plan<-data.frame(Activity=factor(levels=groups), StartBin=integer(), EndBin=integer())
  bin<-1
  while(bin<=binsize) {
    probs<-as.vector(xastp[,bin]) # pick the column probabilities
    filter<-probs==0 & astp[,bin]!=0 # find cols that are zero but shouldn't be and give them a small probability
    probs[filter]<- 0.001
    # if no activity can start in this bin then progress to the next bin
    if(sum(probs==0)==length(probs)) { bin<-bin+1; next }
    # if unlikely to start some activity in this bin then progress to the next bin
    if(runif(1)<1-sum(probs)) { bin<-bin+1; next }
    # normalise if non-zero
    if (sum(probs==0)!=length(probs)) probs<-probs/sum(probs) 
    # pick a new activity for this bin
    act<-rownames(astp)[selectIndexFromProbabilities(probs)]
    # this will be the start bin for this activity  
    sbin<-bin 
    # pick duration for activity starting in this bin
    mean<-admm[act,bin]; sigma<-adms[act,bin]
    duration<-ifelse(mean==0||sigma==0, 
                     binSizeInMins, 
                     abs(round(rnorm(1,admm[act,bin],adms[act,bin]))) # WARNING: abs will change the distribution
    )
    # pick an end bin for this activity (clipped to last bin)
    ebin<-min(binsize, sbin + duration %/% binSizeInMins)
    # save it
    plan[nrow(plan)+1,]<-list(act, sbin, ebin)
    # pick the next time bin
    bin<-ebin
  }

  # Sew up Home Morning/Night activities properly
  
  # First activity should always be Home Morning, and starting in Bin1 
  if(plan[1,]$Activity != "Home Morning" && plan[1,]$StartBin!=1) {
    plan<-rbind(data.frame(Activity="Home Morning", StartBin=c(1), EndBin=c(plan[1,]$StartBin)), plan)
  }
  # If last activity is not Home Night, then make it so
  if(plan[nrow(plan),]$Activity != "Home Night") {
    plan[nrow(plan)+1,]<-list("Home Night", plan[nrow(plan),]$StartBin, binsize)
  }
  # If last activity is Home Night, then make sure it ends in the last bin
  if(plan[nrow(plan),]$Activity == "Home Night" && plan[nrow(plan),]$EndBin != binsize) {
    plan[nrow(plan),]$EndBin<-binsize
  }
  #if(plan[1,]$Activity != "Home Morning") plan<-rbind(data.frame(Activity="Home Morning", StartBin=c(1), EndBin=c(1)), plan)
  #if(plan[nrow(plan),]$Activity != "Home Night") plan[nrow(plan)+1,]<-list("Home Night", binsize, binsize)

  return(plan)
}


# binCols: vector of bin column ids that correspond to the daily time bins, e.g., 
# binCols<-3:50 # specifies that columns 3-50 correspond to 48 time bins, i.e., 30-mins each
#
# bins: data frame with the following columns:
# Activity.Group, Activity.Stat, X1..XN where N is the enumber of time bins in the day; and
#
# unique(bins$Activity.Group)
# [1] "Home Morning"           "Work"                   "Home Night"             "Pickup/Dropoff/Deliver"
# [5] "Shop"                   "Home Daytime"           "Study"                  "Personal"              
# [9] "Other"                  "Social/Recreational"    "With Someone"           "Mode Change"           
#
# unique(bins$Activity.Stat)
# "Act.Start.Time.Prob"     "Act.End.Time.Prob"       "Act.Duration.Mins.Mean"  "Act.Duration.Mins.Sigma"

# Read in the time bins
binCols<-3:50
csv<-paste0('./setup/vista_2012_18_extracted_activities_weekday_time_bins.csv.gz')
gz1 <- gzfile(csv,'rt')
bins<-read.csv(gz1,header = T,sep=',',stringsAsFactors = F,strip.white = T)
bins[is.na(bins)]<-0 # convert NAs to 0s
close(gz1)

# Make a copy of the bins to track progress
newbins<-data.frame(bins)
newbins[,binCols]<-0
binIndexOffset<-head(binCols,1)-1
for(i in 1:5000) {
  printProgress(i,'.')
  plan<-createNewPlan(bins, newbins, binCols)
  # record progress
  for(j in 1:nrow(plan)) {
    srow<-newbins$Activity.Group==plan[j,]$Activity & newbins$Activity.Stat=="Act.Start.Time.Prob"
    scol<-binIndexOffset+plan[j,]$StartBin
    erow<-newbins$Activity.Group==plan[j,]$Activity & newbins$Activity.Stat=="Act.End.Time.Prob"
    ecol<-binIndexOffset+plan[j,]$EndBin
    newbins[srow, scol]<-newbins[srow, scol] + 1
    newbins[erow, ecol]<-newbins[erow, ecol] + 1
  }
}


groups<-getActivityGroups(bins)
stats<-c("Act.Start.Time.Prob", "Act.End.Time.Prob") #unique(bins$Activity.Stat)
binsize<-length(binCols)
binSizeInMins<-floor(60*24)/binsize
pp<-data.frame(matrix(0, nrow = binsize*length(groups), ncol = 5))
colnames(pp)<-c("Activity", "Stat", "Bin", "Expected", "Actual")
rowid<-1
for (act in groups) {
  for (stat in stats) {
    e<-as.numeric(bins[bins$Activity.Group==act & bins$Activity.Stat==stat,binCols])
    e<-e/sum(e)
    a<-as.numeric(newbins[newbins$Activity.Group==act & newbins$Activity.Stat==stat,binCols])
    a<-a/sum(a)
    shift<-(rowid-1)*binsize
    pp[shift+(1:binsize),"Activity"]<-rep(act,binsize)
    pp[shift+(1:binsize),"Stat"]<-rep(stat,binsize)
    pp[shift+(1:binsize),"Bin"]<-1:binsize
    pp[shift+(1:binsize),"Expected"]<-e
    pp[shift+(1:binsize),"Actual"]<-a
    rowid<-rowid+1
  }
}

suppressMessages(library(ggplot2))
gg<-ggplot(pp[pp$Stat=="Act.Start.Time.Prob",], aes(x=Expected, y=Actual)) + 
  geom_abline(aes(colour='red', slope = 1, intercept=0)) +
  geom_point(aes(fill=Bin), colour = 'blue', size=3, shape=21, alpha=0.9) + guides(colour=FALSE) +
  #theme(legend.position="none") + theme(plot.title = element_text(hjust = 0.5)) +
  ggtitle(paste0('Activity Start Time Probabilities in ',binSizeInMins,'-Min Bins')) +
  facet_wrap(~Activity, scales="free", ncol=2)
ggsave("analysis.act.start.pdf", gg, width=8.5, height=11)
gg<-ggplot(pp[pp$Stat=="Act.End.Time.Prob",], aes(x=Expected, y=Actual)) + 
  geom_abline(aes(colour='red', slope = 1, intercept=0)) +
  geom_point(aes(fill=Bin), colour = 'blue', size=3, shape=21, alpha=0.9) + guides(colour=FALSE) +
  #theme(legend.position="none") + theme(plot.title = element_text(hjust = 0.5)) +
  ggtitle(paste0('Activity End Time Probabilities in ',binSizeInMins,'-Min Bins')) +
  facet_wrap(~Activity, scales="free", ncol=2)
ggsave("analysis.act.end.pdf", gg, width=8.5, height=11)


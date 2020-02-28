options(scipen=999) # disable scientific notation for more readible filenames with small sample sizes

selectIndexFromProbabilities <-function(vv) {
  vv<-vv/sum(vv) # normalise to 1
  v<-cumsum(vv) # cumulative sum to 1
  roll<-runif(1)
  select<-match(TRUE,v>roll) # pick the first col that is higher than the dice roll
  return(select)
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
  astp <- getProbabilitiesMatrix(bins, "Act.Start.Time.Prob", binCols)
  admm <- getProbabilitiesMatrix(bins, "Act.Duration.Mins.Mean", binCols)
  adms <- getProbabilitiesMatrix(bins, "Act.Duration.Mins.Sigma", binCols)

  nastp <- getProbabilitiesMatrix(newbins, "Act.Start.Time.Prob", binCols)
  nastp <- getProbabilitiesMatrix(newbins, "Act.Start.Time.Prob", binCols)
  nadmm <- getProbabilitiesMatrix(newbins, "Act.Duration.Mins.Mean", binCols)
  nadms <- getProbabilitiesMatrix(newbins, "Act.Duration.Mins.Sigma", binCols)
  
    
  plan<-data.frame(Activity=factor(levels=groups), StartBin=integer(), EndBin=integer())
  bin<-1
  while(bin<=binsize) {
    # get the expected and actual probabilities of activities starting in this bin
    eprobs<-as.vector(astp[,bin])
    nprobs<-as.vector(nastp[,bin])
    if (sum(nprobs==0)!=length(nprobs)) nprobs<-nprobs/sum(nprobs) # normalise if non-zero
    # calculate the error (negative values indicate oversampled probabilities)
    probs<-eprobs-nprobs
    probs<-(probs-min(probs))^2
    probs[1]<-0 # Make the probability of selecting "Home Morning" zero
    #probs[probs<0]<-0 # remove the negative values (we want to try and avoid sampling those)
    #probs[probs>0]<-probs[probs>0]+1 # just to give others a non-zero probability (so one of them does get sampled)
    # if no activity can start in this bin then progress to the next bin
    if(sum(probs==0)==length(probs)) { bin<-bin+1; next }
    # pick a new activity for this bin
    act<-ifelse(nrow(plan)==0, "Home Morning", rownames(astp)[selectIndexFromProbabilities(probs)])
    if(bin==binsize) act<-"Home Night"
    # pick a start bin for this activity  
    sbin<-bin # selectIndexFromProbabilities(as.vector(astp[act,]))
    # pick duration for activity starting in this bin
    mean<-admm[act,bin]; sigma<-adms[act,bin]
    duration<-ifelse(mean==0||sigma==0, 
                     binSizeInMins, 
                     abs(round(rnorm(1,admm[act,bin],adms[act,bin]))) # WARNING: abs will change the distribution
    )
    # pick an end bin for this activity
    ebin<-ifelse(act=="Home Night", binsize, min(binsize-1, sbin + duration %/% binSizeInMins))
    # save it
    plan[nrow(plan)+1,]<-list(act, sbin, ebin)
    # pick the next time bin
    bin<-ebin+1
  }
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
for(i in 1:1000) {
  if((i-1)%%100==0) cat(paste0("\n", Sys.time(), " | "))
  cat(".")
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
binsize<-length(binCols)
binSizeInMins<-floor(60*24)/binsize
pp<-data.frame(matrix(0, nrow = binsize*length(groups), ncol = 4))
colnames(pp)<-c("Activity", "Bin", "Expected", "Actual")
rowid<-1
for (act in groups) {
  # Home Morning activity end times
  e<-as.numeric(bins[bins$Activity.Group==act & bins$Activity.Stat=="Act.Start.Time.Prob",binCols])
  e<-e/sum(e)
  a<-as.numeric(newbins[newbins$Activity.Group==act & newbins$Activity.Stat=="Act.Start.Time.Prob",binCols])
  a<-a/sum(a)
  shift<-(rowid-1)*binsize
  pp[shift+(1:binsize),"Activity"]<-rep(act,binsize)
  pp[shift+(1:binsize),"Bin"]<-1:binsize
  pp[shift+(1:binsize),"Expected"]<-e
  pp[shift+(1:binsize),"Actual"]<-a
  rowid<-rowid+1
}

suppressMessages(library(ggplot2))
gg<-ggplot(pp, aes(x=Expected, y=Actual)) + 
  geom_abline(aes(colour='red', slope = 1, intercept=0)) +
  geom_point(colour = 'blue', fill='blue', size=3, shape=21, alpha=0.3) + 
  theme(legend.position="none") + theme(plot.title = element_text(hjust = 0.5)) +
  ggtitle(paste0('Activity Start Time Probabilities in ',binSizeInMins,'-Min Bins')) +
  facet_wrap(~Activity, scales="free", ncol=2)
ggsave("analysis.act.start.pdf", gg, width=8.5, height=11)


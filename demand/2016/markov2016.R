suppressPackageStartupMessages(library(markovchain))
source('vista2016.R')

create_markov_chain_model<-function(modelname, activities_csv_gz) {
  gz1 <- gzfile(activities_csv_gz,'rt')
  orig<-read.csv(gz1,header = T,sep=',',stringsAsFactors = F,strip.white = T)
  close(gz1)
  
  activities<-split_home_activity(orig)

  # Get list of activities per person
  activity.chains<-activities%>%
    group_by(Person,Count) %>% 
    dplyr::summarise(Activity.Chain = list(unique(Activity.Group)))
  
  states<-unique(sort(activities$Activity.Group))
  probs<-data.frame(
    matrix(0, nrow=length(states), ncol=length(states)),
    row.names = states)
  colnames(probs)<-states
  
  for (j in 1:length(activity.chains$Activity.Chain)) {
    sq<-activity.chains[j,]$Activity.Chain[[1]]
    if(length(sq)>1) {
      sq1<-sq[min(2,length(sq)):length(sq)]
      sq<-sq[1:length(sq)-1]
      probs[sq,sq1]<-probs[sq,sq1]+activity.chains[j,]$Count
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

# Generates a markov chain starting with "Home Morning", 
# using the given model, and for the given SA1 (not currently used)
generateActivityChain<-function(mc, SA1) {
  v<-c("Home Morning",rmarkovchain(n=100,mc,t0="Home Morning")) # chain of requested length
  idx<-match("Home Night", v); # find index of last activity 
  v<-v[seq(1,idx)] # remove repeating last activity
  return(v)
}

# internal function to replace activity tags with location tags
replaceActivityWithLocationTags<-function (tc) {
  # convert activity-based tags to location-based tags (from SA1_attributes.sqlite) being: 
  # Home* -> home
  # Work -> work
  # Study -> education
  # Shop -> commercial
  # Personal -> commercial
  # Social/Recreational -> commercial,park
  # Pickup/Dropoff/Deliver -> work,education,commercial,park (but not home)
  # Other -> work,education,commercial,park (but not home)
  tc<-replace(tc, tc=="Home Morning", "home")
  tc<-replace(tc, tc=="Home Daytime", "home")
  tc<-replace(tc, tc=="Home Night", "home")
  tc<-replace(tc, tc=="Work", "work")
  tc<-replace(tc, tc=="Study", "education")
  tc<-replace(tc, tc=="Shop", "commercial")
  tc<-replace(tc, tc=="Personal", "commercial")

  # KISS: replace 'With Someone' with Other for now
  tc<-replace(tc, tc=="With Someone", "Other")
  # KISS: assuming Social/Recreational is equally likely to occur in commercial or park locations ; improve later on
  tc<-as.vector(sapply(tc, function(x) replace(x, x=="Social/Recreational", sample(c("commercial","park"), 1))))
  # KISS: assuming Pickup/Dropoff/Deliver is equally likely to occur in any location; improve later on
  tc<-as.vector(sapply(tc, function(x) replace(x, x=="Pickup/Dropoff/Deliver", sample(c("work","education","commercial","park"), 1))))
  # KISS: assuming Other is equally likely to occur in any location; improve later on; improve later on
  tc<-as.vector(sapply(tc, function(x) replace(x, x=="Other", sample(c("work","education","commercial","park"), 1))))
  return(tc)
}


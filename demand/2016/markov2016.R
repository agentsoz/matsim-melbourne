suppressPackageStartupMessages(library(markovchain))

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


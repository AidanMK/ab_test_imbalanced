########################################
#
#    Analyze mobile app A/B test 
#
########################################


library(plyr) 
library(dplyr) 
library(doBy)
library(ggplot2)
library(lfe)
#library(summarytools)

rm(list=ls())

mydir <- "C:\\Users"

setwd(mydir)



##############################
####  Experiment start date   
##############################

startdate <- as.Date("2019-02-06", format = "%Y-%m-%d")



##############################
####  List of data tables   
##############################

csvtablelist <- 
   c( "table1_user_minutes"
     ,"table2_user_arm"
     ,"table3_user_minutes_pre"
     ,"table4_user_characteristics"
    )



##############################
#### Import and check data  
##############################

#### Import data

importData <- function(csvfile) {
  
    df <- read.csv(file=paste0(csvfile,".csv")
                   , header=TRUE, sep=",") 
    return( df )
}  


#### Check data
  
checkData <- function() {
  
  # Check unique identifiers

  for (minutestable in c("table1_user_minutes","table3_user_minutes_pre")) {
    
    temp <- eval(parse(text=minutestable))
    unique <- data.frame(unique(subset(temp, keep=c("userid","dt"))))
    
    if (nrow(temp) != nrow(unique)) {
      print(paste0("Error: ", minutestable, " not uniquely identified by userid and dt"))      
    }      
    else {
      print(paste0(minutestable, " uniquely identified by userid and dt"))      
    }
  }  
  
  for (usertable in c("table2_user_arm","table4_user_characteristics")) {

    temp <- eval(parse(text=usertable))
    unique <- data.frame(unique(subset(temp, keep="userid")))

    if (nrow(temp) != nrow(unique)) {
      print(paste0("Error: ", usertable, " not uniquely identified by userid"))      
    }      
    else {
      print(paste0(usertable, " uniquely identified by userid"))      
    }          
  }
  
  if (nrow(table2_user_arm)!=nrow(table4_user_characteristics)) {
    print("Error: Different number of users")
  } 

  # Check variables 

  print(table(table4_user_characteristics$gender))
  print(table(table4_user_characteristics$user_type))
  print(table(table2_user_arm$treat_arm))    
  print(table(table2_user_arm$dt))      
}  

checkData()

 


#### Append and merge data 

mergeUserData <- function() {

  # Merge user data 

  temp2 <- join( subset(table2_user_arm
                      , select = c("userid", "treat_arm", "signup_date"))
               , table4_user_characteristics
               , by = "userid" 
               , type = "full", match = "all")

  # Format date 

  temp2$signup_day <- as.Date(temp2$signup_date, format = "%Y-%m-%d")
  temp2$signup_year <- as.numeric(format(temp2$signup_day, "%Y"))  
  temp2 <- temp2 %>% mutate( signup_year = 
                               ifelse(signup_year < 2012, 2012, signup_year))

  # Number of days in pre-period sample
  
  temp2 <- temp2 %>% mutate( days_pre = as.numeric(startdate - signup_day))
  
  return(temp2)
}

minutesData <- function(userdataset) {

  # Append minutes data 
  
  table1_user_minutes$post <- 1
  table3_user_minutes_pre$post <- 0
  temp1 <- rbind(table1_user_minutes, table3_user_minutes_pre)
  
  print(nrow(temp1))
  
  temp1$day <- as.Date(temp1$dt, format = "%Y-%m-%d")
  
  join_data <- join(temp1
                    , subset(userdata
                             ,select=c("userid","treat_arm","user_type","gender"))
                    , by = "userid" 
                    , type = "left", match = "all")      
  
  print(nrow(join_data))  
  
  return(join_data)      
}
  

### Remove outliers 

removeOutliers <- function(dataset) {

  # Summarize minutes 

  print(summary(dataset$active_mins))
  print(nrow(dataset))
  
  # If user not in minutes data, minutes = 0 

  dataset <- dataset %>% mutate( 
              active_mins = ifelse(is.na(active_mins)==T, 0, active_mins ) )

  # Minutes should never be negative 

  dataset <- subset(dataset, active_mins >= 0)

  # Upper limit on minutes per day

  max_minutes <- 60*24
  dataset <- subset(dataset, active_mins <= max_minutes)

  print(nrow(dataset))  
  return(dataset)
}

  

################################
####  Check balance
################################

checkBalance <- function() {
  
  ### Check if treatment randomly assigned across users       
  
  # Gender
  
  print(summaryBy( treat_arm ~ gender
                   , data = userdata, FUN = mean ))        
  covartest <- glm(treat_arm ~  gender
                   ,data = userdata  
                   ,family = "binomial")
  print(summary(covartest))
  
  # User types
  
  print(summaryBy( treat_arm ~ user_type
                   , data = userdata, FUN = mean ))            
  covartest <- glm(treat_arm ~  user_type
                   ,data = userdata  
                   ,family = "binomial")
  print(summary(covartest))    
  
  # Sign-up year 
  
  print(summaryBy( treat_arm ~ as.factor(signup_year)
                   , data = userdata, FUN = mean ))                
  covartest <- glm(treat_arm ~  as.factor(signup_year)
                   ,data = userdata  
                   ,family = "binomial")
  print(summary(covartest))        
  
}

checkBalance()  




################################
####  Visualization
################################

### Check parallel trends          

minutesByDay <- function(minsdataset, userdataset) {
  
  # Number of users who had signed up by each date
  
  userdataset$signups <- 1
  signups_treated <- summaryBy( signups ~ signup_day + treat_arm
                                , data = subset(userdataset, treat_arm==1)
                                , FUN = sum)
  signups_treated$total <- cumsum(signups_treated$signups.sum)
  
  signups_control <- summaryBy( signups ~ signup_day + treat_arm
                                , data = subset(userdataset, treat_arm==0)
                                , FUN = sum)
  signups_control$total <- cumsum(signups_control$signups.sum)  
  
  signups <- subset(rbind(signups_treated,signups_control), 
                    select = c("signup_day","treat_arm","total"))
  names(signups) <- c("day","treat_arm","total")
  
  # Total number of minutes per day 
  
  mins_by_day <- summaryBy( 
    active_mins ~ treat_arm + day + post 
    , data = minsdataset, FUN = sum )     
  
  join_data <- join(mins_by_day, signups
                    , by = c("day","treat_arm"), type="left" )
  
  join_data <- arrange(join_data, treat_arm, day)
  
  # Users per day
  
  n_treated <- nrow(subset(userdataset, treat_arm==1))
  n_control <- nrow(subset(userdataset, treat_arm==0))    
  
  for (i in seq(1:20)) {
    join_data$total <- ifelse(join_data$post==0 
                              & is.na(join_data$total)==T 
                              & join_data$treat_arm==lag(join_data$treat_arm), 
                              lag(join_data$total), join_data$total)
  }
  
  join_data$n_users <- ifelse(join_data$treat_arm==1, n_treated, n_control) 
  join_data$n_users <- ifelse(join_data$post==0 & is.na(join_data$total)==F, 
                              join_data$total, join_data$n_users )
  
  # Average minutes per user, per day 
  
  join_data$mins_per_user <- join_data$active_mins.sum / join_data$n_users
  
  return(join_data)            
}

parallelTrendsGraph <- function(dataset, yvar, graphname) {    
  
  g<-ggplot() +
    geom_line(data = subset(dataset, treat_arm==0), 
              aes(x = day, 
                  y = eval(parse(text=yvar)), color = "Control")) +
    geom_line(data = subset(dataset, treat_arm==1), 
              aes(x = day, 
                  y = eval(parse(text=yvar)), color = "Treated")) +
    ylab("Average minutes per user") +
    labs(color = "Group") +
    geom_vline(xintercept = startdate, linetype = "dotted") +
    geom_hline(yintercept = 0, linetype = "solid") +   
    xlab("Date")     
  ggsave(paste0(graphname,".pdf"), height = 5, width = 8) 
  g  
}  

parallelTrendsGraph(mins_by_day, "mins_per_user", "trends_all")




################################
####  Difference-in-differences
################################

### Collapse data  

collapseData <- function(dataset) {
  
  # Sum to user-post level
  
  sum_minutes <- summaryBy( active_mins ~ userid + post, 
                            data = dataset, FUN = sum )
  
  # Fill in data to get balanced panel
  
  time_df <- data.frame(unique(subset(sum_minutes, is.na(post)==F, select = "post")))
  userid_df <- subset(table4_user_characteristics, select = "userid")    
  full_df <- merge(time_df, userid_df, all = TRUE)    
  sum_minutes_fill <- join(full_df, sum_minutes
                           , by = c("userid","post") 
                           , type = "left", match = "all")      
  sum_minutes_fill <- sum_minutes_fill %>% 
    mutate( active_mins.sum = ifelse(is.na(active_mins.sum)==T,0,active_mins.sum) )  
  
  # Merge in user characteristics
  
  join_data <- join(sum_minutes_fill, userdata, by = "userid" 
                    , type = "full", match = "all")    
  
  join_data <- join_data %>% 
    mutate( treatpost = post*treat_arm)
  
  # Calculate average minutes per day 
  
  numdayspre <- nrow(unique(subset(dataset,post==0,select = "day")))    
  numdayspost <- nrow(unique(subset(dataset,post==1,select = "day")))    
  
  join_data$days_in_sample <- numdayspost
  
  join_data <- join_data %>% 
    mutate(
      days_in_sample = ifelse(post==0,numdayspre,days_in_sample),
      days_in_sample = ifelse(post==0 & days_pre<numdayspre,days_pre,days_in_sample),
      avg_mins = active_mins.sum/days_in_sample )
  
  # Flag large values using SD
  
  mu_mins <- mean(join_data$avg_mins)
  sd_mins <- sd(join_data$avg_mins)
  
  join_data <- join_data %>% 
    mutate( outlier3 = (avg_mins > mu_mins + 3*sd_mins
                        | avg_mins < mu_mins - 3*sd_mins), 
            outlier4 = (avg_mins > mu_mins + 4*sd_mins
                        | avg_mins < mu_mins - 4*sd_mins) )
  print(table(join_data$outlier3))    
  print(table(join_data$outlier4))    
  
  return(join_data)  
}

testDifDif <- function(dataset) {    

  dataset <- dataset %>% mutate(logavg_mins = log(avg_mins+1))  
  
  # No fixed effects, cluster standard errors
  
  difdiftest <- felm(avg_mins ~ treat_arm + post + treatpost
                     | 0 | 0 | userid,  
                     data = dataset)
  print(summary(difdiftest))         
  print(confint(difdiftest, level = 0.95))  
  
  difdiftest <- felm(logavg_mins ~ treat_arm + post + treatpost
                     | 0 | 0 | userid,  
                     data = dataset)
  print(summary(difdiftest))         
  print(confint(difdiftest, level = 0.95))    
  
  # User fixed effects, cluster standard errors
  
  difdiftest <- felm(avg_mins ~ treat_arm + post + treatpost
                     | userid | 0 | userid,  
                     data = dataset)
  print(summary(difdiftest))         
  print(confint(difdiftest, level = 0.95))  
}

testDifDif(avgmindata)  



        
    
##############################
####  Execute functions 
##############################

  for (file in csvtablelist) {
  
    temp <- importData(file)
    assign(file, temp)
    rm(temp) 
  }  

  checkData()

  userdata <- mergeUserData()

  minutesdata <- minutesData(userdata)

  minutesdata <- removeOutliers(minutesdata)

  checkBalance()  

  mins_by_day <- minutesByDay(minutesdata, userdata)  
  
  parallelTrendsGraph(mins_by_day, "mins_per_user", "trends_all")

  avgmindata <- collapseData(minutesdata)  
  
  testDifDif(avgmindata)  
  


    
##############################  
### Differences in effects
##############################
    
  # By gender
  
  testdata <- avgmindata
  testdata <- testdata %>% mutate (
    postgroup = ifelse(gender=="male",1,0)*post,
    treatpostgroup = ifelse(gender=="male",1,0)*treatpost
  )
  difDifEffects(testdata)    

  # Treatment effects by user type 
  
  for (userstring in c("poster","new_user","viewer","non_viewer")) {
    
    print(userstring)
    testdata <- subset(avgmindata, user_type==userstring)
    testDifDif(testdata)        
  }  
  
  # Test difference by user type
  
  for (userstring in c("poster","new_user","viewer")) {
    
    print(userstring)
    
    testdata <- subset(avgmindata, user_type=="non_viewer" | user_type==userstring)
    testdata <- testdata %>% mutate (
      postgroup = ifelse(user_type==userstring,1,0)*post,
      treatpostgroup = ifelse(user_type==userstring,1,0)*treatpost
    )
    difDifEffects(testdata)        
  }
  

  #Parallel trends: viewers and posters
  
  subsetusers <- subset(userdata, 
                        (user_type=="viewer" | user_type=="poster") )
  subsetminutes <- subset(minutesdata, 
                          (user_type=="viewer" | user_type=="poster") )  
  mins_by_day <- minutesByDay(subsetminutes, subsetusers)    
  parallelTrendsGraph(mins_by_day, "mins_per_user", "trends_viewer")  
  
  #Parallel trends: non-viewers 
  
  subsetusers <- subset(userdata, (user_type=="non_viewer") )
  subsetminutes <- subset(minutesdata, (user_type=="non_viewer") )  
  mins_by_day <- minutesByDay(subsetminutes, subsetusers)    
  parallelTrendsGraph(mins_by_day, "mins_per_user", "trends_nonviewer")    
  
  #Parallel trends: new users 
  
  subsetusers <- subset(userdata, (user_type=="new_user") )
  subsetminutes <- subset(minutesdata, 
                          (user_type=="new_user" & day >= as.Date("2019-01-15", format = "%Y-%m-%d")) )  
  mins_by_day <- minutesByDay(subsetminutes, subsetusers)    
  parallelTrendsGraph(mins_by_day, "mins_per_user", "trends_newuser")    
    
  
  
  
# install.packages("RJDBC")
#  install.packages("rJava")
require(RODBC)
library(rJava)
R.Version()
Sys.setenv(JAVA_HOME='C:/app/oracle/Client21c/jdk')
cn  <- odbcConnect("oraanalysis",uid = "system",
                   pwd = "Dr@gons9")

dataframe <- sqlQuery(cn, "
 SELECT *
 FROM
 dba_users")
head(dataframe)
odbcClose(cn)

ibrary(RODBC)
library(dplyr)
library(dbplyr)
library(lubridate)

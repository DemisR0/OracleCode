// Databricks notebook source
// account informations
val storage_account_name = "stgdl"
var storage_account_access_key: String = "uXRX4UlxZYNjVB3gxAznJLNm+4OnOvutEhsb0mZkv/tFGEqA3bzZWRNoGQm8oGxDUB5BnU7bZ4GhM4zBijRWAg==" //.replace("/", "%2F")
val container_name = "job"
val mount_point_source = "/mnt/awrsource"
val source="wasbs://"+container_name+"@"+storage_account_name+".blob.core.windows.net/awr-inputs"
val conf_key = "fs.azure.account.key."+storage_account_name+".blob.core.windows.net"
val destination="wasbs://"+container_name+"@"+storage_account_name+".blob.core.windows.net/awr-to-csv-out"
val mount_point_dest = "/mnt/awrdest"

// COMMAND ----------

spark.conf.set("fs.azure.account.key.stgdl.blob.core.windows.net","uXRX4UlxZYNjVB3gxAznJLNm+4OnOvutEhsb0mZkv/tFGEqA3bzZWRNoGQm8oGxDUB5BnU7bZ4GhM4zBijRWAg==")
dbutils.fs.mount(
  source = mount_point_source,
  mountPoint = mount_point,
  extraConfigs = Map(conf_key -> storage_account_access_key))


// COMMAND ----------

spark.conf.set("fs.azure.account.key.stgdl.blob.core.windows.net",storage_account_access_key)
dbutils.fs.mount(
  source = destination,
  mountPoint = mount_point_dest,
  extraConfigs = Map(conf_key -> storage_account_access_key))


// COMMAND ----------

val mount_point_source = "/mnt/awrsource"
val rdd = sc.wholeTextFiles(mount_point_source+"/*.html")

// COMMAND ----------

rdd.take(1)

// COMMAND ----------

// getrid of html tags
val htmlToCsvLine = (s: String) => { s.replaceAll(",","").replaceAll("""<\/td><\/tr>""","").replaceAll("""<\/td>""",",").replaceAll("<([^>]+)>","") }
// spark.udf.register("htmlToCsvLine", htmlToCsvLine)

// COMMAND ----------

// build rdd with full key
val named_rdd = rdd.values.map( f_content => { 
                            val shead = f_content.split('\n')(0)
                            val ahead = shead.substring(shead.indexOf("<title>")+7,shead.indexOf("</title>")).split(":")
                            val f_name = ahead(1).split(",")(0).trim()+"_"+ahead(2).split(",")(0).trim()+"_"+ahead(3).split(",")(0).trim()
                            val astrings=f_content.split("<table ")
                            (f_name,astrings)
                            })

// COMMAND ----------

// awr tables headers
val dbInfoRegExp = ".+DB Name.+Inst num.+Startup Time".r
val serverInfoRegExp = ".+Host Name.+Platform.+CPUs.+Cores.+Sockets.+".r
val snapInfoRegExp = ".+Snap Id.+Snap Time.+Sessions.+Cursors/Session.+".r
val hostCpuHistoBeginRegExp = "Snap Time.+Load.+%busy.+%user.+%sys.+%idle.+%iowait.+".r
val hostCpuHistoEndRegExp = ".+Back to Wait Events Statistics.+".r
val memoryStatsRegExp = ".*Begin.+End.+Host Mem.+SGA use.+PGA use.+".r
val cacheSizeRegExp = ".*Cache Sizes.*".r
val nonKeyStatsRegExp = ".+This table displays non-key Instance activity statistics.+".r // ".+Statistic.+Total.+Second.+Trans.+".r
val instActivityStats = ".+This table displays Instance activity statistics.+".r
val lastTableRegExp =".+Tablespace IO Stats.+".r

// stats
val phyReadTotBytesRegExp = "physical read total bytes$".r
val phyWritTotBytesRegExp = "physical write total bytes$".r
val netSqlOutRegExp = "bytes sent via SQL\\*Net to client".r
val readIOReqRegExp = "read IO requests.+".r
val writIOReqRegExp = "write IO requests".r
val cellPhyIOBytesElForPredOfflRegExp = "cell physical IO bytes eligible for predicate offload".r
val cellPhyIOBytSvdByStgIdxRegExp = "cell physical IO bytes saved by storage index".r
val cellPartWritInFlashCachRegExp = "cell partial writes in flash cache".r
          // "<tr>.+cell physical IO interconnect bytes.+</tr>".r
          // "<tr>.+cell IO uncompressed bytes.+</tr>".r
          // "<tr>.+redo blocks written.+</tr>".r
val statsRegExp = "^.+ \\w+,\\d+,\\d+\\.\\d+,\\d+\\.\\d+"
val statsNameFilterRegExp = "physical read total bytes.+|physical write total bytes.+|bytes \\w+ via SQL\\*Net \\w+ client.+|read IO requests.r+|write IO requests.r+|cell physical IO bytes eligible for predicate offload.+|cell physical IO bytes saved by storage index.+|cell partial writes in flash cache.+|".r

// COMMAND ----------

// test 
val blocRegExp = "<tr>.+physical read tutut otal bytes.+</tr>".r   
named_rdd.map( table => {
    var x = 0
    var exit = 0
    var strOutput = ""
    while ( ( lastTableRegExp.findAllIn(table._2(x)).length < 1 ) && ( x < table._2.length - 1 ) && ( exit == 0 ) ) {
      if ( otherStatsRegExp.findFirstIn(table._2(x)).getOrElse("").length > 0 ) {
          strOutput = table._2(x)
          exit = 1
      }
      x = x + 1
    }
  strOutput
} ).take(2).map(table => {
     htmlToCsvLine(blocRegExp.findFirstIn(table).getOrElse(",")).split(",")
   })
// named_rdd.take(1).map(row => row._2(38).length)
// named_rdd.take(2).map(table => { table._2.length })

// COMMAND ----------

val row = named_rdd.take(1)

// COMMAND ----------

val nonKeyStats = htmlToCsvLine(row(0)._2(38)).split("\n").toList.filter( line => line.matches(statsRegExp) ).filter ( line => statsNameFilterRegExp.pattern.matcher(line).matches ).map(line => {
          val linesplit = line.split(",")
          (linesplit(0),linesplit(1)) }).filter( line => cellPartWritInFlashCachRegExp.pattern.matcher(line._1).matches )
nonKeyStats.map(line => line._1).foreach(println)

// nonKeyStats.filter( line => cellPhyIOBytesElForPredOfflRegExp.pattern.matcher(line._1).matches )(0)._2 //+ "," + nonKeyStats.filter( line => cellPhyIOBytSvdByStgIdxRegExp.pattern.matcher(line._1).matches )(0)._2 + ","  + nonKeyStats.filter( line => cellPartWritInFlashCachRegExp.pattern.matcher(line._1).matches )(0)._2

// COMMAND ----------

val regexPourri = "bytes.+via.+SQL\\+client.+".r
val test = htmlToCsvLine(row(0)._2(38)).split("\n").toList.filter( line => line.matches(statsRegExp) ).filter ( line => regexPourri.pattern.matcher(line).matches ).map(line => {
              val linesplit = line.split(",")
              (linesplit(0),linesplit(1)) })
//test.filter( line => regexPourri.pattern.matcher(line._1).matches )(0)._2

// COMMAND ----------

// get data and create csv line
val csv_rdd = named_rdd.map( table => {
    var x = 0
    var exit = 0
    var strOutput = ""
    var temp : Option[String] = None
    while ( ( lastTableRegExp.findAllIn(table._2(x)).length < 1 ) && ( x < table._2.length - 1 ) && ( exit == 0 ) ) {
      if ( dbInfoRegExp.findAllIn(table._2(x)).length > 0 ) strOutput = strOutput + htmlToCsvLine(table._2(x)).split("\n")(2)
      if ( serverInfoRegExp.findAllIn(table._2(x)).length > 0 ) strOutput = strOutput + "," + htmlToCsvLine(table._2(x)).split("\n")(2).replace(" ","") // be carrefull if server meme is more than 1 TB 
      if ( snapInfoRegExp.findAllIn(table._2(x)).length > 0 ) {
        val lines = htmlToCsvLine(table._2(x).replace(",","")).split("\n") // supress , in numbers before creating csv
        val beginSnap = lines(2).split(",")
        val endSnap = lines(3).split(",")
        val elapsed = lines(4).split(",")(2).replace(" (mins)","").trim()
        val dbtime = lines(5).split(",")(2).replace(" (mins)","").trim()
        strOutput = strOutput + "," + beginSnap(1) + "," + beginSnap(2) + "," + endSnap(1) + "," + endSnap(2) + "," + elapsed + "," + dbtime
      }
      if ( memoryStatsRegExp.findAllIn(table._2(x)).length > 0 ) {
        val lines = htmlToCsvLine(table._2(x+1).replace(",","")).split("\n")
        val sgaUseB = lines(3).split(",")(1).trim().toFloat  // .replace(".","")
        val sgaUseE = lines(3).split(",")(2).trim().toFloat
        val pgaUseB = lines(4).split(",")(1).trim().toFloat
        val pgaUseE = lines(4).split(",")(2).trim().toFloat
        
        strOutput = strOutput + "," + sgaUseB.max(sgaUseE) + "," + pgaUseB.max(pgaUseE)
      }
      
      if ( nonKeyStatsRegExp.findFirstIn(table._2(x)).getOrElse("").length > 0 || instActivityStats.findFirstIn(table._2(x)).getOrElse("").length > 0 ) {
        val nonKeyStats = htmlToCsvLine(table._2(x)).split("\n").toList.filter( line => line.matches(statsRegExp) ).filter ( line => statsNameFilterRegExp.pattern.matcher(line).matches ).map(line => {
          val linesplit = line.split(",")
          (linesplit(0),linesplit(1)) })
        
        val phyReadTotBytes = nonKeyStats.filter( line => phyReadTotBytesRegExp.pattern.matcher(line._1).matches )(0)._2
        val phyWritTotBytes = nonKeyStats.filter( line => phyWritTotBytesRegExp.pattern.matcher(line._1).matches )(0)._2
        val netSqlOutBytes = nonKeyStats.filter( line => netSqlOutRegExp.pattern.matcher(line._1).matches )(0)._2
        // val readIOReq = nonKeyStats.filter( line => readIOReqRegExp.pattern.matcher(line._1).matches )(0)._2
        //val writIOReq = nonKeyStats.filter( line => writIOReqRegExp.pattern.matcher(line._1).matches )(0)._2
        
        var cellIOStats = ""
        if ( nonKeyStats.length > 3) {
          cellIOStats = { nonKeyStats.filter( line => cellPhyIOBytesElForPredOfflRegExp.pattern.matcher(line._1).matches )(0)._2 + "," + nonKeyStats.filter( line => cellPhyIOBytSvdByStgIdxRegExp.pattern.matcher(line._1).matches )(0)._2 + ","  + nonKeyStats.filter( line => cellPartWritInFlashCachRegExp.pattern.matcher(line._1).matches )(0)._2 }
        } else 
        { cellIOStats = ",," }
        
        strOutput = strOutput + "," + phyReadTotBytes + "," + phyWritTotBytes + "," + netSqlOutBytes + "," + cellIOStats
          exit = 1
      }
        
      x = x + 1
    }
    (table._1,strOutput)
} ).take(2)

// COMMAND ----------

named_rdd.map( table => {
    val x = 0
    for { x <- 0 until ( table._1(x) == ".*Tablespace IO Stats.*" ) }
      {
        if ( table._1(x).indexOf("""<([^>]+)>DB Name<([^>]+)>Inst num<([^>]+)>Startup Time""") >= 0 ) println("got it") // htmlToCsvLine(v[x+1])
      }
}
              ).take(1)

// COMMAND ----------

// write data to file
val fileName = mount_point_dest + "/awr_to_csv_result.parquet"
csv_rdd.saveAsTextFile(fileName)

// COMMAND ----------



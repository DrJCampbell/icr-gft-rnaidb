#
#
#
#

#setwd("~/Desktop")

#x <- read.table(
#	file="Breast_HCC1187_KS_TS_DR_CGC_384_template_2014-09-23_summary.txt",
#	sep="\t",
#	header=TRUE,
#	)

Zscreen_qc <- function(
			  datapath,
		      summaryName,
              ReportdirName,
		      controls_qc,
		      corr_coeff
		      ){
		      
datapath=paste(datapath,"/", sep="")

summary <- paste(datapath, summaryName, sep="")

summary_file <- read.table(
 				file= summary, 
 				sep="\t",
			    header=TRUE,
 				)
 				
sicon1.z <- (names.arg=summary_file$score)[which(summary_file$wellAnno == "sicon1")] 

sicon2.z <- (names.arg=summary_file$score)[which(summary_file$wellAnno == "sicon2")] 

allstar.z <- (names.arg=summary_file$score)[which(summary_file$wellAnno == "allstar")] 

plk1.z <- (names.arg=summary_file$score)[which(summary_file$wellAnno == "siplk1")] 

qc_file <- paste(datapath, controls_qc, sep="")

if (!file.exists(qc_file)){

  png(file=qc_file, width=800, height=500)

  boxplot(
	sicon1.z,
	sicon2.z,
	allstar.z,
	plk1.z,
	names=c(
	  "sicon1",
	  "sicon2",
	  "allstar",
      "plk1"
	),
	ylab="z-score",
    pch="",
	cex.axis=2,
	cex.lab=2,
	lwd=1.5
  )
  points(
	jitter(rep(1, length(sicon1.z)),amount=0.3),
	sicon1.z,
	pch=19,
	col=rgb(0,0,1,0.5)
	)
  points(
	jitter(rep(2, length(sicon2.z)),amount=0.3),
	sicon2.z,
	pch=19,
	col=rgb(0,0,1,0.5)
	)
  points(
	jitter(rep(3, length(allstar.z)),amount=0.3),
	allstar.z,
	pch=19,
	col=rgb(0,0,1,0.5)
	)
  points(
	jitter(rep(4, length(plk1.z)),amount=0.3),
	plk1.z,
	pch=19,
	col=rgb(1,0,0,0.5)
	)

dev.off()
}

rep1 <- (names.arg=summary_file$normalized_r1_ch1)[which(summary_file$wellAnno == "sample")]
rep2 <- (names.arg-summary_file$normalized_r2_ch1)[which(summary_file$wellAnno == "sample")]
rep3 <- (names.arg=summary_file$normalized_r3_ch1)[which(summary_file$wellAnno == "sample")]

r12.cor <- cor(rep1,rep2,method="pearson",use="pairwise.complete.obs")
r13.cor <- cor(rep1,rep3,method="pearson",use="pairwise.complete.obs")
r23.cor <- cor(rep2,rep3,method="pearson",use="pairwise.complete.obs")

min.cor <- min(r12.cor, r13.cor, r23.cor)
max.cor <- max(r12.cor, r13.cor, r23.cor)

## write correlation coefficient values in a text file

combined.cor<-data.frame(min.cor, max.cor)
names(combined.cor)<-c("Minimum_correlation", "Maximum_correlation")
write.table(combined.cor, corr_coeff, sep="\t", quote=FALSE, row.names=FALSE)
}





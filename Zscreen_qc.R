Zscreen_qc<- function(datapath, summaryName, ReportdirName, controls_qc, corr_coeff)
{
	datapath=paste(datapath,"/", sep="")
	summary <- paste(datapath, summaryName, sep="")
	summary_file <- read.table(file= summary, sep="\t", header=TRUE) 				
	sicon1.z <-  summary_file$score[summary_file$wellAnno == "sicon1"] 
	sicon2.z <-  summary_file$score[summary_file$wellAnno == "sicon2"] 
	allstar.z <- summary_file$score[summary_file$wellAnno == "allstar"] 
	plk1.z <-    summary_file$score[c(which(summary_file$wellAnno == "siplk1"), which(summary_file$wellAnno == "plk1"))] 
	kras.z <- summary_file$score[summary_file$wellAnno == "kras"]
	sample.z <- summary_file$score[summary_file$wellAnno == "sample"]
	qc_file <- paste(datapath, controls_qc, sep="")

  	png(file=qc_file, width=800, height=500)
  	
  	if (length(kras.z)<=5)
  	{
  		boxplot(sicon1.z, sicon2.z, allstar.z, plk1.z, sample.z, 
  			names=c("sicon1", "sicon2", "allstar", "plk1", "sample"), 
  			ylab="z-score", pch="", cex.axis=2, cex.lab=2, lwd=1.5)
  	}
  
 	if (length(kras.z)>5)
  	{
  		boxplot(sicon1.z, sicon2.z, allstar.z, plk1.z, kras.z, sample.z,
			names=c("sicon1", "sicon2", "allstar", "plk1", "KRAS", "sample"),
			ylab="z-score", pch="", cex.axis=2, cex.lab=2, lwd=1.5)  	
  	}
  
  	points(jitter(rep(1, length(sicon1.z)),amount=0.3), sicon1.z, pch=19, col=rgb(0,0,1,0.5))
  	points(jitter(rep(2, length(sicon2.z)),amount=0.3), sicon2.z, pch=19, col=rgb(0,0,1,0.5))
  	points(jitter(rep(3, length(allstar.z)),amount=0.3), allstar.z, pch=19, col=rgb(0,0,1,0.5))
  	points(jitter(rep(4, length(plk1.z)),amount=0.3), plk1.z, pch=19, col=rgb(1,0,0,0.5))
  	if (length(kras.z)>5)
  	{
  		points(jitter(rep(5, length(kras.z)),amount=0.3), kras.z, pch=19, col=rgb(1,0,0,0.5)) 	
	}

	dev.off()
	
	sample_summary_data<-subset(summary_file, subset=(wellAnno=="sample"))
	rep1<-sample_summary_data$normalized_r1_ch1
	rep2<-sample_summary_data$normalized_r2_ch1
	rep3<-sample_summary_data$normalized_r3_ch1

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





#' MetagenomeSeq Feature model
#'
#' Implemented as in:
#' https://microbiomejournal.biomedcentral.com/articles/10.1186/s40168-016-0208-8
#' @param data Either a matrix with counts/abundances, OR a \code{phyloseq} object. If a matrix/data.frame is provided rows should be taxa/genes/proteins and columns samples
#' @param predictor The predictor of interest. Factor, OR if \code{data} is a \code{phyloseq} object the name of the variable in \code{sample_data(data)} in quotation
#' @param p.adj Character. P-value adjustment. Default "fdr". See \code{p.adjust} for details
#' @param allResults If TRUE will return raw results from the \code{fitFeatureModel} function
#' @param ... Additional arguments for the \code{fitFeatureModel} function
#' @export

DA.msf <- function(data, predictor, p.adj = "fdr", allResults = FALSE, ...){

  suppressMessages(library(metagenomeSeq))
  
  # Extract from phyloseq
  if(class(data) == "phyloseq"){
    DAdata <- DA.phyloseq(data, predictor)
    count_table <- DAdata$count_table
    predictor <- DAdata$predictor
  } else {
    count_table <- data
  }

  # Collect data
  count_table <- as.data.frame.matrix(count_table)
  mgsdata <- newMRexperiment(counts = count_table)
  
  # Normalize
  mgsp <- cumNormStat(mgsdata)
  mgsdata <- cumNorm(mgsdata, mgsp)
  
  # The design
  mod <- model.matrix(~predictor)
  
  # Fit model
  mgsfit <- fitFeatureModel(obj=mgsdata,mod=mod,...)
  
  # Extract results
  temp_table <- MRtable(mgsfit, number=nrow(count_table))
  temp_table <- temp_table[!is.na(row.names(temp_table)),]
  temp_table$Feature <- rownames(temp_table)
  colnames(temp_table)[7] <- "pval"
  temp_table$pval.adj <- p.adjust(temp_table$pval, method = p.adj)
  temp_table$ordering <- NA
  temp_table[!is.na(temp_table$logFC) & temp_table$logFC > 0,"ordering"] <- paste0(levels(as.factor(predictor))[2],">",levels(as.factor(predictor))[1])
  temp_table[!is.na(temp_table$logFC) & temp_table$logFC < 0,"ordering"] <- paste0(levels(as.factor(predictor))[1],">",levels(as.factor(predictor))[2])
  temp_table$Method <- "MgSeq Feature (msf)"  

  if(class(data) == "phyloseq") temp_table <- add.tax.DA(data, temp_table)
  
  if(allResults) return(mgsfit) else return(temp_table)
}

#' ANOVA
#' 
#' Apply ANOVA on multiple features with one \code{predictor}, with log transformation of counts before normalization.
#' @param data Either a matrix with counts/abundances, OR a \code{phyloseq} object. If a matrix/data.frame is provided rows should be taxa/genes/proteins and columns samples
#' @param predictor The predictor of interest. Factor, OR if \code{data} is a \code{phyloseq} object the name of the variable in \code{sample_data(data)} in quotation
#' @param covars Either a named list with covariables, OR if \code{data} is a \code{phyloseq} object a character vector with names of the variables in \code{sample_data(data)}
#' @param relative Logical. Should \code{data} be normalized to relative abundances. Default TRUE
#' @param p.adj Character. P-value adjustment. Default "fdr". See \code{p.adjust} for details
#' @param delta Numeric. Pseudocount for the log transformation. Default 1
#' @param allResults If TRUE will return raw results from the \code{aov} function
#' @param ... Additional arguments for the \code{aov} functions
#' @export

DA.lao <- function(data, predictor, covars = NULL, relative = TRUE, p.adj = "fdr", delta = 1, allResults = FALSE, ...){
  
  # Extract from phyloseq
  if(class(data) == "phyloseq"){
    DAdata <- DA.phyloseq(data, predictor, paired = NULL, covars)
    count_table <- DAdata$count_table
    predictor <- DAdata$predictor
    covars <- DAdata$covars
  } else {
    count_table <- data
  }
  if(!is.null(covars)){
    for(i in 1:length(covars)){
      assign(names(covars)[i], covars[[i]])
    }
  }
  
  # Define model
  if(is.null(covars)){
    form <- paste("x ~ predictor")
  } else {
    form <- paste("x ~ ",paste(names(covars), collapse="+"),"+ predictor",sep = "")
  }
  
  # Define function
  ao <- function(x){
    tryCatch(as.numeric(summary(aov(as.formula(form), ...))[[1]][(length(covars)+1),5]), error = function(e){NA}) 
  }
  
  # Log and relative abundance
  count_table <- log(count_table+delta)
  if(relative) count_table <- apply(count_table,2,function(x) x/sum(x))
  
  # Run tests
  if(allResults){
    ao <- function(x){
      tryCatch(aov(as.formula(form), ...), error = function(e){NA}) 
    }
    return(apply(count_table,1,ao))
  } else {
    res <- data.frame(pval = apply(count_table,1,ao))
    res$pval.adj <- p.adjust(res$pval, method = p.adj)
    res$Feature <- rownames(res)
    res$Method <- "Log ANOVA (lao)"
    if(class(data) == "phyloseq") res <- add.tax.DA(data, res)
    return(res)
  }
}



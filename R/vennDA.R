#' Plot Venn diagram from \code{allDA} object
#'
#' Plot a Venn (Euler) diagram of features found by different methods.
#' 
#' Require the eulerr package unless output is TRUE.
#' @param x (Required) Output from the \code{allDA} function
#' @param tests (Required) Character vector with tests to plot (E.g. \code{c("ttt","adx.t","wil")}, see \code{names(x$results)}). Default none
#' @param alpha Numeric. q-value threshold for significant features. Default 0.1
#' @param split If TRUE will split diagrams in positive and negative estimates if possible
#' @param output If TRUE will return a data.frame instead of a plot
#' @param pkg Use either "eulerr" package (default) or "venneuler" for drawing diagrams.
#' @param ... Additional arguments for plotting
#' @return If output TRUE then a data.frame with Features detected by the different methods
#' @export
vennDA <- function(x, tests = NULL, alpha = 0.1, split = FALSE, output = FALSE, pkg = "eulerr", ...){

  # Load package
  if(pkg == "eulerr") library(eulerr)
  if(pkg == "venneuler") library(venneuler)
  
  # Check input
  if(!all(names(x) == c("raw","adj","est","details","results"))) stop("x is not an allDA object")
  
  plottests <- tests[tests %in% names(x[[2]])]  
  if(!all(tests %in% names(x[[2]]))){
    message(paste(tests[!tests %in% names(x[[2]])],collapse = ", ")," not found in the allDA object")
  }
  if(length(plottests) == 0) stop("Nothing to plot")
  
  # Which are significant
  featurelist <- list()
  for(i in seq_along(plottests)){
    sub <- x$adj[,c("Feature",plottests[i])]
    if(!plottests[i] %in% c("sam","anc")) featurelist[[i]] <- sub[sub[,2] < alpha,"Feature"]
    if(plottests[i] %in% c("sam","anc")) featurelist[[i]] <- sub[sub[,2] != "No","Feature"]
  }

  # Split in negative and positive significant
  if(split){
    featurelist.pos <- list()
    featurelist.neg <- list()
    for(i in seq_along(plottests)){
      
      subs <- x$est[,c(1,which(gsub("_.*","",colnames(x$est)) == plottests[i]))]

      if(plottests[i] == "bay"){
        sub.p <- subs[subs[,2] == levels(subs[,2])[1],"Feature"]
        sub.n <- subs[subs[,2] == levels(subs[,2])[2],"Feature"]
        featurelist.pos[[i]] <- featurelist[[i]][featurelist[[i]] %in% sub.p]
        featurelist.neg[[i]] <- featurelist[[i]][featurelist[[i]] %in% sub.n]
      }
      if(plottests[i] %in% c("mva","sam","znb","zpo","poi","qpo","neb","lrm","llm","llm2","lim","lli","lli2","vli","pea","spe","per","adx.t","adx.w","wil","ttt","ltt","ltt2","ere","ere2","erq","erq2","ds2","ds2x","msf","zig","rai")){
        if(is.null(ncol(subs))){
          featurelist.pos[[i]] <- featurelist[[i]]
          featurelist.neg[[i]] <- featurelist[[i]]
        } else {
          sub.p <- subs[subs[,2] > 0,"Feature"]
          sub.n <- subs[subs[,2] < 0,"Feature"]
          featurelist.pos[[i]] <- featurelist[[i]][featurelist[[i]] %in% sub.p]
          featurelist.neg[[i]] <- featurelist[[i]][featurelist[[i]] %in% sub.n]
        }
      }
      # If not estimate/logFC provided throw all significant in both positive and negative list
      if(!plottests[i] %in% c("mva","sam","bay","znb","zpo","poi","qpo","neb","lrm","llm","llm2","lim","lli","lli2","vli","pea","spe","per","adx.t","adx.w","wil","ttt","ltt","ltt2","ere","ere2","erq","erq2","ds2","ds2x","msf","zig","rai")){
        featurelist.pos[[i]] <- featurelist[[i]]
        featurelist.neg[[i]] <- featurelist[[i]]
      }
    }
  } 

  # Collect significant features and make correct naming
  if(split){
    
    vennfeat.p <- do.call(c, featurelist.pos)
    vennfeat.n <- do.call(c, featurelist.neg)
    vennfeat <- c(vennfeat.p,vennfeat.n)
    if(length(vennfeat) == 0) stop("No significant features")
    naming.pos <- list()
    naming.neg <- list()
    for(i in 1:length(featurelist)){
      if(plottests[i] == "bay"){
        naming.pos[[i]] <- rep(paste0(plottests[i],"_",levels(x$results$bay$ordering)[1]),length(featurelist.pos[[i]]))
        naming.neg[[i]] <- rep(paste0(plottests[i],"_",levels(x$results$bay$ordering)[2]),length(featurelist.neg[[i]]))
      } else {
        naming.pos[[i]] <- rep(paste0(plottests[i],"_Positive"),length(featurelist.pos[[i]]))
        naming.neg[[i]] <- rep(paste0(plottests[i],"_Negative"),length(featurelist.neg[[i]])) 
      }
    }
    vennname.pos <- do.call(c, naming.pos)
    vennname.neg <- do.call(c, naming.neg)
    vennname <- c(vennname.pos,vennname.neg)

  } else {
    
    vennfeat <- do.call(c, featurelist)
    if(length(vennfeat) == 0) stop("No significant features")
    naming <- list()
    for(i in 1:length(featurelist)){
      naming[[i]] <- rep(plottests[i],length(featurelist[[i]]))
    }
    vennname <- do.call(c, naming)
    
  }
  
  # Make dataframe with significant features for each method
  venndf <- data.frame(vennfeat,vennname)

  # Remove the duplicate ones created earlier for methods without estimates/logFC
  if(split){
    for(i in seq_along(plottests)){
      if(!plottests[i] %in% c("mva","sam","bay","znb","zpo","poi","qpo","neb","lrm","llm","llm2","lim","lli","lli2","vli","pea","spe","per","adx.t","adx.w","wil","ttt","ltt","ltt2","ere","ere2","erq","erq2","ds2","ds2x","msf","zig","rai")){
        venndf <- venndf[venndf$vennname != paste0(plottests[i],"_Negative"),]
        venndf$vennname <- as.character(venndf$vennname)
        venndf[venndf$vennname == paste0(plottests[i],"_Positive"),"vennname"] <- plottests[i]
      }
      if(plottests[i] %in% c("znb","zpo","poi","qpo","neb","lrm","llm","llm2") & !plottests[i] %in% gsub("_.*","",colnames(x$est))){
        venndf <- venndf[venndf$vennname != paste0(plottests[i],"_Negative"),]
        venndf$vennname <- as.character(venndf$vennname)
        venndf[venndf$vennname == paste0(plottests[i],"_Positive"),"vennname"] <- plottests[i]
      }
    }
    
  }

  # Remove NAs
  venndf <- na.omit(venndf)
  
  # Return data.frame or plot
  if(output){
    colnames(venndf) <- c("Feature","Method")
    return(venndf)
  } else {
    if(pkg == "venneuler"){
      venndia <- venneuler::venneuler(venndf)
      plot(venndia, ...)
    }
    if(pkg == "eulerr"){
      euler.list <- list()
      for(i in seq_along(unique(venndf$vennname))){
        euler.list[[i]] <- venndf[venndf$vennname == unique(venndf$vennname)[i],1]
      }
      names(euler.list) <- unique(venndf$vennname)
      plot(euler(euler.list), quantities = TRUE, ...)
    }
  }
}

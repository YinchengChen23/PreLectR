#' Sample randomization by fold change from label shuffling
#' 
#' @param X              Matrix or DataFrame. Raw count data with samples as rows and features as columns.
#' @param Y              Character vector. Labels corresponding to the samples in the data.
#' @param control_sample Character. The name of the control sample.
#' @return A DataFrame where the first column contains the observed order, and the following 999 columns contain randomized orders.
#' @export
#' 
generatePermutedTable <- function(X, Y, control_sample) {
  mean_control <- rowMeans(X[,Y == control_sample])
  mean_case    <- rowMeans(X[,Y != control_sample])
  fc <- log2(mean_case+1) - log2(mean_control+1)
  original <- rownames(X)[order(fc, decreasing = T)]
  GSEAtable <- data.frame('original' = original)
  for(i in 1:999){
    shuffled_Y <- sample(Y, length(Y))
    mean_control <- rowMeans(X[, shuffled_Y == control_sample])
    mean_case    <- rowMeans(X[, shuffled_Y != control_sample])
    fc <- log2(mean_case+1) - log2(mean_control+1)
    permuted <- rownames(X)[order(fc, decreasing = T)]
    permuted <- data.frame(permuted)
    colnames(permuted) <- paste0('perm_',i)
    GSEAtable <- cbind(GSEAtable, permuted)
  }
  return(GSEAtable)
}

#' Sample randomization by continuous label shuffling
#' 
#' @param X  Matrix or DataFrame. Raw count data with samples as rows and features as columns.
#' @param Y  Numeric vector. Labels corresponding to the samples in the data.
#' @return A DataFrame where the first column contains the observed order, and the following 999 columns contain randomized orders.
#' @export
#' 
generatePermutedTableContinuous <- function(X, Y) {
  original <- rownames(X)[order(Y, decreasing = T)]
  GSEAtable <- data.frame('original' = original)
  for(i in 1:999){
    shuffled_Y <- sample(Y, length(Y))
    permuted <- rownames(X)[order(shuffled_Y, decreasing = T)]
    permuted <- data.frame(permuted)
    colnames(permuted) <- paste0('perm_',i)
    GSEAtable <- cbind(GSEAtable, permuted)
  }
  return(GSEAtable)
}

#' Permutation test function using the GSEA method
#' 
#' @param permutated_table DataFrame. A table containing randomized order, generated by `generatePermutedTable` or `generatePermutedTableContinuous`.
#' @param ko_mapper        List. A list that records taxa groups for each KO, generated by `map_ko_to_taxon`.
#' @return A DataFrame containing the results of the permutation test, including enrichment score (ES), z-value, and p-value for each KO.
#' @export
#' 
permutatedTest <- function(permutated_table, ko_mapper) {
  n_feat = nrow(permutated_table)
  out <- data.frame()
  pb <- txtProgressBar(min = 0, max = length(ko_mapper), style = 3)
  for(i in 1:length(ko_mapper)){
    query <- ko_mapper[[i]]
    hitted <- which(permutated_table[, 1] %in% query)
    observed <- GSEA_run(hitted, n_feat)
    
    permutated_scores <- c()
    for(j in 2:ncol(permutated_table)){
      hitted <- which(permutated_table[, j] %in% query)
      permutated_scores <- c(permutated_scores, GSEA_run(hitted, n_feat))
    }
    
    z <- (observed - mean(permutated_scores))/sd(permutated_scores)
    
    permutated_scores <- c(permutated_scores, observed)
    permutated_scores <- sort(permutated_scores, decreasing = TRUE)
    
    p <- which(permutated_scores == observed)[1]/1000
    out <- rbind(out, data.frame('KO'=names(ko_mapper)[i], 'ES'=observed, 'z'=z, 'p'=p))
    setTxtProgressBar(pb, i)
  }
  close(pb)
  return(out)
}


#' GSEA test with binary labels
#' 
#' @param KO_index    DataFrame. A table containing pair-relationship between KOs and taxa, generally is `pred_metagenome_contrib.tsv` file generated` by `PICRUst2`
#' @param X           Matrix or DataFrame. Raw count data with samples as rows and features as columns.
#' @param Y           Character vector. Labels corresponding to the samples in the data.
#' @param case_sample Character. The name of the case sample.
#' @return A list containing two DataFrames:
#' - `Actived_KO`: Results of the GSEA analysis for case-activated KOs, including enrichment scores (ES), z-values, and p-values for each KO.
#' - `Suppressed_KO`: Results of the GSEA analysis for case-suppressed KOs, including enrichment scores (ES), z-values, and p-values for each KO.
#' @export
#' @examples
#' 
#' KOindex <- read.table(".../KO/pred_metagenome_contrib.tsv", sep = "\t", header = TRUE)
#' GSEAresult <- GSEATestwithFC(KOindex, ASV_table, groupings$Class, "Cancer")
#' Actived_result <- GSEAresult$Actived_KO
#' Actived_result <- Actived_result[Actived_result$z > 2,]
#' nrow(Actived_result)
#' 
GSEATestwithFC <- function(KO_index, X, Y, case_sample){
  
  # check ncol(X) == Y
  if (ncol(X) != length(Y)) {
    stop(paste("Label count mismatch: found", length(Y),
               "labels but data has", ncol(X), "samples."))
  }
  
  # check Y is binary
  if (length(unique(Y)) > 2) {
    stop("This testing function only supports binary labels. If the labels are continuous, please use `GSEATest`.")
  }
  
  # check case_sample in Y
  if (!case_sample %in% Y) {
    stop("Invalid case condition assignment. Please ensure 'case_sample' is present in the labels.")
  }
  
  control_sample = unique(Y)[unique(Y) != case_sample]
  
  message("Building the KO-to-taxa mapper...")
  KO_mapper <- map_ko_to_taxon(KO_index)
  message(paste("Done. In total,", length(KO_mapper), "KOs need to be processed."))
  
  message("Shuffling the labels for GSEA...")
  permutated_case <- generatePermutedTable(X, Y, control_sample)
  
  message("Performing GSEA to identify activated KOs...")
  case_actived <- permutatedTest(permutated_case, KO_mapper)
  
  message("Shuffling the labels for GSEA...")
  permutated_control <- generatePermutedTable(X, Y, case_sample)
  message("Performing GSEA to identify suppressed KOs...")
  case_suppressed <- permutatedTest(permutated_control, KO_mapper)
  message("Done.")
  return(list('Actived_KO'=case_actived, 'Suppressed_KO'=case_suppressed))
}

#' GSEA test with continuous labels
#' 
#' @param KO_index    DataFrame. A table containing pair-relationship between KOs and taxa, generally is `pred_metagenome_contrib.tsv` file generated` by `PICRUst2`
#' @param X           Matrix or DataFrame. Raw count data with samples as rows and features as columns.
#' @param Y           Numeric vector. Labels corresponding to the samples in the data.
#' @return A list containing two DataFrames:
#' - `Actived_KO`: Results of the GSEA analysis for case-activated KOs, including enrichment scores (ES), z-values, and p-values for each KO.
#' - `Suppressed_KO`: Results of the GSEA analysis for case-suppressed KOs, including enrichment scores (ES), z-values, and p-values for each KO.
#' @export
#' @examples
#' 
#' KOindex <- read.table(".../KO/pred_metagenome_contrib.tsv", sep = "\t", header = TRUE)
#' GSEAresult <- GSEATestwithFC(KOindex, ASV_table, groupings$bmi)
#' Actived_result <- GSEAresult$Actived_KO
#' Actived_result <- Actived_result[Actived_result$z > 2,]
#' nrow(Actived_result)
#' 
GSEATest <- function(KO_index, X, Y){
  
  # check ncol(X) == Y
  if (ncol(X) != length(Y)) {
    stop(paste("Label count mismatch: found", length(Y),
               "labels but data has", ncol(X), "samples."))
  }
  
  message("Building the KO-to-taxa mapper...")
  KO_mapper <- map_ko_to_taxon(KO_index)
  message(paste("Done. In total,", length(KO_mapper), "KOs need to be processed."))
  
  message("Shuffling the labels for GSEA...")
  permutated_case <- generatePermutedTableContinuous(X, Y)
  
  message("Performing GSEA to identify activated KOs...")
  case_actived <- permutatedTest(permutated_case, KO_mapper)
  
  message("Shuffling the labels for GSEA...")
  permutated_control <- generatePermutedTableContinuous(X, rev(Y))
  message("Performing GSEA to identify suppressed KOs...")
  case_suppressed <- permutatedTest(permutated_control, KO_mapper)
  message("Done.")
  return(list('Actived_KO'=case_actived, 'Suppressed_KO'=case_suppressed))
}

#' Fisher's exact test for pathway enrichment
#' 
#' @param filtered_KO     Character vector. A list of significant KOs obtained from the GSEA test.
#' @param KOmap           KO-pathway mapping information generated by the `GetKOInfo` function using the KEGG API.
#' @return DataFrame. A data frame containing the pathway enrichment results.
#' @export
#' 
PathwayEnrichment <- function(filtered_KO, KOmap) {
  enrichment_results <- data.frame()
  unique_pathways <- unique(KOmap$pathway[KOmap$KO %in% filtered_KO])
  for (pathway_name in unique_pathways) {
  
    pathway_id <- unique(KOmap$mapid[KOmap$pathway == pathway_name])
    pathway_KOs <- unique(KOmap$KO[KOmap$pathway == pathway_name])
    non_pathway_KOs <- unique(KOmap$KO[KOmap$pathway != pathway_name])
  
    # Calculate counts for the contingency table
    in_pathway_selected <- length(intersect(pathway_KOs, filtered_KO))
    in_pathway_not_selected <- length(setdiff(pathway_KOs, filtered_KO))
    not_in_pathway_selected <- length(intersect(non_pathway_KOs, filtered_KO))
    not_in_pathway_not_selected <- length(setdiff(non_pathway_KOs, filtered_KO))
  
    # Construct the contingency table
    contingency_table <- matrix(c(in_pathway_selected, in_pathway_not_selected, 
                                not_in_pathway_selected, not_in_pathway_not_selected), nrow = 2)
  
    # Perform Fisher's exact test
    fisher_test_result <- fisher.test(contingency_table)
  
    # Store the results in a temporary data frame
    result_row <- data.frame(
      pathway = pathway_name,
      id = pathway_id,
      count = in_pathway_selected,
      ratio = in_pathway_selected/length(pathway_KOs),
      p = fisher_test_result$p.value,
      odds_ratio = as.numeric(fisher_test_result$estimate)
    )
  
    # Append the result to the enrichment results data frame
    enrichment_results <- rbind(enrichment_results, result_row)
  }
  return(enrichment_results)
}
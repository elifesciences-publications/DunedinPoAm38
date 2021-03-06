#' Generate the Dunedin Methylation Pace of Aging Scores!
#'
#' \code{PoAmProjector} returns the Dunedin Pace of Aging Methylation Scores
#'
#' @param betas A numeric matrix containing the percent-methylation for each probe.  Missing data should be 'NA's.  The rows should be probes, with the probe ID as the row name, and the columns should be samples, with sample names as the column name.
#' @param proportionOfProbesRequired (default: 0.8).  This value specificies the threshold for missing data (see description for more details on how missing data is handled)
#' @return A list of mPoA values.  There will be one element in the list for each mPoA model.  Each element will consist of a numeric vector with mPoA values.  The names of the values in the vector will be the sample names from the 'betas' matrix.
#' @details This function returns the Dunedin Methylation Pace of Aging scores for methylation data generated from either the Illumina 450K array or the Illumina EPIC array.  The Age38 score is the one described in the eLife paper (2020).  The Age45 score is one that has been trained on data based on 3 waves of collection (26, 38, and 45).  The manuscript is currently in preparation, but has been shown to be more accurate than the Age38 score.
#' Missing data handled in two different ways (and the threshold for both is set by the 'proportionOfProbesRequired' parameter).  First, if a sample is missing data for more probes than the threshold, the sample will get an NA back for a score.  If a particular probe is missing fewer samples than the threshold, then missing data is set to the mean in the provided 'betas' matrix.  If a probe is missing more samples than the threshold, then all samples in the 'betas' matrix have their value replaced with the mean of the training data for that particular model.
#' Because of how we handle missing data, it is reccomended that entire cohorts be run at once as a large 'betas' matrix.
#' @examples
#' PoAmProjector(betas)

PoAmProjector = function( betas, proportionOfProbesRequired=0.8 ) {
  # loop through models
  model_results <- lapply(mPOA_Models$model_names, function(model_name) {
    # make sure it has been converted to a matrix
    if( !is.numeric(as.matrix(betas)) ) { stop("betas matrix/data.frame is not numeric!") }
    probeOverlap <- length(which(rownames(betas) %in% mPOA_Models$model_probes[[model_name]])) / length(mPOA_Models$model_probes[[model_name]])
    # make sure enough of the probes are present in the data file
    if( probeOverlap < proportionOfProbesRequired ) {
      result <- rep(NA, ncol(betas))
      names(result) <- colnames(betas)
      result
    } else {
      # Work with a numeric matrix of betas
      betas.mat <- as.matrix(betas[which(rownames(betas) %in% mPOA_Models$model_probes[[model_name]]),])
      # If probes don't exist, we'll add them as rows of 'NA's
      probesNotInMatrix <- mPOA_Models$model_probes[[model_name]][which(mPOA_Models$model_probes[[model_name]] %in% rownames(betas.mat) == F)]
      if( length(probesNotInMatrix) > 0 ) {
        for( probe in probesNotInMatrix ) {
          tmp.mat <- matrix(NA, nrow=1, ncol=ncol(betas.mat))
          rownames(tmp.mat) <- probe
          colnames(tmp.mat) <- colnames(betas.mat)
          betas.mat <- rbind(betas.mat, tmp.mat)
        }
      }

      # Identify samples with too many missing probes and remove them from the matrix
      samplesToRemove <- colnames(betas.mat)[which(apply(betas.mat, 2, function(x) { 1 - ( length(which(is.na(x))) / length(x) ) < proportionOfProbesRequired}))]
      if( length(samplesToRemove) > 0 ) {
        betas.mat <- betas.mat[,-which(colnames(betas.mat) %in% samplesToRemove)]
      }
      if(ncol(betas.mat) > 0) {
        # Identify missingness on a probe level
        pctValuesPresent <- apply( betas.mat, 1, function(x) { 1 - (length(which(is.na(x))) / length(x)) } )
        # If they're missing values, but less than the proportion required, we impute to the cohort mean
        probesToAdjust <- which(pctValuesPresent < 1 & pctValuesPresent >= proportionOfProbesRequired)
        if( length(probesToAdjust) > 0 ) {
          if( length(probesToAdjust) > 1 ) {
            betas.mat[probesToAdjust,] <- t(apply( betas.mat[probesToAdjust,], 1 , function(x) {
              x[is.na(x)] = mean( x, na.rm = TRUE )
              x
            }))
          } else {
            betas.mat[probesToAdjust,which(is.na(betas.mat[probesToAdjust,]))] <- mean(betas.mat[probesToAdjust,], na.rm=T)
          }
        }
        # If they're missing too many values, everyones value gets replaced with the mean from the Dunedin cohort
        if( length(which(pctValuesPresent < proportionOfProbesRequired)) > 0 ) {
          probesToReplaceWithMean <- rownames(betas.mat)[which(pctValuesPresent < proportionOfProbesRequired)]
          for( probe in probesToReplaceWithMean ) {
            betas.mat[probe,] <- rep(mPOA_Models$model_means[[model_name]][probe], ncol(betas.mat))
          }
        }
        # Calculate score:
        score = mPOA_Models$model_intercept[[model_name]] + rowSums(t(betas.mat[mPOA_Models$model_probes[[model_name]],]) %*% diag(mPOA_Models$model_weights[[model_name]]))
        names(score) <- colnames(betas.mat)
        if( length(samplesToRemove) > 0 ) {
          score.tmp <- rep(NA, length(samplesToRemove))
          names(score.tmp) <- samplesToRemove
          score <- c(score, score.tmp)
        }
        score <- score[colnames(betas)]
        score
      } else {
        result <- rep(NA, ncol(betas.mat))
        names(result) <- colnames(betas.mat)
        result
      }
    }
  })
  names(model_results) <- mPOA_Models$model_names
  model_results
}

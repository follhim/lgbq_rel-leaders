#' Calculate Spearman-Brown reliability for two-item scale
#'
#' This function calculates the Spearman-Brown reliability for a two-item scale,
#' which is the recommended measure for two-item scales (rather than Cronbach's
#' alpha, which is used for longer scales.)
#'
#' @param df A dataframe
#' @param items Character vector of length 2, with names of the two items
#' @param name Name of the scale, relevant only if data.frame is returned
#' @param SB_only Logical, indicating whether to return only the reliabity as
#' a number or a dataframe that also includes the scale name and correlation.
#' @return Either the Spearman-Brown coefficient as a single number, or a
#'   dataframe including the Pearson correlation coefficient and the scale name
#' @export
#' @source https://www.r-bloggers.com/five-ways-to-calculate-internal-consistency/
#'
spearman_brown <- function(df, items, name = "", SB_only = FALSE) {
  cor_value <- cor.test(magrittr::extract2(df, items[1]), magrittr::extract2(df, items[2]), na.rm = T)$estimate
  SB_value <- (abs(cor_value) * 2) / (1 + abs(cor_value))
  if (SB_only) {
    return(SB_value)
  }
  result <- data.frame(correlation = cor_value, spearman_brown = SB_value, row.names = name)
  return(result)
}

#' Creates a scale by calculating item mean and returns descriptives
#'
#' This function creates a scale by calculating the mean of a set of items,
#' and prints and returns descriptives that allow to assess internal consistency
#' and spread. It is primarily based on the \code{psych::alpha} function, with
#' more parsimonious output and some added functionality.
#'
#' @param df A dataframe
#' @param scale_items Character vector with names of scale items (variables in df)
#' @param scale_name Name of the scale
#' @param reverse Should scale items be reverse coded? One of "auto" - items are
#'   reversed if that contributes to scale consistency, "none" - no items reversed,
#'   or "spec" - items specific in \code{reverse_items} are reversed.
#' @param reverse_items Character vector with names of scale items to be reversed
#'   (must be subset of scale_items)
#' @param two_items_reliability How should the reliability of two-item scales be
#'   reported? "spearman_brown" is the recommended default, but "cronbachs_alpha"
#'   and Pearson's "r" are also supported.
#' @param r_key (optional) Numeric. Set to the possible maximum value of the scale
#' if the whole scale should be reversed, or to -1 to reverse the scale based on
#' the observed maximum.
#' @param print_hist Logical. Should histograms for items and resulting scale be printed?
#' @param print_desc Logical. Should descriptives for scales be printed?
#' @param return_list Logical. Should only scale values be returned, or descriptives as well?
#' @return Depends on \code{return_list} argument. Either just the scale values,
#'   or a list of scale values and descriptives.
#' @export
#'

make_scale <- function(df, scale_items, scale_name, reverse = c(
  "auto",
  "none", "spec"
), reverse_items = NULL, two_items_reliability = c(
  "spearman_brown", "cron_alpha",
  "r"
), r_key = NULL, print_hist = TRUE, print_desc = TRUE, return_list = FALSE) {
  if (!all(scale_items %in% names(df))) stop("Not all scale_items can be found in the dataset. The following are missing: ", paste(setdiff(scale_items, names(df)), collapse = ", "), call. = FALSE)
  
  if (df %>% dplyr::select(dplyr::any_of(scale_items)) %>% {all(sapply(., checkmate::allMissing))}) stop("All variables for scale ", scale_name, " only contain missing values.", call. = FALSE)
  
  assert_choice(reverse[1], c("auto", "none", "spec"))
  
  if(!is.null(reverse_items)&!reverse=="spec") stop('reverse_items should only be specified together with reverse = "spec"')
  
  if (is.null(r_key)) r_key <- 0
  scale_vals <- df %>%
    dplyr::select(dplyr::one_of(scale_items)) %>%
    dplyr::mutate_all(as.numeric)
  if ((reverse != "spec")[1]) {
    check.keys <- ifelse(reverse == "none", F, T)
    alpha_obj <- suppressWarnings(scale_vals %>% psych::alpha(na.rm = TRUE, check.keys = check.keys))
  } else {
    alpha_obj <- suppressWarnings(scale_vals %>% psych::alpha(na.rm = TRUE, keys = reverse_items))
  }
  
  if (r_key == -1) {
    alpha_obj$scores <- psych::reverse.code(-1, alpha_obj$scores)
  } else if (r_key > 0) {
    alpha_obj$scores <- psych::reverse.code(-1, alpha_obj$scores, maxi = r_key)
  }
  reversed <- names(alpha_obj$keys[alpha_obj$keys == -1])
  if (length(scale_items) == 2) {
    if (two_items_reliability[1] == "spearman_brown") {
      reliab <- spearman_brown(df, items = scale_items, SB_only = T)
    } else if (two_items_reliability[1] == "cronbachs_alpha") {
      reliab <- alpha_obj$total$std.alpha
    } else if (two_items_reliability[1] == "r") {
      reliab <- cor.test(df[, scale_items[1]], df[, scale_items[2]], na.rm = T)$estimate
    }
  } else {
    reliab <- alpha_obj$total$std.alpha
  }
  if (return_list) {
    descriptives <- list(NoItems = length(scale_items), Reliability = reliab, mean = mean(alpha_obj$scores,
                                                                                          na.rm = T
    ), SD = sd(alpha_obj$scores, na.rm = T), Reversed = paste0(reversed,
                                                               collapse = " "
    ), RevMin = ifelse(length(reversed) > 0, min(scale_vals, na.rm = T),
                       NA
    ), RevMax = ifelse(length(reversed) > 0, max(scale_vals, na.rm = T), NA))
  }
  if (print_desc) {
    print(paste0("Descriptives for scale ", scale_name))
    print(paste0(ifelse(length(scale_items) == 2, paste0(two_items_reliability, ": "),
                        "Cronbach's alpha: "
    ), round_(reliab, 2)))
    print(paste0("Scale mean: ", mean(alpha_obj$scores, na.rm = T)))
    print(paste0("Scale SD: ", sd(alpha_obj$scores, na.rm = T)))
    
    if (length(reversed) > 0) {
      print(paste(c("The following items are reverse coded: ", reversed),
                  sep = ", ",
                  collapse = ", "
      ))
      print(paste(
        "The min and max used for reverse coding:", min(scale_vals, na.rm = T),
        max(scale_vals, na.rm = T)
      ))
    }
  }
  if (print_hist) {
    (cbind(scale_vals, Scale = alpha_obj$scores) %>%
       tidyr::gather(
         key = "category", value = "resp",
         factor_key = TRUE
       ) %>%
       ggplot2::ggplot(ggplot2::aes(x = .data$resp)) +
       ggplot2::geom_histogram(binwidth = 0.5) +
       ggplot2::facet_wrap(~ .data$category) +
       ggplot2::ggtitle(paste0("Histogram for ", scale_name))) %>%
      print() #Remember: %>% has higher precedence than +
  }
  if (return_list) {
    return(list(scores = alpha_obj$scores, descriptives = descriptives))
  }
  
  alpha_obj$scores
}

#' Creates multiple scales by calculating item means and returns descriptives
#'
#' This function creates multiple scales, returns descriptives and supports
#' reverse-coding of items.
#'
#' @param df A dataframe
#' @param items A named list of characters vectors. Names are the scale names,
#'   each vector contains the items for that scale (variables in df)
#' @param reversed A named list of characters vectors. Names are the scale names,
#'   each vector contains the items to be reverse-coded for that scale
#' @inheritParams make_scale
#' @inheritDotParams make_scale print_desc print_hist
#' @return A list of two dataframes: scale values (`scores`) and
#' descriptive statistics for each scale (`descriptives`)
#' @export

make_mult_scales <- function(df, items, reversed = NULL, two_items_reliability = c(
  "spearman_brown",
  "cronbachs_alpha", "r"
), ...) {
  if (!all(unlist(items) %in% names(df))) stop("Not all items can be found in the dataset. The following are missing: ", paste(setdiff(unlist(items), names(df)), collapse = ", "), call. = FALSE)
  
  
  if (!is.null(reversed)) {
    scales_rev <- intersect(names(items), names(reversed))
    if (length(scales_rev) > 0) {
      print(paste0(
        "The following scales will be calculated with specified reverse coding: ",
        paste0(scales_rev, collapse = ", ")
      ))
      
      scales_rev_values <- purrr::pmap(list(
        scale_items = items[scales_rev], scale_name = scales_rev,
        reverse_items = reversed[scales_rev]
      ), make_scale,
      df = df, return_list = T,
      reverse = "spec", two_items_reliability, ...
      ) %>% purrr::transpose()
    } else {
      stop("Reverse list and variable lists cannot be matched - check that they have same names")
    }
  }
  
  scales_n_rev <- setdiff(names(items), names(reversed))
  
  if (length(scales_n_rev) > 0) {
    print(paste0(
      "The following scales will be calculated without reverse coding: ",
      paste0(scales_n_rev, collapse = ", ")
    ))
    
    scales_n_rev_values <- purrr::map2(items[scales_n_rev], scales_n_rev, make_scale,
                                       df = df,
                                       return_list = T, reverse = "none", two_items_reliability = two_items_reliability, ...
    ) %>% purrr::transpose()
  }
  
  scores <- if (exists("scales_n_rev_values") & exists("scales_rev_values")) {
    cbind(data.frame(scales_n_rev_values$scores), data.frame(scales_rev_values$scores))
  } else if (exists("scales_rev_values")) {
    data.frame(scales_rev_values$scores)
  } else if (exists("scales_n_rev_values")) {
    data.frame(scales_n_rev_values$scores)
  } else {
    stop("No scales created - check inputs")
  }
  
  descript <- if (exists("scales_n_rev_values") & exists("scales_rev_values")) {
    c(scales_n_rev_values$descriptives, scales_rev_values$descriptives)
  } else if (exists("scales_rev_values")) {
    scales_rev_values$descriptives
  } else if (exists("scales_n_rev_values")) {
    scales_n_rev_values$descriptives
  } else {
    stop("No scales created - check inputs")
  }
  
  descriptives <- do.call(rbind.data.frame, descript) %>% tibble::rownames_to_column(var = "Scale")
  
  list(scores = scores, descriptives = descriptives)
}

#' Creates scale by calculating item mean and returns descriptives for srvyr objects
#'
#' This function creates a scale by calculating the mean of a set of items,
#' and prints and returns descriptives that allow to assess internal consistency
#' and spread. It is primarily based on the \code{psych::alpha} function, with
#' more parsimonious output and some added functionality.
#'
#' @param df A srvyr survey object
#' @param scale_items A characters vector containing the items for that scale
#'   (variables in df)
#' @param scale_name Character. The name of the variable the scale should be saved as
#' @param print_hist Logical. Should histograms of the scale and its items be printed.
#' @param scale_title Character. Name of scale for printing. Defaults to scale_name
#' @param reversed (optional) A characters vector containing the items that should be reverse-coded (
#'   subset of scale_items)
#' @param r_key (optional) Numeric. Set to the possible maximum value of the scale
#' if the whole scale should be reversed, or to -1 to reverse the scale based on
#' the observed maximum
#' @return The survey object with the scale added as an additional variable.
#' @export

## TODO
### Merge/align with standard make_scale functions


svy_make_scale <- function(df, scale_items, scale_name, print_hist = T, scale_title = scale_name,
                           reversed = NULL, r_key = NULL) {
  if (!requireNamespace("survey", quietly = TRUE)) {
    stop("Package \"survey\" needed for this function to work. Please install it.",
         call. = FALSE
    )
  }
  
  if (!scale_title == scale_name) {
    scale_title <- paste0(scale_title, " (", scale_name, ")")
  }
  
  # Convert all scale items into numeric vars
  scale_items_num <- paste0(scale_items, "num")
  for (i in 1:length(scale_items)) {
    df <- eval(parse(text = paste0("update(df,", scale_items_num[i], " = as.numeric(unlist(df[,scale_items[i]]$variables)))")))
  }
  
  # Reverse reverse-coded items
  if (!is.null(reversed)) {
    reversed_num <- paste0(reversed, "num")
    scale_items_num <- c(setdiff(scale_items_num, reversed_num), paste0(
      reversed_num,
      "r"
    ))
    for (i in 1:length(reversed)) {
      df <- eval(parse(text = paste0("update(df,", reversed_num[i], "r = psych::reverse.code(-1, df[,reversed_num[i]]$variables))")))
    }
  }
  
  # Create scale
  df <- eval(parse(text = paste0("update(df,", scale_name, " = rowMeans(df[,scale_items_num]$variables, na.rm=T))")))
  
  # Reverse full scale
  if (!is.null(r_key)) {
    if (r_key == -1) {
      df <- eval(parse(text = paste0(
        "update(df,", scale_name, " = psych::reverse.code(",
        r_key, ", df$variables$", scale_name, "))"
      )))
    } else if (r_key > 0) {
      df <- eval(parse(text = paste0(
        "update(df,", scale_name, " = psych::reverse.code(",
        -1, ", df$variables$", scale_name, ", maxi = ", r_key, "))"
      )))
    }
  }
  
  # Print scale descriptives
  cat(paste0("Descriptive stats for ", scale_title, "\n", "Cronbach's alpha:", round_(survey::svycralpha(as.formula(.scale_formula(scale_items_num)),
                                                                                                         df,
                                                                                                         na.rm = T
  ), 2), "\nMean: ", round_(survey::svymean(as.formula(paste0("~", scale_name)),
                                            df,
                                            na.rm = T
  )[1], 2), "  SD: ", round_(sqrt(survey::svyvar(as.formula(paste0("~", scale_name)),
                                                 df,
                                                 na.rm = T
  )[1]), 2)))
  
  # Print histograms of items and scale
  if (print_hist) {
    hist_vars <- c(scale_name, paste0(scale_items, "num"))
    df2 <- NULL
    for (i in 1:length(hist_vars)) {
      x <- as.data.frame(survey::svytable(
        as.formula(paste0("~round(", hist_vars[i], ")")),
        df
      ))
      x$var <- stringr::str_split(names(x[1]), "\\.")[[1]][2]
      colnames(x)[1] <- "val"
      df2 %<>% rbind(x)
    }
    print(ggplot2::ggplot(df2, ggplot2::aes(.data$val, y = .data$Freq)) +
            ggplot2::geom_bar(stat = "identity") +
            ggplot2::facet_wrap(~var))
  }
  return(df)
}

# Helper function for calculating Cronbach's alpha
.scale_formula <- function(items) {
  x <- paste0("~", paste(items, "+", collapse = ""))
  stringr::str_sub(x, 1, stringr::str_length(x) - 2)
}
library(magrittr)
library(dplyr)

handler <- function(var_name, operator, value, result_file = NULL){
  
  expr <- glue::glue("{var_name} {operator} {value}")
  
  expr <- rlang::parse_expr(expr)
  
  data <- mtcars %>% 
    dplyr::filter(rlang::eval_bare(expr))

  if (! rlang::is_null(result_file)){

    is_s3 <- botor::check_s3_uri(result_file) == TRUE

    if (! is_s3){
      stop(glue::glue("The address `{result_file}` does not look like S3 address. Cannot save to file."))
    }

    data_csv <- vroom::vroom_format(mtcars, delim = ",")

    aws.s3::put_object(data_csv,                       
                       aws.s3::get_objectkey(result_file),
                       aws.s3::get_bucketname(result_file))
  } else {
    result_file = NA
  }

  body <- list(number_of_rows = nrow(data),
               result_file = result_file)
    
  l <- list(statusCode = 200,
            header = list("Content-Type" = "application/json"),
            body = body)

  return(l)          
}

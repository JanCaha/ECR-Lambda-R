library(glue)
library(httr)
library(jsonlite)
library(rlang)
library(logging)

aws_lambda_runtime_api <- function() {
  return(Sys.getenv("AWS_LAMBDA_RUNTIME_API"))
}

api_endpoint <- function() {
  return(glue::glue("http://", aws_lambda_runtime_api(), "/2018-06-01/runtime/"))
}

to_str <- function(x) {
  output <- capture.output(print(x))
  
  return(glue::glue_collapse(output, sep = "\n"))
}

error_to_payload <- function(error) {
  return(list(errorMessage = toString(error), 
              errorType = class(error)[1]))
}

post_error <- function(error, url) {
  logging::logerror(error, logger = 'runtime')
  
  res <- httr::POST(url,
              add_headers("Lambda-Runtime-Function-Error-Type" = "Unhandled"),
              body = jsonlite::toJSON(error_to_payload(error), auto_unbox = TRUE),
              encode = "raw")

  error_log <- glue::glue_collapse(error_to_payload(error), sep="\n")

  logging::logdebug(glue::glue("Posted result:\n", res$status_code, "\n", error_log),logger = 'runtime')
}

get_source_file_name <- function(file_base_name) {
  
  file_name <- glue::glue(file_base_name, ".R")
  
  if (! file.exists(file_name)) {
    file_name <- glue::glue(file_base_name, ".r")
  }
  
  if (! file.exists(file_name)) {
    stop(glue::glue('Source file does not exist: ', file_base_name, '.[R|r]'))
  }
  
  return(file_name)
}

invoke_lambda <- function(EVENT_DATA, function_name) {
  
  params <- jsonlite::fromJSON(EVENT_DATA)
  
  logging::logdebug(glue::glue("Invoking function '", function_name, "' with parameters:\n", to_str(params)), logger = 'runtime')
  
  function_args <- rlang::fn_fmls_names(rlang::as_closure(function_name))
  
  event_names <- names(params)
  
  for (event_name in event_names){
    if (! event_name %in% function_args){
      stop(glue::glue("'", event_name, "' parameter specified but does not exist in definition of lambda function."))
    }
  }
  
  result <- rlang::exec(function_name, !!!params) 

  logging::logdebug(glue::glue("Function returned:\n", to_str(result)), logger = 'runtime')
  
  return(result)
}

initializeLogging <- function() {
  
  logging::basicConfig()
  
  logging::addHandler(writeToConsole, logger='runtime')
  
  log_level <- Sys.getenv('LOGLEVEL', unset = NA)
  
  if (!is.na(log_level)) {
    logging::setLevel(log_level, 'runtime')
  }
}

initializeRuntime <- function() {

  initializeLogging()
  
  HANDLER_ENV <- Sys.getenv("_HANDLER")
  
  HANDLER_split <- strsplit(HANDLER_ENV, ".", fixed = TRUE)[[1]]
  
  file_base_name <- HANDLER_split[1]
  
  file_name <- get_source_file_name(file_base_name)

  logging::logdebug(glue::glue("Sourcing '", file_name, "'"), logger = 'runtime')
  
  source(file_name)

  function_name <- HANDLER_split[2]
  
  if (!exists(function_name, mode = "function")) {
    
    stop(glue::glue("Function '", function_name, "' does not exist."))
  }

  return(function_name)
}


throwInitError <- function(error) {
  
  url <- glue::glue(api_endpoint(), "init/error")
  
  post_error(error, url)
  
  stop()
}

throwRuntimeError <- function(error, REQUEST_ID) {
  
  url <- glue::glue(api_endpoint(), "invocation/", REQUEST_ID, "/error")
  
  post_error(error, url)
}

postResult <- function(result, REQUEST_ID) {
  
  url <- glue::glue(api_endpoint(), "invocation/", REQUEST_ID, "/response")
  
  res <- httr::POST(url, 
                    body = jsonlite::toJSON(result, auto_unbox = TRUE), 
                    encode = "raw")

  logdebug(glue::glue("Posted result:\n", res$status_code), logger = 'runtime')
}

handle_request <- function(function_name) {
  
  event_url <- glue::glue(api_endpoint(), "invocation/next")
  
  event_response <- httr::GET(event_url)
  
  REQUEST_ID <- event_response$headers$`Lambda-Runtime-Aws-Request-Id`
  
  tryCatch({
    
    EVENT_DATA <- rawToChar(event_response$content)

    result <- invoke_lambda(EVENT_DATA, function_name)

    postResult(result, REQUEST_ID)
  },
  
  error = function(error) {
    throwRuntimeError(error, REQUEST_ID)
  })
}

handler <- function(x) {

    body <- list(result = x + 1)
    
    l <- list(statusCode = 200,
              header = list("Content-Type" = "application/json"),
              body = body)

    return(l)
}

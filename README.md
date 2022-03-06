# AWS ECR Docker Image with R language runtime

This largely based on [bakdata/aws-lambda-r-runtime](https://github.com/bakdata/aws-lambda-r-runtime) only updated for AWS Lambda using ECR image instead of working only with the Lambda function. This removes limits on Lambda package size etc.

## What is in the image?  

The docker image contains installation of necessary libraries, **R**, **Python** (needed to support working with AWS even from R), **[AWS cli](https://aws.amazon.com/cli/)** and **[AWS RIE](https://docs.aws.amazon.com/lambda/latest/dg/images-test.html)**. This setup allows running and testing the Lambda functions locally.

R packages included are: 

- httr, logging, jsonlite, glue, rlang (these are needed for core runtime functions)
- botor, vroom, aws.s3 (installed from [https://RForge.net](https://RForge.net) - newer version then on CRAN) (these are useful to interact with S3 and other AWS resources)
- tidyverse, here, data.table, fs, remotes (these are generally useful tools to work with)
  
## Test Lambda functions

The image contains two lambda for testing purposes. They are store in `/lambda` directory.  

The lambda which will be run by default is specified in `Dockerfile` with lines:
```
WORKDIR /lambda/test
CMD [ "script.handler" ]
```
These can be override while calling `docker run` with `--workdir=""` and command (as normally for docker).

For example, the following command runs lambda function __test2__ instead of the default function __test__:

```bash
docker run -p 9000:8080 --workdir="/lambda/test2" lambda-r-ubuntu:latest script.handler 
```

### Testing Lambda functions 

## Lambda function in `/lambda/test`

Simple function which expects only one argument **x**, which needs to be numeric. The function adds 1 to the value a returns it as **result**.

Testing it locally should loook like this:

```bash
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{"x": 1}'
> {"statusCode":200,"header":{"Content-Type":"application/json"},"body":{"result":2}}
```

```bash
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{"x": "a"}'
> {"errorMessage":"Error in x + 1: non-numeric argument to binary operator\n","errorType":"simpleError"}
```

## Lambda function in `/lambda/test2`

The second example is significantly more complex function. It expects three necessary arguments and one optional. These are **var_name**, **operator**, **value** and **result_file** (with default value `NULL`). These inputs are used to filter data using `dplyr::filter()` on R example dataset `mtcars`. **var_name** and **operator** are specified as characters and **value** can be numeric of character. If **result_file** is specified it is check if it is valid S3 location and if so the result of the filter is stored in the provided file as **csv**. The default value for **result_file** means that the file should not be saved.

The result from the functions are **number_of_rows** and **result_file**. **number_of_rows** specifies number of rows in result of the query and **result_file** returns location of the file (if it was provided) or `null`.

The results from the function look like this:

```bash
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{"var_name": "mpg", "operator": ">", "value": 20}'
>{"statusCode":200,"header":{"Content-Type":"application/json"},"body":{"number_of_rows":14,"result_file":null}}
```

```bash
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{"var_name": "mpg", "operator": ">", "value": 20, "result_file": "a.csv"}'
>{"errorMessage":"Error in handler(var_name = \"mpg\", operator = \">\", value = 20L, result_file = \"a.csv\"): The address `a.csv` does not look like S3 address. Cannot save to file.\n","errorType":"simpleError"}
```

```bash
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{"var_name": "mpg", "operator": ">", "value": 20, "result_file": "s3://bucket/path/file.csv"}
>{"statusCode":200,"header":{"Content-Type":"application/json"},"body":{"number_of_rows":14,"result_file":"s3://bucket/path/file.csv"}}
```
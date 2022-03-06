from functions import run_lambda_docker, assert_response


def test_lambda_function_1():

    lambda_response = run_lambda_docker('{"var_name": "mpg", "operator": ">", "value": 20}')

    assert_response(lambda_response, {"number_of_rows": 14, "result_file": None})


def test_lambda_function_2():

    lambda_response = run_lambda_docker('{"x": "a"}')

    assert_response(
        lambda_response, {
            'errorMessage':
                "Error in invoke_lambda(EVENT_DATA, function_name): 'x' parameter specified but does not exist in definition of lambda function.\n",
            'errorType':
                'simpleError'
        })


def test_lambda_function_3():

    lambda_response = run_lambda_docker(
        '{"var_name": "mpg", "operator": ">", "value": 20, "result_file": "a.csv"}')

    assert_response(
        lambda_response, {
            "errorMessage":
                "Error in handler(var_name = \"mpg\", operator = \">\", value = 20L, result_file = \"a.csv\"): The address `a.csv` does not look like S3 address. Cannot save to file.\n",
            "errorType":
                "simpleError"
        })

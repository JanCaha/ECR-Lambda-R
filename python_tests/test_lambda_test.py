from functions import run_lambda_docker, assert_response


def test_lambda_function_1():

    lambda_response = run_lambda_docker('{"x": 1}')

    assert_response(lambda_response, 200, {'result': 2})


def test_lambda_function_2():

    lambda_response = run_lambda_docker('{"x": "a"}')

    assert_response(
        lambda_response, 200, {
            'errorMessage': 'Error in x + 1: non-numeric argument to binary operator\n',
            'errorType': 'simpleError'
        })

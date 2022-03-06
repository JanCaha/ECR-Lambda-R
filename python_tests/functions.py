from typing import Dict, Any
import requests
import json


def run_lambda_docker(data: Dict[str, Any]) -> requests.models.Response:

    headers = {
        'Content-type': 'application/json',
    }

    response = requests.get('http://localhost:9000/2015-03-31/functions/function/invocations',
                            headers=headers,
                            data=data)

    return response


def assert_response(response: requests.models.Response, content: Dict) -> None:
    print(json.loads(response.content))
    assert json.loads(response.content) == content

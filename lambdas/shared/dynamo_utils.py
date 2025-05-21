import boto3
import os

dynamo = boto3.client('dynamodb')
TABLE_NAME = os.environ['TABLE_NAME']

def get_lookup_id(key: str) -> str:
    response = dynamo.get_item(
        TableName=TABLE_NAME,
        Key={'id-z': {'S': key}}
    )
    return response['Item']['id-a']['S']

def put_lookup_id(key_a: str, key_z: str) -> None:
    dynamo.put_item(
        TableName=TABLE_NAME,
        Item={
            'id-a': {'S': key_a},
            'id-z': {'S': key_z}
        }
    )

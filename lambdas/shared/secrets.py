import boto3
from botocore.exceptions import ClientError
import os

def get_secret(secret_name: str, region_name: str = None) -> str:
    region = region_name or os.environ.get('REGION_NAME')
    session = boto3.session.Session()
    client = session.client('secretsmanager', region_name=region)
    
    try:
        response = client.get_secret_value(SecretId=secret_name,VersionStage='AWSCURRENT')
        return response['SecretString']
    except ClientError as e:
        raise Exception(f"Unable to retrieve secret: {e}")

import boto3
import sys
from dotenv import load_dotenv, find_dotenv
import os

def send_email(recipient, subject, body):
    # Load environment variables from .env file
    dotenv_path = os.path.join(os.path.dirname(__file__), '.env')
    print("Loading environment variables from:", dotenv_path)

    if not os.path.exists(dotenv_path):
        raise FileNotFoundError(f".env file not found at path: {dotenv_path}")

    load_dotenv(dotenv_path, override=True)

    aws_access_key_id = os.getenv('AWS_ACCESS_KEY_ID')
    aws_secret_access_key = os.getenv('AWS_SECRET_ACCESS_KEY')

    if not aws_access_key_id or not aws_secret_access_key:
        raise ValueError("AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set in the .env file")

    # Print the loaded keys for debugging purposes
    print("Loaded AWS_ACCESS_KEY_ID:", aws_access_key_id)
    print("Loaded AWS_SECRET_ACCESS_KEY:", aws_secret_access_key)

    ses_client = boto3.client(
        'ses',
        region_name='us-east-1',  # Change the region if needed
        aws_access_key_id=aws_access_key_id,
        aws_secret_access_key=aws_secret_access_key
    )

    response = ses_client.send_email(
        Source='dev-support@tuum.tech',
        Destination={
            'ToAddresses': [
                recipient,
            ]
        },
        Message={
            'Subject': {
                'Data': subject,
                'Charset': 'UTF-8'
            },
            'Body': {
                'Text': {
                    'Data': body,
                    'Charset': 'UTF-8'
                }
            }
        }
    )

    return response

if __name__ == '__main__':
    recipient = sys.argv[1]
    subject = sys.argv[2]
    body = sys.argv[3]

    send_email(recipient, subject, body)

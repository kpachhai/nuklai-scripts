import boto3
import sys

def send_email(subject, body, recipient):
    ses_client = boto3.client('ses', region_name='us-east-1')  # Change the region if needed

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
    subject = sys.argv[1]
    body = sys.argv[2]
    recipient = sys.argv[3]

    send_email(subject, body, recipient)

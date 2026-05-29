import json
import os
import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])
    job_id = event.get('pathParameters', {}).get('job_id')

    if not job_id:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'job_id is required'})
        }

    response = table.get_item(Key={'job_id': job_id})
    item = response.get('Item')

    if not item:
        return {
            'statusCode': 404,
            'body': json.dumps({'error': 'Job not found'})
        }

    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({
            'job_id': item['job_id'],
            'status': item['status'],
            'filename': item.get('filename'),
            'created_at': item.get('created_at'),
            'updated_at': item.get('updated_at'),
            'thumbnail_key': item.get('thumbnail_key'),
            'error_message': item.get('error_message')
        })
    }
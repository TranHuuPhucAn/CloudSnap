import json
import uuid
import boto3
import os
from datetime import datetime, timezone

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    bucket = os.environ['RAW_UPLOADS_BUCKET']
    table_name = os.environ['DYNAMODB_TABLE']

    body = json.loads(event.get('body', '{}'))
    filename = body.get('filename')
    content_type = body.get('content_type', 'image/jpeg')

    if not filename:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'filename is required'})
        }

    job_id = str(uuid.uuid4())
    s3_key = f"uploads/{job_id}/{filename}"

    presigned_url = s3.generate_presigned_url(
        'put_object',
        Params={
            'Bucket': bucket,
            'Key': s3_key,
            'ContentType': content_type
        },
        ExpiresIn=3600
    )

    table = dynamodb.Table(table_name)
    now = datetime.now(timezone.utc)
    table.put_item(Item={
        'job_id': job_id,
        'status': 'PENDING',
        's3_key': s3_key,
        'filename': filename,
        'created_at': now.isoformat(),
        'expires_at': int(now.timestamp()) + (7 * 24 * 60 * 60)
    })

    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({
            'job_id': job_id,
            'upload_url': presigned_url,
            's3_key': s3_key
        })
    }
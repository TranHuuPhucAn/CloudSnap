# src/processor/handler.py

import json
import os
import io
import boto3
from PIL import Image
from datetime import datetime, timezone

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

def update_job_status(table, job_id, status, extra_fields=None):
    """Helper to update DynamoDB job status cleanly."""
    update_expr = 'SET #s = :s, updated_at = :u'
    attr_names = {'#s': 'status'}  
    attr_values = {
        ':s': status,
        ':u': datetime.now(timezone.utc).isoformat()
    }

    if extra_fields:
        for key, value in extra_fields.items():
            update_expr += f', {key} = :{key}'
            attr_values[f':{key}'] = value

    table.update_item(
        Key={'job_id': job_id},
        UpdateExpression=update_expr,
        ExpressionAttributeNames=attr_names,
        ExpressionAttributeValues=attr_values
    )

def lambda_handler(event, context):
    table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])
    processed_bucket = os.environ['PROCESSED_BUCKET']
    sns_topic_arn = os.environ['SNS_TOPIC_ARN']

    for record in event['Records']:
        # SQS wraps the S3 event as a JSON string in the body
        body = json.loads(record['body'])
        s3_records = body.get('Records', [])

        for s3_record in s3_records:
            raw_bucket = s3_record['s3']['bucket']['name']
            s3_key = s3_record['s3']['object']['key']

            # Key format is: uploads/{job_id}/{filename}
            parts = s3_key.split('/')
            job_id = parts[1]
            filename = parts[2]

            try:
                # Mark job as in-progress
                update_job_status(table, job_id, 'PROCESSING')

                # Download the raw image from S3
                response = s3.get_object(Bucket=raw_bucket, Key=s3_key)
                image_data = response['Body'].read()

                # Generate thumbnail
                image = Image.open(io.BytesIO(image_data))
                original_format = image.format or 'JPEG'
                image.thumbnail((200, 200))

                # Save thumbnail to an in-memory buffer
                buffer = io.BytesIO()
                image.save(buffer, format=original_format)
                buffer.seek(0)

                # Upload thumbnail to the processed bucket
                thumbnail_key = f"thumbnails/{job_id}/{filename}"
                s3.put_object(
                    Bucket=processed_bucket,
                    Key=thumbnail_key,
                    Body=buffer,
                    ContentType=f'image/{original_format.lower()}'
                )

                # Mark job as complete and record where the thumbnail lives
                update_job_status(table, job_id, 'COMPLETED', {
                    'thumbnail_key': thumbnail_key
                })

                # Send success email via SNS
                sns.publish(
                    TopicArn=sns_topic_arn,
                    Subject='CloudSnap: Processing Complete ✅',
                    Message=(
                        f'Job {job_id} completed successfully.\n\n'
                        f'Original: s3://{raw_bucket}/{s3_key}\n'
                        f'Thumbnail: s3://{processed_bucket}/{thumbnail_key}'
                    )
                )

            except Exception as e:
                update_job_status(table, job_id, 'FAILED', {'error_message': str(e)})
                raise
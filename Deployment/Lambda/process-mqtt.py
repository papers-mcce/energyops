import json
import boto3
from datetime import datetime

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('SensorData')

def lambda_handler(event, context):
    # Process the incoming MQTT message
    print(f"Received event: {json.dumps(event)}")
    
    # Extract data from the MQTT message
    timestamp = datetime.now().isoformat()
    device_id = event.get('device_id', 'unknown')
    temperature = event.get('temperature')
    humidity = event.get('humidity')
    
    # Store in DynamoDB
    response = table.put_item(
        Item={
            'device_id': device_id,
            'timestamp': timestamp,
            'temperature': temperature,
            'humidity': humidity
        }
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps('Data processed successfully!')
    }
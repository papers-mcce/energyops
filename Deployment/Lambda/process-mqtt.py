import json
import boto3
import os
from datetime import datetime
from decimal import Decimal

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('DYNAMODB_TABLE', 'SensorData')
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    Process Tasmota MQTT messages containing energy data
    Expected message structure from tele/+/SENSOR topic
    
    Ensures all timestamps are stored in microsecond format (YYYY-MM-DDTHH:MM:SS.ffffff)
    for SQL query compatibility.
    """
    print(f"Received event: {json.dumps(event, default=str)}")
    
    try:
        # Extract topic to get device name
        topic = event.get('topic', '')
        device_name = extract_device_name(topic)
        
        # Get timestamps
        device_time = event.get('Time', '')
        aws_timestamp_raw = event.get('aws_timestamp', datetime.now())
        
        # Ensure timestamp always has microseconds format for SQL compatibility
        aws_timestamp = ensure_microsecond_timestamp(aws_timestamp_raw)
        
        # Extract energy data if present
        energy_data = event.get('ENERGY', {})
        
        if not energy_data:
            print("No ENERGY data found in message, skipping...")
            return {
                'statusCode': 200,
                'body': json.dumps('No energy data to process')
            }
        
        # Convert float values to Decimal for DynamoDB
        item = {
            'device_id': device_name,
            'timestamp': aws_timestamp,  # Timestamp with microseconds format: YYYY-MM-DDTHH:MM:SS.ffffff
            'device_time': device_time,
            'total_energy': convert_to_decimal(energy_data.get('Total', 0)),
            'today_energy': convert_to_decimal(energy_data.get('Today', 0)),
            'yesterday_energy': convert_to_decimal(energy_data.get('Yesterday', 0)),
            'current_power': convert_to_decimal(energy_data.get('Power', 0)),
            'apparent_power': convert_to_decimal(energy_data.get('ApparentPower', 0)),
            'reactive_power': convert_to_decimal(energy_data.get('ReactivePower', 0)),
            'power_factor': convert_to_decimal(energy_data.get('Factor', 0)),
            'voltage': convert_to_decimal(energy_data.get('Voltage', 0)),
            'current': convert_to_decimal(energy_data.get('Current', 0)),
            'period': convert_to_decimal(energy_data.get('Period', 0)),
            'total_start_time': energy_data.get('TotalStartTime', '')
        }
        
        # Add analog data if present
        analog_data = event.get('ANALOG', {})
        if analog_data:
            item['analog_a0'] = convert_to_decimal(analog_data.get('A0', 0))
        
        # Store in DynamoDB
        response = table.put_item(Item=item)
        
        print(f"Successfully stored data for device: {device_name}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Energy data processed successfully',
                'device': device_name,
                'power': float(energy_data.get('Power', 0)),
                'total_energy': float(energy_data.get('Total', 0))
            })
        }
        
    except Exception as e:
        print(f"Error processing MQTT message: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error processing data: {str(e)}')
        }

def extract_device_name(topic):
    """
    Extract device name from MQTT topic
    Example: tele/serverpowermeter/SENSOR -> serverpowermeter
    """
    try:
        parts = topic.split('/')
        if len(parts) >= 2:
            return parts[1]  # Device name is the second part
        return 'unknown_device'
    except:
        return 'unknown_device'

def ensure_microsecond_timestamp(timestamp_input):
    """
    Ensure timestamp is in microsecond format: YYYY-MM-DDTHH:MM:SS.ffffff
    Accepts various input formats and normalizes them
    """
    try:
        if isinstance(timestamp_input, (int, float)):
            # Unix timestamp (milliseconds)
            dt = datetime.fromtimestamp(timestamp_input / 1000)
        elif isinstance(timestamp_input, str):
            # ISO string - try to parse it
            try:
                dt = datetime.fromisoformat(timestamp_input.replace('Z', '+00:00'))
            except:
                # If parsing fails, use current time
                dt = datetime.now()
        elif isinstance(timestamp_input, datetime):
            # Already a datetime object
            dt = timestamp_input
        else:
            # Fallback to current time
            dt = datetime.now()
        
        # Return formatted string with microseconds
        return dt.strftime('%Y-%m-%dT%H:%M:%S.%f')
    except:
        # Ultimate fallback
        return datetime.now().strftime('%Y-%m-%dT%H:%M:%S.%f')

def convert_to_decimal(value):
    """
    Convert numeric values to Decimal for DynamoDB compatibility
    """
    try:
        if value is None:
            return Decimal('0')
        return Decimal(str(value))
    except:
        return Decimal('0')
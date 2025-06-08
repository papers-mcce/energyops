import json
import boto3
import requests
import os
from datetime import datetime
from decimal import Decimal

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('EnergyLiveData')

# OBIS code mapping
OBIS_CODES = {
    '0100010700': {
        'name': 'active_power_plus',
        'description': 'Active power (P+)',
        'unit': 'W'
    },
    '0100010800': {
        'name': 'active_energy_plus',
        'description': 'Active energy (E+)',
        'unit': 'Wh'
    },
    '0100020700': {
        'name': 'active_power_minus',
        'description': 'Active power (P-)',
        'unit': 'W'
    },
    '0100020800': {
        'name': 'active_energy_minus',
        'description': 'Active energy (E-)',
        'unit': 'Wh'
    }
}

def lambda_handler(event, context):
    """
    Lambda function to fetch data from energyLIVE API and store in DynamoDB
    
    Environment variables required:
    - API_KEY: energyLIVE API key
    - DEVICE_UID: Interface UID (e.g., I-10082023-01658401)
    """
    
    try:
        # Get configuration from environment variables
        api_key = os.environ.get('API_KEY')
        device_uid = os.environ.get('DEVICE_UID')
        
        if not api_key or not device_uid:
            raise ValueError("API_KEY and DEVICE_UID environment variables are required")
        
        # energyLIVE API endpoint
        api_url = f"https://backend.energylive.e-steiermark.com/api/v1/devices/{device_uid}/measurements/latest"
        
        # Headers for the API request
        headers = {
            'X-API-KEY': api_key,
            'Content-Type': 'application/json'
        }
        
        print(f"Fetching data from energyLIVE API for device: {device_uid}")
        
        # Make API request
        response = requests.get(api_url, headers=headers, timeout=30)
        response.raise_for_status()
        
        # Parse JSON response
        measurements = response.json()
        
        if not measurements:
            print("No measurements received from API")
            return {
                'statusCode': 200,
                'body': json.dumps('No measurements to process')
            }
        
        # Process and store each measurement
        stored_count = 0
        for measurement in measurements:
            try:
                # Extract measurement data
                obis_code = measurement.get('measurement')
                timestamp = measurement.get('timestamp')
                value = measurement.get('value')
                
                if not all([obis_code, timestamp, value is not None]):
                    print(f"Skipping incomplete measurement: {measurement}")
                    continue
                
                # Get OBIS code information
                obis_info = OBIS_CODES.get(obis_code, {
                    'name': obis_code,
                    'description': f'Unknown measurement ({obis_code})',
                    'unit': 'unknown'
                })
                
                # Convert timestamp to ISO format for better readability
                dt = datetime.fromtimestamp(timestamp / 1000)  # Convert from ms to seconds
                iso_timestamp = dt.isoformat()
                
                # Convert float to Decimal for DynamoDB
                decimal_value = Decimal(str(value))
                
                # Create item for DynamoDB
                item = {
                    'device_id': device_uid,
                    'timestamp': timestamp,  # Keep original timestamp as sort key
                    'iso_timestamp': iso_timestamp,
                    'obis_code': obis_code,
                    'measurement_name': obis_info['name'],
                    'description': obis_info['description'],
                    'unit': obis_info['unit'],
                    'value': decimal_value,
                    'collection_time': datetime.now().isoformat(),
                    'ttl': int((datetime.now().timestamp() + (365 * 24 * 60 * 60)))  # 1 year TTL
                }
                
                # Store in DynamoDB
                table.put_item(Item=item)
                stored_count += 1
                
                print(f"Stored measurement: {obis_info['description']} = {value} {obis_info['unit']} at {iso_timestamp}")
                
            except Exception as e:
                print(f"Error processing measurement {measurement}: {str(e)}")
                continue
        
        print(f"Successfully stored {stored_count} measurements")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully processed {stored_count} measurements',
                'device_id': device_uid,
                'measurements_processed': stored_count
            })
        }
        
    except requests.exceptions.RequestException as e:
        print(f"API request error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'API request failed: {str(e)}')
        }
    
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        } 
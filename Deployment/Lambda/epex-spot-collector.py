import json
import boto3
import requests
import os
from datetime import datetime, timezone
from decimal import Decimal
import dateutil.parser

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('EPEXSpotPrices')

def lambda_handler(event, context):
    """
    Lambda function to fetch EPEX Spot prices from smartENERGY API and store in DynamoDB
    
    No environment variables required - the API is free and public
    """
    
    try:
        # smartENERGY API endpoint
        api_url = "https://apis.smartenergy.at/market/v1/price"
        
        # Headers for the API request
        headers = {
            'User-Agent': 'AWS-Lambda-EPEX-Collector/1.0',
            'Accept': 'application/json'
        }
        
        print(f"Fetching EPEX Spot prices from smartENERGY API")
        
        # Make API request
        response = requests.get(api_url, headers=headers, timeout=30)
        response.raise_for_status()
        
        # Parse JSON response
        price_data = response.json()
        
        if not price_data or 'data' not in price_data:
            print("No price data received from API")
            return {
                'statusCode': 200,
                'body': json.dumps('No price data to process')
            }
        
        # Extract metadata
        tariff = price_data.get('tariff', 'EPEXSPOTAT')
        unit = price_data.get('unit', 'ct/kWh')
        interval = price_data.get('interval', 15)
        
        print(f"Processing {tariff} prices in {unit} with {interval}-minute intervals")
        
        # Process and store each price entry
        stored_count = 0
        for price_entry in price_data['data']:
            try:
                # Extract price data
                date_str = price_entry.get('date')
                value = price_entry.get('value')
                
                if not all([date_str, value is not None]):
                    print(f"Skipping incomplete price entry: {price_entry}")
                    continue
                
                # Parse the date string to datetime object
                dt = dateutil.parser.parse(date_str)
                
                # Convert to Unix timestamp (milliseconds) for consistency with energyLIVE data
                timestamp_ms = int(dt.timestamp() * 1000)
                
                # Create ISO timestamp for readability
                iso_timestamp = dt.isoformat()
                
                # Convert price to Decimal for DynamoDB
                decimal_value = Decimal(str(value))
                
                # Create item for DynamoDB
                item = {
                    'tariff': tariff,
                    'timestamp': timestamp_ms,  # Primary sort key
                    'iso_timestamp': iso_timestamp,
                    'date_local': date_str,  # Original date string with timezone
                    'price': decimal_value,
                    'unit': unit,
                    'interval_minutes': interval,
                    'collection_time': datetime.now().isoformat(),
                    'ttl': int((datetime.now().timestamp() + (365 * 24 * 60 * 60)))  # 1 year TTL
                }
                
                # Store in DynamoDB (use conditional write to avoid duplicates)
                table.put_item(
                    Item=item,
                    ConditionExpression='attribute_not_exists(#ts)',
                    ExpressionAttributeNames={'#ts': 'timestamp'}
                )
                stored_count += 1
                
                print(f"Stored price: {value} {unit} for {iso_timestamp}")
                
            except boto3.client('dynamodb').exceptions.ConditionalCheckFailedException:
                # Item already exists, skip
                print(f"Price for {date_str} already exists, skipping")
                continue
            except Exception as e:
                print(f"Error processing price entry {price_entry}: {str(e)}")
                continue
        
        print(f"Successfully stored {stored_count} new price entries")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully processed {stored_count} price entries',
                'tariff': tariff,
                'unit': unit,
                'interval_minutes': interval,
                'prices_processed': stored_count,
                'total_entries_received': len(price_data['data'])
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
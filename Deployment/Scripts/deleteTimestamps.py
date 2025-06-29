# This script is used to delete items from the SensorData table that have a timestamp 
# without microseconds.
# It is used to clean up the table after the migration to the new format.

import boto3
import time
from botocore.exceptions import ClientError

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('SensorData')

print("Checking table schema...")

# Get table description to find primary key
table_description = table.meta.client.describe_table(TableName='SensorData')
key_schema = table_description['Table']['KeySchema']

print("Table key schema:")
for key in key_schema:
    print(f"  {key['AttributeName']} ({key['KeyType']})")

# Find the partition key and sort key
partition_key_name = None
sort_key_name = None
for key in key_schema:
    if key['KeyType'] == 'HASH':  # Partition key
        partition_key_name = key['AttributeName']
    elif key['KeyType'] == 'RANGE':  # Sort key
        sort_key_name = key['AttributeName']

if not partition_key_name or not sort_key_name:
    print("ERROR: Could not find partition key or sort key")
    exit(1)

print(f"Partition key: {partition_key_name}")
print(f"Sort key: {sort_key_name}")

print("Scanning DynamoDB table...")

# Count items without microseconds
count_without_microseconds = 0
items_to_delete = []
total_scanned = 0

def scan_with_retry(exclusive_start_key=None):
    """Scan with exponential backoff for throughput exceptions"""
    max_retries = 5
    base_delay = 1
    
    for attempt in range(max_retries):
        try:
            if exclusive_start_key:
                response = table.scan(
                    ExclusiveStartKey=exclusive_start_key,
                    ProjectionExpression='#pk, #sk',
                    ExpressionAttributeNames={
                        '#pk': partition_key_name, 
                        '#sk': sort_key_name
                    }
                )
            else:
                response = table.scan(
                    ProjectionExpression='#pk, #sk',
                    ExpressionAttributeNames={
                        '#pk': partition_key_name, 
                        '#sk': sort_key_name
                    }
                )
            return response
        except ClientError as e:
            if e.response['Error']['Code'] == 'ProvisionedThroughputExceededException':
                if attempt < max_retries - 1:
                    delay = base_delay * (2 ** attempt)  # Exponential backoff
                    print(f"Throughput exceeded, waiting {delay} seconds...")
                    time.sleep(delay)
                else:
                    raise
            else:
                raise

# Scan with pagination to get all items
try:
    response = scan_with_retry()
    
    # Process first batch
    for item in response['Items']:
        total_scanned += 1
        timestamp = item[sort_key_name]  # Use sort key name
        if len(timestamp) == 19:  # No microseconds
            count_without_microseconds += 1
            # Use both partition key and sort key for deletion
            delete_key = {
                partition_key_name: item[partition_key_name],
                sort_key_name: item[sort_key_name]
            }
            items_to_delete.append(delete_key)
    
    # Continue scanning while there are more items
    while 'LastEvaluatedKey' in response:
        print(f"Scanned {total_scanned} items so far...")
        time.sleep(0.1)  # Small delay between scans
        
        response = scan_with_retry(response['LastEvaluatedKey'])
        
        for item in response['Items']:
            total_scanned += 1
            timestamp = item[sort_key_name]  # Use sort key name
            if len(timestamp) == 19:  # No microseconds
                count_without_microseconds += 1
                # Use both partition key and sort key for deletion
                delete_key = {
                    partition_key_name: item[partition_key_name],
                    sort_key_name: item[sort_key_name]
                }
                items_to_delete.append(delete_key)

except ClientError as e:
    if e.response['Error']['Code'] == 'ProvisionedThroughputExceededException':
        print("ERROR: DynamoDB throughput exceeded. Consider:")
        print("1. Increasing provisioned throughput")
        print("2. Running this script during off-peak hours")
        print("3. Using on-demand billing mode")
    else:
        print(f"ERROR: {e.response['Error']['Message']}")
    exit(1)

print(f"Total items scanned: {total_scanned}")
print(f"Found {count_without_microseconds} items without microseconds")

if count_without_microseconds > 0:
    # Show first few items to delete
    print("First 5 items to delete:")
    for item in items_to_delete[:5]:
        print(f"  {item}")
    
    # Ask for confirmation
    confirm = input("Do you want to delete these items? (yes/no): ")
    if confirm.lower() == 'yes':
        # Delete items with rate limiting
        deleted_count = 0
        for item in items_to_delete:
            try:
                table.delete_item(Key=item)
                deleted_count += 1
                if deleted_count % 50 == 0:  # Progress update every 50 items
                    print(f"Deleted {deleted_count} items...")
                    time.sleep(0.1)  # Small delay
            except ClientError as e:
                if e.response['Error']['Code'] == 'ProvisionedThroughputExceededException':
                    print(f"Throughput exceeded while deleting. Stopped at {deleted_count} items.")
                    break
                else:
                    print(f"Error deleting item: {e.response['Error']['Message']}")
        print(f"Successfully deleted {deleted_count} items")
    else:
        print("Deletion cancelled")
else:
    print("No items found without microseconds")
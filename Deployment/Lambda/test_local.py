#!/usr/bin/env python3
"""
Local test script for the energyLIVE Lambda function.
This script allows you to test the function locally before deploying to AWS.
"""

import os
import json
from unittest.mock import patch, MagicMock

# Mock AWS services for local testing
def mock_aws_services():
    """Mock AWS services for local testing"""
    
    # Mock DynamoDB
    mock_table = MagicMock()
    mock_table.put_item.return_value = {'ResponseMetadata': {'HTTPStatusCode': 200}}
    
    mock_dynamodb = MagicMock()
    mock_dynamodb.Table.return_value = mock_table
    
    return mock_table, mock_dynamodb

def test_lambda_function():
    """Test the Lambda function with mock data"""
    
    # Set environment variables for testing
    os.environ['API_KEY'] = 'test_api_key'
    os.environ['DEVICE_UID'] = 'I-10082023-01658401'
    
    # Mock response data (based on the API documentation)
    mock_api_response = [
        {
            "measurement": "0100010700",
            "timestamp": 1726559995000,
            "value": 138.0
        },
        {
            "measurement": "0100010800", 
            "timestamp": 1726559995000,
            "value": 9577201.0
        },
        {
            "measurement": "0100020700",
            "timestamp": 1726559975000,
            "value": 0.0
        },
        {
            "measurement": "batteryVoltage",
            "timestamp": 1726559995000,
            "value": 3.2
        }
    ]
    
    # Mock the requests library
    mock_response = MagicMock()
    mock_response.json.return_value = mock_api_response
    mock_response.raise_for_status.return_value = None
    
    # Mock AWS services
    mock_table, mock_dynamodb = mock_aws_services()
    
    # Import and test the function with mocks
    with patch('requests.get', return_value=mock_response), \
         patch('boto3.resource', return_value=mock_dynamodb):
        
        # Import the function after setting up mocks
        from energylive_api_collector import lambda_handler
        
        # Test the function
        result = lambda_handler({}, {})
        
        # Verify the result
        print("Lambda function result:")
        print(json.dumps(result, indent=2))
        
        # Verify DynamoDB calls
        print(f"\nDynamoDB put_item called {mock_table.put_item.call_count} times")
        
        # Print the items that would be stored
        print("\nItems that would be stored in DynamoDB:")
        for call in mock_table.put_item.call_args_list:
            item = call[1]['Item']  # Get the Item from kwargs
            print(f"- {item['measurement_type']}: {item['value']} at {item['iso_timestamp']}")
        
        return result

def test_error_handling():
    """Test error handling scenarios"""
    
    print("\n" + "="*50)
    print("Testing error handling scenarios")
    print("="*50)
    
    # Test missing environment variables
    print("\n1. Testing missing environment variables...")
    
    # Clear environment variables
    if 'API_KEY' in os.environ:
        del os.environ['API_KEY']
    if 'DEVICE_UID' in os.environ:
        del os.environ['DEVICE_UID']
    
    mock_table, mock_dynamodb = mock_aws_services()
    
    with patch('boto3.resource', return_value=mock_dynamodb):
        from energylive_api_collector import lambda_handler
        
        result = lambda_handler({}, {})
        print(f"Result: {result}")
        assert result['statusCode'] == 500
        assert 'API_KEY and DEVICE_UID environment variables are required' in result['body']
    
    print("✓ Missing environment variables handled correctly")
    
    # Test API error
    print("\n2. Testing API error...")
    
    os.environ['API_KEY'] = 'test_api_key'
    os.environ['DEVICE_UID'] = 'I-10082023-01658401'
    
    mock_response = MagicMock()
    mock_response.raise_for_status.side_effect = Exception("API Error")
    
    with patch('requests.get', return_value=mock_response), \
         patch('boto3.resource', return_value=mock_dynamodb):
        
        result = lambda_handler({}, {})
        print(f"Result: {result}")
        assert result['statusCode'] == 500
    
    print("✓ API error handled correctly")

if __name__ == "__main__":
    print("Testing energyLIVE Lambda function locally...")
    print("="*50)
    
    try:
        # Test normal operation
        result = test_lambda_function()
        
        if result['statusCode'] == 200:
            print("\n✓ Lambda function test passed!")
        else:
            print(f"\n✗ Lambda function test failed: {result}")
        
        # Test error scenarios
        test_error_handling()
        
        print("\n" + "="*50)
        print("All tests completed successfully!")
        print("="*50)
        
    except ImportError as e:
        print(f"\n✗ Import error: {e}")
        print("Make sure the energylive-api-collector.py file is in the same directory")
        print("and rename it to energylive_api_collector.py for local testing")
    except Exception as e:
        print(f"\n✗ Test failed: {e}")
        import traceback
        traceback.print_exc() 
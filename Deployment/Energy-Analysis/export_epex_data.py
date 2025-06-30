#!/usr/bin/env python3
"""
EPEX Spot Price Data Export Script
==================================

This script exports electricity price data from the EPEXSpotPrices DynamoDB table
for analysis and correlation with energy consumption measurements.

Features:
- Export EPEX spot prices for specific date ranges
- Convert UTC timestamps to local time
- Calculate price statistics and variations
- Export to multiple formats (JSON, CSV, LaTeX)
- Correlate prices with energy consumption test periods

Author: Generated for G1-S2-INENI Project
"""

import boto3
import json
import statistics
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Dict, List, Tuple, Optional
import pandas as pd
from botocore.exceptions import ClientError

class EPEXDataExporter:
    """Class to export and analyze EPEX spot price data from DynamoDB"""
    
    def __init__(self, table_name: str = 'EPEXSpotPrices', tariff: str = 'EPEXSPOTAT'):
        """
        Initialize the EPEX data exporter
        
        Args:
            table_name: Name of the DynamoDB table
            tariff: Tariff type to filter (default: EPEXSPOTAT for Austria)
        """
        self.dynamodb = boto3.resource('dynamodb')
        self.table = self.dynamodb.Table(table_name)
        self.tariff = tariff
        self.test_date = "2025-06-29"
        
        # Define test periods (in local time for reference)
        self.test_periods = {
            'WL1_CPU_Stress': {
                'name': 'CPU Stress Test',
                'local_start': '16:45',
                'local_end': '18:45',
                'utc_start': '14:45',
                'utc_end': '16:45'
            },
            'WL2_IO_Stress': {
                'name': 'I/O Stress Test', 
                'local_start': '18:45',
                'local_end': '19:45',
                'utc_start': '16:45',
                'utc_end': '17:45'
            },
            'WL3_Reboot': {
                'name': 'System Reboot',
                'local_start': '20:35',
                'local_end': '20:40',
                'utc_start': '18:35',
                'utc_end': '18:40'
            },
            'WL4_Maintenance': {
                'name': 'Maintenance Operations',
                'local_start': '22:30',
                'local_end': '22:35',
                'utc_start': '20:30',
                'utc_end': '20:35'
            },
            'WL5_Idle': {
                'name': 'Idle State',
                'local_start': '22:50',
                'local_end': '23:50',
                'utc_start': '20:50',
                'utc_end': '21:50'
            }
        }
    
    def discover_available_tariffs(self) -> List[str]:
        """Discover what tariffs are available in the table"""
        try:
            response = self.table.scan(
                ProjectionExpression='tariff',
                Limit=10
            )
            
            tariffs = list(set([item['tariff'] for item in response['Items']]))
            print(f"Available tariffs: {tariffs}")
            return tariffs
            
        except ClientError as e:
            print(f"Error discovering tariffs: {e}")
            return []
    
    def get_sample_data(self) -> None:
        """Get sample data to understand the table structure"""
        try:
            response = self.table.scan(Limit=5)
            
            if response['Items']:
                print(f"\n🔍 Sample EPEX data structure:")
                for i, item in enumerate(response['Items'][:3]):
                    print(f"  Sample {i+1}:")
                    for key, value in item.items():
                        print(f"    {key}: {value} (type: {type(value)})")
                    print()
            else:
                print("No data found in EPEX table")
                
        except ClientError as e:
            print(f"Error getting sample data: {e}")
    
    def query_prices_for_date(self, date: str) -> List[Dict]:
        """
        Query EPEX prices for a specific date
        
        Args:
            date: Date in YYYY-MM-DD format
            
        Returns:
            List of price data points
        """
        try:
            # Create timestamp range for the entire day (UTC)
            start_timestamp = int(datetime.strptime(f"{date}T00:00:00", "%Y-%m-%dT%H:%M:%S").timestamp() * 1000)
            end_timestamp = int(datetime.strptime(f"{date}T23:59:59", "%Y-%m-%dT%H:%M:%S").timestamp() * 1000)
            
            print(f"🔍 Querying EPEX prices for {date}")
            print(f"   Tariff: {self.tariff}")
            print(f"   Timestamp range: {start_timestamp} - {end_timestamp}")
            
            # Query DynamoDB for the date range
            response = self.table.query(
                KeyConditionExpression=boto3.dynamodb.conditions.Key('tariff').eq(self.tariff) &
                                     boto3.dynamodb.conditions.Key('timestamp').between(start_timestamp, end_timestamp),
                ScanIndexForward=True  # Sort by timestamp ascending
            )
            
            items = response['Items']
            print(f"   ✅ Found {len(items)} price data points")
            
            return items
            
        except ClientError as e:
            print(f"Error querying EPEX data: {e}")
            return []
    
    def convert_timestamp_to_local(self, timestamp_ms: int) -> str:
        """Convert Unix timestamp (ms) to local time string"""
        dt_utc = datetime.fromtimestamp(timestamp_ms / 1000, tz=timezone.utc)
        dt_local = dt_utc + timedelta(hours=2)  # Convert UTC to CET/CEST
        return dt_local.strftime("%Y-%m-%d %H:%M:%S")
    
    def convert_price_units(self, price_cent_per_kwh: float) -> Dict[str, float]:
        """
        Convert price from Euro cent per kWh to various units
        
        Args:
            price_cent_per_kwh: Price in Euro cent per kWh
            
        Returns:
            Dictionary with price in different units
        """
        return {
            'cent_per_kwh': round(price_cent_per_kwh, 3),
            'eur_per_kwh': round(price_cent_per_kwh / 100, 5),
            'eur_per_mwh': round(price_cent_per_kwh * 10, 2)  # 1 MWh = 1000 kWh, so cent/kWh * 10 = EUR/MWh
        }
    
    def analyze_price_data(self, price_data: List[Dict]) -> Dict:
        """Analyze the price data and calculate statistics"""
        
        if not price_data:
            return {'error': 'No price data available'}
        
        # Extract prices (in Euro cent per kWh) and convert to different units
        prices_cent_kwh = []
        prices_eur_mwh = []
        prices_eur_kwh = []
        timestamps_local = []
        
        for item in price_data:
            price_cent_kwh = float(item.get('price', 0))  # Original format: Euro cent per kWh
            timestamp_ms = item.get('timestamp', 0)
            local_time = self.convert_timestamp_to_local(timestamp_ms)
            
            # Convert to different units
            price_units = self.convert_price_units(price_cent_kwh)
            
            prices_cent_kwh.append(price_units['cent_per_kwh'])
            prices_eur_kwh.append(price_units['eur_per_kwh'])
            prices_eur_mwh.append(price_units['eur_per_mwh'])
            timestamps_local.append(local_time)
        
        if not prices_cent_kwh:
            return {'error': 'No valid price data found'}
        
        # Calculate statistics for different units
        analysis = {
            'data_points': len(prices_cent_kwh),
            'data_interval': '15 minutes',
            'price_stats_cent_kwh': {
                'min_price': round(min(prices_cent_kwh), 3),
                'max_price': round(max(prices_cent_kwh), 3),
                'avg_price': round(statistics.mean(prices_cent_kwh), 3),
                'median_price': round(statistics.median(prices_cent_kwh), 3),
                'std_dev': round(statistics.stdev(prices_cent_kwh) if len(prices_cent_kwh) > 1 else 0, 3)
            },
            'price_stats_eur_kwh': {
                'min_price': round(min(prices_eur_kwh), 5),
                'max_price': round(max(prices_eur_kwh), 5),
                'avg_price': round(statistics.mean(prices_eur_kwh), 5),
                'median_price': round(statistics.median(prices_eur_kwh), 5),
                'std_dev': round(statistics.stdev(prices_eur_kwh) if len(prices_eur_kwh) > 1 else 0, 5)
            },
            'price_stats_eur_mwh': {
                'min_price': round(min(prices_eur_mwh), 2),
                'max_price': round(max(prices_eur_mwh), 2),
                'avg_price': round(statistics.mean(prices_eur_mwh), 2),
                'median_price': round(statistics.median(prices_eur_mwh), 2),
                'std_dev': round(statistics.stdev(prices_eur_mwh) if len(prices_eur_mwh) > 1 else 0, 2)
            },
            'price_range': {
                'variation_cent_kwh': round(max(prices_cent_kwh) - min(prices_cent_kwh), 3),
                'variation_eur_mwh': round(max(prices_eur_mwh) - min(prices_eur_mwh), 2),
                'variation_percent': round(((max(prices_cent_kwh) - min(prices_cent_kwh)) / statistics.mean(prices_cent_kwh)) * 100, 1) if statistics.mean(prices_cent_kwh) > 0 else 0
            },
            'time_range': {
                'first_timestamp': timestamps_local[0] if timestamps_local else 'N/A',
                'last_timestamp': timestamps_local[-1] if timestamps_local else 'N/A'
            },
            'raw_data': {
                'prices_cent_kwh': prices_cent_kwh,
                'prices_eur_kwh': prices_eur_kwh,
                'prices_eur_mwh': prices_eur_mwh,
                'timestamps_local': timestamps_local,
                'original_data': price_data
            }
        }
        
        return analysis
    
    def get_prices_for_test_periods(self, price_data: List[Dict]) -> Dict:
        """Get price data for specific test periods"""
        
        test_period_prices = {}
        
        for period_key, period_info in self.test_periods.items():
            print(f"\n📊 Analyzing prices for {period_info['name']}")
            print(f"   Local time: {period_info['local_start']} - {period_info['local_end']}")
            
            # Find prices that fall within this test period (using local time)
            period_prices = []
            
            for item in price_data:
                timestamp_ms = item.get('timestamp', 0)
                local_time = self.convert_timestamp_to_local(timestamp_ms)
                local_hour_min = local_time.split()[1][:5]  # Extract HH:MM
                
                # Check if this price falls within the test period
                if period_info['local_start'] <= local_hour_min <= period_info['local_end']:
                    price_cent_kwh = float(item.get('price', 0))
                    price_units = self.convert_price_units(price_cent_kwh)
                    
                    period_prices.append({
                        'price_cent_kwh': price_units['cent_per_kwh'],
                        'price_eur_kwh': price_units['eur_per_kwh'], 
                        'price_eur_mwh': price_units['eur_per_mwh'],
                        'local_time': local_time,
                        'timestamp_ms': timestamp_ms
                    })
            
            if period_prices:
                prices_cent_kwh = [p['price_cent_kwh'] for p in period_prices]
                prices_eur_mwh = [p['price_eur_mwh'] for p in period_prices]
                
                test_period_prices[period_key] = {
                    'name': period_info['name'],
                    'local_time_range': f"{period_info['local_start']} - {period_info['local_end']}",
                    'data_points': len(period_prices),
                    'avg_price_cent_kwh': round(statistics.mean(prices_cent_kwh), 3),
                    'min_price_cent_kwh': round(min(prices_cent_kwh), 3),
                    'max_price_cent_kwh': round(max(prices_cent_kwh), 3),
                    'avg_price_eur_mwh': round(statistics.mean(prices_eur_mwh), 2),
                    'min_price_eur_mwh': round(min(prices_eur_mwh), 2),
                    'max_price_eur_mwh': round(max(prices_eur_mwh), 2),
                    'price_data': period_prices
                }
                print(f"   ✅ Found {len(period_prices)} price points")
                print(f"      Avg: {test_period_prices[period_key]['avg_price_cent_kwh']} cent/kWh ({test_period_prices[period_key]['avg_price_eur_mwh']} EUR/MWh)")
            else:
                test_period_prices[period_key] = {
                    'name': period_info['name'],
                    'local_time_range': f"{period_info['local_start']} - {period_info['local_end']}",
                    'error': 'No price data found for this period'
                }
                print(f"   ⚠️  No price data found for this period")
        
        return test_period_prices
    
    def export_to_files(self, analysis: Dict, test_period_prices: Dict):
        """Export analysis results to various file formats"""
        
        # Create comprehensive export data
        export_data = {
            'export_date': datetime.now().isoformat(),
            'test_date': self.test_date,
            'tariff': self.tariff,
            'overall_analysis': analysis,
            'test_period_prices': test_period_prices
        }
        
        # Export to JSON
        with open('epex_price_analysis.json', 'w') as f:
            json.dump(export_data, f, indent=2, default=str)
        
        # Export to CSV (15-minute prices)
        if 'raw_data' in analysis:
            df_data = []
            for i, (price_cent, price_eur_kwh, price_eur_mwh, timestamp) in enumerate(zip(
                analysis['raw_data']['prices_cent_kwh'],
                analysis['raw_data']['prices_eur_kwh'],
                analysis['raw_data']['prices_eur_mwh'],
                analysis['raw_data']['timestamps_local']
            )):
                df_data.append({
                    'Timestamp_Local': timestamp,
                    'Price_Cent_kWh': price_cent,
                    'Price_EUR_kWh': price_eur_kwh,
                    'Price_EUR_MWh': price_eur_mwh,
                    'Hour': timestamp.split()[1][:2],
                    'Quarter_Hour': timestamp.split()[1][:5]
                })
            
            if df_data:
                df = pd.DataFrame(df_data)
                df.to_csv('epex_prices_15min.csv', index=False)
        
        # Export test period summary to CSV
        test_period_data = []
        for period_key, data in test_period_prices.items():
            if 'error' not in data:
                test_period_data.append({
                    'Test_Period': data['name'],
                    'Local_Time_Range': data['local_time_range'],
                    'Data_Points': data['data_points'],
                    'Avg_Price_Cent_kWh': data['avg_price_cent_kwh'],
                    'Min_Price_Cent_kWh': data['min_price_cent_kwh'],
                    'Max_Price_Cent_kWh': data['max_price_cent_kwh'],
                    'Avg_Price_EUR_MWh': data['avg_price_eur_mwh'],
                    'Min_Price_EUR_MWh': data['min_price_eur_mwh'],
                    'Max_Price_EUR_MWh': data['max_price_eur_mwh']
                })
        
        if test_period_data:
            df_periods = pd.DataFrame(test_period_data)
            df_periods.to_csv('epex_prices_test_periods.csv', index=False)
        
        # Generate LaTeX summary
        latex_output = self.generate_latex_summary(analysis, test_period_prices)
        with open('epex_price_analysis_latex.txt', 'w') as f:
            f.write(latex_output)
        
        print(f"\n📁 EPEX price data exported to:")
        print(f"   - epex_price_analysis.json (complete data)")
        print(f"   - epex_prices_15min.csv (15-minute interval prices)")
        print(f"   - epex_prices_test_periods.csv (test period summary)")
        print(f"   - epex_price_analysis_latex.txt (LaTeX values)")
    
    def generate_latex_summary(self, analysis: Dict, test_period_prices: Dict) -> str:
        """Generate LaTeX-ready values for the paper"""
        
        latex_content = f"""
% EPEX Spot Price Analysis Results
% Generated automatically from DynamoDB data analysis
% Date: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
% Test Date: {self.test_date}
% Tariff: {self.tariff}

% Overall Price Statistics for {self.test_date}
% Data points: {analysis.get('data_points', 'N/A')} (15-minute intervals)
% Average price: {analysis.get('price_stats_cent_kwh', {}).get('avg_price', 'N/A')} cent/kWh ({analysis.get('price_stats_eur_mwh', {}).get('avg_price', 'N/A')} EUR/MWh)
% Minimum price: {analysis.get('price_stats_cent_kwh', {}).get('min_price', 'N/A')} cent/kWh ({analysis.get('price_stats_eur_mwh', {}).get('min_price', 'N/A')} EUR/MWh)
% Maximum price: {analysis.get('price_stats_cent_kwh', {}).get('max_price', 'N/A')} cent/kWh ({analysis.get('price_stats_eur_mwh', {}).get('max_price', 'N/A')} EUR/MWh)
% Price variation: {analysis.get('price_range', {}).get('variation_cent_kwh', 'N/A')} cent/kWh ({analysis.get('price_range', {}).get('variation_eur_mwh', 'N/A')} EUR/MWh)
% Price variation percentage: {analysis.get('price_range', {}).get('variation_percent', 'N/A')}%

% Test Period Price Analysis
"""
        
        for period_key, data in test_period_prices.items():
            if 'error' not in data:
                latex_content += f"""
% {data['name']} ({data['local_time_range']} local time)
% Average electricity price: {data['avg_price_cent_kwh']} cent/kWh ({data['avg_price_eur_mwh']} EUR/MWh)
% Price range: {data['min_price_cent_kwh']} - {data['max_price_cent_kwh']} cent/kWh ({data['min_price_eur_mwh']} - {data['max_price_eur_mwh']} EUR/MWh)
% Data points: {data['data_points']} (15-minute intervals)
"""
        
        # Add cost optimization analysis
        if test_period_prices:
            valid_periods = {k: v for k, v in test_period_prices.items() if 'error' not in v}
            if len(valid_periods) >= 2:
                prices_cent = [data['avg_price_cent_kwh'] for data in valid_periods.values()]
                prices_eur_mwh = [data['avg_price_eur_mwh'] for data in valid_periods.values()]
                min_price_period = min(valid_periods.items(), key=lambda x: x[1]['avg_price_cent_kwh'])
                max_price_period = max(valid_periods.items(), key=lambda x: x[1]['avg_price_cent_kwh'])
                
                savings_cent = round(max_price_period[1]['avg_price_cent_kwh'] - min_price_period[1]['avg_price_cent_kwh'], 3)
                savings_eur_mwh = round(max_price_period[1]['avg_price_eur_mwh'] - min_price_period[1]['avg_price_eur_mwh'], 2)
                savings_percent = round((savings_cent / max_price_period[1]['avg_price_cent_kwh']) * 100, 1)
                
                latex_content += f"""
% Cost Optimization Potential
% Lowest price period: {min_price_period[1]['name']} at {min_price_period[1]['avg_price_cent_kwh']} cent/kWh ({min_price_period[1]['avg_price_eur_mwh']} EUR/MWh)
% Highest price period: {max_price_period[1]['name']} at {max_price_period[1]['avg_price_cent_kwh']} cent/kWh ({max_price_period[1]['avg_price_eur_mwh']} EUR/MWh)
% Potential savings: {savings_cent} cent/kWh ({savings_eur_mwh} EUR/MWh)
% Savings percentage: {savings_percent}%
"""
        
        latex_content += """
% LaTeX Integration Guide:
% =======================
% Use these values in your results.tex file for:
% - Economic Impact Analysis section
% - Cost Optimization Potential subsection
% - Replace [X] placeholders with the values above
"""
        
        return latex_content
    
    def run_complete_analysis(self):
        """Run the complete EPEX price analysis"""
        
        print("🔍 Starting EPEX Spot Price Analysis")
        print(f"📅 Test Date: {self.test_date}")
        print(f"🏷️  DynamoDB Table: {self.table.name}")
        print(f"💰 Tariff: {self.tariff}")
        
        # Discover available tariffs
        self.discover_available_tariffs()
        
        # Get sample data structure
        self.get_sample_data()
        
        # Query price data for the test date
        price_data = self.query_prices_for_date(self.test_date)
        
        if not price_data:
            print("❌ No price data found for the specified date")
            return
        
        # Analyze overall price data
        print(f"\n📊 Analyzing overall price data...")
        analysis = self.analyze_price_data(price_data)
        
        if 'error' in analysis:
            print(f"❌ Analysis failed: {analysis['error']}")
            return
        
        # Get prices for specific test periods
        print(f"\n📋 Analyzing prices for test periods...")
        test_period_prices = self.get_prices_for_test_periods(price_data)
        
        # Export results
        print(f"\n💾 Exporting results...")
        self.export_to_files(analysis, test_period_prices)
        
        # Print summary
        self.print_summary(analysis, test_period_prices)
        
        return analysis, test_period_prices
    
    def print_summary(self, analysis: Dict, test_period_prices: Dict):
        """Print a summary of the price analysis"""
        
        print("\n" + "="*60)
        print("💰 EPEX SPOT PRICE ANALYSIS SUMMARY")
        print("="*60)
        
        print(f"\n📊 Overall Statistics for {self.test_date}:")
        stats_cent = analysis.get('price_stats_cent_kwh', {})
        stats_eur_mwh = analysis.get('price_stats_eur_mwh', {})
        print(f"   Data Points: {analysis.get('data_points', 'N/A')} (15-minute intervals)")
        print(f"   Average Price: {stats_cent.get('avg_price', 'N/A')} cent/kWh ({stats_eur_mwh.get('avg_price', 'N/A')} EUR/MWh)")
        print(f"   Price Range: {stats_cent.get('min_price', 'N/A')} - {stats_cent.get('max_price', 'N/A')} cent/kWh")
        print(f"   Price Variation: {analysis.get('price_range', {}).get('variation_cent_kwh', 'N/A')} cent/kWh ({analysis.get('price_range', {}).get('variation_eur_mwh', 'N/A')} EUR/MWh)")
        
        print(f"\n⚡ Test Period Prices:")
        for period_key, data in test_period_prices.items():
            if 'error' in data:
                print(f"   ❌ {data['name']}: {data['error']}")
            else:
                print(f"   ✅ {data['name']} ({data['local_time_range']}): {data['avg_price_cent_kwh']} cent/kWh ({data['avg_price_eur_mwh']} EUR/MWh)")
        
        # Cost optimization potential
        valid_periods = {k: v for k, v in test_period_prices.items() if 'error' not in v}
        if len(valid_periods) >= 2:
            prices_cent = [data['avg_price_cent_kwh'] for data in valid_periods.values()]
            prices_eur_mwh = [data['avg_price_eur_mwh'] for data in valid_periods.values()]
            min_price_cent = min(prices_cent)
            max_price_cent = max(prices_cent)
            min_price_eur_mwh = min(prices_eur_mwh)
            max_price_eur_mwh = max(prices_eur_mwh)
            savings_potential_cent = max_price_cent - min_price_cent
            savings_potential_eur_mwh = max_price_eur_mwh - min_price_eur_mwh
            
            print(f"\n💡 Cost Optimization Potential:")
            print(f"   Price Range: {min_price_cent:.3f} - {max_price_cent:.3f} cent/kWh ({min_price_eur_mwh:.2f} - {max_price_eur_mwh:.2f} EUR/MWh)")
            print(f"   Potential Savings: {savings_potential_cent:.3f} cent/kWh ({savings_potential_eur_mwh:.2f} EUR/MWh)")
            print(f"   Savings Percentage: {(savings_potential_cent/max_price_cent)*100:.1f}%")
        
        print("\n" + "="*60)


def main():
    """Main function to run the EPEX price analysis"""
    
    # Initialize exporter
    exporter = EPEXDataExporter()
    
    try:
        # Run complete analysis
        analysis, test_period_prices = exporter.run_complete_analysis()
        
        print("\n🎉 EPEX price analysis completed successfully!")
        print("📁 Check the generated files for detailed results:")
        print("   - epex_price_analysis.json")
        print("   - epex_prices_15min.csv")
        print("   - epex_prices_test_periods.csv")
        print("   - epex_price_analysis_latex.txt")
        
    except Exception as e:
        print(f"❌ Analysis failed: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
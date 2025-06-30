#!/usr/bin/env python3
"""
Energy Consumption Data Evaluation Script
==========================================

This script analyzes energy consumption data from the SensorData DynamoDB table
for the five defined workload scenarios and generates comprehensive results
for the research paper.

Test Periods (29.06.2025):
- WL1: CPU Stress Test: 16:45 - 18:45 (2 hours)
- WL2: I/O Stress Test: 18:45 - 19:45 (1 hour)  
- WL3: System Reboot: 20:35 - 20:40 (5 minutes)
- WL4: Maintenance Operations: 22:30 - 22:35 (5 minutes)
- WL5: Idle State: From 22:50 onwards

Author: Generated for G1-S2-INENI Project
"""

import boto3
import json
import statistics
from datetime import datetime, timedelta
from decimal import Decimal
from typing import Dict, List, Tuple, Optional
import matplotlib.pyplot as plt
import pandas as pd
from botocore.exceptions import ClientError

class EnergyDataAnalyzer:
    """Class to analyze energy consumption data from DynamoDB"""
    
    def __init__(self, table_name: str = 'SensorData', device_id: str = None):
        """
        Initialize the analyzer
        
        Args:
            table_name: Name of the DynamoDB table
            device_id: Device ID to filter data (if None, uses first found device)
        """
        self.dynamodb = boto3.resource('dynamodb')
        self.table = self.dynamodb.Table(table_name)
        self.device_id = device_id
        self.test_date = "2025-06-29"
        
        # Define test periods
        self.test_periods = {
            'WL1_CPU_Stress': {
                'name': 'Maximum Computational Load',
                'start': f"{self.test_date}T16:45:00",
                'end': f"{self.test_date}T18:45:00",
                'duration_minutes': 120,
                'description': 'CPU stress testing with stress-ng'
            },
            'WL2_IO_Stress': {
                'name': 'I/O Stress Testing',
                'start': f"{self.test_date}T18:45:00",
                'end': f"{self.test_date}T19:45:00",
                'duration_minutes': 60,
                'description': 'FIO I/O stress testing'
            },
            'WL3_Reboot': {
                'name': 'System Reboot Cycle',
                'start': f"{self.test_date}T20:35:00",
                'end': f"{self.test_date}T20:40:00",
                'duration_minutes': 5,
                'description': 'Full system reboot cycle'
            },
            'WL4_Maintenance': {
                'name': 'Maintenance Operations',
                'start': f"{self.test_date}T22:30:00",
                'end': f"{self.test_date}T22:35:00",
                'duration_minutes': 5,
                'description': 'System maintenance and updates'
            },
            'WL5_Idle': {
                'name': 'Idle State',
                'start': f"{self.test_date}T22:50:00",
                'end': f"{self.test_date}T23:50:00",  # 1 hour of idle data
                'duration_minutes': 60,
                'description': 'System idle state baseline'
            }
        }
    
    def discover_device_id(self) -> Optional[str]:
        """Discover the device ID by scanning the table"""
        try:
            response = self.table.scan(
                ProjectionExpression='device_id',
                Limit=1
            )
            
            if response['Items']:
                device_id = response['Items'][0]['device_id']
                print(f"Discovered device ID: {device_id}")
                return device_id
            else:
                print("No devices found in table")
                return None
                
        except ClientError as e:
            print(f"Error discovering device ID: {e}")
            return None
    
    def query_time_range(self, start_time: str, end_time: str) -> List[Dict]:
        """
        Query data for a specific time range
        
        Args:
            start_time: Start time in ISO format (YYYY-MM-DDTHH:MM:SS)
            end_time: End time in ISO format (YYYY-MM-DDTHH:MM:SS)
            
        Returns:
            List of data points
        """
        if not self.device_id:
            self.device_id = self.discover_device_id()
            if not self.device_id:
                return []
        
        try:
            # Query DynamoDB for the time range
            response = self.table.query(
                KeyConditionExpression=boto3.dynamodb.conditions.Key('device_id').eq(self.device_id) &
                                     boto3.dynamodb.conditions.Key('timestamp').between(start_time, end_time),
                ScanIndexForward=True  # Sort by timestamp ascending
            )
            
            return response['Items']
            
        except ClientError as e:
            print(f"Error querying data for {start_time} - {end_time}: {e}")
            return []
    
    def analyze_workload_period(self, period_key: str) -> Dict:
        """
        Analyze energy consumption for a specific workload period
        
        Args:
            period_key: Key identifying the test period
            
        Returns:
            Dictionary with analysis results
        """
        period = self.test_periods[period_key]
        print(f"\n📊 Analyzing {period['name']} ({period_key})")
        print(f"   Period: {period['start']} - {period['end']}")
        
        # Query data for the period
        data_points = self.query_time_range(period['start'], period['end'])
        
        if not data_points:
            print(f"   ⚠️  No data found for period {period_key}")
            return {
                'period': period_key,
                'name': period['name'],
                'data_points': 0,
                'error': 'No data found'
            }
        
        # Extract power values (convert Decimal to float)
        power_values = []
        timestamps = []
        
        for point in data_points:
            if 'current_power' in point:
                power_w = float(point['current_power'])
                power_values.append(power_w)
                timestamps.append(point['timestamp'])
        
        if not power_values:
            print(f"   ⚠️  No power data found for period {period_key}")
            return {
                'period': period_key,
                'name': period['name'],
                'data_points': len(data_points),
                'error': 'No power data found'
            }
        
        # Calculate statistics
        avg_power = statistics.mean(power_values)
        max_power = max(power_values)
        min_power = min(power_values)
        std_dev = statistics.stdev(power_values) if len(power_values) > 1 else 0
        
        # Calculate energy consumption (kWh)
        # Assuming measurements are taken at regular intervals
        duration_hours = period['duration_minutes'] / 60
        energy_kwh = (avg_power * duration_hours) / 1000  # Convert W*h to kWh
        
        # Calculate additional metrics
        power_stability = (std_dev / avg_power * 100) if avg_power > 0 else 0  # CV%
        
        results = {
            'period': period_key,
            'name': period['name'],
            'description': period['description'],
            'start_time': period['start'],
            'end_time': period['end'],
            'duration_minutes': period['duration_minutes'],
            'data_points': len(power_values),
            'power_stats': {
                'average_w': round(avg_power, 2),
                'peak_w': round(max_power, 2),
                'minimum_w': round(min_power, 2),
                'std_deviation_w': round(std_dev, 2),
                'stability_cv_percent': round(power_stability, 2)
            },
            'energy_consumption': {
                'total_kwh': round(energy_kwh, 6),
                'duration_hours': round(duration_hours, 2)
            },
            'raw_data': {
                'timestamps': timestamps,
                'power_values': power_values
            }
        }
        
        print(f"   ✅ Found {len(power_values)} power measurements")
        print(f"   📈 Average Power: {avg_power:.1f} W")
        print(f"   ⚡ Peak Power: {max_power:.1f} W")
        print(f"   🔋 Energy Consumption: {energy_kwh:.6f} kWh")
        
        return results
    
    def generate_comparison_analysis(self, all_results: Dict) -> Dict:
        """Generate comparative analysis between workloads"""
        
        # Filter out periods with errors
        valid_results = {k: v for k, v in all_results.items() 
                        if 'error' not in v and 'power_stats' in v}
        
        if not valid_results:
            return {'error': 'No valid data for comparison'}
        
        # Find baseline (idle state)
        baseline_power = None
        if 'WL5_Idle' in valid_results:
            baseline_power = valid_results['WL5_Idle']['power_stats']['average_w']
        
        comparison = {
            'baseline_power_w': baseline_power,
            'workload_comparison': {},
            'efficiency_metrics': {}
        }
        
        # Compare each workload to baseline
        for period_key, results in valid_results.items():
            avg_power = results['power_stats']['average_w']
            peak_power = results['power_stats']['peak_w']
            
            workload_data = {
                'average_power_w': avg_power,
                'peak_power_w': peak_power,
                'energy_kwh': results['energy_consumption']['total_kwh']
            }
            
            if baseline_power:
                power_increase = avg_power - baseline_power
                power_increase_percent = (power_increase / baseline_power) * 100
                workload_data.update({
                    'power_increase_w': round(power_increase, 2),
                    'power_increase_percent': round(power_increase_percent, 1)
                })
            
            comparison['workload_comparison'][period_key] = workload_data
        
        return comparison
    
    def export_results_to_files(self, all_results: Dict, comparison: Dict):
        """Export results to various output formats"""
        
        # Create results summary for LaTeX
        latex_output = self.generate_latex_summary(all_results, comparison)
        
        # Create detailed JSON report
        json_output = {
            'analysis_date': datetime.now().isoformat(),
            'device_id': self.device_id,
            'test_date': self.test_date,
            'workload_results': all_results,
            'comparison_analysis': comparison
        }
        
        # Write files
        with open('energy_analysis_results.json', 'w') as f:
            json.dump(json_output, f, indent=2, default=str)
        
        with open('energy_analysis_latex.txt', 'w') as f:
            f.write(latex_output)
        
        # Create CSV for spreadsheet analysis
        self.create_csv_export(all_results)
        
        print(f"\n📁 Results exported to:")
        print(f"   - energy_analysis_results.json (detailed data)")
        print(f"   - energy_analysis_latex.txt (LaTeX values)")
        print(f"   - energy_analysis_summary.csv (spreadsheet data)")
    
    def generate_latex_summary(self, all_results: Dict, comparison: Dict) -> str:
        """Generate LaTeX-ready values for the paper"""
        
        latex_content = """
% Energy Consumption Analysis Results
% Generated automatically from DynamoDB data analysis
% Date: {analysis_date}

% WL1: Maximum Computational Load (CPU Stress)
""".format(analysis_date=datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        
        for period_key, results in all_results.items():
            if 'error' in results:
                latex_content += f"% {period_key}: ERROR - {results['error']}\n"
                continue
                
            period_name = results['name']
            stats = results['power_stats']
            energy = results['energy_consumption']
            
            latex_content += f"""
% {period_name} ({period_key})
% Average power consumption: {stats['average_w']} W
% Peak power consumption: {stats['peak_w']} W  
% Total energy consumption: {energy['total_kwh']} kWh
% Duration: {energy['duration_hours']} hours
% Power stability: ±{stats['std_deviation_w']} W variation
"""
        
        # Add comparison data
        if 'workload_comparison' in comparison:
            latex_content += "\n% Workload Comparison Analysis\n"
            for period_key, comp_data in comparison['workload_comparison'].items():
                if 'power_increase_percent' in comp_data:
                    latex_content += f"% {period_key}: {comp_data['power_increase_percent']}% increase over baseline\n"
        
        return latex_content
    
    def create_csv_export(self, all_results: Dict):
        """Create CSV file for spreadsheet analysis"""
        
        csv_data = []
        for period_key, results in all_results.items():
            if 'error' in results:
                continue
                
            csv_data.append({
                'Workload': results['name'],
                'Period_Key': period_key,
                'Duration_Minutes': results['duration_minutes'],
                'Data_Points': results['data_points'],
                'Average_Power_W': results['power_stats']['average_w'],
                'Peak_Power_W': results['power_stats']['peak_w'],
                'Min_Power_W': results['power_stats']['minimum_w'],
                'Std_Dev_W': results['power_stats']['std_deviation_w'],
                'Total_Energy_kWh': results['energy_consumption']['total_kwh'],
                'Power_Stability_CV%': results['power_stats']['stability_cv_percent']
            })
        
        if csv_data:
            df = pd.DataFrame(csv_data)
            df.to_csv('energy_analysis_summary.csv', index=False)
    
    def run_complete_analysis(self):
        """Run the complete analysis for all workload periods"""
        
        print("🔍 Starting Energy Consumption Analysis")
        print(f"📅 Test Date: {self.test_date}")
        print(f"🏷️  DynamoDB Table: {self.table.name}")
        
        # Discover device if not provided
        if not self.device_id:
            self.device_id = self.discover_device_id()
            if not self.device_id:
                print("❌ Could not find any devices in the table")
                return
        
        print(f"🔌 Device ID: {self.device_id}")
        
        # Analyze each workload period
        all_results = {}
        for period_key in self.test_periods.keys():
            try:
                results = self.analyze_workload_period(period_key)
                all_results[period_key] = results
            except Exception as e:
                print(f"❌ Error analyzing {period_key}: {e}")
                all_results[period_key] = {
                    'period': period_key,
                    'error': str(e)
                }
        
        # Generate comparison analysis
        print("\n🔄 Generating comparison analysis...")
        comparison = self.generate_comparison_analysis(all_results)
        
        # Export results
        print("\n💾 Exporting results...")
        self.export_results_to_files(all_results, comparison)
        
        # Print summary
        self.print_summary(all_results, comparison)
        
        return all_results, comparison
    
    def print_summary(self, all_results: Dict, comparison: Dict):
        """Print a summary of the analysis results"""
        
        print("\n" + "="*60)
        print("📊 ENERGY CONSUMPTION ANALYSIS SUMMARY")
        print("="*60)
        
        for period_key, results in all_results.items():
            if 'error' in results:
                print(f"\n❌ {results.get('name', period_key)}: {results['error']}")
                continue
            
            print(f"\n✅ {results['name']} ({period_key})")
            print(f"   Duration: {results['duration_minutes']} minutes")
            print(f"   Average Power: {results['power_stats']['average_w']} W")
            print(f"   Peak Power: {results['power_stats']['peak_w']} W")
            print(f"   Total Energy: {results['energy_consumption']['total_kwh']} kWh")
            print(f"   Data Points: {results['data_points']}")
        
        # Print comparison if available
        if 'workload_comparison' in comparison and comparison['baseline_power_w']:
            print(f"\n🔋 Baseline Power (Idle): {comparison['baseline_power_w']:.1f} W")
            print("\n📈 Power Increase vs Baseline:")
            for period_key, comp_data in comparison['workload_comparison'].items():
                if 'power_increase_percent' in comp_data:
                    print(f"   {period_key}: +{comp_data['power_increase_percent']}% "
                          f"({comp_data['power_increase_w']} W)")
        
        print("\n" + "="*60)


def main():
    """Main function to run the energy data analysis"""
    
    # Initialize analyzer
    analyzer = EnergyDataAnalyzer()
    
    try:
        # Run complete analysis
        results, comparison = analyzer.run_complete_analysis()
        
        print("\n🎉 Analysis completed successfully!")
        print("📁 Check the generated files for detailed results:")
        print("   - energy_analysis_results.json")
        print("   - energy_analysis_latex.txt") 
        print("   - energy_analysis_summary.csv")
        
    except Exception as e:
        print(f"❌ Analysis failed: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main() 
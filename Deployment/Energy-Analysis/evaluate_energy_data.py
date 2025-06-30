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
        
        # Define test periods - Converted to UTC (subtract 2 hours from local times)
        # Local times -> UTC times: 16:45 -> 14:45, 18:45 -> 16:45, etc.
        self.test_periods = {
            'WL1_CPU_Stress': {
                'name': 'Maximum Computational Load',
                'start': f"{self.test_date}T14:45:00",  # 16:45 local -> 14:45 UTC
                'end': f"{self.test_date}T16:45:00",    # 18:45 local -> 16:45 UTC
                'duration_minutes': 120,
                'description': 'CPU stress testing with stress-ng (4 cycles: 15min stress + 15min pause)',
                'pattern': 'cyclic',
                'cycle_duration': 15,  # 15 minutes active stress
                'cycle_pause': 15,     # 15 minutes pause
                'cycles': 4,
                'active_periods': [
                    (f"{self.test_date}T14:45:00", f"{self.test_date}T15:00:00"),  # Cycle 1: 16:45-17:00 local
                    (f"{self.test_date}T15:15:00", f"{self.test_date}T15:30:00"),  # Cycle 2: 17:15-17:30 local
                    (f"{self.test_date}T15:45:00", f"{self.test_date}T16:00:00"),  # Cycle 3: 17:45-18:00 local
                    (f"{self.test_date}T16:15:00", f"{self.test_date}T16:30:00"),  # Cycle 4: 18:15-18:30 local
                ]
            },
            'WL2_IO_Stress': {
                'name': 'I/O Stress Testing',
                'start': f"{self.test_date}T16:45:00",  # 18:45 local -> 16:45 UTC
                'end': f"{self.test_date}T17:45:00",    # 19:45 local -> 17:45 UTC
                'duration_minutes': 60,
                'description': 'FIO I/O stress testing (4 cycles: 15min I/O stress + 15min pause)',
                'pattern': 'cyclic',
                'cycle_duration': 15,  # 15 minutes active I/O
                'cycle_pause': 15,     # 15 minutes pause
                'cycles': 4,
                'active_periods': [
                    (f"{self.test_date}T16:45:00", f"{self.test_date}T17:00:00"),  # Cycle 1: 18:45-19:00 local
                    (f"{self.test_date}T17:15:00", f"{self.test_date}T17:30:00"),  # Cycle 2: 19:15-19:30 local
                    # Note: Only 2 full cycles fit in 1 hour with 15min pause
                ]
            },
            'WL3_Reboot': {
                'name': 'System Reboot Cycle',
                'start': f"{self.test_date}T18:35:00",  # 20:35 local -> 18:35 UTC
                'end': f"{self.test_date}T18:40:00",    # 20:40 local -> 18:40 UTC
                'duration_minutes': 5,
                'description': 'Full system reboot cycle',
                'pattern': 'single',
                'active_periods': [
                    (f"{self.test_date}T18:35:00", f"{self.test_date}T18:40:00"),
                ]
            },
            'WL4_Maintenance': {
                'name': 'Maintenance Operations',
                'start': f"{self.test_date}T20:30:00",  # 22:30 local -> 20:30 UTC
                'end': f"{self.test_date}T20:35:00",    # 22:35 local -> 20:35 UTC
                'duration_minutes': 5,
                'description': 'System maintenance and updates',
                'pattern': 'single',
                'active_periods': [
                    (f"{self.test_date}T20:30:00", f"{self.test_date}T20:35:00"),
                ]
            },
            'WL5_Idle': {
                'name': 'Idle State',
                'start': f"{self.test_date}T20:50:00",  # 22:50 local -> 20:50 UTC
                'end': f"{self.test_date}T21:50:00",    # 23:50 local -> 21:50 UTC
                'duration_minutes': 60,
                'description': 'System idle state baseline',
                'pattern': 'continuous',
                'active_periods': [
                    (f"{self.test_date}T20:50:00", f"{self.test_date}T21:50:00"),
                ]
            }
        }
    
    def discover_device_id(self) -> Optional[str]:
        """Discover the device ID by scanning the table and check timestamp format"""
        try:
            response = self.table.scan(
                Limit=5  # Get a few samples to check timestamp format
            )
            
            if response['Items']:
                device_id = response['Items'][0]['device_id']
                print(f"Discovered device ID: {device_id}")
                
                # Check timestamp format in the data
                print(f"\n🔍 Sample data from DynamoDB:")
                for i, item in enumerate(response['Items'][:3]):
                    timestamp = item.get('timestamp', 'N/A')
                    power = item.get('current_power', 'N/A')
                    device_time = item.get('device_time', 'N/A')
                    print(f"  Sample {i+1}:")
                    print(f"    timestamp: {timestamp} (type: {type(timestamp)})")
                    print(f"    device_time: {device_time}")
                    print(f"    current_power: {power}")
                    print()
                
                return device_id
            else:
                print("No devices found in table")
                return None
                
        except ClientError as e:
            print(f"Error discovering device ID: {e}")
            return None
    
    def query_time_range(self, start_time: str, end_time: str, debug: bool = False) -> List[Dict]:
        """
        Query data for a specific time range
        
        Args:
            start_time: Start time in ISO format (YYYY-MM-DDTHH:MM:SS)
            end_time: End time in ISO format (YYYY-MM-DDTHH:MM:SS)
            debug: If True, print debug information
            
        Returns:
            List of data points
        """
        if not self.device_id:
            self.device_id = self.discover_device_id()
            if not self.device_id:
                return []
        
        if debug:
            print(f"🔍 Querying range: {start_time} to {end_time}")
        
        try:
            # Query DynamoDB for the time range
            response = self.table.query(
                KeyConditionExpression=boto3.dynamodb.conditions.Key('device_id').eq(self.device_id) &
                                     boto3.dynamodb.conditions.Key('timestamp').between(start_time, end_time),
                ScanIndexForward=True  # Sort by timestamp ascending
            )
            
            items = response['Items']
            
            if debug and items:
                print(f"📊 Found {len(items)} items in range")
                print(f"First item timestamp: {items[0].get('timestamp')}")
                print(f"Last item timestamp: {items[-1].get('timestamp')}")
                print(f"First item power: {items[0].get('current_power')}")
                print(f"Last item power: {items[-1].get('current_power')}")
                
                # Check for any high power values
                power_values = [float(item.get('current_power', 0)) for item in items if 'current_power' in item]
                if power_values:
                    max_power = max(power_values)
                    min_power = min(power_values)
                    print(f"Power range in this period: {min_power:.1f}W - {max_power:.1f}W")
            
            return items
            
        except ClientError as e:
            print(f"Error querying data for {start_time} - {end_time}: {e}")
            return []
    
    def analyze_workload_period(self, period_key: str) -> Dict:
        """
        Analyze energy consumption for a specific workload period
        Handles different patterns: cyclic, single, and continuous
        
        Args:
            period_key: Key identifying the test period
            
        Returns:
            Dictionary with analysis results
        """
        period = self.test_periods[period_key]
        print(f"\n📊 Analyzing {period['name']} ({period_key})")
        print(f"   Period: {period['start']} - {period['end']}")
        print(f"   Pattern: {period.get('pattern', 'continuous')}")
        
        if period.get('pattern') == 'cyclic':
            return self.analyze_cyclic_workload(period_key)
        else:
            return self.analyze_continuous_workload(period_key)
    
    def analyze_cyclic_workload(self, period_key: str) -> Dict:
        """Analyze cyclic workloads with active/pause periods"""
        period = self.test_periods[period_key]
        
        # Analyze each active period separately
        active_periods_data = []
        pause_periods_data = []
        all_power_values = []
        all_timestamps = []
        
        for i, (start_time, end_time) in enumerate(period['active_periods']):
            print(f"   📈 Analyzing active period {i+1}: {start_time} - {end_time}")
            
            # Query data for this active period with debug for first period
            debug_mode = (i == 0)  # Debug first period only
            active_data = self.query_time_range(start_time, end_time, debug=debug_mode)
            
            if active_data:
                active_power_values = []
                for point in active_data:
                    if 'current_power' in point:
                        power_w = float(point['current_power'])
                        active_power_values.append(power_w)
                        all_power_values.append(power_w)
                        all_timestamps.append(point['timestamp'])
                
                if active_power_values:
                    active_periods_data.append({
                        'period': i+1,
                        'start': start_time,
                        'end': end_time,
                        'power_values': active_power_values,
                        'avg_power': statistics.mean(active_power_values),
                        'peak_power': max(active_power_values),
                        'data_points': len(active_power_values)
                    })
                    print(f"     ✅ Active period {i+1}: {len(active_power_values)} points, "
                          f"avg {statistics.mean(active_power_values):.1f}W")
        
        if not all_power_values:
            print(f"   ⚠️  No power data found for any active periods in {period_key}")
            return {
                'period': period_key,
                'name': period['name'],
                'data_points': 0,
                'error': 'No power data found in active periods'
            }
        
        # Calculate overall statistics for active periods only
        avg_power = statistics.mean(all_power_values)
        max_power = max(all_power_values)
        min_power = min(all_power_values)
        std_dev = statistics.stdev(all_power_values) if len(all_power_values) > 1 else 0
        
        # Calculate energy consumption for active periods only (15 minutes per cycle)
        active_duration_minutes = len(period['active_periods']) * period.get('cycle_duration', 15)
        active_duration_hours = active_duration_minutes / 60
        energy_kwh = (avg_power * active_duration_hours) / 1000
        
        # Calculate additional metrics
        power_stability = (std_dev / avg_power * 100) if avg_power > 0 else 0
        
        results = {
            'period': period_key,
            'name': period['name'],
            'description': period['description'],
            'pattern': period['pattern'],
            'start_time': period['start'],
            'end_time': period['end'],
            'total_duration_minutes': period['duration_minutes'],
            'active_duration_minutes': active_duration_minutes,
            'cycles': len(period['active_periods']),
            'data_points': len(all_power_values),
            'power_stats': {
                'average_w': round(avg_power, 2),
                'peak_w': round(max_power, 2),
                'minimum_w': round(min_power, 2),
                'std_deviation_w': round(std_dev, 2),
                'stability_cv_percent': round(power_stability, 2)
            },
            'energy_consumption': {
                'total_kwh': round(energy_kwh, 6),
                'active_duration_hours': round(active_duration_hours, 2),
                'kwh_per_15min': round(energy_kwh / len(period['active_periods']), 6)
            },
            'cycle_details': active_periods_data,
            'raw_data': {
                'timestamps': all_timestamps,
                'power_values': all_power_values
            }
        }
        
        print(f"   ✅ Found {len(all_power_values)} power measurements across {len(period['active_periods'])} active periods")
        print(f"   📈 Average Power (active periods): {avg_power:.1f} W")
        print(f"   ⚡ Peak Power: {max_power:.1f} W")
        print(f"   🔋 Energy Consumption (active only): {energy_kwh:.6f} kWh")
        print(f"   ⏱️  Active Duration: {active_duration_minutes} minutes ({len(period['active_periods'])} × 15min)")
        
        return results
    
    def analyze_continuous_workload(self, period_key: str) -> Dict:
        """Analyze continuous workloads (single period or idle state)"""
        period = self.test_periods[period_key]
        
        # Query data for the entire period
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
        duration_hours = period['duration_minutes'] / 60
        energy_kwh = (avg_power * duration_hours) / 1000
        
        # Calculate additional metrics
        power_stability = (std_dev / avg_power * 100) if avg_power > 0 else 0
        
        results = {
            'period': period_key,
            'name': period['name'],
            'description': period['description'],
            'pattern': period.get('pattern', 'continuous'),
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
        
        latex_content = f"""
% Energy Consumption Analysis Results
% Generated automatically from DynamoDB data analysis  
% Date: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
% Test Date: 2025-06-29

"""
        
        for period_key, results in all_results.items():
            if 'error' in results:
                latex_content += f"% {period_key}: ERROR - {results['error']}\n"
                continue
                
            period_name = results['name']
            stats = results['power_stats']
            energy = results['energy_consumption']
            pattern = results.get('pattern', 'continuous')
            
            latex_content += f"% {period_name} ({period_key})\n"
            latex_content += f"% Pattern: {pattern}\n"
            latex_content += f"% Average power consumption: {stats['average_w']} W\n"
            latex_content += f"% Peak power consumption: {stats['peak_w']} W\n"
            
            if pattern == 'cyclic':
                # For cyclic workloads, show both total and per-cycle data
                cycles = results.get('cycles', 0)
                active_duration = results.get('active_duration_minutes', 0)
                kwh_per_15min = energy.get('kwh_per_15min', 0)
                
                latex_content += f"% Total energy consumption ({cycles} cycles): {energy['total_kwh']} kWh\n"
                latex_content += f"% Energy consumption per 15-min cycle: {kwh_per_15min} kWh\n"
                latex_content += f"% Active duration: {active_duration} minutes ({cycles} × 15min cycles)\n"
                latex_content += f"% Total test duration: {results.get('total_duration_minutes', 0)} minutes\n"
                
                # Add cycle details
                if 'cycle_details' in results:
                    latex_content += f"% Cycle breakdown:\n"
                    for cycle in results['cycle_details']:
                        latex_content += f"%   Cycle {cycle['period']}: {cycle['avg_power']:.1f}W avg, {cycle['peak_power']:.1f}W peak\n"
                        
            else:
                # For continuous workloads
                duration_key = 'duration_hours' if 'duration_hours' in energy else 'active_duration_hours'
                duration = energy.get(duration_key, 0)
                latex_content += f"% Total energy consumption: {energy['total_kwh']} kWh\n"
                latex_content += f"% Duration: {duration} hours\n"
                
            latex_content += f"% Power stability: ±{stats['std_deviation_w']} W variation\n"
            latex_content += f"% Data points: {results['data_points']}\n"
            latex_content += "\n"
        
        # Add comparison data
        if 'workload_comparison' in comparison and comparison['baseline_power_w']:
            latex_content += "% Workload Comparison Analysis\n"
            latex_content += f"% Baseline (Idle): {comparison['baseline_power_w']:.1f} W\n"
            for period_key, comp_data in comparison['workload_comparison'].items():
                if 'power_increase_percent' in comp_data:
                    latex_content += f"% {period_key}: {comp_data['power_increase_percent']}% increase over baseline "
                    latex_content += f"(+{comp_data['power_increase_w']} W)\n"
            latex_content += "\n"
        
        # Add LaTeX replacement suggestions
        latex_content += """% LaTeX Replacement Guide for results.tex:
% ==========================================
% Replace [X] placeholders with the values above.
% 
% For cyclic workloads (WL1, WL2):
%   - Use "Energy consumption per 15-min cycle" for individual cycle energy
%   - Use "Total energy consumption" for entire test period
%   - Mention the cyclic nature in descriptions
%
% For single events (WL3, WL4):
%   - Use total energy consumption directly
%   - Duration is typically 5 minutes
%
% For idle state (WL5):
%   - Use as baseline for comparisons
%   - Shows minimum power consumption
"""
        
        return latex_content
    
    def create_csv_export(self, all_results: Dict):
        """Create CSV file for spreadsheet analysis"""
        
        csv_data = []
        for period_key, results in all_results.items():
            if 'error' in results:
                continue
            
            # Handle different duration field names for different patterns
            pattern = results.get('pattern', 'continuous')
            if pattern == 'cyclic':
                total_duration = results.get('total_duration_minutes', 0)
                active_duration = results.get('active_duration_minutes', 0)
                cycles = results.get('cycles', 0)
                kwh_per_cycle = results['energy_consumption'].get('kwh_per_15min', 0)
            else:
                total_duration = results.get('duration_minutes', 0)
                active_duration = total_duration
                cycles = 1
                kwh_per_cycle = results['energy_consumption']['total_kwh']
                
            csv_data.append({
                'Workload': results['name'],
                'Period_Key': period_key,
                'Pattern': pattern,
                'Total_Duration_Minutes': total_duration,
                'Active_Duration_Minutes': active_duration,
                'Cycles': cycles,
                'Data_Points': results['data_points'],
                'Average_Power_W': results['power_stats']['average_w'],
                'Peak_Power_W': results['power_stats']['peak_w'],
                'Min_Power_W': results['power_stats']['minimum_w'],
                'Std_Dev_W': results['power_stats']['std_deviation_w'],
                'Total_Energy_kWh': results['energy_consumption']['total_kwh'],
                'Energy_Per_Cycle_kWh': kwh_per_cycle,
                'Power_Stability_CV%': results['power_stats']['stability_cv_percent']
            })
        
        if csv_data:
            df = pd.DataFrame(csv_data)
            df.to_csv('energy_analysis_summary.csv', index=False)
    
    def check_available_data_around_test_date(self):
        """Check what data is available around the test date"""
        print(f"\n🔍 Checking available data around test date {self.test_date}...")
        
        # Check a broader range around the test date
        start_check = f"{self.test_date}T00:00:00"
        end_check = f"{self.test_date}T23:59:59"
        
        try:
            # Get a sample of data from the test date
            response = self.table.query(
                KeyConditionExpression=boto3.dynamodb.conditions.Key('device_id').eq(self.device_id) &
                                     boto3.dynamodb.conditions.Key('timestamp').between(start_check, end_check),
                Limit=10
            )
            
            items = response['Items']
            if items:
                print(f"✅ Found {len(items)} sample items on {self.test_date}")
                print("Sample timestamps and power values:")
                for i, item in enumerate(items[:5]):
                    timestamp = item.get('timestamp')
                    power = item.get('current_power', 'N/A')
                    print(f"  {i+1}. {timestamp} -> {power}W")
            else:
                print(f"❌ No data found for {self.test_date}")
                
                # Try to find any data at all
                print("🔍 Searching for any recent data...")
                response = self.table.query(
                    KeyConditionExpression=boto3.dynamodb.conditions.Key('device_id').eq(self.device_id),
                    ScanIndexForward=False,  # Get most recent
                    Limit=5
                )
                
                if response['Items']:
                    print("Most recent data found:")
                    for item in response['Items']:
                        timestamp = item.get('timestamp')
                        power = item.get('current_power', 'N/A')
                        print(f"  {timestamp} -> {power}W")
                else:
                    print("❌ No data found at all for this device")
                    
        except ClientError as e:
            print(f"Error checking data: {e}")

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
        
        # Check what data is available around the test date
        self.check_available_data_around_test_date()
        
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
            
            pattern = results.get('pattern', 'continuous')
            print(f"\n✅ {results['name']} ({period_key}) - {pattern.title()}")
            
            if pattern == 'cyclic':
                total_duration = results.get('total_duration_minutes', 0)
                active_duration = results.get('active_duration_minutes', 0)
                cycles = results.get('cycles', 0)
                
                print(f"   Total Duration: {total_duration} minutes")
                print(f"   Active Duration: {active_duration} minutes ({cycles} × 15min cycles)")
                print(f"   Average Power (active): {results['power_stats']['average_w']} W")
                print(f"   Peak Power: {results['power_stats']['peak_w']} W")
                print(f"   Total Energy (active): {results['energy_consumption']['total_kwh']} kWh")
                
                if 'kwh_per_15min' in results['energy_consumption']:
                    print(f"   Energy per 15-min cycle: {results['energy_consumption']['kwh_per_15min']} kWh")
                    
                print(f"   Data Points: {results['data_points']} (across {cycles} cycles)")
            else:
                duration_minutes = results.get('duration_minutes', 0)
                print(f"   Duration: {duration_minutes} minutes")
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
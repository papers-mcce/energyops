# Energy Data Analysis Script

This script analyzes energy consumption data from the SensorData DynamoDB table for the five defined workload scenarios.

## Test Periods (29.06.2025)

- **WL1: CPU Stress Test**: 16:45 - 18:45 (2 hours)
- **WL2: I/O Stress Test**: 18:45 - 19:45 (1 hour)
- **WL3: System Reboot**: 20:35 - 20:40 (5 minutes)
- **WL4: Maintenance Operations**: 22:30 - 22:35 (5 minutes)
- **WL5: Idle State**: 22:50 - 23:50 (1 hour baseline)

## Prerequisites

1. **AWS Credentials**: Ensure your AWS credentials are configured

   ```bash
   aws configure
   ```

2. **Python Dependencies**: Install required packages

   ```bash
   pip install -r requirements.txt
   ```

3. **DynamoDB Access**: Ensure you have read access to the SensorData table

## Usage

### Basic Usage

```bash
cd Deployment/Scripts
python evaluate_energy_data.py
```

### With Specific Device ID

If you know your device ID, you can specify it directly in the script by modifying:

```python
analyzer = EnergyDataAnalyzer(device_id='your-device-id-here')
```

## Output Files

The script generates three output files:

1. **energy_analysis_results.json**: Complete detailed analysis data
2. **energy_analysis_latex.txt**: LaTeX-ready values for your paper
3. **energy_analysis_summary.csv**: Spreadsheet-compatible summary

## Analysis Features

- **Power Statistics**: Average, peak, minimum power consumption
- **Energy Consumption**: Total kWh for each workload period
- **Comparative Analysis**: Power increase vs baseline (idle state)
- **Data Quality**: Number of data points and measurement stability
- **Export Formats**: JSON, LaTeX, and CSV outputs

## Expected Output Structure

```
📊 ENERGY CONSUMPTION ANALYSIS SUMMARY
============================================================

✅ Maximum Computational Load (WL1_CPU_Stress)
   Duration: 120 minutes
   Average Power: [X] W
   Peak Power: [X] W
   Total Energy: [X] kWh
   Data Points: [X]

✅ I/O Stress Testing (WL2_IO_Stress)
   Duration: 60 minutes
   Average Power: [X] W
   Peak Power: [X] W
   Total Energy: [X] kWh
   Data Points: [X]

[... and so on for all workloads]

🔋 Baseline Power (Idle): [X] W

📈 Power Increase vs Baseline:
   WL1_CPU_Stress: +[X]% ([X] W)
   WL2_IO_Stress: +[X]% ([X] W)
   [... etc]
```

## Troubleshooting

### No Data Found

- Check if the test date (2025-06-29) is correct
- Verify your AWS credentials have DynamoDB access
- Ensure the SensorData table exists and contains data

### AWS Credentials Issues

```bash
aws sts get-caller-identity  # Check if credentials work
```

### Missing Dependencies

```bash
pip install boto3 pandas matplotlib
```

## Integration with LaTeX Paper

The generated `energy_analysis_latex.txt` file contains values you can copy directly into your `results.tex` file to replace the `[X]` placeholders.

Example:

```latex
% From energy_analysis_latex.txt:
% Average power consumption: 245.7 W
% Peak power consumption: 267.3 W
% Total energy consumption: 0.491400 kWh

% Use in results.tex:
\item Average power consumption: 245.7 W
\item Peak power consumption: 267.3 W
\item Total energy consumption (15 min): 0.491400 kWh
```

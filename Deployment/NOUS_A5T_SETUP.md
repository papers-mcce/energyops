# NOUS A5T Integration with AWS IoT

This guide shows how to integrate your NOUS A5T power strip with your existing AWS IoT infrastructure.

## Prerequisites

1. **NOUS A5T Power Strip** with Tasmota firmware
2. **Custom Tasmota Build** with AWS IoT support (see compilation steps below)
3. **Existing Terraform Infrastructure** (already deployed)

## Step 1: Deploy Tasmota Infrastructure

Deploy the new Tasmota-specific infrastructure:

```bash
cd Deployment/terraform
terraform plan -target=aws_cloudformation_stack.tasmota_auth
terraform apply -target=aws_cloudformation_stack.tasmota_auth
```

This will create:

- CloudFormation stack for Tasmota authentication
- IoT Thing for NOUS A5T
- Topic rules for Tasmota telemetry and status

## Step 2: Get Configuration Command

After deployment, get the BackLog command:

```bash
terraform output -raw tasmota_backlog_command
```

This will output something like:

```
BackLog SetOption3 1; SetOption103 1; MqttHost a1234567890123-ats.iot.eu-central-1.amazonaws.com; MqttPort 443; MqttUser tasmota?x-amz-customauthorizer-name=TasmotaAuth; MqttPassword YknLuSd2tBY2HodwI/7RqA==
```

## Step 3: Compile Custom Tasmota Firmware

Since the NOUS A5T comes with basic Tasmota, you need to compile a custom version with AWS IoT support.

### Option A: Use Gitpod (Recommended)

1. Go to [Gitpod Tasmota](https://gitpod.io/#https://github.com/arendst/Tasmota)
2. Wait for environment to load
3. Create `user_config_override.h`:

```c
#ifndef USE_MQTT_TLS
#define USE_MQTT_TLS
#define USE_MQTT_TLS_CA_CERT
#endif
#ifndef USE_MQTT_AWS_IOT_LIGHT
#define USE_MQTT_AWS_IOT_LIGHT
#endif
#ifdef USE_DISCOVERY
#undef USE_DISCOVERY
#endif
```

4. Compile: `pio run -e tasmota`
5. Download the firmware from `.pio/build/tasmota/firmware.bin`

### Option B: Local PlatformIO

1. Install PlatformIO
2. Clone Tasmota repository
3. Add the same `user_config_override.h`
4. Run `pio run -e tasmota`

## Step 4: Flash Custom Firmware

### Via Web Interface (OTA):

1. Access your NOUS A5T web interface
2. Go to **Firmware Upgrade**
3. Upload the compiled `firmware.bin`
4. Wait for reboot

### Via Serial (if needed):

1. Connect serial adapter to NOUS A5T
2. Use esptool or Tasmotizer to flash

## Step 5: Configure NOUS A5T

1. **Access Web Interface**: Connect to your NOUS A5T
2. **Apply Template**: In console, enter:
   ```
   Template {"NAME":"NOUS A5T","GPIO":[0,3072,544,3104,0,259,0,0,225,226,224,0,35,4704],"FLAG":1,"BASE":18}
   ```
3. **Configure AWS IoT**: Paste the BackLog command from Step 2
4. **Restart**: Device will restart and connect to AWS IoT

## Step 6: Verify Connection

### Check Tasmota Console:

Look for:

```
21:28:25 MQT: Attempting connection...
21:28:25 MQT: AWS IoT endpoint: xxxxxxxxxxxxx-ats.iot.eu-central-1.amazonaws.com
21:28:26 MQT: AWS IoT connected in 1279 ms
21:28:26 MQT: Connected
```

### Check AWS IoT Console:

1. Go to AWS IoT Console → **MQTT test client**
2. Subscribe to: `tele/+/SENSOR`
3. You should see power monitoring data

## Data Flow

Your NOUS A5T will send data to these topics:

### Telemetry Data:

- **Topic**: `tele/tasmota_XXXXXX/SENSOR`
- **Content**: Power, voltage, current, energy consumption
- **Frequency**: Every few seconds

### Status Updates:

- **Topic**: `stat/tasmota_XXXXXX/POWER1-4`
- **Content**: Outlet and USB port status
- **Trigger**: When state changes

### Commands:

- **Topic**: `cmnd/tasmota_XXXXXX/POWER1-4`
- **Content**: Control commands for outlets/USB

## Integration with Existing System

The new topic rules will forward Tasmota data to your existing `mqtt_processor` Lambda function. You may need to update the Lambda to handle Tasmota's data format:

```json
{
  "Time": "2023-12-07T10:30:00",
  "ENERGY": {
    "TotalStartTime": "2023-12-01T00:00:00",
    "Total": 1.234,
    "Yesterday": 0.567,
    "Today": 0.123,
    "Power": 45,
    "ApparentPower": 47,
    "ReactivePower": 12,
    "Factor": 0.96,
    "Voltage": 230,
    "Current": 0.196
  }
}
```

## Troubleshooting

### Connection Issues:

- Ensure custom firmware with AWS IoT support is flashed
- Check memory usage (should be >15KB free)
- Verify BackLog command was applied correctly

### Data Not Flowing:

- Check topic rules in AWS IoT Console
- Verify Lambda function permissions
- Check CloudWatch logs for errors

### Memory Problems:

- Disable unnecessary Tasmota features
- Consider running ESP8266 at 160MHz

## Cost Considerations

- **Free Tier**: 50 devices, 300 messages/day per device
- **Typical Usage**: NOUS A5T sends ~100-200 messages/day
- **Estimated Cost**: $0/month for single device (within free tier)

## Security Notes

- Uses TLS 1.2 encryption
- Password-based authentication (simplified)
- All data remains in your AWS account
- No data shared with third parties

# Tasmota Configuration

This directory contains custom Tasmota configuration files for the project.

## Files

### `user_config_override.h`

Custom Tasmota configuration with:

- **AWS IoT support** (TLS/SSL enabled)
- **NOUS A5T template** for power strip device
- **Energy monitoring** capabilities
- **Custom device naming** support

## Usage

1. **Copy to Tasmota submodule:**

   ```bash
   copy tasmota-config\user_config_override.h tasmota\tasmota\user_config_override.h
   ```

2. **Build custom firmware:**

   ```bash
   cd tasmota
   pio run -e tasmota
   ```

3. **Flash firmware:**
   - Use built firmware from `tasmota/build_output/firmware/tasmota.bin`
   - Flash via Tasmota web UI or serial connection

## Device Configuration

### Hardware: NOUS A5T Power Strip

- **4 AC outlets** with individual control
- **3 USB ports**
- **Energy monitoring** (voltage, current, power)
- **ESP8285** microcontroller (1MB flash)

### Template

```json
{
  "NAME": "NOUS A5T",
  "GPIO": [0, 3072, 544, 3104, 0, 259, 0, 0, 225, 226, 224, 0, 35, 4704],
  "FLAG": 1,
  "BASE": 18
}
```

### Features Enabled

- ✅ AWS IoT TLS support
- ✅ Energy monitoring
- ✅ HTTP API
- ✅ Web interface
- ✅ MQTT support
- ✅ Rules engine

## AWS IoT Setup

After flashing, configure AWS IoT with:

```
BackLog SetOption3 1; SetOption103 1; MqttHost your-endpoint.iot.region.amazonaws.com; MqttPort 443; MqttUser tasmota?x-amz-customauthorizer-name=TasmotaAuth; MqttPassword your-password
```

## Device Info

- **Name**: Server PowerMeter
- **Topic**: serverpowermeter
- **IP**: 10.0.60.5 (example)
- **Firmware**: Custom Tasmota v14.6.0 with AWS IoT

## Build Date

Last built: 2025-06-06T22:38:36

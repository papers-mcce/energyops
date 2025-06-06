# NOUS A5T Flashing Guide

This guide covers multiple methods to flash custom Tasmota firmware with AWS IoT support to your NOUS A5T power strip.

## ⚠️ Safety Warning

- **Unplug the device** from mains power before opening
- **Work on a static-free surface**
- **Double-check connections** before powering on
- **Use proper tools** to avoid damage

## Method 1: OTA Flash (Easiest - Recommended)

Since your NOUS A5T already has Tasmota installed, this is the simplest method.

### Prerequisites:

- NOUS A5T connected to WiFi
- Custom compiled firmware file (`firmware.bin`)
- Web browser

### Steps:

1. **Access Web Interface**:

   - Find your device IP (check router or use network scanner)
   - Open browser and go to `http://DEVICE_IP`

2. **Navigate to Firmware Upgrade**:

   - Click **Firmware Upgrade** in the main menu
   - Or go directly to `http://DEVICE_IP/up`

3. **Upload Firmware**:

   - Click **Choose File**
   - Select your compiled `firmware.bin`
   - Click **Start Upgrade**

4. **Wait for Completion**:

   - Progress bar will show upload status
   - Device will reboot automatically
   - **Do NOT power off during this process**

5. **Verify**:
   - Device should reconnect to WiFi
   - Check console for AWS IoT capabilities

### Troubleshooting OTA:

- If upload fails, try smaller firmware file
- Ensure stable WiFi connection
- Check available flash memory: `Status 0` in console

## Method 2: Serial Flashing (Most Reliable)

This method requires opening the device and connecting a serial adapter.

### Required Hardware:

- **USB-to-Serial adapter** (3.3V logic level)
  - FTDI FT232RL
  - CP2102
  - CH340G
- **Jumper wires** (female-to-male)
- **Screwdriver** (triangle head)

### Step 1: Open the Device

1. **Remove Rubber Pads**:

   - Pop out all 6 rubber pads on the back
   - They cover the screws

2. **Remove Screws**:

   - Use triangle head screwdriver
   - Remove all 6 screws
   - Keep screws safe

3. **Open Case**:
   - Carefully pry open the back cover
   - Use plastic spudger or small flat screwdriver
   - Work around edges slowly

### Step 2: Locate Serial Pins

The NOUS A5T uses a **CUCO_Z0_V1.1** ESP8266 board. Look for these labeled pins:

```
[VCC] [GND] [GPIO0] [TX] [RX]
```

**Pin Locations** (usually near the ESP8266 chip):

- **VCC**: 3.3V power
- **GND**: Ground
- **TX**: Transmit (connect to RX on adapter)
- **RX**: Receive (connect to TX on adapter)
- **GPIO0**: Boot mode selection

### Step 3: Make Connections

**Serial Adapter → NOUS A5T**:

```
3.3V → VCC
GND  → GND
TX   → RX
RX   → TX
```

**Important**:

- **DO NOT connect 5V** - this will damage the ESP8266
- **GPIO0 to GND** for flash mode (connect during boot)

### Step 4: Flash Firmware

#### Option A: Using esptool.py

1. **Install esptool**:

   ```bash
   pip install esptool
   ```

2. **Put device in flash mode**:

   - Connect GPIO0 to GND
   - Power on device (connect VCC)
   - Device should be in flash mode

3. **Erase flash** (recommended):

   ```bash
   esptool.py --port COM3 erase_flash
   ```

4. **Flash firmware**:

   ```bash
   esptool.py --port COM3 write_flash -fs 1MB -fm dout 0x0 firmware.bin
   ```

5. **Reset device**:
   - Disconnect GPIO0 from GND
   - Power cycle device

#### Option B: Using Tasmotizer (GUI Tool)

1. **Download Tasmotizer**:

   - Get from: https://github.com/tasmota/tasmotizer
   - Windows/Mac/Linux versions available

2. **Run Tasmotizer**:

   - Select your serial port
   - Choose your compiled firmware file
   - Click **Tasmotize!**

3. **Follow prompts**:
   - Tool will guide you through the process
   - Automatically handles erase and flash

### Step 5: Reassemble

1. **Test first** (before closing case):

   - Power on device
   - Check if it boots properly
   - Verify WiFi connection

2. **Close case**:
   - Carefully align case halves
   - Replace all 6 screws
   - Replace rubber pads

## Method 3: Using Tuya-Convert (If Applicable)

**Note**: This only works if your device has never been updated and still has vulnerable Tuya firmware.

### Check Compatibility:

- Only works on very old firmware versions
- Most NOUS A5T devices already have Tasmota

### Steps (if compatible):

1. **Setup Tuya-Convert**:

   ```bash
   git clone https://github.com/ct-Open-Source/tuya-convert
   cd tuya-convert
   ./install_prereq.sh
   ```

2. **Run conversion**:

   ```bash
   ./start_flash.sh
   ```

3. **Follow prompts**:
   - Put device in pairing mode
   - Follow on-screen instructions

## Firmware Compilation

### Quick Compilation with Gitpod:

1. **Open Gitpod**:

   - Go to: https://gitpod.io/#https://github.com/arendst/Tasmota

2. **Create config file**:

   ```bash
   nano tasmota/user_config_override.h
   ```

3. **Add AWS IoT support**:

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

4. **Compile**:

   ```bash
   pio run -e tasmota
   ```

5. **Download firmware**:
   - File location: `.pio/build/tasmota/firmware.bin`
   - Download to your computer

### Local Compilation:

1. **Install PlatformIO**:

   ```bash
   pip install platformio
   ```

2. **Clone Tasmota**:

   ```bash
   git clone https://github.com/arendst/Tasmota.git
   cd Tasmota
   ```

3. **Create config** (same as above)

4. **Compile**:
   ```bash
   pio run -e tasmota
   ```

## Verification After Flashing

### Check AWS IoT Support:

1. **Access console** via web interface
2. **Check build info**:

   ```
   Status 2
   ```

   Look for AWS IoT features in the build

3. **Test MQTT TLS**:
   ```
   MqttHost test.mosquitto.org
   MqttPort 8883
   ```

### Memory Check:

```
Status 0
```

Should show >15KB free for AWS IoT operations.

## Troubleshooting

### Common Issues:

**Device won't enter flash mode**:

- Check GPIO0 connection to GND
- Verify 3.3V power supply
- Try different serial adapter

**Flash fails**:

- Check baud rate (try 115200 or 9600)
- Verify connections
- Try erasing flash first

**Device won't boot after flash**:

- Check for correct firmware file
- Try flashing minimal Tasmota first
- Verify flash size settings

**OTA upload fails**:

- Check available flash space
- Try smaller firmware build
- Ensure stable WiFi connection

### Recovery:

If device becomes unresponsive:

1. **Serial recovery**: Use serial method to reflash
2. **Factory reset**: Hold button during power-on
3. **Minimal flash**: Flash basic Tasmota first, then upgrade

## Pin Reference

### NOUS A5T (CUCO_Z0_V1.1) Pinout:

```
     [ESP8266]
        |
[VCC][GND][GPIO0][TX][RX]
```

### Serial Connection Diagram:

```
USB-Serial    NOUS A5T
---------     --------
3.3V    →     VCC
GND     →     GND
TX      →     RX
RX      →     TX
        →     GPIO0 (to GND for flash mode)
```

## Safety Reminders

- ⚠️ **Never connect 5V to 3.3V pins**
- ⚠️ **Always disconnect mains power**
- ⚠️ **Use ESD protection**
- ⚠️ **Double-check connections**
- ⚠️ **Don't force connectors**

## Next Steps

After successful flashing:

1. Configure device template
2. Apply AWS IoT settings
3. Test power monitoring
4. Integrate with your infrastructure

See the main setup guide for configuration steps.

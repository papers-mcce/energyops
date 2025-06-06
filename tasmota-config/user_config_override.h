/*
  user_config_override.h - user configuration overrides my_user_config.h for Tasmota

  Copyright (C) 2021  Theo Arends

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef _USER_CONFIG_OVERRIDE_H_
#define _USER_CONFIG_OVERRIDE_H_

/*****************************************************************************************************\
 * USAGE:
 *   To modify the stock configuration without changing the my_user_config.h file:
 *   (1) copy this file to "user_config_override.h" (It will be ignored by Git)
 *   (2) define your own settings below
 *
 ******************************************************************************************************
 * ATTENTION:
 *   - Changes to SECTION1 PARAMETER defines will only override flash settings if you change define CFG_HOLDER.
 *   - Expect compiler warnings when no ifdef/undef/endif sequence is used.
 *   - You still need to update my_user_config.h for major define USE_MQTT_TLS.
 *   - All parameters can be persistent changed online using commands via MQTT, WebConsole or Serial.
\*****************************************************************************************************/

// -- AWS IoT Configuration ---------------------------
// Enable MQTT TLS support for AWS IoT
#ifndef USE_MQTT_TLS
#define USE_MQTT_TLS
#define USE_MQTT_TLS_CA_CERT // Optional but highly recommended
#endif

// Enable AWS IoT Light (password-based authentication)
#ifndef USE_MQTT_AWS_IOT_LIGHT
#define USE_MQTT_AWS_IOT_LIGHT
#endif

// Disable Discovery to save memory
#ifdef USE_DISCOVERY
#undef USE_DISCOVERY
#endif

// -- Optional: Your WiFi settings (uncomment and modify as needed) --
/*
#undef  STA_SSID1
#define STA_SSID1         "YourSSID"             // [Ssid1] Wifi SSID

#undef  STA_PASS1
#define STA_PASS1         "YourWifiPassword"     // [Password1] Wifi password
*/

// -- Device Configuration for Nous 15A 3AC 3USB Power Strip --
#undef  FRIENDLY_NAME
#define FRIENDLY_NAME     "Nous Power Strip"    // [FriendlyName] Friendlyname up to 32 characters used by webpages and Alexa

#undef  PROJECT
#define PROJECT           "nous"                 // PROJECT is used as the default topic delimiter

// Template for Nous 15A 3AC 3USB Power Strip
// {"NAME":"NOUS A5T","GPIO":[0,3072,544,3104,0,259,0,0,225,226,224,0,35,4704],"FLAG":1,"BASE":18}
#ifdef USER_TEMPLATE
#undef USER_TEMPLATE
#endif
#define USER_TEMPLATE     "{\"NAME\":\"NOUS A5T\",\"GPIO\":[0,3072,544,3104,0,259,0,0,225,226,224,0,35,4704],\"FLAG\":1,\"BASE\":18}"

#undef  MODULE
#define MODULE            USER_MODULE           // Use the custom template above

// !!! Remember that your changes GOES AT THE BOTTOM OF THIS FILE right before the last #endif !!!

#endif  // _USER_CONFIG_OVERRIDE_H_ 
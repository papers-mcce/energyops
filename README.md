# G1-S2-INENI: Serverless Energy Monitoring System

A reproducible research repository for the paper:  
**"Serverless Energy Monitoring and IoT Integration with AWS"**

## Table of Contents

1. [Overview](#overview)
2. [Project Structure](#project-structure)
3. [Quick Start](#quick-start)
4. [Deployment Instructions](#deployment-instructions)
    - [Terraform Infrastructure](#terraform-infrastructure)
    - [Lambda Functions](#lambda-functions)
    - [Helper Scripts](#helper-scripts)
    - [IAM Policies](#iam-policies)
5. [Tasmota Firmware & Configuration](#tasmota-firmware--configuration)
    - [Custom Firmware Build](#custom-firmware-build)
    - [Flashing Guide](#flashing-guide)
    - [Device Setup](#device-setup)
6. [Replication Checklist](#replication-checklist)
7. [References](#references)

---

## 1. Overview

This repository contains all code, configuration, and documentation required to replicate the experiments and infrastructure described in our paper. The system collects energy data from smart devices (e.g., NOUS A5T power strip running Tasmota), processes it serverlessly on AWS, and stores it for analysis.

## 2. Project Structure

- [`/Deployment`](./Deployment): All AWS infrastructure as code (Terraform), Lambda functions, scripts, and IAM policies.
- [`/tasmota-config`](./tasmota-config): Custom Tasmota firmware configuration for AWS IoT integration.
- [`/tasmota`](./tasmota): (Submodule or source) for Tasmota firmware (see [Tasmota Firmware & Configuration](#tasmota-firmware--configuration)).

## 3. Quick Start

- Clone the repository and follow the [Deployment Instructions](#deployment-instructions).
- Build and flash the custom Tasmota firmware as described in [Tasmota Firmware & Configuration](#tasmota-firmware--configuration).

## 4. Deployment Instructions

### Terraform Infrastructure

- See [`Deployment/terraform/README.md`](./Deployment/terraform/README.md) for full details.
- Deploys DynamoDB, Lambda, IoT Core, EventBridge, IAM, and all required AWS resources.
- Example:
  ```bash
  cd Deployment/terraform
  terraform init
  terraform apply
  ```

### Lambda Functions

- Located in [`Deployment/Lambda`](./Deployment/Lambda)
    - `energylive-api-collector.py`: Collects data from energyLIVE API.
    - `process-mqtt.py`: Processes MQTT messages from Tasmota devices.
    - `epex-spot-collector.py`: Collects electricity price data.
- Test scripts and requirements included.

### Helper Scripts

- Located in [`Deployment/Scripts`](./Deployment/Scripts)
    - `mfa-auth.sh`: AWS MFA authentication helper.
    - `schedule_stress.sh`, `schedule_update_stress.sh`, `schedule_fio_stress.sh`: Stress test scheduling.
    - `deleteTimestamps.py`: Data cleanup utility.

### IAM Policies

- Located in [`Deployment/IAM-Custom`](./Deployment/IAM-Custom)
    - `requireMFA.json`: Enforces MFA.
    - `restricttoFrankfurt.json`: Restricts AWS actions to Frankfurt region.

## 5. Tasmota Firmware & Configuration

### Custom Firmware Build

- See [`tasmota-config/README.md`](./tasmota-config/README.md) for detailed build instructions.
- Copy `user_config_override.h` to your Tasmota source and build with PlatformIO or Gitpod.

### Flashing Guide

- See [`Deployment/NOUS_A5T_FLASHING_GUIDE.md`](./Deployment/NOUS_A5T_FLASHING_GUIDE.md) for step-by-step flashing instructions (OTA, serial, or Tuya-Convert).

### Device Setup

- See [`Deployment/NOUS_A5T_SETUP.md`](./Deployment/NOUS_A5T_SETUP.md) for AWS IoT configuration and device template.
- Includes BackLog command for MQTT/TLS setup.

## 6. Replication Checklist

- [ ] Deploy AWS infrastructure with Terraform
- [ ] Build and flash custom Tasmota firmware
- [ ] Configure device with AWS IoT credentials
- [ ] Verify data flow from device to AWS
- [ ] Analyze data in DynamoDB
- [ ] Establish AWS Glue Crawler
- [ ] Build AWS Athena for SQL Querying 
- [ ] Build AWS Quicksight with custom queries and Dashboard

## 7. References

- All scripts, configuration, and guides are referenced in the above sections.
- For further details, see the in-folder `README.md` and markdown guides.

---

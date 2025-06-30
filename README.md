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
    - [Energy Analysis](#energy-analysis)
5. [Tasmota Firmware & Configuration](#tasmota-firmware--configuration)
    - [Custom Firmware Build](#custom-firmware-build)
    - [Flashing Guide](#flashing-guide)
    - [Device Setup](#device-setup)
6. [Documentation & Presentations](#documentation--presentations)
    - [Final Paper](#final-paper)
    - [Position Paper](#position-paper)
    - [HTML Presentation](#html-presentation)
7. [Replication Checklist](#replication-checklist)
8. [References](#references)

---

## 1. Overview

This repository contains all code, configuration, and documentation required to replicate the experiments and infrastructure described in our paper. The system collects energy data from smart devices (e.g., NOUS A5T power strip running Tasmota), processes it serverlessly on AWS, and stores it for analysis.

All necessary scripts, infrastructure definitions, and setup guides are included to ensure full reproducibility of the research results.

## 2. Project Structure

- [`/Deployment`](./Deployment): All AWS infrastructure as code (Terraform), Lambda functions, scripts, and IAM policies
  - [`/Energy-Analysis`](./Deployment/Energy-Analysis): Scripts and tools for energy data analysis
  - [`/terraform`](./Deployment/terraform): Complete AWS infrastructure as code
  - [`/Lambda`](./Deployment/Lambda): Serverless functions for data collection and processing
  - [`/Scripts`](./Deployment/Scripts): Utility scripts for deployment and maintenance
  - [`/IAM-Custom`](./Deployment/IAM-Custom): Custom IAM policies for security
- [`/tasmota-config`](./tasmota-config): Custom Tasmota firmware configuration for AWS IoT integration
- [`/tasmota`](./tasmota): Tasmota firmware source for custom builds
- [`/Final-Paper`](./Final-Paper): LaTeX source for the final research paper
- [`/Position-Paper`](./Position-Paper): LaTeX source for the position paper
- [`/html-presentation-project`](./html-presentation-project): Interactive HTML presentation of research findings
- [`/drawio`](./drawio): System architecture and use case diagrams
- [`/PlantUML_Diagramms`](./PlantUML_Diagramms): UML diagrams for system documentation

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

### Energy Analysis

Located in [`Deployment/Energy-Analysis`](./Deployment/Energy-Analysis):
- Energy consumption data analysis scripts
- EPEX price analysis tools
- Data visualization utilities
- CSV exports for reproducibility

## 5. Tasmota Firmware & Configuration

### Custom Firmware Build

- See [`tasmota-config/README.md`](./tasmota-config/README.md) for detailed build instructions.
- Copy `user_config_override.h` to your Tasmota source and build with PlatformIO or Gitpod.

### Flashing Guide

- See [`Deployment/NOUS_A5T_FLASHING_GUIDE.md`](./Deployment/NOUS_A5T_FLASHING_GUIDE.md) for step-by-step flashing instructions (OTA, serial, or Tuya-Convert).

### Device Setup

- See [`Deployment/NOUS_A5T_SETUP.md`](./Deployment/NOUS_A5T_SETUP.md) for AWS IoT configuration and device template.
- Includes BackLog command for MQTT/TLS setup.

## 6. Documentation & Presentations

### Final Paper

The [`/Final-Paper`](./Final-Paper) directory contains the LaTeX source for our research paper, including:
- Complete manuscript source
- Figures and diagrams
- Bibliography and references
- Build instructions in the directory's README

### Position Paper

The [`/Position-Paper`](./Position-Paper) directory contains our initial position paper, including:
- Problem statement
- Proposed methodology
- Preliminary results
- Build instructions in the directory's README

### HTML Presentation

The [`/html-presentation-project`](./html-presentation-project) provides an interactive web-based presentation of our research:
- Responsive design for multiple devices
- Interactive diagrams and visualizations
- Built with modern web technologies
- Deployment instructions in the directory's README

## 7. Replication Checklist

The following checklist summarizes the steps required to fully replicate the system and experiments described in the paper. All required materials and instructions are provided within this repository.

- [ ] Deploy AWS infrastructure with Terraform
- [ ] Build and flash custom Tasmota firmware
- [ ] Configure device with AWS IoT credentials
- [ ] Verify data flow from device to AWS
- [ ] Run energy analysis scripts
- [ ] Analyze data in DynamoDB
- [ ] Establish AWS Glue Crawler
- [ ] Build AWS Athena for SQL Querying 
- [ ] Build AWS Quicksight with custom queries and Dashboard
- [ ] Deploy HTML presentation (optional)

## 8. References

- All scripts, configuration, and guides are referenced in the above sections
- For further details, see the in-folder `README.md` and markdown guides
- Architecture diagrams available in the [`/drawio`](./drawio) directory
- UML documentation in [`/PlantUML_Diagramms`](./PlantUML_Diagramms)

---

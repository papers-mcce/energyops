#!/bin/bash

# System Update Energy Testing Script
# Usage: ./schedule_update_stress.sh [time] [update_type]

# Default values
DEFAULT_TIME="22:30"
DEFAULT_UPDATE_TYPE="standard"

# Get parameters
TARGET_TIME=${1:-$DEFAULT_TIME}
UPDATE_TYPE=${2:-$DEFAULT_UPDATE_TYPE}

echo "🔧 System Update Energy Testing Script"
echo "======================================"
echo "Target time: $TARGET_TIME"
echo "Update type: $UPDATE_TYPE"
echo ""

# Check if required tools are installed
check_and_install() {
    local package=$1
    local command=${2:-$1}
    
    if ! command -v $command &> /dev/null; then
        echo "Installing $package..."
        sudo apt update
        sudo apt install -y $package
    fi
}

# Install required packages
check_and_install "at"

# Ensure atd service is running
if ! systemctl is-active --quiet atd; then
    echo "Starting atd service..."
    sudo systemctl start atd
    sudo systemctl enable atd
fi

# Create the update test script
UPDATE_SCRIPT="/tmp/update_test_job_$$.sh"
cat > "$UPDATE_SCRIPT" << EOF
#!/bin/bash
UPDATE_TYPE=\$1

echo "🚀 Starting system update energy test at \$(date)" | tee -a /tmp/update-test.log
echo "Update type: \$UPDATE_TYPE" | tee -a /tmp/update-test.log
echo "=============================================" | tee -a /tmp/update-test.log

# Verify sudo access is still available
if ! sudo -n apt --version &>/dev/null; then
    echo "❌ Error: No sudo access for apt commands" | tee -a /tmp/update-test.log
    exit 1
fi

case "\$UPDATE_TYPE" in
    "standard")
        echo "📦 Running standard update cycle..." | tee -a /tmp/update-test.log
        echo "Phase 1: Repository update (apt update)" | tee -a /tmp/update-test.log
        sudo apt update 2>&1 | tee -a /tmp/update-test.log
        
        echo "Phase 2: Package upgrades (apt upgrade)" | tee -a /tmp/update-test.log
        sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y 2>&1 | tee -a /tmp/update-test.log
        ;;
        
    "repository-only")
        echo "📡 Running repository update only..." | tee -a /tmp/update-test.log
        sudo apt update 2>&1 | tee -a /tmp/update-test.log
        ;;
        
    "large-package")
        echo "📦 Installing large package (docker.io)..." | tee -a /tmp/update-test.log
        sudo apt update 2>&1 | tee -a /tmp/update-test.log
        sudo DEBIAN_FRONTEND=noninteractive apt install -y docker.io 2>&1 | tee -a /tmp/update-test.log
        ;;
        
    "development-tools")
        echo "🛠️  Installing development tools..." | tee -a /tmp/update-test.log
        sudo apt update 2>&1 | tee -a /tmp/update-test.log
        sudo DEBIAN_FRONTEND=noninteractive apt install -y build-essential 2>&1 | tee -a /tmp/update-test.log
        ;;
        
    "security-only")
        echo "🔒 Installing security updates only..." | tee -a /tmp/update-test.log
        sudo apt update 2>&1 | tee -a /tmp/update-test.log
        sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y --only-upgrade \$(apt list --upgradable 2>/dev/null | grep -i security | cut -d/ -f1) 2>&1 | tee -a /tmp/update-test.log
        ;;
        
    "autoremove")
        echo "🧹 Running autoremove and autoclean..." | tee -a /tmp/update-test.log
        sudo apt autoremove -y 2>&1 | tee -a /tmp/update-test.log
        sudo apt autoclean 2>&1 | tee -a /tmp/update-test.log
        ;;
        
    *)
        echo "❌ Unknown update type: \$UPDATE_TYPE" | tee -a /tmp/update-test.log
        exit 1
        ;;
esac

echo "✅ System update test completed at \$(date)" | tee -a /tmp/update-test.log
echo "📊 Energy consumption measurement complete!" | tee -a /tmp/update-test.log
echo "Results logged to: /tmp/update-test.log"

# Clean up the temporary script
rm -f "$UPDATE_SCRIPT"
EOF

# Make the script executable
chmod +x "$UPDATE_SCRIPT"

# Create a wrapper script that passes the parameters
WRAPPER_SCRIPT="/tmp/update_wrapper_$$.sh"
cat > "$WRAPPER_SCRIPT" << EOF
#!/bin/bash
"$UPDATE_SCRIPT" $UPDATE_TYPE
rm -f "$WRAPPER_SCRIPT"
EOF

chmod +x "$WRAPPER_SCRIPT"

# Schedule the job with 'at'
echo "Scheduling system update test for $TARGET_TIME..."
echo "$WRAPPER_SCRIPT" | at "$TARGET_TIME" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ System update test successfully scheduled for $TARGET_TIME"
    echo "📝 Output will be logged to: /tmp/update-test.log"
    echo ""
else
    echo "❌ Failed to schedule job. Check if 'at' service is running."
    echo "Try: sudo systemctl start atd"
    exit 1
fi

# Show information about the scheduled job
echo "📋 Scheduled Update Test Details:"
echo "================================="
echo "Update type: $UPDATE_TYPE"
echo "Scheduled for: $TARGET_TIME"
echo "Log file: /tmp/update-test.log"
echo ""

case "$UPDATE_TYPE" in
    "standard")
        echo "Test phases: Repository update → Package upgrades"
        echo "Expected duration: 5-15 minutes"
        echo "Energy profile: Network I/O → Disk I/O → CPU processing"
        ;;
    "repository-only")
        echo "Test phases: Repository metadata update only"
        echo "Expected duration: 1-3 minutes"
        echo "Energy profile: Pure network I/O activity"
        ;;
    "large-package")
        echo "Test phases: Repository update → Docker installation"
        echo "Expected duration: 5-10 minutes"
        echo "Energy profile: Network download → Disk I/O → Service setup"
        ;;
    "development-tools")
        echo "Test phases: Repository update → Build tools installation"
        echo "Expected duration: 3-8 minutes"
        echo "Energy profile: Network download → Disk I/O → Compilation"
        ;;
    "security-only")
        echo "Test phases: Repository update → Security patches only"
        echo "Expected duration: 2-8 minutes"
        echo "Energy profile: Targeted updates with minimal overhead"
        ;;
    "autoremove")
        echo "Test phases: Package cleanup → Cache cleanup"
        echo "Expected duration: 1-5 minutes"
        echo "Energy profile: Disk I/O for cleanup operations"
        ;;
esac

echo ""
echo "📖 Usage Examples:"
echo "=================="
echo "./schedule_update_stress.sh                    # Standard update at 18:00"
echo "./schedule_update_stress.sh 14:30              # Standard update at 14:30"
echo "./schedule_update_stress.sh 14:30 repository-only    # Repo update only"
echo "./schedule_update_stress.sh 14:30 large-package      # Install Docker"
echo "./schedule_update_stress.sh 14:30 development-tools  # Install build tools"
echo "./schedule_update_stress.sh 14:30 security-only      # Security updates only"
echo "./schedule_update_stress.sh 14:30 autoremove         # Cleanup operations"
echo ""
echo "⚡ Energy Measurement Tips:"
echo "=========================="
echo "- Monitor network activity during download phases"
echo "- Watch disk I/O during installation phases"
echo "- CPU usage spikes during package configuration"
echo "- Different update types have distinct energy profiles"
echo "- Consider running before/after comparisons" 
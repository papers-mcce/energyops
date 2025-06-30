#!/bin/bash

# FIO I/O Stress Scheduling Script for Energy Consumption Testing
# Usage: ./schedule_fio_stress.sh [time] [cycles] [duration] [pause]

# Default values
DEFAULT_TIME="17:00"
DEFAULT_CYCLES=4        # Number of I/O stress cycles
DEFAULT_DURATION=900    # 15 minutes (900 seconds)
DEFAULT_PAUSE=900       # 15 minutes pause (900 seconds)

# Get parameters
TARGET_TIME=${1:-$DEFAULT_TIME}
CYCLES=${2:-$DEFAULT_CYCLES}
DURATION=${3:-$DEFAULT_DURATION}
PAUSE=${4:-$DEFAULT_PAUSE}

echo "🔧 FIO I/O Stress Scheduling Script for Energy Testing"
echo "====================================================="
echo "Target time: $TARGET_TIME"
echo "Cycles: $CYCLES"
echo "I/O stress duration: ${DURATION}s ($(($DURATION/60)) minutes)"
echo "Pause between cycles: ${PAUSE}s ($(($PAUSE/60)) minutes)"
echo "Total runtime: $(( ($DURATION + $PAUSE) * $CYCLES - $PAUSE ))s (~$(( (($DURATION + $PAUSE) * $CYCLES - $PAUSE) / 60 )) minutes)"
echo "Test disk: /mnt/fio-test (50GB dedicated disk)"
echo "Test file size: 8GB per job"
echo ""

# Check if test disk is mounted
if ! mountpoint -q /mnt/fio-test; then
    echo "❌ Error: /mnt/fio-test is not mounted!"
    echo "Please ensure the FIO test disk is properly mounted."
    exit 1
fi

# Check available space
AVAILABLE_GB=$(df -BG /mnt/fio-test | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_GB" -lt 35 ]; then
    echo "⚠️  Warning: Only ${AVAILABLE_GB}GB available on test disk"
    echo "Recommended: At least 35GB for optimal testing"
fi

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
check_and_install "fio"
check_and_install "at"

# Ensure atd service is running
if ! systemctl is-active --quiet atd; then
    echo "Starting atd service..."
    sudo systemctl start atd
    sudo systemctl enable atd
fi

# Create the FIO stress test script with cycles
FIO_SCRIPT="/tmp/fio_stress_job_$$.sh"
cat > "$FIO_SCRIPT" << 'EOF'
#!/bin/bash
CYCLES=$1
DURATION=$2
PAUSE=$3

echo "🚀 Starting FIO I/O stress cycles at $(date)" | tee -a /tmp/fio-stress.log
echo "Configuration: $CYCLES cycles, ${DURATION}s duration, ${PAUSE}s pause" | tee -a /tmp/fio-stress.log
echo "Target: Maximum I/O load for energy consumption measurement" | tee -a /tmp/fio-stress.log
echo "Test location: /mnt/fio-test (dedicated 50GB disk)" | tee -a /tmp/fio-stress.log
echo "=============================================================" | tee -a /tmp/fio-stress.log

# Verify test disk is still mounted
if ! mountpoint -q /mnt/fio-test; then
    echo "❌ Error: Test disk not mounted!" | tee -a /tmp/fio-stress.log
    exit 1
fi

for i in $(seq 1 $CYCLES); do
    echo "📊 I/O Stress Cycle $i/$CYCLES - Starting at $(date)" | tee -a /tmp/fio-stress.log
    echo "Running maximum I/O load test on dedicated disk..." | tee -a /tmp/fio-stress.log
    
    # Run FIO with maximum I/O stress configuration on dedicated disk
    fio --output-format=normal --output=/tmp/fio_cycle_${i}.log \
        --name=max_io_stress \
        --ioengine=libaio \
        --direct=1 \
        --rw=randrw \
        --rwmixread=70 \
        --bs=4k,64k,1m \
        --bsrange=4k-1m \
        --size=8G \
        --numjobs=4 \
        --iodepth=32 \
        --runtime=${DURATION} \
        --time_based \
        --group_reporting \
        --directory=/mnt/fio-test \
        --filename_format='fio_test_$jobnum.$filenum' \
        --fallocate=none \
        --create_serialize=0 \
        --file_service_type=roundrobin \
        --norandommap \
        --random_generator=tausworthe64 \
        --thread 2>&1 | tee -a /tmp/fio-stress.log
    
    echo "✅ I/O Stress Cycle $i/$CYCLES completed at $(date)" | tee -a /tmp/fio-stress.log
    
    # Extract key metrics from this cycle
    if [ -f "/tmp/fio_cycle_${i}.log" ]; then
        echo "📈 Cycle $i Performance Summary:" | tee -a /tmp/fio-stress.log
        grep -E "(READ:|WRITE:|read:|write:)" /tmp/fio_cycle_${i}.log | head -4 | tee -a /tmp/fio-stress.log
        echo "---" | tee -a /tmp/fio-stress.log
    fi
    
    # Clean up test files after each cycle to save space
    echo "🧹 Cleaning up test files from cycle $i..." | tee -a /tmp/fio-stress.log
    rm -f /mnt/fio-test/fio_test_*
    
    # Pause between cycles (except after the last cycle)
    if [ $i -lt $CYCLES ]; then
        echo "⏸️  Pausing for ${PAUSE}s ($((PAUSE/60)) minutes) - I/O idle period..." | tee -a /tmp/fio-stress.log
        sleep $PAUSE
        echo "▶️  Pause completed at $(date)" | tee -a /tmp/fio-stress.log
    fi
done

echo "🏁 All FIO I/O stress cycles completed at $(date)" | tee -a /tmp/fio-stress.log

# Final cleanup
echo "🧹 Final cleanup..." | tee -a /tmp/fio-stress.log
rm -f /mnt/fio-test/fio_test_*
rm -f /tmp/fio_cycle_*.log

echo "📊 Energy consumption measurement complete!" | tee -a /tmp/fio-stress.log
echo "Results logged to: /tmp/fio-stress.log"

# Clean up the temporary script
rm -f "$FIO_SCRIPT"
EOF

# Make the script executable and pass parameters
chmod +x "$FIO_SCRIPT"

# Create a wrapper script that passes the parameters
WRAPPER_SCRIPT="/tmp/fio_wrapper_$$.sh"
cat > "$WRAPPER_SCRIPT" << EOF
#!/bin/bash
"$FIO_SCRIPT" $CYCLES $DURATION $PAUSE
rm -f "$WRAPPER_SCRIPT"
EOF

chmod +x "$WRAPPER_SCRIPT"

# Schedule the job with 'at'
echo "Scheduling FIO I/O stress job for $TARGET_TIME..."
echo "$WRAPPER_SCRIPT" | at "$TARGET_TIME" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ FIO I/O stress job successfully scheduled for $TARGET_TIME"
    echo "📝 Output will be logged to: /tmp/fio-stress.log"
    echo ""
else
    echo "❌ Failed to schedule job. Check if 'at' service is running."
    echo "Try: sudo systemctl start atd"
    exit 1
fi

# Show information about the scheduled job
echo "📋 Scheduled FIO I/O Stress Test Details:"
echo "========================================"
echo "Pattern: $CYCLES cycles of ${DURATION}s max I/O + ${PAUSE}s idle"
echo "I/O Configuration:"
echo "  - 4 parallel jobs with 32 queue depth"
echo "  - Mixed random read/write (70% read, 30% write)"
echo "  - Variable block sizes (4K-1M)"
echo "  - 8GB test file per job (32GB total)"
echo "  - Direct I/O on dedicated 50GB disk (/mnt/fio-test)"
echo "  - Files cleaned up after each cycle"
echo "Scheduled for: $TARGET_TIME"
echo "Estimated completion: $(date -d "$TARGET_TIME + $(( ($DURATION + $PAUSE) * $CYCLES - $PAUSE )) seconds" '+%H:%M')"
echo "Log file: /tmp/fio-stress.log"
echo ""

# List all scheduled 'at' jobs
echo "📅 All Scheduled Jobs:"
echo "====================="
if command -v atq &> /dev/null; then
    atq | while read job_id time date queue user; do
        if [ -n "$job_id" ]; then
            echo "Job ID: $job_id | Time: $time $date | User: $user"
            # Show job details
            echo "Command preview:"
            at -c "$job_id" 2>/dev/null | tail -5 | head -3 | sed 's/^/  /'
            echo ""
        fi
    done
    
    # If no jobs, show message
    if [ $(atq | wc -l) -eq 0 ]; then
        echo "No jobs currently scheduled."
    fi
else
    echo "atq command not available"
fi

echo ""
echo "🔧 Management Commands:"
echo "======================"
echo "List jobs:         atq"
echo "Remove job:        atrm <job_id>"
echo "View job:          at -c <job_id>"
echo "View live log:     tail -f /tmp/fio-stress.log"
echo "Monitor I/O:       iostat -x 1"
echo "Monitor disk:      watch 'df -h /mnt/fio-test'"
echo "Monitor processes: top -p \$(pgrep fio)"
echo ""
echo "📖 Usage Examples:"
echo "=================="
echo "./schedule_fio_stress.sh                     # Default: 4 cycles at 17:00"
echo "./schedule_fio_stress.sh 14:30               # 4 cycles at 14:30"
echo "./schedule_fio_stress.sh 14:30 6             # 6 cycles at 14:30"
echo "./schedule_fio_stress.sh 14:30 6 1800        # 6 cycles, 30min duration"
echo "./schedule_fio_stress.sh 14:30 6 1800 600    # 6 cycles, 30min I/O, 10min pause"
echo ""
echo "⚡ Energy Measurement Tips:"
echo "=========================="
echo "- Monitor power consumption during I/O stress periods"
echo "- Compare idle periods vs. active I/O periods"
echo "- Use 'iostat -x 1' to verify I/O activity on sdb"
echo "- Check CPU usage with 'top' during tests"
echo "- Monitor disk temperature if available"
echo ""
echo "✅ Disk Setup Complete:"
echo "======================"
echo "Test disk: /dev/sdb mounted at /mnt/fio-test"
echo "Available space: $(df -h /mnt/fio-test | awk 'NR==2 {print $4}')"
echo "Ready for energy consumption testing!" 
#!/bin/bash

# Stress-ng Scheduling Script using 'at' command
# Usage: ./schedule_stress.sh [time] [cycles] [duration] [pause]

# Default values
DEFAULT_TIME="16:45"
DEFAULT_CYCLES=4        # Number of stress cycles
DEFAULT_DURATION=900    # 15 minutes (900 seconds)
DEFAULT_PAUSE=900       # 15 minutes pause (900 seconds)

# Get parameters
TARGET_TIME=${1:-$DEFAULT_TIME}
CYCLES=${2:-$DEFAULT_CYCLES}
DURATION=${3:-$DEFAULT_DURATION}
PAUSE=${4:-$DEFAULT_PAUSE}

echo "🔧 Stress-ng Scheduling Script (using 'at' command)"
echo "=================================================="
echo "Target time: $TARGET_TIME"
echo "Cycles: $CYCLES"
echo "Duration per cycle: ${DURATION}s ($(($DURATION/60)) minutes)"
echo "Pause between cycles: ${PAUSE}s ($(($PAUSE/60)) minutes)"
echo "Total runtime: $(( ($DURATION + $PAUSE) * $CYCLES - $PAUSE ))s (~$(( (($DURATION + $PAUSE) * $CYCLES - $PAUSE) / 60 )) minutes)"
echo "CPUs: 56 (all logical processors)"
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
check_and_install "stress-ng"
check_and_install "at"

# Ensure atd service is running
if ! systemctl is-active --quiet atd; then
    echo "Starting atd service..."
    sudo systemctl start atd
    sudo systemctl enable atd
fi

# Create the stress-ng command script with cycles
STRESS_SCRIPT="/tmp/stress_job_$$.sh"
cat > "$STRESS_SCRIPT" << EOF
#!/bin/bash
CYCLES=$CYCLES
DURATION=$DURATION
PAUSE=$PAUSE

echo "🚀 Starting stress-ng cycles at \$(date)" | tee -a /tmp/stress-ng.log
echo "Configuration: \$CYCLES cycles, \${DURATION}s duration, \${PAUSE}s pause" | tee -a /tmp/stress-ng.log
echo "=============================================" | tee -a /tmp/stress-ng.log

for i in \$(seq 1 \$CYCLES); do
    echo "📊 Cycle \$i/\$CYCLES - Starting at \$(date)" | tee -a /tmp/stress-ng.log
    echo "Running: stress-ng --cpu 56 --timeout \${DURATION}s" | tee -a /tmp/stress-ng.log
    
    # Run stress-ng
    stress-ng --cpu 56 --timeout \${DURATION}s 2>&1 | tee -a /tmp/stress-ng.log
    
    echo "✅ Cycle \$i/\$CYCLES completed at \$(date)" | tee -a /tmp/stress-ng.log
    
    # Pause between cycles (except after the last cycle)
    if [ \$i -lt \$CYCLES ]; then
        echo "⏸️  Pausing for \${PAUSE}s (\$((PAUSE/60)) minutes)..." | tee -a /tmp/stress-ng.log
        sleep \$PAUSE
        echo "▶️  Pause completed at \$(date)" | tee -a /tmp/stress-ng.log
    fi
done

echo "🏁 All stress-ng cycles completed at \$(date)" | tee -a /tmp/stress-ng.log
echo "Results logged to: /tmp/stress-ng.log"
# Clean up the temporary script
rm -f "$STRESS_SCRIPT"
EOF

chmod +x "$STRESS_SCRIPT"

# Schedule the job with 'at'
echo "Scheduling stress-ng job for $TARGET_TIME..."
echo "$STRESS_SCRIPT" | at "$TARGET_TIME" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Stress-ng job successfully scheduled for $TARGET_TIME"
    echo "📝 Output will be logged to: /tmp/stress-ng.log"
    echo ""
else
    echo "❌ Failed to schedule job. Check if 'at' service is running."
    echo "Try: sudo systemctl start atd"
    exit 1
fi

# Show information about the scheduled job
echo "📋 Scheduled Job Details:"
echo "========================"
echo "Pattern: $CYCLES cycles of ${DURATION}s stress + ${PAUSE}s pause"
echo "Command: stress-ng --cpu 56 --timeout ${DURATION}s (repeated $CYCLES times)"
echo "Scheduled for: $TARGET_TIME"
echo "Estimated completion: $(date -d "$TARGET_TIME + $(( ($DURATION + $PAUSE) * $CYCLES - $PAUSE )) seconds" '+%H:%M')"
echo "Log file: /tmp/stress-ng.log"
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
echo "List jobs:    atq"
echo "Remove job:   atrm <job_id>"
echo "View job:     at -c <job_id>"
echo "View log:     tail -f /tmp/stress-ng.log"
echo ""
echo "📖 Usage Examples:"
echo "=================="
echo "./schedule_stress.sh                    # Default: 4 cycles at 23:30"
echo "./schedule_stress.sh 14:30              # 4 cycles at 14:30"
echo "./schedule_stress.sh 14:30 6            # 6 cycles at 14:30"
echo "./schedule_stress.sh 14:30 6 1800       # 6 cycles, 30min duration"
echo "./schedule_stress.sh 14:30 6 1800 600   # 6 cycles, 30min stress, 10min pause"
echo ""
echo "Note: Jobs will run even if you log out (unlike background processes)" 
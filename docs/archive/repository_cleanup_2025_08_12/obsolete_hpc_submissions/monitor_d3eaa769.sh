#!/bin/bash
# Monitoring script for job tracking

JOB_ID=$1
OUTPUT_DIR="$HOME/globtim_hpc/outputs/d3eaa769"

echo "Monitoring job $JOB_ID"
echo "Output directory: $OUTPUT_DIR"

while true; do
    # Check job status
    STATUS=$(squeue -j $JOB_ID -h -o "%T" 2>/dev/null)
    
    if [ -z "$STATUS" ]; then
        # Job no longer in queue
        echo "Job $JOB_ID completed or failed"
        
        # Get final status from sacct
        FINAL_STATUS=$(sacct -j $JOB_ID --format=State --noheader | head -1)
        echo "Final status: $FINAL_STATUS"
        
        # Collect output files
        if [ -d "$OUTPUT_DIR" ]; then
            echo "Output files:"
            ls -la $OUTPUT_DIR/
        fi
        
        break
    else
        echo "[$(date +%H:%M:%S)] Job status: $STATUS"
        
        # Check if output files are being generated
        if [ -d "$OUTPUT_DIR" ]; then
            FILE_COUNT=$(ls -1 $OUTPUT_DIR 2>/dev/null | wc -l)
            echo "  Output files generated: $FILE_COUNT"
        fi
        
        sleep 30
    fi
done

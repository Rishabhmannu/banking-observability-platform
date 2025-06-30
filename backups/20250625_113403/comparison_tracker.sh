#!/bin/bash
echo "==============================================="
echo "    AIOps Tools Comparison Results Tracker"
echo "==============================================="
echo ""
echo "Please provide your observations for each scenario:"
echo ""

# Memory Leak Scenario
echo "MEMORY LEAK DETECTION SCENARIO"
echo "=============================="
read -p "Time to detect in New Relic (seconds): " nr_memory_time
read -p "Time to detect in Datadog (seconds): " dd_memory_time  
read -p "Time to detect in Grafana (seconds): " gf_memory_time
read -p "Alert quality in New Relic (1-5 scale): " nr_memory_alert
read -p "Alert quality in Datadog (1-5 scale): " dd_memory_alert
read -p "Alert quality in Grafana (1-5 scale): " gf_memory_alert
read -p "Visualization clarity in New Relic (1-5 scale): " nr_memory_viz
read -p "Visualization clarity in Datadog (1-5 scale): " dd_memory_viz
read -p "Visualization clarity in Grafana (1-5 scale): " gf_memory_viz

echo ""

# CPU Load Scenario  
echo "CPU LOAD DETECTION SCENARIO"
echo "==========================="
read -p "Time to detect in New Relic (seconds): " nr_cpu_time
read -p "Time to detect in Datadog (seconds): " dd_cpu_time
read -p "Time to detect in Grafana (seconds): " gf_cpu_time
read -p "Alert quality in New Relic (1-5 scale): " nr_cpu_alert
read -p "Alert quality in Datadog (1-5 scale): " dd_cpu_alert
read -p "Alert quality in Grafana (1-5 scale): " gf_cpu_alert
read -p "Visualization clarity in New Relic (1-5 scale): " nr_cpu_viz
read -p "Visualization clarity in Datadog (1-5 scale): " dd_cpu_viz
read -p "Visualization clarity in Grafana (1-5 scale): " gf_cpu_viz

echo ""

# Network Latency Scenario
echo "NETWORK LATENCY DETECTION SCENARIO"
echo "=================================="
read -p "Time to detect in New Relic (seconds): " nr_latency_time
read -p "Time to detect in Datadog (seconds): " dd_latency_time
read -p "Time to detect in Grafana (seconds): " gf_latency_time
read -p "Alert quality in New Relic (1-5 scale): " nr_latency_alert
read -p "Alert quality in Datadog (1-5 scale): " dd_latency_alert
read -p "Alert quality in Grafana (1-5 scale): " gf_latency_alert
read -p "Visualization clarity in New Relic (1-5 scale): " nr_latency_viz
read -p "Visualization clarity in Datadog (1-5 scale): " dd_latency_viz
read -p "Visualization clarity in Grafana (1-5 scale): " gf_latency_viz

# Calculate averages
nr_avg_time=$(echo "scale=1; (${nr_memory_time} + ${nr_cpu_time} + ${nr_latency_time})/3" | bc)
dd_avg_time=$(echo "scale=1; (${dd_memory_time} + ${dd_cpu_time} + ${dd_latency_time})/3" | bc)
gf_avg_time=$(echo "scale=1; (${gf_memory_time} + ${gf_cpu_time} + ${gf_latency_time})/3" | bc)

nr_avg_alert=$(echo "scale=1; (${nr_memory_alert} + ${nr_cpu_alert} + ${nr_latency_alert})/3" | bc)
dd_avg_alert=$(echo "scale=1; (${dd_memory_alert} + ${dd_cpu_alert} + ${dd_latency_alert})/3" | bc)
gf_avg_alert=$(echo "scale=1; (${gf_memory_alert} + ${gf_cpu_alert} + ${gf_latency_alert})/3" | bc)

nr_avg_viz=$(echo "scale=1; (${nr_memory_viz} + ${nr_cpu_viz} + ${nr_latency_viz})/3" | bc)
dd_avg_viz=$(echo "scale=1; (${dd_memory_viz} + ${dd_cpu_viz} + ${dd_latency_viz})/3" | bc)
gf_avg_viz=$(echo "scale=1; (${gf_memory_viz} + ${gf_cpu_viz} + ${gf_latency_viz})/3" | bc)

# Display results
echo ""
echo "==============================================="
echo "               FINAL RESULTS"
echo "==============================================="
echo ""
echo "DETECTION SUMMARY:"
echo "------------------"
echo "Memory Leak Detection:"
echo "  New Relic: ${nr_memory_time}s | Alert: $nr_memory_alert/5 | Visualization: $nr_memory_viz/5"
echo "  Datadog:   ${dd_memory_time}s | Alert: $dd_memory_alert/5 | Visualization: $dd_memory_viz/5"
echo "  Grafana:   ${gf_memory_time}s | Alert: $gf_memory_alert/5 | Visualization: $gf_memory_viz/5"
echo ""
echo "CPU Load Detection:"
echo "  New Relic: ${nr_cpu_time}s | Alert: $nr_cpu_alert/5 | Visualization: $nr_cpu_viz/5"
echo "  Datadog:   ${dd_cpu_time}s | Alert: $dd_cpu_alert/5 | Visualization: $dd_cpu_viz/5"
echo "  Grafana:   ${gf_cpu_time}s | Alert: $gf_cpu_alert/5 | Visualization: $gf_cpu_viz/5"
echo ""
echo "Network Latency Detection:"
echo "  New Relic: ${nr_latency_time}s | Alert: $nr_latency_alert/5 | Visualization: $nr_latency_viz/5"
echo "  Datadog:   ${dd_latency_time}s | Alert: $dd_latency_alert/5 | Visualization: $dd_latency_viz/5"
echo "  Grafana:   ${gf_latency_time}s | Alert: $gf_latency_alert/5 | Visualization: $gf_latency_viz/5"
echo ""
echo "OVERALL AVERAGES:"
echo "-----------------"
echo "New Relic: Avg Time: ${nr_avg_time}s | Avg Alert: $nr_avg_alert/5 | Avg Visualization: $nr_avg_viz/5"
echo "Datadog:   Avg Time: ${dd_avg_time}s | Avg Alert: $dd_avg_alert/5 | Avg Visualization: $dd_avg_viz/5"
echo "Grafana:   Avg Time: ${gf_avg_time}s | Avg Alert: $gf_avg_alert/5 | Avg Visualization: $gf_avg_viz/5"

# Save results to file
{
echo "AIOps Tools Comparison Results - $(date)"
echo "========================================="
echo ""
echo "Memory Leak Detection:"
echo "  New Relic: ${nr_memory_time}s | Alert: $nr_memory_alert/5 | Viz: $nr_memory_viz/5"
echo "  Datadog:   ${dd_memory_time}s | Alert: $dd_memory_alert/5 | Viz: $dd_memory_viz/5"
echo "  Grafana:   ${gf_memory_time}s | Alert: $gf_memory_alert/5 | Viz: $gf_memory_viz/5"
echo ""
echo "CPU Load Detection:"
echo "  New Relic: ${nr_cpu_time}s | Alert: $nr_cpu_alert/5 | Viz: $nr_cpu_viz/5"
echo "  Datadog:   ${dd_cpu_time}s | Alert: $dd_cpu_alert/5 | Viz: $dd_cpu_viz/5"
echo "  Grafana:   ${gf_cpu_time}s | Alert: $gf_cpu_alert/5 | Viz: $gf_cpu_viz/5"
echo ""
echo "Network Latency Detection:"
echo "  New Relic: ${nr_latency_time}s | Alert: $nr_latency_alert/5 | Viz: $nr_latency_viz/5"
echo "  Datadog:   ${dd_latency_time}s | Alert: $dd_latency_alert/5 | Viz: $dd_latency_viz/5"
echo "  Grafana:   ${gf_latency_time}s | Alert: $gf_latency_alert/5 | Viz: $gf_latency_viz/5"
echo ""
echo "Overall Averages:"
echo "  New Relic: Time: ${nr_avg_time}s | Alert: $nr_avg_alert/5 | Viz: $nr_avg_viz/5"
echo "  Datadog:   Time: ${dd_avg_time}s | Alert: $dd_avg_alert/5 | Viz: $dd_avg_viz/5"
echo "  Grafana:   Time: ${gf_avg_time}s | Alert: $gf_avg_alert/5 | Viz: $gf_avg_viz/5"
} > aiops_comparison_results.txt

echo ""
echo "Results saved to: aiops_comparison_results.txt"
echo "==============================================="

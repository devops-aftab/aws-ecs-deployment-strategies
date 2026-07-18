#!/bin/bash
# Log user-data execution details
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "========================================="
echo "Registering EC2 Instance with ECS..."
echo "========================================="

# The critical configuration line that registers this host to your specific cluster
echo "ECS_CLUSTER=${cluster_name}" >> /etc/ecs/ecs.config

# Verify the configuration was written
cat /etc/ecs/ecs.config

echo "EC2 Host Node successfully initialized."
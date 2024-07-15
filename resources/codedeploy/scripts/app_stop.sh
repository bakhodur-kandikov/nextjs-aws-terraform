#!/bin/bash
docker-compose -f /home/ec2-user/docker-compose.yml down
docker system prune -f
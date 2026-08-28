#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/configs/course.env"

VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=usms-vpc" \
  --query 'Vpcs[0].VpcId' \
  --output text)

PUBLIC_RT_ID=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
            "Name=tag:Name,Values=usms-public-rt" \
  --query 'RouteTables[0].RouteTableId' \
  --output text)

PRIVATE_RT_ID=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
            "Name=tag:Name,Values=usms-private-rt" \
  --query 'RouteTables[0].RouteTableId' \
  --output text)

IGW_ID=$(aws ec2 describe-route-tables \
  --route-table-ids "$PUBLIC_RT_ID" \
  --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].GatewayId | [0]' \
  --output text)

NAT_ID=$(aws ec2 describe-route-tables \
  --route-table-ids "$PRIVATE_RT_ID" \
  --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`].NatGatewayId | [0]' \
  --output text)

SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[].SubnetId' \
  --output text)

for SUBNET_ID in $SUBNET_IDS; do

    CIDR=$(aws ec2 describe-subnets \
      --subnet-ids "$SUBNET_ID" \
      --query 'Subnets[0].CidrBlock' \
      --output text)

    AZ=$(aws ec2 describe-subnets \
      --subnet-ids "$SUBNET_ID" \
      --query 'Subnets[0].AvailabilityZone' \
      --output text)

    SUBNET_NAME=$(aws ec2 describe-subnets \
      --subnet-ids "$SUBNET_ID" \
      --query 'Subnets[0].Tags[?Key==`Name`].Value | [0]' \
      --output text)

    ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
      --filters "Name=vpc-id,Values=$VPC_ID" \
      --query "RouteTables[?Associations[?SubnetId=='$SUBNET_ID']].RouteTableId | [0]" \
      --output text)

    if [[ "$ROUTE_TABLE_ID" == "$PUBLIC_RT_ID" ]]; then

        echo "$SUBNET_NAME   $CIDR  $AZ  PUBLIC    via $IGW_ID"

    elif [[ "$ROUTE_TABLE_ID" == "$PRIVATE_RT_ID" ]]; then

        echo "$SUBNET_NAME   $CIDR  $AZ  PRIVATE   via $NAT_ID"

    else

        echo "$SUBNET_NAME   $CIDR  $AZ  ISOLATED  no default route"

    fi

done
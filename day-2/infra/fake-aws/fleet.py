"""Manage TradeNova's simulated market-data fleet in the fake AWS EC2 API (Moto).

Each simulated EC2 instance stands for one market-data server. The real work is done by the
containers market-data-1 ... market-data-5 (each runs node exporter on port 9100); this script
only registers or terminates the matching "instances", with the tags Prometheus discovers.

    python fleet.py status        list the running instances and their tags
    python fleet.py scale 3       make exactly market-data-1..3 running (adds or terminates)

Usage from the lab folder:
    docker compose run --rm fleet status
    docker compose run --rm fleet scale 5
"""
import os
import sys

import boto3

ENDPOINT = os.getenv("FAKE_AWS_URL", "http://fake-aws:5000")
REGION = os.getenv("AWS_DEFAULT_REGION", "us-east-1")
MAX_SERVERS = 5  # market-data-1 ... market-data-5 exist in docker-compose.yml

ec2 = boto3.client(
    "ec2",
    endpoint_url=ENDPOINT,
    region_name=REGION,
    aws_access_key_id="training",
    aws_secret_access_key="training",
)


def running_instances() -> dict:
    """Name tag -> instance, for every running market-data instance."""
    pages = ec2.get_paginator("describe_instances").paginate(Filters=[
        {"Name": "tag:team", "Values": ["market-data"]},
        {"Name": "instance-state-name", "Values": ["pending", "running"]},
    ])
    found = {}
    for page in pages:
        for reservation in page["Reservations"]:
            for instance in reservation["Instances"]:
                tags = {t["Key"]: t["Value"] for t in instance.get("Tags", [])}
                found[tags.get("Name", instance["InstanceId"])] = {**instance, "TagMap": tags}
    return found


def launch(n: int) -> None:
    name = f"market-data-{n}"
    tags = [
        {"Key": "Name", "Value": name},
        {"Key": "team", "Value": "market-data"},
        {"Key": "environment", "Value": "training"},
        {"Key": "monitoring", "Value": "enabled"},
        # Where Prometheus should scrape. In real AWS you would use the private IP address
        # (__meta_ec2_private_ip); in the lab the "instance" is really a container on this host.
        {"Key": "scrape_target", "Value": f"{name}:9100"},
    ]
    ec2.run_instances(
        ImageId="ami-12c6146b",
        InstanceType="t3.medium",
        MinCount=1,
        MaxCount=1,
        TagSpecifications=[{"ResourceType": "instance", "Tags": tags}],
    )
    print(f"  launched {name}")


def scale(target: int) -> None:
    if not 0 <= target <= MAX_SERVERS:
        sys.exit(f"Choose a fleet size between 0 and {MAX_SERVERS}")
    current = running_instances()
    for n in range(1, MAX_SERVERS + 1):
        name = f"market-data-{n}"
        if n <= target and name not in current:
            launch(n)
        elif n > target and name in current:
            ec2.terminate_instances(InstanceIds=[current[name]["InstanceId"]])
            print(f"  terminated {name}")
    status()


def status() -> None:
    current = running_instances()
    print(f"Market-data fleet in fake AWS ({ENDPOINT}, {REGION}): {len(current)} running")
    for name in sorted(current):
        instance = current[name]
        tags = instance["TagMap"]
        print(f"  {name:<15} {instance['InstanceId']:<21} {instance['PrivateIpAddress']:<15} "
              f"team={tags.get('team')} monitoring={tags.get('monitoring')} scrape_target={tags.get('scrape_target')}")


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "status":
        status()
    elif len(sys.argv) == 3 and sys.argv[1] == "scale":
        scale(int(sys.argv[2]))
    else:
        sys.exit(__doc__)

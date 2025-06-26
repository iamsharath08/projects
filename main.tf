provider "aws" {
    region = "us-east-1"
}

resource "aws_vpc" "default_vpc" {
    cidr_block = "10.0.0.0/24"
    instance_tenancy = "default"

    tags = {
      Name = "default_vpc"
    }
}

resource "aws_subnet" "default_subnet" {
  vpc_id = aws_vpc.default_vpc.id
  cidr_block = "10.0.0.0/24"
  tags = {
    Name = "default_subnet"
  }
}

resource "tls_private_key" "windows_compute_key" {
    algorithm = "RSA"
    rsa_bits = 2048
}

resource "aws_key_pair" "windows_compute_key" {
    key_name = "windows_compute_key"
    public_key = tls_private_key.windows_compute_key.public_key_openssh

}

resource "local_file" "windows_compute_key_pem" {
    content = tls_private_key.windows_compute_key.private_key_pem
    filename = "C:/projects/ec2/Surendra/windows_compute_key.pem"
    file_permission = "0600"
}

resource "aws_security_group" "windows_compute_security_group" {
    vpc_id = aws_vpc.default_vpc.id
    name = "windows_compute_security_group"
    description = "Allow RDP access only"

    ingress {
        description = "Allow RDp only"
        from_port = 3389
        to_port = 3389
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        description = "outgoing ttraffic"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "windows_compute_security_group"
    }
}

resource "aws_instance" "windows_compute" {
    ami = "ami-05ffe3c48a9991133"
    instance_type = "t3a.medium"
    key_name = aws_key_pair.windows_compute_key.key_name
    subnet_id = aws_subnet.default_subnet.id
    vpc_security_group_ids = [aws_security_group.windows_compute_security_group.id]

    root_block_device {
        volume_size = 30
        volume_type = "gp2"
        delete_on_termination = false
    }

    tags = {
        name = "windows_compute"
    }
}

resource "aws_sns_topic" "windows_compute_sns_topic" {
    name = "windows_compute_sns_topic"
}

resource "aws_sns_topic_subscription" "windows_compute_sns_topic_subscription" {
    topic_arn = aws_sns_topic.windows_compute_sns_topic.arn
    protocol = "email"
    endpoint = "systemadmin@abc.com"
}

resource "aws_cloudwatch_metric_alarm" "windows_compute_cpu_usage_alarm" {
    alarm_name = "windows_compute_cpu_usage_alarm"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods = 1
    period = 120
    statistic = "Average"
    threshold = 80
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"

    dimensions = { Installed = aws_instance.windows_compute.id}

    alarm_description = "Alert: windows_compute EC2 instance CPU utilization exceeded 80"
    alarm_actions = [aws_sns_topic.windows_compute_sns_topic.arn]
    ok_actions = [aws_sns_topic.windows_compute_sns_topic.arn]
    treat_missing_data = "missing"

}
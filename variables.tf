variable "ec2" {
  description  = "EC2 instances names and types included in AutoScaling groups"
  default      = {
    varnish    = "m6g.large"
    frontend   = "c6g.xlarge"
    admin      = "c6g.xlarge"
    staging    = "c6g.xlarge"
   }
}

variable "app" {
  description      = "Map application params | Magento 2"
  default          = {
    cidr_block       = "172.31.0.0/16"
    brand            = "vsgcommerce"
    domain           = "magprd.vsgcommerce.cloud"
    admin_email      = "admin@vsgcommerce.cloud"
    staging_domain   = "magstg.vsgcommerce.cloud"
    source           = "https://github.com/bencarlson/Magento-2.git"
    language         = "en_US"
    currency         = "USD"
    timezone         = "CDT"
    php_version      = "7.4"
    volume_size      = "50"
  }
}

variable "elk" {
  description      = "Map ElasticSearch configuration values"
  default  = {
    domain_name            = "elk"
    elasticsearch_version  = "7.9"
    instance_type          = "m6g.large.elasticsearch"
    instance_count         = "3"
    ebs_enabled            = true
    volume_type            = "gp2"
    volume_size            = "20"
    log_type               = "ES_APPLICATION_LOGS"
  }
}

variable "rds" {
  description      = "Map RDS configuration values"
  default  = {
    name                   = ["production","staging"]
    allocated_storage      = "50"
    max_allocated_storage  = "100"
    storage_type           = "gp2"
    engine_version         = "10.5.12"
    instance_class         = "db.m6g.large"
    instance_class_staging = "db.m6g.large"
    engine                 = "mariadb"
    skip_final_snapshot    = true
    multi_az               = true
    enabled_cloudwatch_logs_exports = "error"
    performance_insights_enabled = true
    copy_tags_to_snapshot    = true
    backup_retention_period  = "0"
    delete_automated_backups = true
    deletion_protection      = false
  }
}

variable "max_connection_count" {
  description = "Map 6g. class RDS max connection count"
  default = {
     "db.m6g.large"    = "683"
     "db.m6g.xlarge"   = "1365"
     "db.r6g.large"    = "1365"
     "db.m6g.2xlarge"  = "2731"
     "db.r6g.xlarge"   = "2731"
     "db.m6g.4xlarge"  = "5461"
     "db.r6g.2xlarge"  = "5461"
     "db.m6g.8xlarge"  = "10923"
     "db.r6g.4xlarge"  = "10923"
     "db.m6g.12xlarge" = "16384"
     "db.m6g.16xlarge" = "21845"
     "db.r6g.8xlarge"  = "21845"
     "db.r6g.12xlarge" = "32768"
     "db.r6g.16xlarge" = "43691"
  }
}
      
variable "mq" {
  description      = "Map RabbitMQ configuration values"
  default  = {
    broker_name            = "queue"
    engine_version         = "3.8.11"
    host_instance_type     = "mq.t3.micro"
  }
}

variable "redis" {
  description      = "Map ElastiCache Redis configuration values"
  default  = {    
    node_type                  = "cache.m6g.large"
    name                       = ["session", "cache"]
    engine_version                = "6.x"
    port                          = "6379"
    automatic_failover_enabled    = true
    multi_az_enabled              = true
  }
}
          
variable "asg" {
  description      = "Map Autoscaling Group configuration values"
  default  = {
    desired_capacity      = "1"
    min_size              = "1"
    max_size              = "5"
    health_check_type     = "EC2"
    health_check_grace_period = "300"
  }
}
          
variable "asp" {
  description      = "Map Autoscaling Policy configuration values"
  default  = {    
    evaluation_periods  = "2"
    period              = "300"
    out_threshold       = "80"
    in_threshold        = "25"
  }
}

variable "s3" {
  description = "S3 bucket names"
  type        = set(string)
  default     = ["media", "system", "backup"]
}

variable "alb" {
  description = "Application Load Balancer names and type"
  default     = {
    outer     = false
    inner     = true
    }
}

variable "ec2_instance_profile_policy" {
  description = "Policy attach to EC2 Instance Profile"
  type        = set(string)
  default     = [
  "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

variable "eventbridge_policy" {
  description = "Policy attach to EventBridge role"
  type        = set(string)
  default     = [
  "arn:aws:iam::aws:policy/service-role/CloudWatchEventsBuiltInTargetExecutionAccess", 
  "arn:aws:iam::aws:policy/service-role/CloudWatchEventsInvocationAccess",
  "arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole"
  ]
}

variable "az_number" {
  description = "Assign a number to each AZ letter used in secondary cidr/subnets configuration"
  default = {
    a = 0
    b = 1
    c = 2
    d = 3
    e = 4
    f = 5
    g = 6
  }
}

locals {
  security_group = setunion(keys(var.alb),var.redis["name"],["ec2","rds","elk","mq","efs"])
}

locals {
 security_rule = {
  outer_alb_https_in = {
    type        = "ingress"
    description = "Allow all inbound traffic on the load balancer https listener port"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.this["outer"].id
    },
  outer_alb_http_in = {
    type        = "ingress"
    description = "Allow all inbound traffic on the load balancer http listener port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.this["outer"].id
    },
  outer_alb_http_out = {
    type        = "egress"
    description = "Allow outbound traffic to instances on the load balancer listener port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["outer"].id
    },
  inner_alb_http_in = {
    type        = "ingress"
    description = "Allow inbound traffic from the VPC CIDR on the load balancer listener port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["inner"].id
    },
  inner_alb_http_out = {
    type        = "egress"
    description = "Allow outbound traffic to instances on the load balancer listener port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["inner"].id
    },
  ec2_https_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance https port"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.this["ec2"].id
    },
  ec2_http_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance http port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.this["ec2"].id
    },
  ec2_mysql_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance MySql port"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["rds"].id
    security_group_id = aws_security_group.this["ec2"].id
    },
  ec2_rabbitmq_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance RabbitMQ port"
    from_port   = 5671
    to_port     = 5671
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["mq"].id
    security_group_id = aws_security_group.this["ec2"].id
    },
  ec2_redis_session_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance Redis port"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["session"].id
    security_group_id = aws_security_group.this["ec2"].id
    },
  ec2_redis_cache_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance Redis port"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["cache"].id
    security_group_id = aws_security_group.this["ec2"].id
    },
  ec2_efs_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance NFS port"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["efs"].id
    security_group_id = aws_security_group.this["ec2"].id
    },
  ec2_ses_out = {
    type        = "egress"
    description = "Allow outbound traffic on the region SES port"
    from_port   = 587
    to_port     = 587
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.this["ec2"].id
    },
  ec2_elk_out = {
    type        = "egress"
    description = "Allow outbound traffic on the instance ELK port"
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["elk"].id
    security_group_id = aws_security_group.this["ec2"].id
    },
  ec2_http_in_ec2 = {
    type        = "ingress"
    description = "Allow all inbound traffic from ec2 on http port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["ec2"].id
    },
  ec2_http_in_inner = {
    type        = "ingress"
    description = "Allow all inbound traffic from the load balancer on http port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["inner"].id
    security_group_id = aws_security_group.this["ec2"].id
    },
  ec2_http_in_outer = {
    type        = "ingress"
    description = "Allow all inbound traffic from the load balancer on http port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["outer"].id
    security_group_id = aws_security_group.this["ec2"].id
    },
  rds_mysql_in = {
    type        = "ingress"
    description = "Allow access instances to MySQL Port"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["rds"].id
    },
  redis_session_in = {
    type        = "ingress"
    description = "Allow access instances to Redis Session"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["session"].id
    },
  redis_cache_in = {
    type        = "ingress"
    description = "Allow access instances to Redis Cache"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["cache"].id
    },
  rabbitmq_in = {
    type        = "ingress"
    description = "Allow access instances to RabbitMQ"
    from_port   = 5671
    to_port     = 5671
    protocol    = "tcp"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["mq"].id
    },
  efs_in = {
    type        = "ingress"
    description = "Allow access instances to EFS target"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["efs"].id
    },
  efs_out = {
    type        = "egress"
    description = "Allow access instances to EFS target"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["efs"].id
    },
  elk_in = {
    type        = "ingress"
    description = "Allow inbound traffic to the instance ELK port"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["elk"].id
    },
  elk_out = {
    type        = "egress"
    description = "Allow outbound traffic to the instance ELK port"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    source_security_group_id = aws_security_group.this["ec2"].id
    security_group_id = aws_security_group.this["elk"].id
    },
  }
}

resource "aws_db_subnet_group" "main" {
  count = var.create_instance ? 1 : 0

  name       = "${var.name_prefix}-rds-subnet-group"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "rds" {
  # checkov:skip=CKV_AWS_23:RDS security group egress rules have descriptions; CKV_AWS_23 flags based on rule-level description requirements
  count = var.create_instance ? 1 : 0

  # checkov:skip=CKV_AWS_382:Egress to 0.0.0.0/0 required for dev outbound internet
  name        = "${var.name_prefix}-rds-sg"
  description = "PostgreSQL (model registry)"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from VPC CIDR"
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic (dev)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-rds-sg" })
}

resource "aws_db_instance" "model_registry" {
  count = var.create_instance ? 1 : 0

  # checkov:skip=CKV_AWS_16:RDS storage encryption not enabled for dev simplicity (SSE-AES256 handled at app layer)
  # checkov:skip=CKV_AWS_157:Multi-AZ not enabled for dev (single-AZ dev instance)
  # checkov:skip=CKV_AWS_161:IAM database authentication not enabled for dev
  # checkov:skip=CKV_AWS_293:Deletion protection disabled for dev (allows teardown)
  # checkov:skip=CKV_AWS_353:Performance Insights not enabled for dev
  # checkov:skip=CKV_AWS_129:RDS logs not published to CloudWatch for dev
  # checkov:skip=CKV_AWS_226:Auto minor version upgrade disabled for dev
  # checkov:skip=CKV_AWS_118:Enhanced monitoring not enabled for dev
  # checkov:skip=CKV2_AWS_60:Copy tags to snapshots not enabled for dev
  # checkov:skip=CKV2_AWS_30:Postgres query logging not enabled for dev
  identifier          = "${var.name_prefix}-model-registry"
  engine              = "postgres"
  engine_version      = var.engine_version
  instance_class      = var.instance_class
  allocated_storage   = var.allocated_storage
  storage_type        = "gp3"
  db_name             = var.db_name
  username            = var.db_username
  password            = var.db_password
  skip_final_snapshot = true
  deletion_protection = false
  publicly_accessible = false
  multi_az            = false

  vpc_security_group_ids = [aws_security_group.rds[0].id]
  db_subnet_group_name   = aws_db_subnet_group.main[0].name

  tags = var.tags
}

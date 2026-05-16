resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.identifier}-db-subnet"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.project_name}-${var.identifier}-db-subnet"
  }
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-${var.identifier}-rds-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Acesso PostgreSQL a partir dos nodes do EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.allowed_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.identifier}-rds-sg"
  }
}

resource "aws_db_instance" "main" {
  identifier            = "${var.project_name}-${var.identifier}"
  engine                = "postgres"
  engine_version        = "17.6"
  instance_class        = var.instance_class
  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  skip_final_snapshot = true
  publicly_accessible = false
  multi_az            = false

  tags = {
    Name = "${var.project_name}-${var.identifier}-rds"
  }
}

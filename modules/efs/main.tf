# EFS File System
resource "aws_efs_file_system" "main" {
  encrypted = true

  tags = {
    Name = "${var.project_name}-${var.environment}-efs"
  }
}

# EFS Mount Targets
resource "aws_efs_mount_target" "main" {
  count           = length(var.private_subnet_ids)
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [var.efs_security_group]
}

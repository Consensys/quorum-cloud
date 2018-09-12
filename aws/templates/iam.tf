resource "aws_iam_role" "ecs_instance" {
  name = "quorum-ecs-instance-${var.deployment_id}"
  path = "/ecs/"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["ec2.amazonaws.com"]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "quorum-ecs-instance-${var.deployment_id}"
  role = "${aws_iam_role.ecs_instance.name}"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_container" {
  role       = "${aws_iam_role.ecs_instance.id}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_cloudwatch" {
  role       = "${aws_iam_role.ecs_instance.id}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role" "ecs_task" {
  name = "quorum-ecs-task-${var.deployment_id}"
  path = "/ecs/"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["ecs-tasks.amazonaws.com"]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = "${aws_iam_role.ecs_task.id}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_cloudwatch" {
  role       = "${aws_iam_role.ecs_task.id}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

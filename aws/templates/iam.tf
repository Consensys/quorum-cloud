resource "aws_iam_role" "ecs_task" {
  name = "quorum-ecs-task-${var.network_name}"
  path = "/ecs/"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "ecs.amazonaws.com",
          "ecs-tasks.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "ecs_task" {
  statement {
    sid = "AllowS3Access"

    actions = [
      "s3:*",
    ]

    resources = [
      "arn:aws:s3:::${local.quorum_bucket}",
      "arn:aws:s3:::${local.quorum_bucket}/*",
    ]
  }

  statement {
    sid = "AllowKMSAccess"

    actions = [
      "kms:*",
    ]

    resources = [
      "${aws_kms_key.bucket.arn}",
    ]
  }

  statement {
    sid = "AllowECS"

    actions = [
      "ecs:DescribeTasks"
    ]

    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "ecs_task" {
  name        = "quorum-ecs-task-policy-${var.network_name}"
  path        = "/"
  description = "This policy allows task to access S3 bucket"
  policy      = "${data.aws_iam_policy_document.ecs_task.json}"
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3" {
  role       = "${aws_iam_role.ecs_task.id}"
  policy_arn = "${aws_iam_policy.ecs_task.arn}"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = "${aws_iam_role.ecs_task.id}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_cloudwatch" {
  role       = "${aws_iam_role.ecs_task.id}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role" "bastion" {
  name = "${local.default_bastion_resource_name}"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "ec2.amazonaws.com"
        ]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "bastion" {
  statement {
    sid = "AllowS3"

    actions = [
      "s3:*",
    ]

    resources = [
      "arn:aws:s3:::${local.quorum_bucket}",
      "arn:aws:s3:::${local.quorum_bucket}/*",
    ]
  }

  statement {
    sid = "AllowKMSAccess"

    actions = [
      "kms:*",
    ]

    resources = [
      "${aws_kms_key.bucket.arn}",
    ]
  }

  statement {
    sid = "AllowECS"

    actions = [
      "ecs:*",
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${local.default_bastion_resource_name}"
  role = "${aws_iam_role.bastion.name}"
}

resource "aws_iam_policy" "bastion" {
  name        = "quorum-bastion-policy-${var.network_name}"
  path        = "/"
  description = "This policy allows task to access S3 bucket and ECS"
  policy      = "${data.aws_iam_policy_document.bastion.json}"
}

resource "aws_iam_role_policy_attachment" "bastion" {
  role       = "${aws_iam_role.bastion.id}"
  policy_arn = "${aws_iam_policy.bastion.arn}"
}

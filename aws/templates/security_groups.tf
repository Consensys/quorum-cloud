resource "aws_security_group" "quorum" {
  name        = "quorum-sg-${var.deployment_id}"
  description = "Security group used in Quorum network ${var.deployment_id}"

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all"
  }

  tags = "${merge(local.common_tags, map("Name", format("quorum-sg-%s", var.deployment_id)))}"
}

resource "aws_security_group_rule" "geth_p2p" {
  from_port         = 30400
  protocol          = "tcp"
  security_group_id = "${aws_security_group.quorum.id}"
  to_port           = 30900
  type              = "ingress"
  self              = true
  description       = "Geth P2P traffic"
}

resource "aws_security_group_rule" "geth_admin_rpc" {
  from_port         = 40400
  protocol          = "tcp"
  security_group_id = "${aws_security_group.quorum.id}"
  to_port           = 40900
  type              = "ingress"
  self              = "true"
  description       = "Geth Admin RPC traffic"
}

resource "aws_security_group_rule" "constellation" {
  count             = "${var.tx_privacy_engine == "constellation" ? 1 : 0}"
  from_port         = "${local.constellation_port}"
  protocol          = "tcp"
  security_group_id = "${aws_security_group.quorum.id}"
  to_port           = "${local.constellation_port}"
  type              = "ingress"
  self              = "true"
  description       = "Constellation Public API traffic"
}

resource "aws_security_group_rule" "raft" {
  count             = "${var.concensus_mechanism == "raft" ? 1 : 0}"
  from_port         = 9000
  protocol          = "tcp"
  security_group_id = "${aws_security_group.quorum.id}"
  to_port           = 9500
  type              = "ingress"
  self              = "true"
  description       = "Raft HTTP traffic"
}

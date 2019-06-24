data "aws_subnet" "vpc" {
  id = "${var.bastion_public_subnet_id}"
}

resource "aws_security_group" "quorum" {
  name        = "quorum-sg-${var.network_name}"
  description = "Security group used in Quorum network ${var.network_name}"
  vpc_id      = "${data.aws_subnet.vpc.vpc_id}"

  egress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0

    cidr_blocks = [
      "0.0.0.0/0",
    ]

    description = "Allow all"
  }

  tags = "${merge(local.common_tags, map("Name", format("quorum-sg-%s", var.network_name)))}"
}

resource "aws_security_group_rule" "ethstats" {
  from_port         = "${local.ethstats_port}"
  protocol          = "tcp"
  security_group_id = "${aws_security_group.quorum.id}"
  to_port           = "${local.ethstats_port}"
  type              = "ingress"
  self              = true
  description       = "ethstats traffic"
}

resource "aws_security_group_rule" "geth_p2p" {
  from_port         = "${local.quorum_p2p_port}"
  protocol          = "tcp"
  security_group_id = "${aws_security_group.quorum.id}"
  to_port           = "${local.quorum_p2p_port}"
  type              = "ingress"
  self              = true
  description       = "Geth P2P traffic"
}

resource "aws_security_group_rule" "geth_admin_rpc" {
  from_port         = "${local.quorum_rpc_port}"
  protocol          = "tcp"
  security_group_id = "${aws_security_group.quorum.id}"
  to_port           = "${local.quorum_rpc_port}"
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
  description       = "Constellation API traffic"
}

resource "aws_security_group_rule" "tessera" {
  count             = "${var.tx_privacy_engine == "tessera" ? 1 : 0}"
  from_port         = "${local.tessera_port}"
  protocol          = "tcp"
  security_group_id = "${aws_security_group.quorum.id}"
  to_port           = "${local.tessera_port}"
  type              = "ingress"
  self              = "true"
  description       = "Tessera API traffic"
}

resource "aws_security_group_rule" "tessera_thirdparty" {
  count             = "${var.tx_privacy_engine == "tessera" ? 1 : 0}"
  from_port         = "${local.tessera_thirdparty_port}"
  protocol          = "tcp"
  security_group_id = "${aws_security_group.quorum.id}"
  to_port           = "${local.tessera_thirdparty_port}"
  type              = "ingress"
  self              = "true"
  description       = "Tessera Thirdparty API traffic"
}

resource "aws_security_group_rule" "raft" {
  count             = "${var.consensus_mechanism == "raft" ? 1 : 0}"
  from_port         = "${local.raft_port}"
  protocol          = "tcp"
  security_group_id = "${aws_security_group.quorum.id}"
  to_port           = "${local.raft_port}"
  type              = "ingress"
  self              = "true"
  description       = "Raft HTTP traffic"
}

resource "aws_security_group" "bastion-ssh" {
  name        = "quorum-bastion-ssh-${var.network_name}"
  description = "Security group used by Bastion node to access Quorum network ${var.network_name}"
  vpc_id      = "${data.aws_subnet.vpc.vpc_id}"

  ingress {
    from_port = 22
    protocol  = "tcp"
    to_port   = 22

    cidr_blocks = [
      "73.150.1.0/24",

      # Trung's home
      "199.253.0.0/16",

      # Office wifi
      "${var.access_bastion_cidr_blocks}",
    ]

    description = "Allow SSH"
  }

  egress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0

    cidr_blocks = [
      "0.0.0.0/0",
    ]

    description = "Allow all"
  }

  tags = "${merge(local.common_tags, map("Name", format("quorum-bastion-ssh-%s", var.network_name)))}"
}

resource "aws_security_group" "bastion-ethstats" {
  name        = "quorum-bastion-ethstats-${var.network_name}"
  description = "Security group used by external to access ethstats for Quorum network ${var.network_name}"
  vpc_id      = "${data.aws_subnet.vpc.vpc_id}"

  ingress {
    from_port = 3000
    protocol  = "tcp"
    to_port   = 3000

    cidr_blocks = [
      "73.150.1.0/24",

      # Trung's home
      "199.253.0.0/16",

      # Office wifi
      "${var.access_bastion_cidr_blocks}",
    ]

    description = "Allow ethstats"
  }

  egress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0

    cidr_blocks = [
      "0.0.0.0/0",
    ]

    description = "Allow all"
  }

  tags = "${merge(local.common_tags, map("Name", format("quorum-bastion-ethstats-%s", var.network_name)))}"
}

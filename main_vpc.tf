/*Add a new set of data.aws_iam_policy_document, aws_elasticsearch_domain, aws_elasticsearch_domain_policy. Because currently terraform/aws_elasticsearch_domain 
does not handle properly null/empty "vpc_options" */

data "aws_iam_policy_document" "es_vpc_management_access" {
  count = "${local.inside_vpc ? 1 : 0}"

  statement {
    actions = [
      "es:*",
    ]

    resources = [
      "${aws_elasticsearch_domain.es_vpc.arn}",
      "${aws_elasticsearch_domain.es_vpc.arn}/*",
    ]

    principals {
      type = "AWS"

      identifiers = ["${distinct(compact(var.management_iam_roles))}"]
    }
  }
}

resource "aws_iam_service_linked_role" "es" {
  count            = "${var.create_iam_service_linked_role ? 1 : 0}"
  aws_service_name = "es.amazonaws.com"
}

resource "aws_elasticsearch_domain" "es_vpc" {
  count = "${local.inside_vpc ? 1 : 0}"

  depends_on = ["aws_iam_service_linked_role.es"]

  domain_name           = "${local.domain_name}"
  elasticsearch_version = "${var.es_version}"

  encrypt_at_rest = {
    enabled    = "${var.encrypt_at_rest}"
    kms_key_id = "${var.kms_key_id}"
  }

  cluster_config {
    instance_type            = "${var.instance_type}"
    instance_count           = "${var.instance_count}"
    dedicated_master_enabled = "${var.instance_count >= var.dedicated_master_threshold ? true : false}"
    dedicated_master_count   = "${var.instance_count >= var.dedicated_master_threshold ? 3 : 0}"
    dedicated_master_type    = "${var.instance_count >= var.dedicated_master_threshold ? (var.dedicated_master_type != "false" ? var.dedicated_master_type : var.instance_type) : ""}"
    zone_awareness_enabled   = "${var.es_zone_awareness}"
  }

  advanced_options = "${var.advanced_options}"

  log_publishing_options = [{
    log_type                 = "INDEX_SLOW_LOGS"
    cloudwatch_log_group_arn = "${var.index_slow_log_cloudwatch_log_group}"
    enabled                  = "${var.index_slow_log_cloudwatch_log_group != "" ? true : false}"
  },
    {
      log_type                 = "SEARCH_SLOW_LOGS"
      cloudwatch_log_group_arn = "${var.search_slow_log_cloudwatch_log_group}"
      enabled                  = "${var.search_slow_log_cloudwatch_log_group != "" ? true : false}"
    },
    {
      log_type                 = "ES_APPLICATION_LOGS"
      cloudwatch_log_group_arn = "${var.es_app_log_cloudwatch_log_group}"
      enabled                  = "${var.es_app_log_cloudwatch_log_group != "" ? true : false}"
    },
  ]

  node_to_node_encryption {
    enabled = "${var.node_to_node_encryption_enabled}"
  }

  vpc_options = ["${var.vpc_options}"]

  ebs_options {
    ebs_enabled = "${var.ebs_volume_size > 0 ? true : false}"
    volume_size = "${var.ebs_volume_size}"
    volume_type = "${var.ebs_volume_type}"
  }

  snapshot_options {
    automated_snapshot_start_hour = "${var.snapshot_start_hour}"
  }

  tags = "${merge(map("Domain", local.domain_name), var.tags)}"
}

resource "aws_elasticsearch_domain_policy" "es_vpc_management_access" {
  count = "${local.inside_vpc ? 1 : 0}"

  domain_name     = "${local.domain_name}"
  access_policies = "${data.aws_iam_policy_document.es_vpc_management_access.json}"
}

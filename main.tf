# Elasticsearch domain
data "aws_iam_policy_document" "es_management_access" {
  count = "${length(var.vpc_options["subnet_ids"]) > 0 ? 0 : 1}"

  statement {
    actions = [
      "es:*",
    ]

    resources = [
      "${aws_elasticsearch_domain.es.arn}",
      "${aws_elasticsearch_domain.es.arn}/*",
    ]

    principals {
      type = "AWS"

      identifiers = ["${distinct(compact(var.management_iam_roles))}"]
    }

    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"

      values = ["${distinct(compact(var.management_public_ip_addresses))}"]
    }
  }
}

resource "aws_elasticsearch_domain" "es" {
  count                 = "${length(var.vpc_options["subnet_ids"]) > 0 ? 0 : 1}"
  domain_name           = "${local.domain_name}"
  elasticsearch_version = "${var.es_version}"

  cluster_config {
    instance_type            = "${var.instance_type}"
    instance_count           = "${var.instance_count}"
    dedicated_master_enabled = "${var.instance_count >= var.dedicated_master_threshold ? true : false}"
    dedicated_master_count   = "${var.instance_count >= var.dedicated_master_threshold ? 3 : 0}"
    dedicated_master_type    = "${var.instance_count >= var.dedicated_master_threshold ? (var.dedicated_master_type != "false" ? var.dedicated_master_type : var.instance_type) : ""}"
    zone_awareness_enabled   = "${var.es_zone_awareness}"
  }

  log_publishing_options = [{
    log_type                 = "INDEX_SLOW_LOGS"
    cloudwatch_log_group_arn = "${var.index_slow_log_cloudwatch_log_group}"
    enabled                  = "${var.index_slow_log_enabled}"
  },
    {
      log_type                 = "SEARCH_SLOW_LOGS"
      cloudwatch_log_group_arn = "${var.search_slow_log_cloudwatch_log_group}"
      enabled                  = "${var.search_slow_log_enabled}"
    },
    {
      log_type                 = "ES_APPLICATION_LOGS"
      cloudwatch_log_group_arn = "${var.es_app_log_cloudwatch_log_group}"
      enabled                  = "${var.es_app_log_enable}"
    },
  ]

  ebs_options {
    ebs_enabled = "${var.ebs_volume_size > 0 ? true : false}"
    volume_size = "${var.ebs_volume_size}"
    volume_type = "${var.ebs_volume_type}"
  }

  snapshot_options {
    automated_snapshot_start_hour = "${var.snapshot_start_hour}"
  }

  tags = "${merge(var.tags, map(
    "Domain", "${local.domain_name}"
  ))}"
}

resource "aws_elasticsearch_domain_policy" "es_management_access" {
  count           = "${length(var.vpc_options["subnet_ids"]) > 0 ? 0 : 1}"
  domain_name     = "${local.domain_name}"
  access_policies = "${data.aws_iam_policy_document.es_management_access.json}"
}

# vim: set et fenc= ff=unix ft=terraform sts=2 sw=2 ts=2 : 


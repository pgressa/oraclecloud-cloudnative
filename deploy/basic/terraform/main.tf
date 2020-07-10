# Copyright (c) 2019, 2020 Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
# 

terraform {
  required_version = ">= 0.12.16"
}
data "template_file" "mushop" {
  template = "${file("./scripts/node.sh")}"
}

resource "oci_core_instance" "app_instance" {
  count               = var.num_nodes
  availability_domain = local.availability_domain[0]
  compartment_id      = var.compartment_ocid
  display_name        = "mushop-${random_id.mushop_id.dec}-${count.index}"
  shape               = var.instance_shape
  freeform_tags       = local.common_tags

  create_vnic_details {
    subnet_id        = oci_core_subnet.mushopLBSubnet.id
    display_name     = "primaryvnic"
    assign_public_ip = true
    hostname_label   = "mushop-${random_id.mushop_id.dec}-${count.index}"
  }

  source_details {
    source_type = "image"
    source_id   = lookup(data.oci_core_images.compute_images.images[0], "id")
  }

  metadata = {
    ssh_authorized_keys = var.generate_public_ssh_key ? tls_private_key.compute_ssh_key.public_key_openssh : var.public_ssh_key
    user_data           = base64encode(data.template_file.mushop.rendered)
    db_name             = oci_database_autonomous_database.mushop_autonomous_database.db_name
    atp_pw              = random_string.autonomous_database_wallet_password.result
    catalogue_sql_par   = "https://objectstorage.${var.region}.oraclecloud.com${oci_objectstorage_preauthrequest.catalogue_sql_script_preauth.access_uri}"
    apache_conf_par     = "https://objectstorage.${var.region}.oraclecloud.com${oci_objectstorage_preauthrequest.apache_conf_preauth.access_uri}"
    entrypoint_par      = "https://objectstorage.${var.region}.oraclecloud.com${oci_objectstorage_preauthrequest.entrypoint_preauth.access_uri}"
    mushop_app_par      = "https://objectstorage.${var.region}.oraclecloud.com${oci_objectstorage_preauthrequest.mushop_lite_preauth.access_uri}"
    wallet_par          = "https://objectstorage.${var.region}.oraclecloud.com${oci_objectstorage_preauthrequest.mushop_wallet_preauth.access_uri}"
    assets_par          = "https://objectstorage.${var.region}.oraclecloud.com${oci_objectstorage_preauthrequest.mushop_media_preauth.access_uri}"
    assets_url          = "https://objectstorage.${var.region}.oraclecloud.com/n/${oci_objectstorage_bucket.mushop_media.namespace}/b/${oci_objectstorage_bucket.mushop_media.name}/o/"
  }

}

locals {
  availability_domain = [for limit in data.oci_limits_limit_values.test_limit_values : limit.limit_values[0].availability_domain if limit.limit_values[0].value > 0]

  common_tags = {
    Reference = "Created by OCI QuickStart for Free Tier"
  }

}

# Generate ssh keys to access Compute Nodes, if generate_public_ssh_key=true, applies to the Compute
resource "tls_private_key" "compute_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
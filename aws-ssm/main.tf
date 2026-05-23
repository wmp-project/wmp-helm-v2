terraform {
  backend "s3" {
    bucket = "terraform-state-mkreddy-devmonkey"
    key    = "awsssm/terraform.tfstate"
    region = "us-east-1"
  }
}


resource "aws_ssm_parameter" "values" {
  count = length(var.inputs)
  name  = lookup(var.inputs[count.index], "name", "")
  type  = lookup(var.inputs[count.index], "type", "")
  value = lookup(var.inputs[count.index], "value", "")
}

variable "inputs" {
  default = [
    {
      name  = "/analytics-service/DATABASE_URL"
      type  = "SecureString"
      value = "postgresql+asyncpg://analytics_svc_user:localdev123@wmp-dev.cbvsckxcecc86yw5beoyxek4.us-east-1.rds.amazonaws.com:5432/wmp"
    },
    {
      name  = "/analytics-service/DB_SCHEMA"
      type  = "String"
      value = "analytics_schema"
    },
    {
      name  = "/analytics-service/LOG_LEVEL"
      type  = "String"
      value = "INFO"
    },
    {
      name  = "/analytics-service/ENVIRONMENT"
      type  = "String"
      value = "production"
    }
  ]
}


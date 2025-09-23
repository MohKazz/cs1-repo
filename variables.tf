variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "name" {
  type    = string
  default = "cs1nca-dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["eu-central-1a", "eu-central-1b"]
}

variable "tags" {
  type = map(string)
  default = {
    project = "cs1nca"
    env     = "dev"
  }
}


variable "db_username" {
  type    = string
  default = "appuser"
}
variable "db_password" {
  type    = string
  default = "ChangeMe123!"
}

# PGPASSWORD='ChangeMe123!' psql -h cs1nca-dev-pg.cjs0e40qgw0h.eu-central-1.rds.amazonaws.com -U appuser -d postgres -c "select version();"

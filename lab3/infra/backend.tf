# Dedicated Lab 3 state only. Foundation, Labs 5/6 and bootstrap remain local.
terraform {
  backend "gcs" {
    bucket = "cpe-hs-lab3-state-565473613966"
    prefix = "lab3"
  }
}

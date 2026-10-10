terraform {
  backend "gcs" {
    bucket = "cerebro-tf-state-0722648923" # Needs to be created
    prefix = "terraform/state"
  }
}

first add your access_key & secret_key & your region to provider"aws"
||
||
vv
# Configure the AWS Provider
provider "aws" {
  region = ""
  access_key = ""
  secret_key = ""

}
***************************************************************
choose your instance type,in my solution it is ubuntu-focal-20.04-amd64-server
you can choose another here,by changing ubuntu and values
||
||
vv
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
*************************************************************************
choose your private_ips for the two instances and add it to
||
||
vv
private_ips in resource "aws_network_interface"
**************************************************************
to enter the wordpress, take your wordpress instance Public IPv4 address
and put it in this formate
http://Public IPv4 address/
///wait a few minutes before trying to enter the wordpress///
output "ami_id" {
  value = aws_instance.jenkins_server.ami
}
output "availability_zone" {
  value = aws_instance.jenkins_server.availability_zone
}
output "aws_security_group" {
  value = aws_security_group.sg.id
}
output "storage_sftp_users" {
  description = "Information about created local SFTP users."
  value       = local.users_output
  sensitive   = true
}
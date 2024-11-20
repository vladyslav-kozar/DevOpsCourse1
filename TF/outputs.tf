# Вихідні дані для публічних IP-адрес кожної віртуальної машини

output "public_ip_addresses" {
 description = "Public IP addresses of the virtual machines"
 value       = [azurerm_public_ip.pip1, azurerm_public_ip.pip2]

}
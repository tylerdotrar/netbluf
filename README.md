# netbluf
The **Bottom Line Up Front** of the default **networking** interface.

# Summary
Effectively, this tool is ipconfig-lite -- rather than returning verbose information for
all of the network interfaces, netbluf returns only the data you care about for the most
relevant interface.  To do this, it determines your most relevant interface (i.e., the 
default interface) via connectivity and interface metrics.
 
On top of viewing configurations, it also has the built-in functionality of intuitively
setting static networking configurations on the default interface -- or renewing said
interface via DHCP.  Currently, the only supported static networking parameters are IPv4
address, default gateway, network CIDR, primary DNS, and DNS suffix.

#### Notes:
- When statically setting an interface, if only one static parameter is specified the 
remaining parameters will be copied from the current configuration.
- Static configurations and DHCP renewing require elevated privileges.

# Parameters
```
# Primary
  -Static      -->   (Alias: Set)   Statically set default interface network configuration
  -DHCP        -->   (Alias: Renew) Renew default interface network configuration via DHCP
  -Help        -->   Return Get-Help information

# Static Options
  -IPAddress   -->   IPv4 Address
  -Gateway     -->   Network Default Gateway
  -CIDR        -->   CIDR / Prefix Length (e.g., 24)
  -DNS         -->   Domain Name Server (only primary)
  -Suffix      -->   Domain Suffix (e.g., example.com)
```
# Usage
Unprivileged user has the ability to view network configuration, but not make any changes.
![Unprivileged User](https://cdn.discordapp.com/attachments/855920119292362802/1071095246961791026/image.png)

Administrative user has the ability to view, modify, and renew network configuration.
![Administrator](https://cdn.discordapp.com/attachments/855920119292362802/1071105946572566700/image.png)



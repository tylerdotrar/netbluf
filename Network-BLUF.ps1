function Network-BLUF {
#.SYNOPSIS
# Tool to view & modify the configuration of the current default networking interface.
# ARBITRARY VERSION NUMBER:  2.0.2
# AUTHOR:  Tyler McCann (@tylerdotrar)
#
#.DESCRIPTION
# The Bottom Line Up Front of your primary networking configuration.  Effectively, this
# tool is ipconfig-lite -- rather than returning all information for all your interfaces,
# it returns only the data you care about for only the current default network interface,
# which it determines utilizing interface metrics and connectivity.
# 
# On top of viewing data, it also has the built in functionality of easily being able to 
# statically modify the networking configuration of said interface, as well as renewing
# the interface via DHCP. Currently supported static networking parameters are IPv4
# address, default gateway, network CIDR, primary DNS, and DNS suffix.  When statically
# setting settings, if only one static parameter is specified the remaining parameters
# will be copied from the current configuration.
#
# DHCP/Static configuration requires elevated privileges.
#
# Parameters:
#
#   Primary
#    -DHCP        -->   Renew default interface network configuration via DHCP
#    -Static      -->   Statically set default interface network configuration
#    -Help        -->   Return Get-Help information
#
#   Static Options
#    -IPAddress   -->   IPv4 Address
#    -Gateway     -->   Network Default Gateway
#    -CIDR        -->   CIDR / Prefix Length (e.g., 24)
#    -DNS         -->   Domain Name Server (only primary)
#    -Suffix      -->   Domain Suffix (e.g., example.com)
#
#.LINK
# https://github.com/tylerdotrar/netbluf
    
    [Alias('netbluf')]

    Param (
        
        # Primary
        [switch] $DHCP,   # Elevated Privileges Required
        [switch] $Static, # Elevated Privileges Required
        [switch] $Help,

        # Static Options
        [string] $IPAddress,
        [string] $Gateway,
        [string] $CIDR,
        [string] $DNS,
        [string] $Suffix
    )    


    # Return help information
    if ($Help) { return (Get-Help Network-BLUF) }

    # Determine if user has elevated privileges
    function Is-UserAdmin {
        $User    = [Security.Principal.WindowsIdentity]::GetCurrent();
        $isAdmin = (New-Object Security.Principal.WindowsPrincipal $User).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

        if (!$isAdmin) { Write-Host 'This function requires elevated privileges.' -ForegroundColor Red }
        else           { return $TRUE }
    }

    # Collect important network config data
    function Get-NetConfig {

        # Determine the interface being used for default routing.
        $IfArray = (Get-NetRoute "0.0.0.0/0").ifIndex | Select-Object -Unique
    

        # If multiple interfaces are returned, find the highest priority interface that is both Connected and IPv4
        if ($IfArray.count -gt 1) {

            $ConnectedIf = Get-NetIPInterface -InterfaceIndex $IfArray -AddressFamily 'IPv4' -ConnectionState Connected
        
            # Create hashtable of interface indexes and interface metrics
            $InterfaceTable = @{}
            $ConnectedIf | % { $InterfaceTable += @{ $_.ifIndex = $_.InterfaceMetric } }
            $PriorityIf = ($InterfaceTable.Values | Measure-Object -Minimum).Minimum

            # Return interface index that has the lowest interface metric (highest priority)
            $DefaultIf = ($InterfaceTable.GetEnumerator() | ? { $_.Value -eq $PriorityIf }).name
        }
        else { $DefaultIf = $IfArray }


        # Interface alias for human readable output
        $IfAlias = (Get-NetIPInterface -InterfaceIndex $DefaultIf).InterfaceAlias | Select-Object -Unique


        # Determine if DHCP is being utilized
        $DHCP = (Get-NetIPInterface -InterfaceIndex $DefaultIf -AddressFamily IPv4).Dhcp
        if ($DHCP -eq 'Enabled') { $Config = 'DHCP'   }
        else                     { $Config = 'Static' }


        # Acquire pre-requisite network data
        $IPAddress = (Get-NetIPAddress -InterfaceIndex $DefaultIf -AddressFamily IPv4).IPAddress
        $Gateway   = (Get-NetRoute "0.0.0.0/0" -InterfaceIndex $DefaultIf -AddressFamily IPv4).NextHop
        $CIDR      = (Get-NetIPAddress -InterfaceIndex $DefaultIf -AddressFamily IPv4).PrefixLength
        $DNS       = (Get-DnsClientServerAddress -InterfaceIndex $DefaultIf -AddressFamily IPv4).ServerAddresses[0]
        $Suffix    = (Get-DnsClient -InterfaceIndex $DefaultIf).ConnectionSpecificSuffix


        # Determine the length of the longest string
        $MaxLength = (@($IfAlias,$DefaultIf,$IPAddress,$Gateway,$CIDR,$DNS,$Suffix) | Measure-Object -Maximum -Property Length).Maximum


        # Return relevant network data
        return @{Alias=$IfAlias;Index=$DefaultIf;Config=$Config;IPaddr=$IPAddress;Gateway=$Gateway;CIDR=$CIDR;DNS=$DNS;Suffix=$Suffix;Length=$MaxLength}
    }

    # Statically set default interface (Elevated Privileges required)
    function NetConfig-Static {
        
        # Determine is current user is privileged
        if (!(Is-UserAdmin)) { return }

        Try  {
            # Collect Network Interface Data
            $NetConf   = Get-NetConfig
            $DefaultIf = $NetConf.Index

            if (!$IPAddress) { $IPAddress = $NetConf.IPaddr  }
            if (!$Gateway)   { $Gateway   = $NetConf.Gateway }
            if (!$CIDR)      { $CIDR      = $NetConf.CIDR    }
            if (!$DNS)       { $DNS       = $NetConf.DNS     }
            if (!$Suffix)    { $Suffix    = $NetConf.Suffix  }


            # Statically set new IP and DNS settings
            Remove-NetIPAddress -InterfaceIndex $DefaultIf -AddressFamily IPv4 -Confirm:$False
            Remove-NetRoute -InterfaceIndex $DefaultIf -AddressFamily IPv4 -Confirm:$False

            New-NetIPAddress -InterfaceIndex $DefaultIf -IPAddress $IPAddress -PrefixLength $CIDR -DefaultGateway $Gateway | Out-Null
            Set-DnsClientServerAddress -InterfaceIndex $DefaultIf -ServerAddresses $DNS
            if ($Suffix) { Set-DnsClient -InterfaceIndex $DefaultIf -ConnectionSpecificSuffix $Suffix }


            # Output Information
            Write-Host "Default interface statically set." -ForegroundColor Yellow
            NetConfig-Status
        }

        Catch {   
           Write-Host 'An error occured. Outputing last error message:' -ForegroundColor Yellow
           return $Error[-1]
        }
	}

    # Renew default interface via DHCP (Elevated Privileges required)
    function NetConfig-DHCP {
        
        # Determine is current user is privileged
        if (!(Is-UserAdmin)) { return }

        Try {
            # Collect Network Interface Data
            $NetConf   = Get-NetConfig
            $IfAlias   = $NetConf.Alias
            $DefaultIf = $NetConf.Index
            

            # Remove static settings
            Remove-NetRoute -InterfaceIndex $DefaultIf -Confirm:$False
            Set-DnsClient -InterfaceIndex $DefaultIf -ResetConnectionSpecificSuffix
            Set-DnsClientServerAddress -InterfaceIndex $DefaultIf -ResetServerAddresses
            Set-NetIPInterface -InterfaceIndex $DefaultIf -Dhcp Enabled
            

            # Renew interface via ipconfig
            ipconfig /release $IfAlias | Out-Null
            ipconfig /renew $IfAlias | Out-Null


            # Output Information
            Write-Host "Default interface renewed via DHCP." -ForegroundColor Yellow
            NetConfig-Status
        }

        Catch { 
            Write-Host 'An error occured. Outputing last error message:' -ForegroundColor Yellow
            return $Error[-1]
        }
	}

    # Return current default interface configuration
    function NetConfig-Status {
        
        # Visual formatting of output
        function Net-Out ([string]$Block1,[string]$Block2,[int]$Length,[switch]$NewLine){
        
            # Visual Formatting
            if ($NewLine) { $DeadSpace = ' ' * (29 + $Length) }           
            if (!($Block1.length % 2)) { $Offset = ' ' }
            if (!$Block2) { $Block2 = 'NULL' }

            $Dots  = '. ' * [math]::Floor((27 - $Block1.length) / 2)
            $Space = ' ' * ($Length - $Block2.length)


            # Output to terminal
            if ($NewLine) { Write-Host "[$DeadSpace]" }
            Write-Host "[ $Block1$Offset$Dots" -NoNewline
            Write-Host $Block2 -ForegroundColor Green -NoNewline
            Write-Host "$Space ]"
        }


        # Collect Network Interface Data
        $NetConf = Get-NetConfig


        # Output Information
        Net-Out -Block1 'Interface Alias' -Block2 $NetConf.Alias -Length $NetConf.Length
        Net-Out -Block1 'Interface Index' -Block2 $NetConf.Index -Length $NetConf.Length
        Net-Out -Block1 'Configuration' -Block2 $NetConf.Config -Length $NetConf.Length

        Net-Out -Block1 'IP Address' -Block2 $NetConf.IPaddr -Length $NetConf.Length -NewLine
        Net-Out -Block1 'Gateway' -Block2 $NetConf.Gateway -Length $NetConf.Length
        Net-Out -Block1 'CIDR' -Block2 $NetConf.CIDR -Length $NetConf.Length

        Net-Out -Block1 'DNS Server' -Block2 $NetConf.DNS -Length $NetConf.Length -NewLine
        Net-Out -Block1 'DNS Suffix' -Block2 $NetConf.Suffix -Length $NetConf.Length
    }

    # Main Function
    if ($Static)   {
        $StaticParams = @($IPAddress,$Gateway,$CIDR,$DNS,$Suffix)
        if ($StaticParams -gt 0) { NetConfig-Static }
        else { Write-Host 'No static parameters specified.' -ForegroundColor Red }
    }
    elseif ($DHCP) { NetConfig-DHCP   }
    else           { NetConfig-Status }
}
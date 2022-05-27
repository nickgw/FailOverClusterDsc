$script:resourceHelperModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\Modules\DscResource.Common'

Import-Module -Name $script:resourceHelperModulePath

$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'
Function Get-TargetResource
{
    [CmdletBinding()]
    Param
    (

        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $Address,

        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $AddressMask

    )

    return Get-ClusterNetworkList

}

Function Set-TargetResource
{
    Param
    (

        [Parameter()]
        [System.String]
        [ValidateSet('Present', 'Absent')]
        $Ensure = 'Present',

        # IPAddress to add to Cluster
        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $IPAddress,

        # SubnetMask of IPAddress
        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $AddressMask
    )

    if ($Ensure -eq 'Present')
    {
        # We've gotten here because the IPAddress given is not in the DependencyExpression for the cluster
        # We need to Check if the network is added to the cluster. If not, we fail. If it is, we can append the IPAddress
        if ( -not $(Test-ClusterNetwork -IPAddress $IPAddress -AddressMask $AddressMask) )
        {
            New-InvalidArgumentException -Message ($script:localizedData.NonExistantClusterNetwork -f $IPAddress,$AddressMask)
            break
        }
        else
        {
            $params = @{
                IPAddress   = $IPAddress
                AddressMask  = $AddressMask
                ErrorAction = 'Stop'
            }
            Add-ClusterIPAddressDependency @params
        }
    }
    else
    {
        if (Test-ClusterIPAddressDependency -IPAddress $IPAddress -AddressMask $AddressMask) {
            Remove-ClusterIPAddressDependency -IPAddress $IPAddress -Subnet $AddressMask
        }
    }
}

Function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    Param
    (

        [Parameter()]
        [System.String]
        [ValidateSet('Present', 'Absent')]
        $Ensure = 'Present',

        # IPAddress to add to Cluster
        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $IPAddress,

        # SubnetMask of IPAddress
        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $AddressMask
    )

    # If IPAddress is not in ClusterResource DependencyExpression #fail
    # If IPAddress' Subnet is not in ClusterNetworks #fail
    $params = @{
      IPAddress  = $IPAddress
      AddressMask = $AddressMask
      VerbosePreference = $VerbosePreference
    }
    $testResult = Test-ClusterIPAddressDependency @params

    if ($Ensure -eq 'Present')
    {
        if ($testResult)
        {
            return $True
        }
        else
        {
            return $False
        }
    }
    else
    {
        if ($testResult)
        {
            return $False
        }
        else
        {
            return $True
        }
    }
}

<#
    .Synopsis
        Given an IP Address and a Subnet Mask, returns the IP Addresses subnet.
    .DESCRIPTION
        Returns an IPAddress object of the subnet mask of the given IPAddress and Subnet.
    .PARAMETER IPAddress
        IP address to add to the Cluster's DependencyExpression
    .PARAMETER AddressMask
        The subnet mask of the IPAddress
    .EXAMPLE
        Get-Subnet -IPAddress 10.235.32.129 -AddressMask 255.255.255.128
#>
function Get-Subnet
{
    [CmdletBinding()]
    [OutputType([System.Net.IPAddress])]
    Param
    (
        # IPAddress to add to Cluster
        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $IPAddress,

        # SubnetMask of IPAddress
        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $AddressMask
    )

    return [System.Net.IPAddress]($Ipaddress.Address -band $AddressMask.Address)
}

<#
    .Synopsis
        Adds an IPAddress as a Dependency to a Windows Cluster
    .DESCRIPTION
        Adds an IP Address resource to a Windows Cluster's Dependecy Expression
    .PARAMETER IPAddress
        IP address to add to the Cluster's DependencyExpression
    .PARAMETER AddressMask
        The subnet mask of the IPAddress
    .PARAMETER ClusterName
        Name of the cluster to add IP Address resource to
    .EXAMPLE
        # Using the default ParameterSet of both IP Address and Subnet
        Add-ClusterIPAddressDependency -IPAddress 10.235.32.137 -Subnet 255.255.255.128 -Verbose
#>
function Add-ClusterIPAddressDependency
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $IPAddress,

        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $AddressMask,

        [Parameter()]
        [System.String]
        $ClusterName = 'Cluster Name'
    )

    #* Get Windows Cluster resource
    $cluster = Get-ClusterResource | Where-Object { $_.name -eq $ClusterName}

    $ipResource = Add-ClusterIPResource -IPAddress $IPAddress -OwnerGroup $cluster.OwnerGroup
    Add-ClusterIPParameter -IPAddressResource $ipResource -IPAddress $IPAddress -AddressMask $AddressMask

    $ipResources = Get-ClusterResource | Where-Object
    {
        ( $_.OwnerGroup -eq $cluster.OwnerGroup ) -and
        ( $_.ResourceType -eq 'IP Address' )
    }

    $dependencyExpression = ''
    $ipResourceCount = $ipResources.count
    $i = 0
    while ( $i -lt $ipResourceCount )
    {
        if ( $i -eq $ipResourceCount )
        {
            $dependencyExpression += "[$($ipResources[$i].name)]"
        }
        else
        {
            $dependencyExpression += "[$($ipResources[$i].name)] or "
        }
        $i++
    }

    #Set cluster resources
    Try
    {
        $params = @{
            Resource    = $($cluster.Name)
            Dependency  = $dependencyExpression
            ErrorAction = 'Stop'
        }
        Write-Verbose -Message ($script:localizedData.SetDependencyExpression -f $dependencyExpression)
        Set-ClusterResourceDependency @params
    }
    Catch
    {
        #TODO error handling for when adding the depenencies list fails
        New-InvalidOperationException -Message $_.Exception.Message -ErrorRecord $_
    }
}

<#
    .Synopsis
        Tests whether a given IPAddress is part of the Cluster's DependencyExpression
    .PARAMETER IPAddress
        IP address to check whether it's in the Cluster's DependencyExpression
    .EXAMPLE
        Example using complete IPAddress and AddressMask default ParameterSet
        Test-ClusterIPAddressDependency -IPAddress 10.235.0.141 -AddressMask 255.255.255.128 -verbose
    .EXAMPLE
        Example using IPAddress from default ParameterSet
        Test-ClusterIPAddressDependency -IPAddress 10.235.0.141 -verbose
#>
function Test-ClusterIPAddressDependency
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        # IPAddress to add to Cluster
        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $IPAddress
    )

    $dependencyExpression = Get-ClusterResourceDependencyExpression

    Write-Verbose -Message ($script:localizedData.TestDependencyExpression -f $IPAddress, $dependencyExpression)
    If ( $dependencyExpression -match $IPAddress )
    {
        Write-Verbose -Message ($script:localizedData.SuccessfulTestDependencyExpression -f $IPAddress, $dependencyExpression)
        return $True
    }
    else
    {
        Write-Verbose -Message ($script:localizedData.FailedTestDependencyExpression -f $IPAddress, $dependencyExpression)
        return $False
    }
}

<#
    .Synopsis
        Checks whether the ClusterNetwork for a given IPAddress has been added to a Cluster
    .DESCRIPTION
        Given an IPAddress and AddressMask this cmdlet will check if the correct ClusterNetwork has
        been added to the cluster.
    .PARAMETER IPAddress
        IP address to check whether it's subnet is a cluster network already
    .PARAMETER AddressMask
        The subnet mask of the IPAddress
    .EXAMPLE
    Test-ClusterNetwork -IPAddress 10.245.10.32 -AddressMask 255.255.255.0
#>
function Test-ClusterNetwork
{
    [CmdletBinding()]
    param
    (
        # IPAddress to add to Cluster
        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $IPAddress,

        # SubnetMask of IPAddress
        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $AddressMask
    )

    $clusterNetworks = Get-ClusterNetworkList
    Write-Verbose -Message ($script:localizedData.GetSubnetfromIPAddressandAddressMask -f $IPAddress, $AddressMask)
    $subnet = $(Get-Subnet -IPAddress $IPAddress -AddressMask $AddressMask -Verbose -ErrorAction Stop)
    Write-Verbose -Message ($script:localizedData.FoundSubnetfromIPAddressandAddressMask -f $IPAddress, $AddressMask, $Subnet)

    foreach ( $network in $clusterNetworks )
    {
        if (( $network.Address -eq $subnet.IPAddressToString ) -and
            ( $network.AddressMask -eq $AddressMask.IPAddressToString ))
        {
            Write-Verbose -Message ($script:localizedData.NetworkAlreadyInCluster -f $($network.address), $IPAddress, $subnet)
            return $True
        }
    }

    return $false
}

<#
    .SYNOPSIS
        Returns a list of PSCustomObjects representing the network and subnet mask of all networks in the cluster.
#>
function Get-ClusterNetworkList {
    [CmdletBinding()]
    param()

    Write-Verbose -Message ($script:localizedData.GetClusterNetworks)
    $networks = New-Object "System.Collections.Generic.List[PSCustomObject]"
    Foreach ( $network in Get-ClusterNetwork )
    {
        $clusterNetworks.Add([PSCustomObject]@{
            Address     = $network.Address
            AddressMask = $network.AddressMask
        })
        Write-Verbose -Message ($script:localizedData.FoundClusterNetwork -f $($network.Address), $($network.AddressMask))
    }

    return $networks
}

<#
    .SYNOPSIS
        Returns the cluster Dependency expression for a given cluster.
    .PARAMETER ClusterName
        The name of the cluster to get the Dependency expression
#>
function Get-ClusterResourceDependencyExpression {
    [CmdletBinding()]
    [Alias()]
    [OutputType([System.String])] #Could be a [Microsoft.FailoverClusters.PowerShell.ClusterResourceDependency]
    Param
    (
        [String]$ClusterName = 'Cluster Name'
    )

    Try
    {
        Write-Verbose -Message ($script:localizedData.GetClusterResourceExpression)
        $cluster = Get-ClusterResource | Where-Object {$_.name -eq $ClusterName}
        return $(Get-ClusterResourceDependency -Resource $cluster.Name).DependencyExpression
    }
    Catch
    {
        New-InvalidOperationException -Message $_.Exception.Message -ErrorRecord $_
    }
}

<#
    .Synopsis
        Adds an IP Address Resource to a given Cluster Group and returns an IPAddress Resource
    .PARAMETER IPAddress
        IP address to check whether it's subnet is a cluster network already
    .PARAMETER OwnerGroup
        OwnerGroup of the cluster to add the IP resource to
#>
function Add-ClusterIPResource
{
    [CmdletBinding()]
    [OutputType([Microsoft.FailoverClusters.PowerShell.ClusterResource])]
    Param
    (
        # IPAddress to add to Cluster
        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $IPAddress,

        # Owner Group of the cluster
        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $OwnerGroup
    )

    Try
    {
        #* Create new IPAddress resource and add the IPAddress parameters to it
        Write-Verbose -Message ($script:localizedData.CreateNewIPResource -f $IPAddress,$AddressMask)
        $params = @{
            Name         = "IP Address $IPAddress"
            ResourceType = 'IP Address'
            Group        = $OwnerGroup
            ErrorAction  = 'Stop'
        }
        return Add-ClusterResource @params
    }
    Catch
    {
        New-InvalidOperationException -Message $_.Exception.Message -ErrorRecord $_
    }
}

<#
    .Synopsis
        Removes an IP Address Resource to a given Cluster Group and returns an IPAddress Resource
    .PARAMETER IPAddress
        IP address to remove from the cluster
    .PARAMETER OwnerGroup
        OwnerGroup of the cluster to remove the IP resource from
#>
function Remove-ClusterIPResource
{
    [CmdletBinding()]
    Param
    (
        # IPAddress to add to Cluster
        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $IPAddress,

        # Owner Group of the cluster
        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $OwnerGroup
    )

    Try
    {
        #* Create new IPAddress resource and add the IPAddress parameters to it
        Write-Verbose -Message ($script:localizedData.CreateNewIPResource -f $IPAddress,$AddressMask)
        $params = @{
            Name         = "IP Address $IPAddress"
            ResourceType = 'IP Address'
            Group        = $OwnerGroup
            ErrorAction  = 'Stop'
        }
        Remove-ClusterResource @params
    }
    Catch
    {
        New-InvalidOperationException -Message $_.Exception.Message -ErrorRecord $_
    }
}

<#
    .Synopsis
        Adds an IP address resource to cluster parameter
    .PARAMETER IPAddressResource
        IP cddress resource to add to the cluster parameter
    .PARAMETER IPAddress
        IP address to add to the cluster parameter
    .PARAMETER AddressMask
        Address mask of the IP address
#>
function Add-ClusterIPParameter
{
    [CmdletBinding()]
    Param
    (
        # IPAddress to add to Cluster
        [Parameter(Mandatory = $true)]
        [Microsoft.FailoverClusters.PowerShell.ClusterResource]
        $IPAddressResource,

        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $IPAddress,

        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $AddressMask
    )

    $parameter1 = New-Object Microsoft.FailoverClusters.PowerShell.ClusterParameter $IPAddressResource,Address,$IPAddress
    $parameter2 = New-Object Microsoft.FailoverClusters.PowerShell.ClusterParameter $IPAddressResource,SubnetMask,$AddressMask
    $parameterList = $parameter1,$parameter2

    #* Add the IP Address resource to the cluster
    Try
    {
        Write-Verbose -Message ($script:localizedData.AddIPAddressResource -f $IPAddress,$AddressMask)
        $parameterList | Set-ClusterParameter -ErrorAction Stop
    }
    Catch
    {
        #TODO Add error handling here for failure. Most likely reasons are
        #* IP Address already exists (does this check actually IP Address or just IP Address Name)
        #* IP Address network has yet to be added to the Cluster
        New-InvalidOperationException -Message $_.Exception.Message -ErrorRecord $_
    }
}

<#
    .Synopsis
        Removes an IP address to the cluster parameter
    .PARAMETER IPAddressResource
        IP cddress resource to remove to the cluster parameter
    .PARAMETER IPAddress
        IP address to remove to the cluster parameter
    .PARAMETER AddressMask
        Address mask of the IP address
#>
function Remove-ClusterIPParameter
{
    [CmdletBinding()]
    Param
    (
        # IPAddress to add to Cluster
        [Parameter(Mandatory = $true)]
        [Microsoft.FailoverClusters.PowerShell.ClusterResource]
        $IPAddressResource,

        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $IPAddress,

        [Parameter(Mandatory = $true)]
        [System.Net.IPAddress]
        $AddressMask
    )

    $parameter1 = New-Object Microsoft.FailoverClusters.PowerShell.ClusterParameter $IPAddressResource,Address,$IPAddress
    $parameter2 = New-Object Microsoft.FailoverClusters.PowerShell.ClusterParameter $IPAddressResource,SubnetMask,$AddressMask
    $parameterList = $parameter1,$parameter2

    #* Add the IP Address resource to the cluster
    Try
    {
        Write-Verbose -Message ($script:localizedData.RemoveIPAddressResource -f $IPAddress,$AddressMask)
        $parameterList | Set-ClusterParameter -Delete -ErrorAction Stop
    }
    Catch
    {
        #TODO Add error handling here for failure. Most likely reasons are
        #* IP Address already exists (does this check actually IP Address or just IP Address Name)
        #* IP Address network has yet to be added to the Cluster
        New-InvalidOperationException -Message $_.Exception.Message -ErrorRecord $_
    }
}
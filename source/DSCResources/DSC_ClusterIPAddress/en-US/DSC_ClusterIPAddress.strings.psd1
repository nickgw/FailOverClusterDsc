# Localized resources for xCluster

ConvertFrom-StringData @'
    CombinedIPAndSubnetMask = Combined IP address and subnet mask were passed as {0}.
    SplitIPandSubnetMask = IP address and subnet mask split as {0} and {1}.
    GetClusterNetworks = Getting all networks added to this cluster.
    FoundClusterNetwork = Found cluster network {0}/{1}.
    GetSubnetfromIPAddressandSubnetMask = Getting the subnet of the given IPAddress {0} with subnet mask {1}
    FoundSubnetfromIPAddressandSubnetMask = IP address {0} with subnet mask {1} is in subnet {2}.
    NetworkAlreadyInCluster = Subnet {0} for IPAddress {1} network {2} is added to the cluster
    GetClusterResourceExpression =  Getting Cluster DependencyExpression.
    TestDependencyExpression = Testing if {0} is in DependencyExpression {1}.
    SuccessfulTestDependencyExpression = {0} is in DependencyExpression {1}.
    FailedTestDependencyExpression = {0} is not in DependencyExpression {1}.
'@
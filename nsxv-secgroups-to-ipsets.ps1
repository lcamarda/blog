 if ( !(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) ) {
. 'C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1'
}

Connect-VIServer vcsa-01a.corp.local -User administrator@vsphere.local -Password VMware1!

Connect-NsxServer 192.168.110.16 -Username admin -Password VMware1!

$NSXUsername = "admin"
$NSXPassword = "VMware1!"
$uri = "https://192.168.110.16"
# Create authentication header with base64 encoding
$EncodedAuthorization = [System.Text.Encoding]::UTF8.GetBytes($NSXUsername + ':' + $NSXPassword)
$EncodedPassword = [System.Convert]::ToBase64String($EncodedAuthorization)
# Construct headers with authentication data + expected Accept header (xml / json)
$head = @{"Authorization" = "Basic $EncodedPassword"}



$secGroups = Get-NsxSecurityGroup

foreach ($secGroup in $secgroups) {
   $secGroupId= $secGroup.objectId

   $Url = $uri + "/api/2.0/services/securitygroup/" + $secGroup.objectId + "/translation/ipaddresses"
   [xml]$r = Invoke-WebRequest -Uri $Url -Method:Get -Headers $head -Body $body -ContentType "application/xml"

   $ipv4name = "ipsv4-" + $secGroup.name
   $ipv6name = "ipsv6-" + $secGroup.name

   $ipSetv4 = New-NsxIpSet -name $ipv4name
   $ipSetv6 = New-NsxIpSet -name $ipv6name

   foreach ($item in $r.ipNodes.ipNode.ipAddresses ) {
      $ipAddresses = $item.string
      $ipAddressesElemets=$ipAddresses.split(' ')
      foreach ( $i in $ipAddressesElemets) {
         $checkifip = [IPAddress] $i.ToString()
         if ( $checkifip.AddressFamily.ToString() -eq "InterNetwork" ) {
            Get-NsxIpSet -objectId $ipSetv4.objectId | Add-NsxIpSetMember -IPAddress ($i.ToString() + "/32")
         }
         if ( $checkifip.AddressFamily.ToString() -eq "InterNetworkV6" ) {
            Get-NsxIpSet -objectId $ipSetv6.objectId | Add-NsxIpSetMember -IPAddress ($i.ToString() + "/128" )
         }
      }
   }


   Get-NsxSecurityGroup -objectId $secGroupId |  Add-NsxSecurityGroupMember -Member $ipSetv4
   Get-NsxSecurityGroup -objectId $secGroupId |  Add-NsxSecurityGroupMember -Member $ipSetv6
}  

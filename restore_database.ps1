param (
        [Parameter(Mandatory = $true)]
        [string]$RG,
        [Parameter(Mandatory = $true)]
        [string]$PrimaryServer,
        [Parameter(Mandatory = $true)]
        [string]$SqlUsername,
        [Parameter(Mandatory = $true)]
        [string]$SqlPass,
        [Parameter(Mandatory = $true)]
        [string]$RestoreInterval
    )

$Failover = Get-AzSqlDatabaseFailoverGroup -ResourceGroupName $RG -ServerName $PrimaryServer
If ($Failover){
    $Failover | ForEach-Object{
        Write-Host "Start of removing failover group $($_.FailoverGroupName)"
        Remove-AzSqlDatabaseFailoverGroup -ResourceGroupName $RG -ServerName $PrimaryServer -FailoverGroupName $_.FailoverGroupName
        
        Foreach ($Database in $_.DatabaseNames){
            $NewDatabaseName = "$Database-old"
            $SQLCommandString = 'ALTER DATABASE "' + $Database + '" MODIFY NAME = "' + $NewDatabaseName + '"'
            $Conn = "Server=tcp:$PrimaryServer.database.windows.net,1433;Persist Security Info=False;User ID=$SqlUsername;Password=$SqlPass;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
            $RestorePoint =((Get-Date) - (New-TimeSpan -Minutes $RestoreInterval)).ToUniversalTime()
        
            Write-Host "Start of removing replication for $Database"
            Remove-AzSqlDatabaseSecondary `
                -ResourceGroupName $_.ResourceGroupName `
                -ServerName $_.ServerName `
                -DatabaseName $Database `
                -PartnerResourceGroupName $_.PartnerResourceGroupName `
                -PartnerServerName $_.PartnerServerName
            
            Write-Host "Start of renaming databse to $NewDatabaseName"
            Invoke-Sqlcmd -Query $SQLCommandString -ConnectionString $Conn
            # It takes some time to save the new database name
            Do {
                $Name = (Get-AzSqlDatabase -ResourceGroupName $_.ResourceGroupName -ServerName $_.ServerName).DatabaseName
                Start-Sleep 60
            }
            Until ($Name -contains $NewDatabaseName)
        
            Write-Host "Start of restoring $Database from $RestorePoint"
            $Primary = Get-AzSqlDatabase -ResourceGroupName $_.ResourceGroupName -ServerName $_.ServerName -DatabaseName $NewDatabaseName           
            Restore-AzSqlDatabase -FromPointInTimeBackup -PointInTime $RestorePoint `
                -ResourceGroupName $_.ResourceGroupName `
                -ServerName $_.ServerName `
                -TargetDatabaseName $Database `
                -ResourceId $Primary.ResourceId `
                -Edition $Primary.Edition `
                -ServiceObjectiveName $Primary.CurrentServiceObjectiveName
            

            Write-Host "Start of removing partner database"
            Remove-AzSqlDatabase -ResourceGroupName $_.PartnerResourceGroupName -ServerName $_.PartnerServerName -DatabaseName $Database
            # Old primary database sould be removed manualy
        }

        Write-Host "Start of creating failover group $($_.FailoverGroupName)"
        New-AzSqlDatabaseFailoverGroup -FailoverGroupName $_.FailoverGroupName `
            -ResourceGroupName $_.ResourceGroupName `
            -ServerName $_.ServerName `
            -PartnerResourceGroupName $_.PartnerResourceGroupName `
            -PartnerServerName $_.PartnerServerName `
            -FailoverPolicy $_.ReadWriteFailoverPolicy `
            -GracePeriodWithDataLossHours $_.FailoverWithDataLossGracePeriodHours
        $FailoverGroup = Get-AzSqlDatabaseFailoverGroup -ResourceGroupName $_.ResourceGroupName -ServerName $_.ServerName -FailoverGroupName $_.FailoverGroupName
        $Databases = Get-AzSqlDatabase -ResourceGroupName $_.ResourceGroupName -ServerName $_.ServerName -Database $Database
        $FailoverGroup = $FailoverGroup | Add-AzSqlDatabaseToFailoverGroup -Database $Databases   
    }
}
Else{
    Write-Host "No one failover group exists"
}
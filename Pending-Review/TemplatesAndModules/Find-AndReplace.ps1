[CmdletBinding(PositionalBinding=$false)]
Param
(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -Path $_ -PathType Container})]
    [String]$ScriptDirectoryName,

    [Parameter(Mandatory)]
    [String]$Find,

    [Parameter(Mandatory)]
    [String]$ReplaceWith,

    [switch]$CaseSensitive = $false
)

Begin
{
    $Files = [System.IO.Directory]::GetFiles("C:\temp","*.ps1")
}

Process
{
    ForEach($File In $Files)
    {
        If($CaseSensitive)
        {
            (Get-Content -Path $File -Force) -creplace $Find, $ReplaceWith | Set-Content -Path $File -Force
        }
        Else
        {
            (Get-Content -Path $File -Force) -replace $Find, $ReplaceWith | Set-Content -Path $File -Force
        }
    }
}

End
{

}
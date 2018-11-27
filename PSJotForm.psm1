function Get-JotFormApiKey {
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ApiKey,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$RegistryKeyPath = 'HKCU:\Software\PSJotForm'
	)
	
	$ErrorActionPreference = 'Stop'

	function decrypt([string]$TextToDecrypt) {
		$secure = ConvertTo-SecureString $TextToDecrypt
		$hook = New-Object system.Management.Automation.PSCredential("test", $secure)
		$plain = $hook.GetNetworkCredential().Password
		return $plain
	}

	try {
		if ($PSBoundParameters.ContainsKey('ApiKey')) {
			$script:JotFormAPIKey = $ApiKey
			$script:JotFormAPIKey
		} elseif (Get-Variable -Name JotFormAPIKey -Scope Script -ErrorAction Ignore) {
			$script:JotFormAPIKey
		} elseif (-not (Test-Path -Path $RegistryKeyPath)) {
			throw "No JotForm configuration found in registry"
		} elseif (-not ($keyValues = Get-ItemProperty -Path $RegistryKeyPath)) {
			throw 'JotForm API not found in registry'
		} else {
			$script:JotFormAPIKey = decrypt $keyValues.APIKey
			$script:JotFormAPIKey
		}
	} catch {
		Write-Error $_.Exception.Message
	}
}

function Save-JotFormApiAuthInfo {
	[CmdletBinding()]
	param (
		[Parameter()]
		[string]$ApiKey,

		[Parameter()]
		[string]$RegistryKeyPath = "HKCU:\Software\PSJotForm"
	)

	begin {
		function encrypt([string]$TextToEncrypt) {
			$secure = ConvertTo-SecureString $TextToEncrypt -AsPlainText -Force
			$encrypted = $secure | ConvertFrom-SecureString
			return $encrypted
		}
	}
	
	process {
		if (-not (Test-Path -Path $RegistryKeyPath)) {
			New-Item -Path ($RegistryKeyPath | Split-Path -Parent) -Name ($RegistryKeyPath | Split-Path -Leaf) | Out-Null
		}
		
		$values = $PSBoundParameters.GetEnumerator().where({ $_.Key -ne 'RegistryKeyPath' -and $_.Value}) | Select-Object -ExpandProperty Key
		
		foreach ($val in $values) {
			Write-Verbose "Creating $RegistryKeyPath\$val"
			New-ItemProperty $RegistryKeyPath -Name $val -Value $(encrypt $((Get-Variable $val).Value)) -Force | Out-Null
		}
	}
}

function Invoke-JotFormApiCall {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$HttpMethod,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Parameters,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[hashtable]$Payload
	)

	$ErrorActionPreference = 'Stop'

	$apiKey = Get-JotFormApiKey

	$baseAuthUri = 'https://api.jotform.com'
	$uri = '{0}/{1}' -f $baseAuthUri, $Parameters
	$headers = @{ 'APIKEY' = $apiKey }

	$invRestParams = @{
		Uri     = $uri
		Headers = $headers
		Method  = $HttpMethod
	}
	if ($PSBoundParameters.ContainsKey('Payload')) {
		$invRestParams.Body = $Payload
	}
	Invoke-RestMethod @invRestParams
}

function Get-JotFormForm {
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$Full
	)

	$ErrorActionPreference = 'Stop'
	
	$invParams = @{ 
		'HttpMethod' = 'GET' 
		'Parameters' = 'user/forms'	
	}
	$userForms = (Invoke-JotFormApiCall @invParams).content
	if ($PSBoundParameters.ContainsKey('Name')) {
		$userForms = $userForms.where({ $_.title -eq $Name})
	}
	$userForms.foreach({
			$properties = (Invoke-JotFormApiCall -HttpMethod GET -Parameters "form/$($_.id)/properties").content
			foreach ($prop in $properties) {
				foreach ($propVal in $prop.PSObject.Properties) {
					$propVal | Add-Member -NotePropertyName $propVal.Name -NotePropertyValue $propVal.Value
				}
				$prop
			}
		})
}

function Get-JotFormQuestion {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$Form,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)

	$ErrorActionPreference = 'Stop'
	
	$invParams = @{ 
		'HttpMethod' = 'GET' 
		'Parameters' = "form/$($Form.id)/questions"
	}
	$result = Invoke-JotFormApiCall @invParams
	$questions = @()
	foreach ($question in $result.content.PSObject.Properties.value) {
		$question | Add-Member -NotePropertyName 'id' -NotePropertyValue $question.qid
		$question | Add-Member -NotePropertyName 'formId' -NotePropertyValue $Form.id
		$questions += $question
	}
	if ($PSBoundParameters.ContainsKey('Name')) {
		$questions.where({ $_.text -eq $Name })	
	} else {
		$questions
	}
}

function Set-JotFormQuestion {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ValueFromPipeline)]
		[ValidateNotNullOrEmpty()]
		[pscustomobject]$Question,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string[]]$Options,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$PassThru
	)

	$ErrorActionPreference = 'Stop'
	
	$invParams = @{ 
		'HttpMethod' = 'POST' 
		'Parameters' = "form/$($Question.formId)/question/$($Question.id)"
	}

	$payload = @{}
	if ($PSBoundParameters.ContainsKey('Options')) {
		if ($Question.type -ne 'control_dropdown') {
			throw 'You cannot update options on a question that is not a drop down.'
		}
		$payload['question[options]'] = $Options -join '|'
	}
	

	$result = Invoke-JotFormApiCall @invParams -Payload $payload
	if ($PassThru.IsPresent) {
		$result
	}
}
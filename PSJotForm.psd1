@{
	RootModule        = 'PSJotForm.psm1'
	ModuleVersion     = '0.1'
	GUID              = '223d8ede-1753-4fa2-a18a-5df263c0f7f4'
	Author            = 'Adam Bertram'
	CompanyName       = 'TechSnips, LLC'
	Copyright         = '(c) 2018 TechSnips, LLC. All rights reserved.'
	Description       = 'PSJotForm is a module that allows you to interact with the JotForm service in a number of different ways with PowerShell.'
	RequiredModules   = @()
	FunctionsToExport = @('*')
	VariablesToExport = @()
	AliasesToExport   = @()
	PrivateData       = @{
		PSData = @{
			Tags       = @('JotForm', 'REST')
			ProjectUri = 'https://github.com/adbertram/PSJotForm'
		}
	}
}
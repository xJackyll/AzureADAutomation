This PowerShell script is designed to automate various management tasks related to Azure Active Directory (Azure AD). It connects to Azure AD using the provided Tenant ID and performs operations such as creating groups and users, checking their existence, and managing group memberships based on a provided CSV file.

### Customization 🔄
- **Dictionary** (`$dict`): Customize this dictionary with your own group attributes and their corresponding values.
- **Debug Mode** (`$Enable_Debug`): Enable or disable debug mode to control logging verbosity.
- **CSV** : Edit the CSV as you wish. I've put some users and groups just for testing

### Logging 📋
The script logs various messages to a log file (`Log_Powershell.txt`) located in the `Logs` folder. It provides information, warnings, errors, and debug messages for better understanding and troubleshooting.

### Project Structure
```
ProjectRoot
│ README.md
│ 
├── Script
│ └── AzureADAutomation.ps1
│
├── Excel
│ ├── CSVxScript.csv
│ └── Mapping.txt
│
└── Logs
   └── "YourDate"_AzAD.log
```

### Important Note ⚠️
This project relies on a specific folder and file structure. To ensure proper functionality, DO NOT modify:
- Folder & File names.
- The Data in the Files (except for the ones mentioned above).
- The Structure outlined in the "Project Structure" section.

Any alterations to these elements may lead to unexpected behavior and could compromise the project's functionality.

*Note: When a user is in multiple groups that have the same names, there's no way for the script to spot the intended one and exiting from the others, so it will leave things as they are.*

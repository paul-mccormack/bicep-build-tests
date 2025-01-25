# Linting Bicep in Github Actions

Azure Bicep supports code linting.  Linting is a process to check code for programatic and stylistic errors.  VS Code with the Bicep extension installed does this automatically as you write to check against the recommended best practices.  More information and details is available in the [Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/linter).  The screenshot below shows the automatic linter in VS Code highlighting a warning for an unused parameter:

![VS Code linter warning]()

This automated linting works fine if you do not need to change from the recommended rules.  If you do need to change the level or disable a rule you can create a file named ```bicepconfig.json``` in the same directory as your bicep files.  You can see an example in this repository.

The available levels for a rule are: off, info, warning and error.  All but error will allow you to deploy the bicep code.  Most of the rules at default configuration are set to warning.  These cover best practise recommenadations mostly and will deploy without issues but there are a few I would prefer to be set to error and halt the deployment.  These are the rules that specifically deal with secrets.

For example, you can ensure a parameter that contains sensitive data is kept out of deployment logs by using the ```@secure()``` decorator.  There is a rule to enforce this called ```secure-secrets-in-params```.  The code below shows that rule with the enforcement raised to error:

```json
{
  "analyzers": {
    "core": {
      "enabled": true,
      "rules": {
        "secure-secrets-in-params": {
          "level": "error"
        }
      }
    }
  }
}
```
To use this in a CI/CD workflow deployment and publish the errors or warnings you need to add the linting stage as a job or step in the deployment.  The ```main.yml``` GitGub Actions workflow file in this repo is configured to do this.

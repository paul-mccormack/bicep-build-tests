[![Check and Deploy Bicep Template](https://github.com/paul-mccormack/bicep-build-tests/actions/workflows/main.yml/badge.svg)](https://github.com/paul-mccormack/bicep-build-tests/actions/workflows/main.yml)

# Linting Bicep in Github Actions

Azure Bicep supports code linting.  Linting is a process to check code for programatic and stylistic errors.  VS Code with the Bicep extension installed does this automatically as you write to check against the recommended best practices.  More information and details is available in the [Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/linter).  The screenshot below shows the automatic linter in VS Code highlighting a warning for an unused parameter:

![VS Code linter warning](https://github.com/paul-mccormack/bicep-build-tests/blob/main/images/linterWarning.jpg)

And an error would appear like the screenshot below:

![VS Code linter error](https://github.com/paul-mccormack/bicep-build-tests/blob/main/images/errorLinterWarning.jpg)

This automated linting works fine if you do not need to change from the recommended rules.  If you do need to change the level or disable a rule you can create a file named ```bicepconfig.json``` in the same directory as your bicep files.  You can see an example in this repository.

The available levels for a rule are: off, info, warning and error.  All but error will allow you to deploy the bicep code.  The default setting for all the rules is warning.  These cover best practise recommendations mostly and will deploy without issues, however there are a few I would prefer to be set to error and halt the deployment.  These are the rules that specifically deal with secrets.

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
To use this in a CI/CD workflow deployment and publish any errors or warnings you need to add the linting stage as a job or step in the deployment.  The ```main.yml``` GitHub Actions workflow file in this repo is configured to do this.  The results of the code tests will appear in the repository under Security - Code Scanning.  You need to give GitHub Actions some permissions to enable it to upload the results into the repo.  This is done in the permissions section of the workflow file:

```yml
permissions:
  id-token: write # Require write permission to Fetch an OIDC token.
  actions: read # Required if repo is private
  contents: read # Required if repo is private
  security-events: write # Required for code scanning
```

id-token is required as I am logging into Azure using OpenID Connect.  The read permissions for actions and contents are only needed if your repository is private.  The security-events permission set to write is the important one for this example.

After the code checkout step I am using the Setup Bicep action by [Anthony C Martin](https://github.com/marketplace/actions/setup-bicep) to install the Bicep CLI onto the Github hosted runner. Then we can run the bicep lint command to perform the analysis and output a SARIF file (Static Analysis Results Interchange Format), this file is then uploaded to the github repository using the GitHub provided [codeql action](https://github.com/github/codeql-action).

The rest of the deployment is logging into Azure, creating a resource group and finally deploying the resources.  In this example I am deploying a storage account.

## Warning example

I've included a commented parameter at the top of the Bicep template which is not used.

```
//uncomment the parameter below to trigger a warning
//param notused string = 'unused'
```
Uncommenting this parameter would cause a warning to be triggered.  The deployment would still succeed but with a warning in the code scanning section of the repo. as shown in the follwing screenshot:

![code scanning warning](https://github.com/paul-mccormack/bicep-build-tests/blob/main/images/codeScanningWarning.jpg)


## Error example

At the bottom of the Bicep template there is a commented output statement which is more serious and I want to cause this deployment to fail the test with an error.

```
//uncomment the output below to trigger an error causing the deployment to fail
//output leakedsecret string = stg.listKeys().keys[0].value
```
Uncommenting this output will write the storage account key into the deployment logs if allowed to complete.  The screenshot below shows what that looks like in the repo code scanning section:

![code scanning error](https://github.com/paul-mccormack/bicep-build-tests/blob/main/images/codeScanningFail.jpg)

In the actions job we can see it did fail at the linting step so our storage account key wasn't exposed.

![job failure](https://github.com/paul-mccormack/bicep-build-tests/blob/main/images/makeItFail.jpg)

## Override a linter rule

Bicep provides a method for overriding a rule when you have no other choice. I would use this with caution.  Add #disable-next-line followed by the name of the linter rule you want to override on the line above the warning.  

```
#disable-next-line no-unused-params
param notused string = 'unused'
```

## Pipeline Configuration

The pipeline is configured to perform the deployment using multiple jobs with an approval gate in place before the deployment is carried out.  The steps are:

* Create the Resource Group - We need to create this first for the validation stage to succeed.
* Run a linting check on the Bicep code.
* Run a Validation check on the Bicep code.
* Run a What-if check on the Bicep code.
* Pause the deployment and wait for approval.
* Upon approval run the deployment.

The config file can be found here: [main.yml](https://github.com/paul-mccormack/bicep-build-tests/blob/main/.github/workflows/main.yml)

Each job is dependant on the previous stage by using the ```needs:``` statement.  The following code block is an example.  Job 2 will not commence unless Job 1 is successfully completed.

```yml
jobs:
  job1:
    name: Job 1
    runs-on: ubuntu-latest
    steps:
    - name: step1
    
  job2:
    name: Job 2
    runs-on: ubuntu-latest
    needs: job1
    steps:
    - name: step1
```

The approval for the final deployment is accomplished by configuring an Environment is the repository with a protection rule requiring a reviewer before the environment can be used.  In a true production environment you would also enable the Prevent self-review feature.

![environment](https://github.com/paul-mccormack/bicep-build-tests/blob/main/images/environment.jpg)

Then you can use the ```environment:``` statement in the deployment job to trigger the protection rule and pause the deployment until the reviewer has approved the job.

```yml
deploy-job:
  name: Deploy Resources
  runs-on: ubuntu-latest
  needs: previous-job
    environment: production
    steps:
```

### Note on using enviroments with OIDC

You need to provide your repo with your Azure tenant ID, Subscription ID and App Registration ID.  These are secured in the Actions Repository Secrets section to allow the [azure/login@v2](https://github.com/marketplace/actions/azure-login) action to gain access.

When you use federated credentials to allow the pipeline access to Azure, the subject claim GitHub sends in the token must match exactly the subject identifier in the App Registration Federated Credentials.  The subject claim GitHub sends includes the branch, normally main and would look like the example below:

```
repo:paul-mccormack/bicep-build-tests:ref:refs/heads/main
```

Only a push or merge into the main branch would be successful at logging into Azure.  When you use an envrionment the branch configuration is replaced with the environment configuration, shown below:

```
repo:paul-mccormack/bicep-build-tests:environment:production
```

To handle this I created two Federated Credentials on the App Registration.

![Federated Credentials](https://github.com/paul-mccormack/bicep-build-tests/blob/main/images/fedCreds.jpg)

There are a lot of options on how you could configure this depending on your scenario.  You could configure credentails for the main branch and another credential for a test or dev branch.  If you had production and dev environments configured in GitHub you could create an App Registration for each environment and put the required secrets into the environment secrets instead of the repository secrets.



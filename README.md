# Publish-GitlabPipelines

To install the [module](https://www.powershellgallery.com/packages/Publish-GitlabPipelines)

```powershell
Install-Module -Name Publish-GitlabPipelines
Import-Module Publish-GitlabPipelines
```

Publish gitlab child pipelines dynamically based on changes in a folder, this is for use with mono repos and gitlab.

```text
.rootDir
├── project-1
│   ├── file 1
│   └── file n
├── project-2
│   ├── file 1
│   └── file n
├── project-3
│   ├── file 1
│   └── file n
└── project-4
    ├── file 1
    └── file n
```

The tool allows for configuration of job commands, job image and root directory as well as automatically replacing `__PROJECT_PATH__` with the generated ci project path.

_RootDir_: Optional, this parameter is used to configure the root location for npm monorepos this can be the lerna or yarn work space overarching folder.  
_Image_: Optional, The image to use in each job for the generated pipelines
_Commands_: Optional, The commands to use in the script section of the yaml configuration for each job

For example to find all changed projects in the directory Modules, generate build and release pipelines using the Microsoft powershell image use a command like this.

```powershell
Import-Module Publish-GitlabPipelines
Publish-GitlabPipelines -RootDir "Modules" -Image "mcr.microsoft.com/powershell" -Commands "Build-Project __PROJECT_PATH__", "Release-Project __PROJECT_PATH__"
```

## CI Configuration

To get started you will need to add new jobs and possibly stages if you choose to your ci configuration.
It is recommended you create your own image to run jobs against instead of installing git each time around.

```yaml
stages:
 - generate
 - trigger

generate-for-changed:
  stage: generate
  image: mcr.microsoft.com/powershell:7.2-alpine-3.13
  script:
    - apk add git
    - Publish-GitlabPipelines -RootDir "Modules"
  artifacts:
    paths:
      - release-gitlab-ci.yml

trigger-pipeline:
  stage: trigger
  trigger:
    include:
      - artifact: release-gitlab-ci.yml
        job: generate-child-pipeline
    strategy: depend
```

## Development

Before submitting a pull request ensure you have run this command

```shell
Invoke-ScriptAnalyzer -Path ./Publish-GitlabPipelines.psm1
```

Then to publish
```powershell
Publish-Module -NuGetApiKey [SECRET] -Path ./
```

# Publish-GitlabPipelines

Publish gitlab child pipelines dynamically based on changes in a folder, this is for use ith mono repos and gitlab.

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

## Development

Before submitting a pr ensure you have run this command

```shell
Invoke-ScriptAnalyzer -Path ./Publish-GitlabPipelines.psm1
```

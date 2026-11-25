# books

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

Books application

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../../library_charts/aws-secrets | aws-secrets | 0.1.0 |
| file://../../library_charts/web-ingress | web-ingress | 0.1.0 |
| file://../../library_charts/web-workload | web-workload | 0.1.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| awsSecrets | list | `[]` | AWS Secrets Manager secrets to synchronize; labels are Kubernetes Secret names. |
| webIngresses | list | `[]` | Ingresses rendered by the web-ingress library chart. |
| webWorkloads | list | `[{"envFromSecrets":["books-auth"],"image":{"repository":"426576223955.dkr.ecr.eu-west-2.amazonaws.com/books","tag":"latest"},"name":"books"}]` | Web workloads rendered by the web-workload library chart. |


Jenkins

Role

Jenkins currently provides:

Infrastructure deployment orchestration.

Application CI/CD.

The long-term plan is Jenkins → GitHub Actions migration after the
platform path is stable.

Infrastructure path

Git
 ↓
Jenkins
 ↓
Terraform
 ↓
AWS

GitOps synchronization

Terraform outputs are read by Jenkins and written into GitOps with yq.

Application path

Application Git
 ↓
Jenkins
 ↓
Build/Test/Scan
 ↓
Docker
 ↓
ECR
 ↓
GitOps
 ↓
ArgoCD
 ↓
EKS

Important pipeline hardening

Terraform application-SG output no longer silently falls back to {}.

Missing output now causes a visible pipeline failure.

Common troubleshooting

Jenkinsfile parser

Remove Markdown code fences.

Maven

Run from:

services/auth-service

using:

dir("${SERVICE_DIR}") {
    sh 'mvn clean verify'
}

Test reports

Ensure actual JUnit tests exist so Surefire reports are generated.
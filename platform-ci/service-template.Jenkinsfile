pipeline {
    agent any

    parameters {
        string(name: 'SERVICE_NAME', defaultValue: 'auth-service',
               description: 'Service directory under services/, e.g. auth-service')
        choice(name: 'PLATFORM_ENVIRONMENT', choices: ['dev', 'staging', 'prod'],
               description: 'Environment configuration and resolved contract to validate')
        booleanParam(name: 'RUN_OWASP_SCAN', defaultValue: false,
                     description: 'Run OWASP Dependency Check')
    }

    environment {
        AWS_REGION = 'us-east-1'
        GITOPS_REPO = 'git@github.com:Oluwole-Faluwoye/enterprise-platform-gitops.git'
        SONARQUBE_ENV = 'sonarqube'
        SERVICE_DIR = ''
        IMAGE_NAME = ''
        IMAGE_TAG = ''
        RUNTIME_TYPE = ''
        RUNTIME_VERSION = ''
        BUILD_IMAGE = ''
        MIGRATION_ENABLED = 'false'
        MIGRATION_ENGINE = ''
        ACCOUNT_ID = ''
        ECR_REPO = ''
        ARTIFACT_BUCKET = ''
        DOCKERFILE_PATH = ''
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        ansiColor('xterm')
        timeout(time: 90, unit: 'MINUTES')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "Service: ${params.SERVICE_NAME}; environment: ${params.PLATFORM_ENVIRONMENT}"
                echo "Git commit: ${env.GIT_COMMIT}"
            }
        }

        stage('Validate Service Contract and Select Runtime') {
            steps {
                script {
                    if (!(params.SERVICE_NAME ==~ /^[a-z0-9]+(-[a-z0-9]+)*$/)) {
                        error("Invalid SERVICE_NAME '${params.SERVICE_NAME}'. Use lowercase letters, numbers, and hyphens.")
                    }

                    env.SERVICE_DIR = "services/${params.SERVICE_NAME}"
                    env.IMAGE_NAME = params.SERVICE_NAME
                    env.IMAGE_TAG = "${params.PLATFORM_ENVIRONMENT}-${params.SERVICE_NAME}-${env.GIT_COMMIT?.take(12) ?: env.BUILD_NUMBER}-${env.BUILD_NUMBER}"

                    if (!fileExists("${env.SERVICE_DIR}/platform.yaml")) {
                        error("Missing ${env.SERVICE_DIR}/platform.yaml.")
                    }

                    def runtimeType = sh(
                        script: "yq e -r '.runtime.type // \"\"' '${env.SERVICE_DIR}/platform.yaml'",
                        returnStdout: true
                    ).trim()
                    def runtimeVersion = sh(
                        script: "yq e -r '.runtime.version // \"\"' '${env.SERVICE_DIR}/platform.yaml'",
                        returnStdout: true
                    ).trim()
                    def migrationEnabled = sh(
                        script: "yq e -r '.migration.enabled // false' '${env.SERVICE_DIR}/platform.yaml'",
                        returnStdout: true
                    ).trim()
                    def migrationEngine = sh(
                        script: "yq e -r '.migration.engine // \"\"' '${env.SERVICE_DIR}/platform.yaml'",
                        returnStdout: true
                    ).trim()

                    if (!(runtimeType in ['spring-boot', 'nodejs'])) {
                        error("Unsupported runtime '${runtimeType}'. Supported: spring-boot, nodejs.")
                    }
                    if (!(runtimeVersion ==~ /^[0-9]+$/)) {
                        error("Invalid or missing runtime.version in ${env.SERVICE_DIR}/platform.yaml.")
                    }

                    
                    if (runtimeType == 'spring-boot') {
                        if (!(runtimeVersion in ['17', '21'])) {
                            error("Unsupported Java version '${runtimeVersion}'. Supported: 17, 21.")
                        }
                        if (!fileExists("${env.SERVICE_DIR}/pom.xml")) {
                            error("Spring Boot service must contain pom.xml.")
                        }

                        env.BUILD_IMAGE = "maven:3.9-eclipse-temurin-${runtimeVersion}"
                        env.DOCKERFILE_PATH =
                            "${env.WORKSPACE}/platform-runtimes/springboot/service-template/Dockerfile"

                    } else {
                        if (runtimeVersion != '22') {
                            error("Unsupported Node.js version '${runtimeVersion}'. Supported: 22.")
                        }
                        if (!fileExists("${env.SERVICE_DIR}/package.json") ||
                            !fileExists("${env.SERVICE_DIR}/package-lock.json")) {
                            error("Node.js service requires package.json and package-lock.json.")
                        }

                        env.BUILD_IMAGE = "node:${runtimeVersion}-alpine"
                        env.DOCKERFILE_PATH =
                            "${env.WORKSPACE}/platform-runtimes/nodejs/service-template/Dockerfile"
                    }

                    if (!fileExists(env.DOCKERFILE_PATH)) {
                        error("Canonical runtime Dockerfile not found: ${env.DOCKERFILE_PATH}")
                    }


                    if (!(migrationEnabled in ['true', 'false'])) {
                        error("migration.enabled must be true or false.")
                    }

                    if (migrationEnabled == 'true') {
                        if (migrationEngine != 'flyway') {
                            error("Unsupported migration engine '${migrationEngine}' for ${params.SERVICE_NAME}.")
                        }

                        def migrationDir = "${env.SERVICE_DIR}/src/main/resources/db/migration"
                        if (!fileExists(migrationDir)) {
                            error("Flyway is enabled but ${migrationDir} is missing. Add migrations or correct the service contract.")
                        }

                        def sqlCount = sh(
                            script: "find '${migrationDir}' -maxdepth 1 -type f -name '*.sql' | wc -l",
                            returnStdout: true
                        ).trim().toInteger()

                        if (sqlCount < 1) {
                            error("Flyway is enabled but no SQL files exist in ${migrationDir}.")
                        }
                    }

                    env.RUNTIME_TYPE = runtimeType
                    env.RUNTIME_VERSION = runtimeVersion
                    env.MIGRATION_ENABLED = migrationEnabled
                    env.MIGRATION_ENGINE = migrationEngine

                    echo "Runtime: ${runtimeType} ${runtimeVersion}; migration enabled: ${migrationEnabled}"
                }

                sh '''
                    set -euo pipefail
                    ./platform-ci/bin/platform validate "$SERVICE_DIR"
                '''
            }
        }

        stage('Build and Unit Tests') {
            agent {
                docker {
                    image "${env.BUILD_IMAGE}"
                    args '--network devops-network -v $HOME/.m2:/root/.m2'
                    reuseNode true
                }
            }
            steps {
                dir("${env.SERVICE_DIR}") {
                    script {
                        if (env.RUNTIME_TYPE == 'spring-boot') {
                            sh 'mvn -B clean verify'
                        } else {
                            sh '''
                                set -euo pipefail
                                npm ci
                                npm test --if-present
                            '''
                        }
                    }
                }
            }
            post {
                always {
                    script {
                        if (env.RUNTIME_TYPE == 'spring-boot') {
                            junit(
                                testResults: "${env.SERVICE_DIR}/target/surefire-reports/*.xml",
                                allowEmptyResults: true
                            )
                        }
                    }
                }
            }
        }

        stage('Platform Contract Tests') {
            agent {
                docker {
                    image "${env.BUILD_IMAGE}"
                    args '--network devops-network -v $HOME/.m2:/root/.m2'
                    reuseNode true
                }
            }
            steps {
                dir("${env.SERVICE_DIR}") {
                    script {
                        if (env.RUNTIME_TYPE == 'spring-boot') {
                            sh 'mvn -B -Dtest=PlatformContractTest test'
                        } else {
                            sh '''
                                set -euo pipefail
                                npm ci
                                npm run test:platform
                            '''
                        }
                    }
                }
            }
        }

        stage('SonarQube Analysis') {
            agent {
                docker {
                    image 'sonarsource/sonar-scanner-cli:5.0.1'
                    args '--network devops-network'
                    reuseNode true
                }
            }
            steps {
                withSonarQubeEnv("${env.SONARQUBE_ENV}") {
                    sh '''
                        set -euo pipefail
                        sonar-scanner \
                          -Dsonar.projectKey="$SERVICE_NAME" \
                          -Dsonar.projectName="$SERVICE_NAME" \
                          -Dsonar.sources="$SERVICE_DIR/src" \
                          -Dsonar.host.url="$SONAR_HOST_URL" \
                          -Dsonar.token="$SONAR_AUTH_TOKEN"
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('OWASP Dependency Check') {
            when {
                expression { return params.RUN_OWASP_SCAN }
            }
            options {
                timeout(time: 20, unit: 'MINUTES')
            }
            steps {
                withCredentials([
                    string(credentialsId: 'nvd-api-key', variable: 'NVD_API_KEY')
                ]) {
                    sh '''
                        set -euo pipefail
                        mkdir -p reports
                        docker run --rm \
                          -v "$WORKSPACE":/src \
                          -v /data/jenkins/dependency-check-data:/usr/share/dependency-check/data \
                          owasp/dependency-check:12.1.8 \
                          --nvdApiKey "$NVD_API_KEY" \
                          --scan "/src/$SERVICE_DIR" \
                          --format HTML \
                          --out /src/reports
                    '''
                }
            }
            post {
                always {
                    publishHTML([
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'reports',
                        reportFiles: 'dependency-check-report.html',
                        reportName: 'OWASP Dependency Check Report'
                    ])
                }
            }
        }

        stage('Trivy Filesystem Scan') {
            steps {
                sh '''
                    set -euo pipefail
                    docker run --rm \
                      -v "$WORKSPACE":/workspace \
                      -v /data/jenkins/trivy-cache:/root/.cache/trivy \
                      aquasec/trivy:0.65.0 \
                      fs --severity HIGH,CRITICAL "/workspace/$SERVICE_DIR"
                '''
            }
        }

        
        stage('Build Docker Image') {
            steps {
                sh '''
                    set -euo pipefail

                    echo "Runtime: $RUNTIME_TYPE $RUNTIME_VERSION"
                    echo "Dockerfile: $DOCKERFILE_PATH"
                    echo "Build context: $WORKSPACE/$SERVICE_DIR"

                    if [ "$RUNTIME_TYPE" = "spring-boot" ]; then
                        docker build \
                        --file "$DOCKERFILE_PATH" \
                        --build-arg JAVA_VERSION="$RUNTIME_VERSION" \
                        --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
                        "$WORKSPACE/$SERVICE_DIR"
                    else
                        docker build \
                        --file "$DOCKERFILE_PATH" \
                        --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
                        "$WORKSPACE/$SERVICE_DIR"
                    fi
                '''
            }
        }


        stage('Trivy Container Scan') {
            steps {
                sh '''
                    set -euo pipefail
                    docker run --rm \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      -v /data/jenkins/trivy-cache:/root/.cache/trivy \
                      aquasec/trivy:0.65.0 \
                      image --severity HIGH,CRITICAL --exit-code 1 \
                      "${IMAGE_NAME}:${IMAGE_TAG}"
                '''
            }
        }

        stage('Resolve Environment and AWS Identity') {
            steps {
                sshagent(['github-ssh']) {
                    script {
                        env.ACCOUNT_ID = sh(
                            script: 'aws sts get-caller-identity --query Account --output text',
                            returnStdout: true
                        ).trim()

                        if (!(env.ACCOUNT_ID ==~ /^[0-9]{12}$/)) {
                            error('Unable to resolve a valid AWS account ID from the active Jenkins AWS identity.')
                        }
                    }

                    sh '''
                        set -euo pipefail
                        ENV_DIR="$(mktemp -d)"
                        trap 'rm -rf "$ENV_DIR"' EXIT
                        git clone --depth 1 "$GITOPS_REPO" "$ENV_DIR/gitops"

                        PLATFORM_ENV_FILE="$ENV_DIR/gitops/platform/environments/${PLATFORM_ENVIRONMENT}.yaml"
                        if [ ! -f "$PLATFORM_ENV_FILE" ]; then
                            echo "ERROR: Environment config not found for $PLATFORM_ENVIRONMENT." >&2
                            exit 1
                        fi

                        ARTIFACT_BUCKET="$(yq e -r '.artifactStore.bucket // ""' "$PLATFORM_ENV_FILE")"
                        if [ -z "$ARTIFACT_BUCKET" ] || [ "$ARTIFACT_BUCKET" = "null" ]; then
                            echo "ERROR: artifactStore.bucket is missing." >&2
                            exit 1
                        fi

                        printf '%s' "$ARTIFACT_BUCKET" > "$WORKSPACE/.artifact_bucket"
                        echo "Environment configuration validated: $PLATFORM_ENVIRONMENT"
                    '''

                    script {
                        env.ARTIFACT_BUCKET = readFile('.artifact_bucket').trim()
                        env.ECR_REPO = "${env.ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com/enterprise-platform"
                    }
                }
            }
        }

        stage('Login to ECR') {
            steps {
                sh '''
                    set -euo pipefail
                    aws ecr get-login-password --region "$AWS_REGION" |
                      docker login --username AWS --password-stdin \
                        "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                '''
            }
        }

        stage('Push Image to ECR') {
            steps {
                sh '''
                    set -euo pipefail
                    docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${ECR_REPO}:${IMAGE_TAG}"
                    docker push "${ECR_REPO}:${IMAGE_TAG}"
                '''
            }
        }

        stage('Package and Upload Flyway Migrations') {
            when {
                expression { return env.MIGRATION_ENABLED == 'true' }
            }
            steps {
                sh '''
                    set -euo pipefail
                    ARTIFACT_BUCKET="$(cat "$WORKSPACE/.artifact_bucket")"
                    MIGRATION_DIR="$SERVICE_DIR/src/main/resources/db/migration"
                    MIGRATION_KEY="$IMAGE_NAME/migrations/$GIT_COMMIT/db/migration"
                    MIGRATION_S3_URI="s3://$ARTIFACT_BUCKET/$MIGRATION_KEY"

                    test -d "$MIGRATION_DIR"
                    find "$MIGRATION_DIR" -maxdepth 1 -type f -name '*.sql' -print -quit | grep -q .
                    aws s3 sync "$MIGRATION_DIR/" "$MIGRATION_S3_URI/" --exclude "*" --include "*.sql"
                    echo "Migration artifacts uploaded for $SERVICE_NAME."
                '''
            }
        }


        stage('GitOps Reconciliation and Publish') {
            steps {
                sshagent(['github-ssh']) {
                    sh '''
                        set -euo pipefail

                        PLATFORM_CLI="$WORKSPACE/platform-ci/bin/platform"
                        ARTIFACT_BUCKET="$(cat "$WORKSPACE/.artifact_bucket")"
                        TMP_ROOT="$(mktemp -d)"
                        trap 'rm -rf "$TMP_ROOT"' EXIT

                        CONTRACT_FILE="$TMP_ROOT/gitops-service-contract.json"
                        GITOPS_WORKTREE="$TMP_ROOT/gitops"

                        aws s3 cp \
                          "s3://$ARTIFACT_BUCKET/platform-contract/$PLATFORM_ENVIRONMENT/gitops-service-contract.json" \
                          "$CONTRACT_FILE"

                        jq empty "$CONTRACT_FILE"

                        jq -e --arg service "$SERVICE_NAME" '
                          (if has("services") then .services else . end)
                          | has($service)
                        ' "$CONTRACT_FILE" >/dev/null || {
                          echo "ERROR: $SERVICE_NAME is missing from the resolved contract." >&2
                          exit 1
                        }

                        CONTRACT_MIGRATION_ENABLED="$(jq -r --arg service "$SERVICE_NAME" '
                          (if has("services") then .services else . end)
                          | .[$service].migration.enabled // false
                        ' "$CONTRACT_FILE")"

                        git clone "$GITOPS_REPO" "$GITOPS_WORKTREE"

                        test "$(git -C "$GITOPS_WORKTREE" branch --show-current)" = "main" || {
                          echo "ERROR: GitOps checkout is not on main." >&2
                          exit 1
                        }

                        run_reconciliation() {
                          MODE="$1"

                          set -- "$PLATFORM_CLI" reconcile-gitops \
                            "$CONTRACT_FILE" "$GITOPS_WORKTREE" \
                            "$MODE" \
                            --service "$SERVICE_NAME" \
                            --image-tag "$IMAGE_TAG" \
                            --image-repository "$ECR_REPO" \
                            --environment "$PLATFORM_ENVIRONMENT"

                          if [ "$CONTRACT_MIGRATION_ENABLED" = "true" ]; then
                            MIGRATION_KEY="$SERVICE_NAME/migrations/$GIT_COMMIT/db/migration"
                            set -- "$@" --migration-artifact-key "$MIGRATION_KEY"
                          fi

                          "$@"
                        }

                        echo "=== Step 1: Validate with dry run ==="
                        run_reconciliation --dry-run

                        if [ -n "$(git -C "$GITOPS_WORKTREE" status --porcelain)" ]; then
                          echo "ERROR: Dry run unexpectedly changed GitOps files." >&2
                          git -C "$GITOPS_WORKTREE" status --short
                          exit 1
                        fi

                        echo "=== Step 2: Generate GitOps files ==="
                        run_reconciliation --write


                        echo "=== Step 3: Verify the generated changes ==="

                        git -C "$GITOPS_WORKTREE" status --short
                        git -C "$GITOPS_WORKTREE" diff --check

                        # Stage only the selected service's GitOps files.
                        git -C "$GITOPS_WORKTREE" add -- \
                          "applications/$SERVICE_NAME.yaml" \
                          "charts/$SERVICE_NAME"

                        # Verify the staged changes are restricted to this service.
                        STAGED_FILES="$(git -C "$GITOPS_WORKTREE" diff --cached --name-only)"

                        if [ -z "$STAGED_FILES" ]; then
                          echo "No GitOps changes needed; nothing to commit."
                          exit 0
                        fi

                        while IFS= read -r path; do
                          case "$path" in
                            "applications/$SERVICE_NAME.yaml" | \
                            "charts/$SERVICE_NAME/"* )
                              ;;
                            * )
                              echo "ERROR: Unexpected staged GitOps change: $path" >&2
                              exit 1
                              ;;
                          esac
                        done <<EOF
$STAGED_FILES
EOF

                        echo "Staged GitOps changes:"
                        printf '%s\n' "$STAGED_FILES"

                        git -C "$GITOPS_WORKTREE" diff --cached --check
                        git -C "$GITOPS_WORKTREE" diff --cached -- \
                          "applications/$SERVICE_NAME.yaml" \
                          "charts/$SERVICE_NAME"

                        echo "=== Step 4: Commit and push ==="

                        git -C "$GITOPS_WORKTREE" config user.name "Enterprise Platform CI"
                        git -C "$GITOPS_WORKTREE" config user.email "enterprise-platform-ci@users.noreply.github.com"

                        git -C "$GITOPS_WORKTREE" commit \
                          -m "Reconcile $SERVICE_NAME for $PLATFORM_ENVIRONMENT"

                        git -C "$GITOPS_WORKTREE" push origin HEAD:main

                        echo "GitOps reconciliation and publish completed."

                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Service pipeline completed for ${params.SERVICE_NAME} in ${params.PLATFORM_ENVIRONMENT}."
        }
        failure {
            echo "Service pipeline failed for ${params.SERVICE_NAME} in ${params.PLATFORM_ENVIRONMENT}."
        }
        always {
            archiveArtifacts(artifacts: 'reports/**/*.*', allowEmptyArchive: true)
            cleanWs()
        }
    }
}

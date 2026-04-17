@Library('bcai_jenkins_lib') _

pipeline {
    agent any
     environment {
        BLOCKCHAIN_API_KEY = credentials('blockchain-api-key')
        BLOCKCHAIN_URL     = 'http://159.223.49.53:3000/api/v1'
    }

    stages {
         stage('Check Backend') {
            steps {
                sh '''
                    response=$(curl -s -o /dev/null -w "%{http_code}" \
                        ${BLOCKCHAIN_URL}/health)
                    if [ "$response" != "200" ]; then
                        echo "Backend unreachable!"
                        exit 1
                    fi
                '''
            }
        }
    
        stage('Clone Repo') {
            steps {
            
                git branch: 'main', url: 'https://github.com/AnuradhaGP/Demo-app.git'
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'npm install'
            }
        }

        stage('OSV Scan') {
            steps {
                sh '''
                docker run --rm -v $(pwd):/src ghcr.io/google/osv-scanner \
                --recursive /src --format=json > osv-report.json

                cat osv-report.json

                docker run --rm -v $(pwd):/src ghcr.io/google/osv-scanner \
                --recursive /src --exit-code=1
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t demo-app .'
            }
        }

         stage('Hash Artifact') {
            steps {
                script {
                    def artifactHash = sh(
                        script: "docker inspect --format='{{.Id}}' demo-app | sed 's/sha256://'",
                        returnStdout: true
                    ).trim()

                    env.ARTIFACT_HASH = artifactHash
                    env.BUILD_ID_BC   = "Build_#${BUILD_NUMBER}"

                    echo "Artifact Hash: ${artifactHash}"
                }
            }
        }

        stage('Verify Before Deploy') {
            steps {
                script {
                    def currentHash = sh(
                        script: "docker inspect --format='{{.Id}}' demo-app | sed 's/sha256://'",
                        returnStdout: true
                    ).trim()

                    if (currentHash != env.ARTIFACT_HASH) {
                        error("TAMPER DETECTED locally! Hashes don't match.")
                    }

                    echo "Artifact verified. Proceeding to deploy."
                }
            }
        }

        stage('Run Container') {
            steps {
                 sh '''
                docker stop demo-app-container || true
                docker rm demo-app-container || true
                sleep 3
                docker run -d -p 3000:3000 --name demo-app-container demo-app || \
                (docker rm -f demo-app-container && docker run -d -p 3000:3000 --name demo-app-container demo-app)
                '''
                }
        }

    }
    post {
        always {
            blockchainHandler(
                blockchainUrl: env.BLOCKCHAIN_URL,
                apiKey       : env.BLOCKCHAIN_API_KEY,
                buildId      : env.BUILD_ID_BC,
                artifactHash : env.ARTIFACT_HASH
            )
        }
    }

}

     
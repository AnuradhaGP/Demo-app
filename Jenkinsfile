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

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t demo-app .'
            }
        }

        stage('Hash Artifact') {
            steps {
                script {
                    sh 'docker save demo-app -o artifact.tar'

                    def artifactHash = sh(
                        script: 'sha256sum artifact.tar | awk \'{print $1}\'',
                        returnStdout: true
                    ).trim()

                    // Next stages වලට pass කරන්න env එකේ save
                    env.ARTIFACT_HASH = artifactHash
                    env.BUILD_ID_BC   = "demo-app-${BUILD_NUMBER}"

                    echo "Artifact Hash: ${artifactHash}"
                }
            }
            post {
                always { sh 'rm -f artifact.tar' }
            }
        }

        stage('Verify Before Deploy') {
            steps {
                script {
                    // Verify stage වෙලාවේ log තාම incomplete
                    // artifact hash verify විතරක් මෙතනදී
                    sh 'docker save demo-app -o verify-artifact.tar'

                    def currentHash = sh(
                        script: 'sha256sum verify-artifact.tar | awk \'{print $1}\'',
                        returnStdout: true
                    ).trim()

                    if (currentHash != env.ARTIFACT_HASH) {
                        error("TAMPER DETECTED locally! Hashes don't match.")
                    }

                    echo "Artifact hash matches. Proceeding to deploy."
                }
            }
            post {
                always { sh 'rm -f verify-artifact.tar' }
            }
        }

        stage('Run Container') {
            steps {
                 sh '''
                    docker stop demo-app-container || true
                    docker rm demo-app-container || true
                    docker run -d -p 3000:3000 --name demo-app-container demo-app
                '''
            }
        }
    }

       post {
        always {
            script {
                try {
                    // 1. Full log capture - pipeline ඉවර නිසා complete log
                    def logContent = currentBuild.rawBuild
                        .getLog(Integer.MAX_VALUE).join('\n')

                    // 2. Log → backend → encrypt → Pinata
                    def logResponse = sh(
                        script: """
                            curl -s -X POST ${BLOCKCHAIN_URL}/log/upload \\
                                -H "Content-Type: application/json" \\
                                -H "x-api-key: ${BLOCKCHAIN_API_KEY}" \\
                                -d '${groovy.json.JsonOutput.toJson([
                                    logContent: logContent,
                                    buildId   : env.BUILD_ID_BC
                                ])}'
                        """,
                        returnStdout: true
                    ).trim()

                    def logJson = readJSON text: logResponse
                    def logCid  = logJson.logCid
                    def logHash = logJson.logHash

                    echo "Log CID: ${logCid}"
                    echo "Log Hash: ${logHash}"

                    // 3. Blockchain record - artifact hash + log hash + log cid
                    def recordResponse = sh(
                        script: """
                            curl -s -X POST ${BLOCKCHAIN_URL}/record \\
                                -H "Content-Type: application/json" \\
                                -H "x-api-key: ${BLOCKCHAIN_API_KEY}" \\
                                -d '${groovy.json.JsonOutput.toJson([
                                    buildId     : env.BUILD_ID_BC,
                                    buildBy     : 'jenkins',
                                    artifactHash: env.ARTIFACT_HASH,
                                    logHash     : logHash,
                                    logCid      : logCid
                                ])}'
                        """,
                        returnStdout: true
                    ).trim()

                    def recordJson = readJSON text: recordResponse
                    if (recordJson.status != 'Success') {
                        echo "WARNING: Blockchain record failed: ${recordJson.error}"
                    } else {
                        echo "Build recorded on blockchain."
                    }

                    // 4. Full verify - artifact + log දෙකම
                    def verifyResponse = sh(
                        script: """
                            curl -s -X POST ${BLOCKCHAIN_URL}/verify \\
                                -H "Content-Type: application/json" \\
                                -H "x-api-key: ${BLOCKCHAIN_API_KEY}" \\
                                -d '${groovy.json.JsonOutput.toJson([
                                    buildId             : env.BUILD_ID_BC,
                                    currentArtifactHash : env.ARTIFACT_HASH,
                                    currentLogHash      : logHash
                                ])}'
                        """,
                        returnStdout: true
                    ).trim()

                    def verifyJson = readJSON text: verifyResponse
                    if (verifyJson.status == 'VERIFIED') {
                        echo "Artifact + Log verified on blockchain."
                    } else {
                        echo "WARNING: Verification failed: ${verifyJson.error}"
                    }

                } catch (Exception e) {
                    echo "Post-build blockchain record failed: ${e.message}"
                }
            }
        }
    }
}
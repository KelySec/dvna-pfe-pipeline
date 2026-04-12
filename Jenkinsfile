pipeline {
    agent any

    environment {
        APP_URL = "http://localhost:9090"
    }

    stages {

        stage('1 - Secrets Scanning (Gitleaks)') {
            steps {
                echo '=== Scan des secrets hardcodes ==='
                bat '''
                    D:\\DevSecOps\\tools\\gitleaks\\gitleaks.exe detect --source . --config .gitleaks.toml --no-git -v || exit 0
                '''
            }
        }

        stage('2 - SAST (Semgrep)') {
            steps {
                echo '=== Analyse statique du code ==='
                bat '''
                    chcp 65001
                    if not exist semgrep-report mkdir semgrep-report
                    docker run --rm -v "%CD%:/src" -e SEMGREP_FORCE_COLOR=0 -e NO_COLOR=1 returntocorp/semgrep semgrep --config=p/nodejs --config=p/security-audit --json /src/server.js --output /src/semgrep-report/semgrep-report.json || exit 0
                '''
                script {
                    def json = readFile('semgrep-report/semgrep-report.json')
                    def data = readJSON text: json
                    def results = data.results
                    def html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Semgrep SAST Report</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 30px; background: #f5f5f5; }
                h1 { color: #333; }
                .summary { background: #fff; padding: 15px; border-radius: 8px; margin-bottom: 20px; border-left: 5px solid #e74c3c; }
                .finding { background: #fff; padding: 15px; margin: 10px 0; border-radius: 8px; border-left: 5px solid #e67e22; }
                .finding h3 { margin: 0 0 8px 0; color: #e74c3c; }
                .finding p { margin: 4px 0; color: #555; }
                .badge { display: inline-block; padding: 3px 10px; border-radius: 12px; font-size: 12px; font-weight: bold; }
                .WARNING { background: #f39c12; color: white; }
                .ERROR { background: #e74c3c; color: white; }
                code { background: #f0f0f0; padding: 2px 6px; border-radius: 4px; font-size: 13px; }
            </style>
        </head>
        <body>
            <h1>Semgrep SAST Report — DVNA</h1>
            <div class="summary">
                <strong>Total findings : ${results.size()}</strong> — Tous bloquants
            </div>
        """
                    results.each { r ->
                        def severity = r.extra?.severity ?: 'WARNING'
                        def message  = r.extra?.message  ?: 'No message'
                        def file     = r.path ?: 'unknown'
                        def line     = r.start?.line ?: '?'
                        def ruleId   = r.check_id ?: 'unknown'
                        html += """
            <div class="finding">
                <h3><span class="badge ${severity}">${severity}</span> &nbsp; ${ruleId}</h3>
                <p><strong>Fichier :</strong> <code>${file}</code> — ligne <code>${line}</code></p>
                <p><strong>Message :</strong> ${message}</p>
            </div>
        """
                    }
                    html += "</body></html>"
                    writeFile file: 'semgrep-report/semgrep-report.html', text: html
                }
            }
            post {
                always {
                    publishHTML([
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'semgrep-report',
                        reportFiles: 'semgrep-report.html',
                        reportName: 'Semgrep SAST Report'
                    ])
                }
            }
        }
        
        stage('3 - SCA (npm audit)') {
            steps {
                echo '=== Analyse des dependances ==='
                bat 'npm audit --audit-level=critical || exit 0'
            }
        }


        stage('4 - Container Scan (Trivy)') {
            steps {
                echo '=== Scan de l image Docker ==='
                bat '''
                    docker build -t dvna-pfe:pipeline .
                    docker run --rm -v //var/run/docker.sock://var/run/docker.sock ghcr.io/aquasecurity/trivy:latest image --severity HIGH,CRITICAL dvna-pfe:pipeline || exit 0
                '''
            }
        }


        stage('5 - IaC Security (Checkov)') {
            steps {
                echo '=== Analyse IaC Dockerfile ==='
                bat '''
                    docker run --rm -v "%CD%:/workspace" bridgecrew/checkov:2.3.0 -f /workspace/Dockerfile --framework dockerfile || exit 0
                '''
            }
        }

        stage('6 - Run App for DAST') {
            steps {
                echo '=== Demarrage de l application pour ZAP ==='
                bat '''
                    docker rm -f dvna-pfe-app 2>nul || exit 0
                    docker run -d --name dvna-pfe-app -p 9090:9090 dvna-pfe:pipeline
                '''
            }
        }

        stage('7 - DAST (OWASP ZAP)') {
            steps {
                echo '=== Test dynamique de l application ==='
                bat '''
                    if not exist zap-report mkdir zap-report
                    docker run --rm --add-host=host.docker.internal:host-gateway -v "%CD%\\zap-report:/zap/wrk" ghcr.io/zaproxy/zaproxy:stable zap-baseline.py -t http://host.docker.internal:9090 -r zap-pipeline.html -I || exit 0
                '''
            }
        }
    }

    post {
        always {
            echo '=== Pipeline DevSecOps termine ==='
            bat 'docker rm -f dvna-pfe-app 2>nul || exit 0'
        }
        success {
            echo '=== Tous les scans executes avec succes ==='
        }
        failure {
            echo '=== Des erreurs ont ete detectees ==='
        }
    }
}

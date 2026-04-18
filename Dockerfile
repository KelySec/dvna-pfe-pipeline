# DVNA-PFE — Dockerfile VULNERABLE (intentionnel)
# Cibles : Trivy (CVEs image), Checkov (misconfigurations)

# VULN-Trivy : image non epinglee avec CVEs dans les paquets OS
FROM node:18

# VULN-Checkov CKV_DOCKER_2 : pas de HEALTHCHECK
# VULN-Checkov CKV_DOCKER_8 : pas d'USER non-root (tourne en root)

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 9090

# Pas de USER -> tourne en root
# Pas de HEALTHCHECK -> Checkov alerte
CMD ["node", "server.js"]
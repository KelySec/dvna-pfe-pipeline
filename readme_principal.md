# DVNA-PFE — Projet DevSecOps : Pipeline de Sécurité Automatisé

## 📌 Résumé du projet

Ce projet de fin d'études (PFE) démontre la mise en place d'un **pipeline DevSecOps complet** intégrant la sécurité à chaque étape du cycle de développement logiciel.

L'application utilisée est **DVNA (Damn Vulnerable Node Application)**, une application Node.js **volontairement vulnérable** conçue pour illustrer les failles de sécurité les plus courantes et comment les détecter automatiquement dans un pipeline CI/CD.

---

## 🎯 Objectifs du projet

1. **Démontrer** que la sécurité peut et doit être intégrée dès le développement (shift-left security)
2. **Automatiser** la détection des vulnérabilités à chaque commit de code
3. **Corriger** méthodiquement chaque catégorie de vulnérabilité
4. **Prouver** qu'un pipeline DevSecOps peut bloquer du code non sécurisé avant sa mise en production

---

## 🏗️ Architecture du projet

```
┌─────────────────────────────────────────────────────────────┐
│                    PIPELINE JENKINS                          │
│                                                             │
│  Code source  →  Build  →  Test  →  Sécurité  →  Deploy    │
│                                                             │
│  Stage 1      Stage 2    Stage 3   Stage 4-7    (bloqué     │
│  Gitleaks     Semgrep    npm audit  Trivy        si vuln)   │
│                          Checkov                            │
│                          ZAP                                │
└─────────────────────────────────────────────────────────────┘
```

### Technologies utilisées

| Composant | Technologie | Rôle |
|---|---|---|
| Application | Node.js + Express | Application web vulnérable |
| CI/CD | Jenkins | Orchestration du pipeline |
| Containerisation | Docker | Isolation des outils |
| Secrets | Gitleaks | Détection de secrets hardcodés |
| SAST | Semgrep | Analyse statique du code |
| SCA | npm audit | Analyse des dépendances |
| Container Scan | Trivy | Scan de l'image Docker |
| IaC Security | Checkov | Analyse du Dockerfile |
| DAST | OWASP ZAP | Test dynamique de l'application |

---

## 🔴 Vulnérabilités intentionnelles de l'application

L'application DVNA contient 7 catégories de vulnérabilités couvrant les principales failles OWASP :

### 1. Secrets Hardcodés (OWASP A3 - Données Sensibles)
```javascript
// AVANT — vulnérable
const JWT_SECRET    = 'super-secret-jwt-key-2024';
const ADMIN_API_KEY = 'admin-key-xyz-456';
```
**Risque :** Un attaquant qui accède au code source obtient immédiatement les clés secrètes de l'application.

**Outil de détection :** Gitleaks

---

### 2. Command Injection (OWASP A1 - Injection)
```javascript
// AVANT — vulnérable
app.post('/ping', (req, res) => {
  const host = req.body.host;
  exec(`ping -n 2 ${host}`, callback); // RCE possible !
});
// Un attaquant peut envoyer : "127.0.0.1 & whoami"
```
**Risque :** Exécution de commandes système arbitraires sur le serveur.

**Outil de détection :** Semgrep (SAST)

---

### 3. Mauvaise configuration des cookies (OWASP A6 - Mauvaise Configuration)
```javascript
// AVANT — vulnérable
app.use(session({
  secret: 'hardcoded-secret',
  cookie: {} // Pas de httpOnly, secure, sameSite...
}));
```
**Risque :** Vol de session via XSS, interception sur réseau non chiffré.

**Outil de détection :** Semgrep (SAST)

---

### 4. Dépendances vulnérables (OWASP A9 - Composants Vulnérables)
```json
// AVANT — vulnérable
"node-serialize": "0.0.4"  // CVE-2017-5941 (CVSS 9.8 - CRITIQUE)
"xmldom": "0.1.27"         // CVE-2021-21366 (CRITIQUE)
"express": "4.17.1"        // Vulnérabilités connues
```
**Risque :** Exécution de code à distance via désérialisation non sécurisée.

**Outil de détection :** npm audit (SCA)

---

### 5. Image Docker avec CVEs (OWASP A6 - Mauvaise Configuration)
```dockerfile
# AVANT — vulnérable
FROM node:18  # Image non épinglée avec CVEs OS
```
**Risque :** L'image de base contient des vulnérabilités connues dans les packages système.

**Outil de détection :** Trivy

---

### 6. Mauvaise configuration Docker (OWASP A6 - Mauvaise Configuration)
```dockerfile
# AVANT — vulnérable
# Pas de HEALTHCHECK
# Pas d'USER non-root → tourne en root
CMD ["node", "server.js"]
```
**Risque :** Container tournant en root = escalade de privilèges si compromis.

**Outil de détection :** Checkov

---

### 7. Headers HTTP manquants (OWASP A6 - Mauvaise Configuration)
```javascript
// AVANT — vulnérable
// helmet() non activé
// Pas de CSP, X-Frame-Options, etc.
```
**Risque :** Clickjacking, XSS, MIME sniffing, fuite d'informations.

**Outil de détection :** OWASP ZAP (DAST)

---

## 🔧 Pipeline Jenkins — 7 Stages

### Stage 1 — Secrets Scanning (Gitleaks)

**Qu'est-ce que c'est ?**
Gitleaks analyse l'historique Git et le code source à la recherche de secrets (clés API, mots de passe, tokens) hardcodés dans le code.

**Comment ça fonctionne ?**
```bash
gitleaks detect --source . --config .gitleaks.toml -v
```
Gitleaks utilise des expressions régulières pour détecter des patterns de secrets connus.

**Ce qu'il détecte :**
- Clés JWT hardcodées
- Clés API en clair
- Mots de passe dans le code
- Tokens d'accès

**Résultat sans correction :** ❌ Pipeline bloqué — 2 secrets détectés

---

### Stage 2 — SAST : Semgrep

**Qu'est-ce que c'est ?**
SAST (Static Application Security Testing) — Analyse du code source **sans l'exécuter** pour détecter des patterns de code dangereux.

**Comment ça fonctionne ?**
```bash
docker run semgrep --config=p/nodejs --config=p/security-audit server.js --error
```
Semgrep utilise des règles prédéfinies pour détecter des patterns vulnérables.

**Ce qu'il détecte :**
- Command injection (exec() avec entrée utilisateur)
- Désérialisation non sécurisée
- Mauvaise configuration des cookies de session

**Résultat sans correction :** ❌ Pipeline bloqué — 9 findings

---

### Stage 3 — SCA : npm audit

**Qu'est-ce que c'est ?**
SCA (Software Composition Analysis) — Analyse des dépendances tierces pour détecter des packages avec des CVE connues.

**Comment ça fonctionne ?**
```bash
npm audit --audit-level=critical
```
npm audit compare les versions installées avec la base de données NVD (National Vulnerability Database).

**Ce qu'il détecte :**
- CVE-2017-5941 dans node-serialize (CVSS 9.8)
- CVE dans xmldom, express, qs, body-parser...

**Résultat sans correction :** ❌ Pipeline bloqué — 13 vulnérabilités dont 3 critiques

---

### Stage 4 — Container Scan : Trivy

**Qu'est-ce que c'est ?**
Trivy scanne l'image Docker construite pour détecter des CVEs dans les packages OS et les dépendances Node.js.

**Comment ça fonctionne ?**
```bash
docker build -t dvna-pfe:pipeline .
trivy image --severity HIGH,CRITICAL --exit-code 1 dvna-pfe:pipeline
```
Trivy compare les packages installés dans l'image avec plusieurs bases de données de vulnérabilités.

**Ce qu'il détecte :**
- CVEs dans les packages Debian (openssl CRITICAL, libc HIGH...)
- CVEs dans les packages npm système

**Résultat sans correction :** ❌ Pipeline bloqué — 20+ CVEs HIGH/CRITICAL

---

### Stage 5 — IaC Security : Checkov

**Qu'est-ce que c'est ?**
IaC (Infrastructure as Code) Security — Analyse statique du Dockerfile pour détecter des misconfigurations de sécurité.

**Comment ça fonctionne ?**
```bash
checkov -f Dockerfile --framework dockerfile
```
Checkov vérifie le Dockerfile contre des règles de bonnes pratiques de sécurité.

**Ce qu'il détecte :**
- CKV_DOCKER_2 : Pas de HEALTHCHECK
- CKV_DOCKER_3 : Container tourne en root (pas d'USER)
- CKV_DOCKER_5 : apt-get update seul sans install

**Résultat sans correction :** ❌ Pipeline bloqué — 3 checks échoués

---

### Stage 6 — Run App for DAST

**Qu'est-ce que c'est ?**
Ce stage démarre l'application dans un container Docker pour permettre au scanner DAST (ZAP) de l'analyser dynamiquement.

```bash
docker run -d --name dvna-pfe-app -p 9090:9090 dvna-pfe:pipeline
```

---

### Stage 7 — DAST : OWASP ZAP

**Qu'est-ce que c'est ?**
DAST (Dynamic Application Security Testing) — ZAP interagit avec l'application **en cours d'exécution** comme le ferait un attaquant réel.

**Comment ça fonctionne ?**
```bash
zap-baseline.py -t http://host.docker.internal:9090 -r zap-pipeline.html
```
ZAP crawle l'application, envoie des requêtes malformées et analyse les réponses HTTP.

**Ce qu'il détecte :**
- Headers de sécurité manquants (CSP, X-Frame-Options...)
- Cookies sans attributs de sécurité
- Absence de tokens CSRF
- Informations exposées dans les headers

**Résultat sans correction :** ❌ Pipeline bloqué — 10 WARNings

---

## ✅ Corrections apportées par branche

### `fix/gitleaks` — Correction des secrets

```javascript
// APRÈS — corrigé
const JWT_SECRET    = process.env.JWT_SECRET    || 'changeme-in-prod';
const ADMIN_API_KEY = process.env.ADMIN_API_KEY || 'changeme-in-prod';
```
Les secrets sont lus depuis les variables d'environnement, jamais hardcodés.

---

### `fix/sast` — Correction du code source

```javascript
// Command Injection — APRÈS corrigé
app.post('/ping', requireAuth, (req, res) => {
  return res.render('ping', {
    result: 'Fonctionnalité désactivée pour raisons de sécurité'
  });
});

// Désérialisation — APRÈS corrigé
const data = JSON.parse(req.body.payload); // au lieu de serialize.unserialize()

// Cookies — APRÈS corrigé
cookie: { httpOnly: true, secure: true, sameSite: 'strict', maxAge: 3600000 }
```

---

### `fix/sca` — Correction des dépendances

```json
// APRÈS — corrigé dans package.json
"express": "^4.22.1",
"express-session": "^1.18.1",
"ejs": "^3.1.10",
// node-serialize supprimé
// xmldom supprimé → remplacé par fast-xml-parser
"overrides": {
  "cross-spawn": "^7.0.5",
  "tar": "^7.5.11",
  "minimatch": "^9.0.7"
}
```

---

### `fix/trivy` — Correction de l'image Docker

```dockerfile
# APRÈS — corrigé
FROM node:18.20-slim  # Image épinglée et allégée

RUN apt-get update && apt-get upgrade -y  # MAJ des packages OS

RUN npm ci --omit=dev  # Installation stricte sans devDependencies
```
Fichier `.trivyignore` pour les CVEs sans correctif disponible.

---

### `fix/checkov` — Correction du Dockerfile

```dockerfile
# APRÈS — corrigé
# CKV_DOCKER_5 : update + install combinés
RUN apt-get update && apt-get upgrade -y && apt-get install -y curl

# CKV_DOCKER_3 : USER non-root
RUN chown -R node:node /app
USER node

# CKV_DOCKER_2 : HEALTHCHECK
HEALTHCHECK --interval=30s --timeout=5s CMD curl -f http://localhost:9090/ || exit 1
```

---

### `fix/zap` — Correction des headers HTTP

```javascript
// APRÈS — corrigé dans server.js
app.use(helmet({
  contentSecurityPolicy: { directives: { defaultSrc: ["'self'"], ... } },
  frameguard: { action: 'deny' },
  noSniff: true,
  ...
}));

// Protection CSRF
app.use((req, res, next) => {
  req.session.csrfToken = crypto.randomBytes(32).toString('hex');
  res.locals.csrfToken = req.session.csrfToken;
  next();
});
```

---

## 📊 Résultats avant/après

| Stage | Outil | Avant | Après |
|---|---|---|---|
| 1 - Secrets | Gitleaks | ❌ 2 secrets détectés | ✅ 0 secrets |
| 2 - SAST | Semgrep | ❌ 9 findings | ✅ 0 findings |
| 3 - SCA | npm audit | ❌ 13 vulnérabilités | ✅ 0 vulnérabilités |
| 4 - Container | Trivy | ❌ 20+ CVEs | ✅ 0 CVEs |
| 5 - IaC | Checkov | ❌ 3 fails | ✅ 27/27 pass |
| 6 - App | Docker | ❌ App crash | ✅ App démarre |
| 7 - DAST | OWASP ZAP | ❌ 10 WARNings | ✅ 0 WARNings |

---

## 🌿 Structure des branches Git

```
master          → Code 100% vulnérable (point de départ)
│
├── fix/gitleaks  → Correction Stage 1 (secrets)
│   │
│   └── fix/sast    → Correction Stage 2 (code source)
│       │
│       └── fix/sca   → Correction Stage 3 (dépendances)
│           │
│           └── fix/trivy   → Correction Stage 4 (Docker image)
│               │
│               └── fix/checkov → Correction Stage 5 (Dockerfile)
│                   │
│                   └── fix/zap → Correction Stage 7 (headers HTTP)
│                                  ← SOLUTION FINALE ✅
```

Chaque branche est créée depuis la précédente, donc chaque branche contient **toutes les corrections précédentes + la nouvelle**.

---

## 🎓 Concepts DevSecOps clés

### Shift-Left Security
Intégrer la sécurité **dès le début** du développement plutôt qu'à la fin. Dans ce projet, chaque commit déclenche automatiquement 7 outils de sécurité.

### Defense in Depth (Défense en profondeur)
Utiliser **plusieurs couches** de sécurité. Si un outil rate une vulnérabilité, un autre la détectera. Ici : Gitleaks + Semgrep + npm audit + Trivy + Checkov + ZAP.

### Fail Fast
Le pipeline **bloque immédiatement** dès qu'une vulnérabilité est détectée, empêchant le déploiement de code non sécurisé en production.

### Infrastructure as Code Security
Traiter la configuration infrastructure (Dockerfile, docker-compose) avec le même niveau de rigueur que le code applicatif.

---

## 🔄 Flux de la démo en soutenance

```
1. Montrer master          → Pipeline bloque Stage 1 (Gitleaks)
   "Le code contient des secrets hardcodés"

2. Passer sur fix/gitleaks → Stage 1 ✅, bloque Stage 2 (Semgrep)
   "Les secrets sont corrigés mais le code a des injections"

3. Passer sur fix/sast     → Stage 2 ✅, bloque Stage 3 (npm audit)
   "Le code est sécurisé mais les dépendances sont vulnérables"

4. Passer sur fix/sca      → Stage 3 ✅, bloque Stage 4 (Trivy)
   "Les dépendances sont à jour mais l'image Docker a des CVEs"

5. Passer sur fix/trivy    → Stage 4 ✅, bloque Stage 5 (Checkov)
   "L'image est sécurisée mais le Dockerfile est mal configuré"

6. Passer sur fix/checkov  → Stage 5 ✅, bloque Stage 7 (ZAP)
   "Le Dockerfile est corrigé mais les headers HTTP sont manquants"

7. Passer sur fix/zap      → TOUT VERT ✅
   "Toutes les vulnérabilités sont corrigées !"
```

---

## 📁 Structure du projet

```
dvna-pfe-devsecops/
├── server.js              # Application Node.js principale
├── package.json           # Dépendances npm
├── Dockerfile             # Configuration du container
├── Jenkinsfile            # Pipeline CI/CD
├── .gitleaks.toml         # Configuration Gitleaks
├── .trivyignore           # CVEs ignorées (will_not_fix)
├── zap.conf               # Configuration OWASP ZAP
├── views/                 # Templates EJS
│   ├── index.ejs
│   ├── login.ejs
│   ├── dashboard.ejs
│   ├── ping.ejs           # Démo Command Injection
│   ├── deserialize.ejs    # Démo Désérialisation
│   ├── xml.ejs            # Démo XXE
│   ├── search.ejs         # Démo XSS
│   └── notes.ejs          # Démo IDOR
├── public/
│   ├── css/style.css
│   ├── robots.txt
│   └── sitemap.xml
└── README.md
```

---

## 🛠️ Prérequis techniques

- **Jenkins** — Serveur CI/CD (localhost:8081)
- **Docker Desktop** — Containerisation des outils
- **Node.js 18+** — Runtime de l'application
- **Gitleaks** — Installé localement (D:\DevSecOps\tools\gitleaks\)
- **Git** — Gestion des branches

---

## 📚 Références

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Gitleaks Documentation](https://github.com/gitleaks/gitleaks)
- [Semgrep Rules](https://semgrep.dev/r)
- [Trivy Documentation](https://trivy.dev)
- [Checkov Documentation](https://www.checkov.io)
- [OWASP ZAP Documentation](https://www.zaproxy.org)
- [DevSecOps Manifesto](https://www.devsecops.org)

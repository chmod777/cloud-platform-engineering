# LAB 4 - Artifact Registry privé → OpenShift Developer Sandbox

[Architecture et résultats](../docs/lab-04-hybrid-openshift.md)

Guide à exécuter depuis la racine du dépôt dans un terminal Bash. Ces commandes
créent des ressources lors d'une future session autorisée ; la rédaction du lab
ne les exécute pas. Les ressources de la session initiale ont été supprimées.

## 1. Prérequis et périmètre

- Docker avec Buildx, Python 3, gcloud, Terraform >= 1.5 et CLI `oc` compatible
  avec le Sandbox ; accès réseau au registre et à la route HTTPS.
- Session gcloud avec le compte et le projet attendus ; authentification ADC
  disponible pour Terraform. Connexion `oc login` depuis la console du Sandbox,
  sans recopier sa commande contenant un token dans Git ou un compte rendu.
- Projet `cloud-platform-engineering-hs`, région `europe-west9`, namespace
  `hassensiad06-dev` existant, quota pour deux pods et un pod de surge.
- Droits GCP permettant les ressources du `prepare` LAB 3 et la publication
  (`roles/artifactregistry.writer` sur le dépôt). Le jeton de pull doit permettre
  la lecture (`roles/artifactregistry.reader` suffit). Le parcours ci-dessous
  utilise l'identité gcloud courante : ses droits accompagnent le jeton.
  Préférer une identité de lecture dédiée avec impersonation si disponible ;
  cela exige les droits de génération de jeton sur cette identité.
- Droits OpenShift de gérer Deployment, Service, Route, ServiceAccount et Secret
  dans ce namespace. Aucun droit administrateur cluster ni SCC `anyuid` requis.
- Vérifier dans la console GCP les crédits, leur expiration et le statut de
  facturation avant toute création. Les quotas ne plafonnent pas les coûts.

```bash
gcloud auth list --filter=status:ACTIVE
gcloud config get-value project
oc whoami
oc project hassensiad06-dev
oc get resourcequota,limitrange -n hassensiad06-dev
oc get deployment,service,route,serviceaccount,secret -n hassensiad06-dev --ignore-not-found \
  | grep -E 'fastapi-lab4|gar-pull-lab4' || true
```

Si les noms existent déjà, vérifier leur propriétaire avant de poursuivre : ne
pas écraser un workload existant. Ne jamais supprimer le namespace partagé.
Les commandes suivantes ciblent explicitement le namespace.

## 2. Reconstruire et publier une image disponible

L'ancien digest est une preuve historique, pas une image réutilisable. Réutiliser
les sources LAB 3 en lecture seule ; le message `/` reste celui du LAB 3.

```bash
python3 -m venv lab3/.venv
lab3/.venv/bin/pip install -r lab3/requirements-dev.txt
(cd lab3 && .venv/bin/python -m pytest app_tests -v)
docker buildx build --platform linux/amd64 --load -t lab4-api:local lab3
docker run --rm -d --name lab4-api-test --user 1004890000:0 \
  -p 127.0.0.1:8080:8080 -e APP_ENV=openshift-lab4 lab4-api:local
curl --fail http://127.0.0.1:8080/health
curl --fail http://127.0.0.1:8080/
docker stop lab4-api-test

terraform -chdir=lab3/infra init -lockfile=readonly
./lab3/lifecycle prepare
# Examiner le plan avant l'application avec confirmation intégrée.
./lab3/lifecycle prepare --apply

gcloud auth configure-docker europe-west9-docker.pkg.dev
IMAGE=europe-west9-docker.pkg.dev/cloud-platform-engineering-hs/lab3-api/api:lab3
docker tag lab4-api:local "$IMAGE"
docker push "$IMAGE"
DIGEST=$(gcloud artifacts docker images describe "$IMAGE" \
  --project=cloud-platform-engineering-hs --format='value(image_summary.digest)')
[[ "$DIGEST" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo 'Digest invalide'; exit 1; }
export LAB4_IMAGE="${IMAGE%:*}@$DIGEST"
```

Le `prepare` existant crée aussi l'identité runtime LAB 3 et active ses API ; il
ne déploie pas Cloud Run. Ne pas exécuter `lifecycle deploy` pour ce lab. Conserver
l'état local jusqu'au nettoyage. Le build n'est pas identique bit à bit garanti :
image de base et dépendances transitives ne sont pas entièrement verrouillées.

## 3. Pull secret temporaire, sans clé de compte de service

Le jeton OAuth expire normalement après 60 minutes. Le secret Kubernetes contient
ce jeton, encodé et non chiffré par base64 : il reste sensible. Il ne faut jamais
versionner un export de Secret, afficher sa valeur ni activer `set -x`.
Le jeton n'est pas placé dans les arguments de processus ; un fichier Docker
privé hors dépôt est supprimé même si l'opération échoue.

Exécuter ce bloc dans un sous-shell Bash avec `pipefail` :

```bash
(
  set -euo pipefail
  set +x
  umask 077
  AUTH_DIR=$(mktemp -d)
  trap 'rm -rf "$AUTH_DIR"' EXIT
  gcloud auth print-access-token | python3 -c '
import sys, json, base64
from pathlib import Path
token = sys.stdin.read().strip()
if not token:
    raise SystemExit("Jeton absent")
auth = base64.b64encode(("oauth2accesstoken:" + token).encode()).decode()
Path(sys.argv[1]).write_text(json.dumps({"auths": {
    "europe-west9-docker.pkg.dev": {"auth": auth}}}))
' "$AUTH_DIR/config.json"
  oc create secret generic gar-pull-lab4 -n hassensiad06-dev \
    --type=kubernetes.io/dockerconfigjson \
    --from-file=.dockerconfigjson="$AUTH_DIR/config.json" \
    --dry-run=client -o yaml | oc apply -n hassensiad06-dev -f -
)
```

Répéter ce bloc avant expiration si un nouveau pull est nécessaire (scaling,
rollout, rollback ou replanification). Les pods déjà démarrés peuvent continuer,
mais cela ne garantit pas les futurs démarrages. En cas d'`ImagePullBackOff`,
vérifier événements, digest, droits GCP et validité du jeton. L'absence de clé
persistante n'élimine pas la présence temporaire d'un secret dans le cluster.

## 4. Déployer et vérifier HTTPS

Le fichier contient un marqueur volontairement invalide `IMAGE_BY_DIGEST`.
Il faut le remplacer par le digest fraîchement publié avant application.
Aucun Secret n'est inclus dans les manifests.

```bash
: "${LAB4_IMAGE:?Reconstruire et publier l image avant de continuer}"
[[ "$LAB4_IMAGE" =~ ^europe-west9-docker\.pkg\.dev/cloud-platform-engineering-hs/lab3-api/api@sha256:[0-9a-f]{64}$ ]] || exit 1
# Prévisualiser les objets, puis appliquer le même rendu.
sed "s|IMAGE_BY_DIGEST|$LAB4_IMAGE|g" lab4/manifests/workload.yaml \
  | oc apply -n hassensiad06-dev --dry-run=server -f -
sed "s|IMAGE_BY_DIGEST|$LAB4_IMAGE|g" lab4/manifests/workload.yaml \
  | oc apply -n hassensiad06-dev -f -
oc rollout status deployment/fastapi-lab4 -n hassensiad06-dev --timeout=180s
HOST=$(oc get route fastapi-lab4 -n hassensiad06-dev -o jsonpath='{.spec.host}')
curl --fail --show-error "https://$HOST/health"
curl --fail --show-error "https://$HOST/"
```

Attendre `{"status":"ok"}` et `environment=openshift-lab4`. Ne pas utiliser `-k` :
le test doit vérifier le certificat. La route est publique et l'API ne possède
pas d'authentification applicative. TLS est terminé au routeur (edge), puis HTTP
vers le Service sur 8080 ; ce n'est pas du TLS de bout en bout.

## 5. Scaling, mise à jour et rollback

```bash
oc scale deployment/fastapi-lab4 -n hassensiad06-dev --replicas=2
oc rollout status deployment/fastapi-lab4 -n hassensiad06-dev --timeout=180s
oc get pods -n hassensiad06-dev -l app=fastapi-lab4 -o wide
curl --fail "https://$HOST/health"
oc scale deployment/fastapi-lab4 -n hassensiad06-dev --replicas=1
oc rollout status deployment/fastapi-lab4 -n hassensiad06-dev --timeout=180s

oc rollout history deployment/fastapi-lab4 -n hassensiad06-dev
# Noter la révision de référence avant la modification.
oc set env deployment/fastapi-lab4 -n hassensiad06-dev APP_ENV=openshift-lab4-v2
oc rollout status deployment/fastapi-lab4 -n hassensiad06-dev --timeout=180s
curl --fail "https://$HOST/"
oc rollout undo deployment/fastapi-lab4 -n hassensiad06-dev
oc rollout status deployment/fastapi-lab4 -n hassensiad06-dev --timeout=180s
curl --fail "https://$HOST/"
```

Vérifier deux pods Ready et leurs nœuds, puis le retour à un pod. L'anti-affinité
est préférée : deux nœuds distincts dépendent de la capacité du Sandbox et ne
sont pas garantis. La v2 doit retourner `openshift-lab4-v2`, le rollback
`openshift-lab4`. `undo` restaure la révision précédente du template, pas les
secrets ni le Service. Sans mutation intermédiaire, il s'agit de la référence
notée ; sinon choisir explicitement `--to-revision` après inspection.
Les probes et `maxUnavailable: 0` encadrent le rollout, sans prouver une absence
totale de requêtes perdues. Aucun test de charge ou HPA n'a été réalisé.

## 6. Vérifier RBAC, SCC et identité Linux

```bash
oc auth can-i create deployments.apps -n hassensiad06-dev \
  --as=system:serviceaccount:hassensiad06-dev:fastapi-lab4
oc auth can-i get secrets -n hassensiad06-dev \
  --as=system:serviceaccount:hassensiad06-dev:fastapi-lab4
POD=$(oc get pods -n hassensiad06-dev -l app=fastapi-lab4 \
  -o jsonpath='{.items[0].metadata.name}')
oc get pod "$POD" -n hassensiad06-dev \
  -o jsonpath='{.metadata.annotations.openshift\.io/scc}{"\n"}{.spec.containers[0].securityContext}{"\n"}'
oc exec -n hassensiad06-dev "$POD" -- id
oc exec -n hassensiad06-dev "$POD" -- sh -c \
  'grep -E "^(Uid|NoNewPrivs|CapEff|CapBnd):" /proc/1/status'
```

Attendre `no` pour les deux permissions, `restricted-v2` pour la SCC de la
session de référence, un UID non-root du namespace, `NoNewPrivs: 1` et des masques
`CapEff`/`CapBnd` nuls. Une erreur d'impersonation n'est pas une preuve de refus
RBAC : demander alors une vérification à un administrateur autorisé, sans
accorder des droits supplémentaires au workload. Le manifeste ne crée aucun
RoleBinding et désactive le montage du token API du ServiceAccount.

Ne pas fixer `runAsUser: 1004890000` : cet UID était celui observé dans ce
namespace. OpenShift doit attribuer un UID autorisé par sa SCC. Le Dockerfile
LAB 3 déclare 10001, remplacé à l'admission ; son code et ses dépendances sont
lisibles par l'UID arbitraire et l'API n'a pas besoin d'écrire dans `/app`.
La sélection des SCC dépend de la version et des politiques du Sandbox ;
vérifier l'annotation réelle, ne pas demander `anyuid` pour contourner un échec.

## 7. Nettoyer, même après une session partielle

Inspecter les objets nommés, puis supprimer seulement les objets de ce lab :

```bash
oc delete route,service,deployment,serviceaccount fastapi-lab4 \
  -n hassensiad06-dev --ignore-not-found
oc delete secret gar-pull-lab4 -n hassensiad06-dev --ignore-not-found
oc get route,service,deployment,serviceaccount fastapi-lab4 \
  -n hassensiad06-dev --ignore-not-found
oc get secret gar-pull-lab4 -n hassensiad06-dev --ignore-not-found
oc get pods,replicasets -n hassensiad06-dev -l app=fastapi-lab4

./lab3/lifecycle clean
# Vérifier que le plan ne cible que les ressources temporaires LAB 3.
./lab3/lifecycle clean --apply
terraform -chdir=lab3/infra state list
gcloud artifacts repositories list --location=europe-west9 \
  --project=cloud-platform-engineering-hs
gcloud run services list --region=europe-west9 \
  --project=cloud-platform-engineering-hs
```

Attendre la suppression des pods et ReplicaSets, des objets nommés, un état LAB 3
vide et les inventaires régionaux attendus. Si d'autres ressources existent,
ne pas les supprimer pour obtenir un inventaire vide. Une erreur API n'est pas
un résultat vide. Le nettoyage LAB 3 détruit tout ce que son état gère, y compris
un éventuel Cloud Run LAB 3 : vérifier qu'aucune autre session ne l'utilise.
Ne pas supprimer les applications Telco, le projet Sandbox, ni exécuter destroy
sur `terraform/environments/dev`. Les API GCP restent activées selon la
configuration LAB 3. Conserver l'état en cas d'échec et résoudre le nettoyage.
Ces vérifications ne garantissent pas l'absence de coût ailleurs dans le projet.

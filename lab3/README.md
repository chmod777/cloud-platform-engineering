# LAB 3 - Docker, FastAPI et Cloud Run

[Architecture et rapport technique](../docs/lab-03-cloud-run.md) · [Résultats vérifiés](RESULTATS.md)

Statut : cycle réel de déploiement et nettoyage terminé le 29 octobre 2026.

## 1. Comprendre et tester l'API

Une API expose des chemins HTTP. `GET /health` confirme que le processus répond ;
`GET /` retourne un message et la variable d'environnement APP_ENV.
Une variable configure la même image sans reconstruire son code ; ne pas y placer de secret.

Depuis la racine du dépôt :

```bash
python3 -m venv lab3/.venv
lab3/.venv/bin/pip install -r lab3/requirements-dev.txt
(cd lab3 && .venv/bin/python -m pytest app_tests -v)
(cd lab3 && .venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8080)
```

Dans un second terminal : `curl --fail http://127.0.0.1:8080/health`.
Arrêter le serveur avec Ctrl-C.

## 2. Construire le conteneur localement

Docker, Buildx et Colima ont été installés sur ce Mac pendant la session.
Pour les prochaines sessions : `colima start --cpu 2 --memory 2`.
À la fin : `colima stop` (cela arrête seulement le moteur local, pas GCP).
L'émulation amd64 fonctionne via QEMU ; Rosetta n'a pas été installée. L'image contient Python et les
bibliothèques, le conteneur est un processus lancé à partir de cette image.
L'utilisateur 10001 évite d'exécuter l'application comme root. Le contexte Docker
exclut notamment les identifiants, l'état Terraform et l'environnement local.
Cloud Run attend Linux amd64 et une écoute sur 0.0.0.0:$PORT.

```bash
docker buildx build --platform linux/amd64 --load -t lab3-api:local lab3
docker run --rm -d --name lab3-api-test -p 127.0.0.1:8080:8080 -e APP_ENV=docker lab3-api:local
curl --fail http://127.0.0.1:8080/health
curl --fail http://127.0.0.1:8080/
docker stop lab3-api-test
```

## 3. Facturation : condition préalable

Vérifier dans la console le statut **Essai gratuit**, le solde et sa date
 d'expiration. Ne jamais activer le compte payant dans ce lab. Une API qui retourne
`billingEnabled=true` ne prouve pas le statut d'essai. Un budget est une alerte,
pas une limite de dépense. Le maximum d'instances ne constitue pas un plafond financier.

Le service utilise 1 CPU, 256 MiB, facturation à la requête, minimum zéro,
maximum une instance au niveau service. L'image stockée reste potentiellement
facturable même sans trafic : supprimer le dépôt à la fin. Les logs peuvent
persister après suppression et engendrer des coûts selon volume/rétention.
Aucun Cloud Build, NAT, connecteur VPC, équilibreur ou VM ajouté.

## 4. Préparer Artifact Registry avec Terraform

Terraform décrit l'état souhaité. Son état local relie les ressources déclarées
aux objets GCP. `lab3/infra` utilise un état indépendant de `terraform/environments/dev`.
Ne jamais lancer destroy dans l'environnement des LAB 1 et 2.
Le script utilise un plan sauvegardé, contrôle son périmètre, puis applique ce plan précis.
Sans `--apply`, il ne crée rien. Les changements et remplacements sont refusés.
Ne pas modifier les fichiers ni changer de compte pendant une opération.

```bash
terraform -chdir=lab3/infra init -lockfile=readonly
./lab3/lifecycle prepare
./lab3/lifecycle prepare --apply
```

Cela active les API nécessaires et crée un dépôt `lab3-api` à Paris et une identité
 d'exécution sans rôle projet. Aucune clé de compte de service n'est créée.
Les API activées restent activées après nettoyage pour préserver les autres usages.

## 5. Publier l'image et déployer

Artifact Registry est le registre privé des images. Le digest sha256 identifie
exactement le contenu déployé, contrairement à une étiquette modifiable.

```bash
gcloud auth configure-docker europe-west9-docker.pkg.dev
IMAGE=europe-west9-docker.pkg.dev/cloud-platform-engineering-hs/lab3-api/api:lab3
docker tag lab3-api:local "$IMAGE"
docker push "$IMAGE"
DIGEST=$(gcloud artifacts docker images describe "$IMAGE" --project=cloud-platform-engineering-hs --format='value(image_summary.digest)')
export LAB3_IMAGE="europe-west9-docker.pkg.dev/cloud-platform-engineering-hs/lab3-api/api@$DIGEST"
./lab3/lifecycle deploy
./lab3/lifecycle deploy --apply
```

L'opérateur a besoin des droits de déploiement et `iam.serviceAccounts.actAs` ;
un refus IAM doit être diagnostiqué sans attribuer aveuglément Owner/Editor.
Aucune autorisation `allUsers` : le service est accessible par réseau mais protégé
par IAM. L'identité d'exécution et l'identité de l'utilisateur qui appelle sont distinctes.

```bash
URL=$(terraform -chdir=lab3/infra output -raw url)
curl --fail -H "Authorization: Bearer $(gcloud auth print-identity-token)" "$URL/health"
curl -s -o /dev/null -w '%{http_code}\n' "$URL/health"
gcloud run services logs read lab3-api --project=cloud-platform-engineering-hs --region=europe-west9 --limit=10
```

Attendre 200 avec une identité autorisée (permission run.routes.invoke),
et un refus sans jeton. Pas de test de charge : le retour à zéro est un comportement
configuré, pas une preuve de montée en charge observée.

## 6. Nettoyer dès la fin, y compris après un échec partiel

```bash
./lab3/lifecycle clean
./lab3/lifecycle clean --apply
gcloud run services list --project=cloud-platform-engineering-hs --region=europe-west9 --filter='metadata.name=lab3-api'
gcloud artifacts repositories list --project=cloud-platform-engineering-hs --location=europe-west9 --filter='name:lab3-api'
terraform -chdir=lab3/infra state list
./scripts/lab-status
```

Le nettoyage supprime uniquement les ressources gérées par l'état LAB 3, dont le
dépôt et ses images. Il ne constitue pas un inventaire exhaustif du projet.
Ne pas effacer l'état avant un nettoyage réussi. En cas d'échec, conserver l'état,
relancer le plan de nettoyage et vérifier les ressources dans la console.
Les dépenses déjà engagées ne sont pas annulées par la suppression.

## Sources

- https://cloud.google.com/signup-faqs
- https://docs.cloud.google.com/run/docs/container-contract
- https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service
